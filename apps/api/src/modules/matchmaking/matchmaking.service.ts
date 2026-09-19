import { Injectable, Logger } from '@nestjs/common';
import { GameMode } from '@prisma/client';
import { RedisService } from '../../redis/redis.service';
import { GamesService } from '../games/games.service';
import { BotService } from '../games/bot.service';
import { teamsForPlayerCount } from '../games/domain/game-state';

export interface MatchFound { gameId: string; userIds: string[]; socketIds: string[]; mode: GameMode; isBotMatch?: boolean }
interface QueueMember { userId: string; socketId: string }

@Injectable()
export class MatchmakingService {
  private readonly logger = new Logger(MatchmakingService.name);
  constructor(private readonly redis: RedisService, private readonly games: GamesService, private readonly bots: BotService) {}

  async join(userId: string, socketId: string, mode: GameMode): Promise<MatchFound | null> {
    const size = mode === GameMode.ONLINE_2P ? 2 : mode === GameMode.ONLINE_4P ? 4 : 0;
    if (!size) throw new Error('Unsupported matchmaking mode');
    await this.redis.ensureConnected();
    await this.leave(userId);
    const member = JSON.stringify({ userId, socketId });
    const key = this.queue(mode);
    const now = Date.now();
    await this.redis.client
      .multi()
      .zremrangebyscore(key, 0, now - 120_000)
      .zadd(key, now, member)
      .set(`matchmaking:user:${userId}`, mode, 'EX', 180)
      .set(`matchmaking:socket:${socketId}`, userId, 'EX', 180)
      .exec();

    const popped = await this.popCompleteGroup(key, size);
    if (!popped.length) return null;
    const players = popped.map(({ member: value }) => JSON.parse(value) as QueueMember);
    if (new Set(players.map((player) => player.userId)).size !== size) {
      await this.requeue(key, popped);
      return null;
    }

    try {
      const state = await this.games.createMatch(players.map((player) => player.userId), mode);
      await this.redis.client.del(
        ...players.flatMap((player) => [`matchmaking:user:${player.userId}`, `matchmaking:socket:${player.socketId}`]),
      );
      return {
        gameId: state.gameId,
        userIds: players.map((player) => player.userId),
        socketIds: players.map((player) => player.socketId),
        mode,
      };
    } catch (error) {
      await this.requeue(key, popped);
      throw error;
    }
  }

  async leave(userId: string): Promise<void> {
    await this.removeEntries((member) => member.userId === userId);
    await this.redis.client.del(`matchmaking:user:${userId}`);
  }

  async leaveSocket(userId: string, socketId: string): Promise<void> {
    await this.removeEntries((member) => member.userId === userId && member.socketId === socketId);
    await this.redis.client.del(`matchmaking:socket:${socketId}`);
  }

  private async removeEntries(predicate: (member: QueueMember) => boolean): Promise<void> {
    await this.redis.ensureConnected();
    for (const mode of [GameMode.ONLINE_2P, GameMode.ONLINE_4P]) {
      const entries = await this.redis.client.zrange(this.queue(mode), 0, -1);
      const own = entries.filter((entry) => {
        const member = this.parse(entry);
        return member != null && predicate(member);
      });
      if (own.length) await this.redis.client.zrem(this.queue(mode), ...own);
      const sockets = own.map((entry) => this.parse(entry)?.socketId).filter((id): id is string => id != null);
      if (sockets.length) await this.redis.client.del(...sockets.map((id) => `matchmaking:socket:${id}`));
    }
  }

  private async popCompleteGroup(key: string, size: number): Promise<Array<{ member: string; score: number }>> {
    const script = `
      if redis.call('ZCARD', KEYS[1]) < tonumber(ARGV[1]) then return {} end
      return redis.call('ZPOPMIN', KEYS[1], tonumber(ARGV[1]))
    `;
    const raw = await this.redis.client.eval(script, 1, key, size) as string[];
    const result: Array<{ member: string; score: number }> = [];
    for (let index = 0; index < raw.length; index += 2) {
      result.push({ member: raw[index], score: Number(raw[index + 1]) });
    }
    return result;
  }

  private async requeue(key: string, entries: Array<{ member: string; score: number }>): Promise<void> {
    if (!entries.length) return;
    await this.redis.client.zadd(key, ...entries.flatMap((entry) => [entry.score, entry.member]));
  }

  private parse(value: string): QueueMember | null {
    try { return JSON.parse(value) as QueueMember; }
    catch { return null; }
  }

  private queue(mode: GameMode): string { return `matchmaking:${mode}`; }

