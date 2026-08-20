import { Injectable } from '@nestjs/common';
import { GameMode } from '@prisma/client';
import { RedisService } from '../../redis/redis.service';
import { GamesService } from '../games/games.service';

export interface MatchFound { gameId: string; userIds: string[]; socketIds: string[]; mode: GameMode }
interface QueueMember { userId: string; socketId: string }

@Injectable()
export class MatchmakingService {
  constructor(private readonly redis: RedisService, private readonly games: GamesService) {}

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
}