  /**
   * Called after 15 seconds of waiting. Pops up to `size` oldest waiting
   * players for the given mode and fills the rest with Persian-named bots.
   * If the requesting user is no longer queued (already matched/left),
   * returns null and requeues any popped members.
   */
  async tryCreateBotMatch(requestingUserId: string, mode: GameMode): Promise<MatchFound | null> {
    const size = mode === GameMode.ONLINE_2P ? 2 : mode === GameMode.ONLINE_4P ? 4 : 0;
    if (!size) return null;
    await this.redis.ensureConnected();
    const key = this.queue(mode);

    // Atomically pop up to size oldest members
    const script = `
      local count = tonumber(ARGV[1])
      local members = redis.call('ZPOPMIN', KEYS[1], count)
      return members
    `;
    const raw = await this.redis.client.eval(script, 1, key, size) as string[];
    const popped: Array<{ member: string; score: number }> = [];
    for (let i = 0; i < raw.length; i += 2) {
      popped.push({ member: raw[i], score: Number(raw[i + 1]) });
    }

    if (!popped.length) return null;

    const players = popped.map(({ member }) => this.parse(member)).filter((m): m is QueueMember => m != null);

    // If requesting user not among popped, they were already matched elsewhere -> requeue and abort
    if (!players.some(p => p.userId === requestingUserId)) {
      await this.requeue(key, popped);
      return null;
    }

    // Ensure unique userIds among popped (avoid duplicate user with multiple sockets)
    const uniqueMap = new Map<string, QueueMember>();
    for (const p of players) {
      if (!uniqueMap.has(p.userId)) uniqueMap.set(p.userId, p);
    }
    const uniquePlayers = Array.from(uniqueMap.values());

    // If duplicates were popped, requeue extras
    if (uniquePlayers.length !== players.length) {
      // Find duplicates to requeue
      const seen = new Set<string>();
      const toRequeue: Array<{ member: string; score: number }> = [];
      for (const entry of popped) {
        const parsed = this.parse(entry.member);
        if (!parsed) continue;
        if (seen.has(parsed.userId)) toRequeue.push(entry);
        else seen.add(parsed.userId);
      }
      if (toRequeue.length) await this.requeue(key, toRequeue);
    }

    const realPlayers = uniquePlayers;
    const botsNeeded = size - realPlayers.length;

    if (botsNeeded < 0) {
      // More real players than needed (should not happen), requeue excess
      const excess = realPlayers.slice(size);
      const excessEntries = popped.filter(e => {
        const pm = this.parse(e.member);
        return pm && excess.some(ex => ex.userId === pm.userId);
      });
      if (excessEntries.length) await this.requeue(key, excessEntries);
      realPlayers.splice(size);
    }

    if (botsNeeded <= 0 && realPlayers.length < size) {
      // Not enough players and no bots needed? Should not happen
      await this.requeue(key, popped);
      return null;
    }

    try {
      const botInfos = botsNeeded > 0 ? await this.bots.createBots(botsNeeded) : [];

      const seating = teamsForPlayerCount(size);
      // Real players get first seats in order of waiting time (oldest first = already popped order)
      // Bots fill remaining seats
      const combined: Array<{ userId: string; team: ReturnType<typeof teamsForPlayerCount>[number]; isBot: boolean }> = [];

      realPlayers.forEach((rp, idx) => {
        combined.push({ userId: rp.userId, team: seating[idx], isBot: false });
      });
      botInfos.forEach((bot, idx) => {
        combined.push({ userId: bot.userId, team: seating[realPlayers.length + idx], isBot: true });
      });

      // Shuffle? Keep seating order as is for deterministic teams

      const state = await this.games.createBotMatch(combined, mode);

      // Register bot game for AI loop
      if (botInfos.length > 0) {
        await this.bots.registerBotGame(state.gameId, botInfos);
      }

      // Cleanup redis keys for real players
      const keysToDel: string[] = [];
      for (const rp of realPlayers) {
        keysToDel.push(`matchmaking:user:${rp.userId}`);
        keysToDel.push(`matchmaking:socket:${rp.socketId}`);
      }
      if (keysToDel.length) await this.redis.client.del(...keysToDel);

      // Also remove any leftover entries for these users in other mode queues (defensive)
      for (const rp of realPlayers) {
        await this.removeEntries((m) => m.userId === rp.userId && m.socketId !== rp.socketId);
      }

      this.logger.log(`Bot match created: ${state.gameId} mode=${mode} real=${realPlayers.length} bots=${botInfos.length}`);

      return {
        gameId: state.gameId,
        userIds: combined.map(c => c.userId),
        socketIds: realPlayers.map(r => r.socketId),
        mode,
        isBotMatch: botInfos.length > 0,
      };
    } catch (error) {
      this.logger.error(`Failed to create bot match for ${requestingUserId}: ${error instanceof Error ? error.message : 'unknown'}`);
      // Requeue real players on failure
      await this.requeue(key, popped);
      throw error;
    }
  }

  /** Check if user is still queued */
  async isQueued(userId: string, mode: GameMode): Promise<boolean> {
    await this.redis.ensureConnected();
    const entries = await this.redis.client.zrange(this.queue(mode), 0, -1);
    return entries.some(e => {
      const m = this.parse(e);
      return m?.userId === userId;
    });
  }
}
