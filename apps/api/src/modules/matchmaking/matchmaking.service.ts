import { Injectable } from '@nestjs/common';
import { GameMode } from '@prisma/client';
import { RedisService } from '../../redis/redis.service';
import { GamesService } from '../games/games.service';

export interface MatchFound { gameId: string; userIds: string[]; socketIds: string[] }

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
    await this.redis.client.zadd(key, Date.now(), member);
    await this.redis.client.set(`matchmaking:user:${userId}`, mode, 'EX', 300);

    const popped = await this.redis.client.zpopmin(key, size);
    const entries: string[] = [];
    for (let index = 0; index < popped.length; index += 2) entries.push(popped[index]);
    if (entries.length < size) {
      for (const entry of entries) await this.redis.client.zadd(key, Date.now(), entry);
      return null;
    }
    const players = entries.map((entry) => JSON.parse(entry) as { userId: string; socketId: string });
    if (new Set(players.map((player) => player.userId)).size !== size) {
      for (const entry of entries) await this.redis.client.zadd(key, Date.now(), entry);
      return null;
    }
    const state = await this.games.createMatch(players.map((player) => player.userId), mode);
    await this.redis.client.del(...players.map((player) => `matchmaking:user:${player.userId}`));
    return { gameId: state.gameId, userIds: players.map((player) => player.userId), socketIds: players.map((player) => player.socketId) };
  }

  async leave(userId: string): Promise<void> {
    await this.redis.ensureConnected();
    for (const mode of [GameMode.ONLINE_2P, GameMode.ONLINE_4P]) {
      const entries = await this.redis.client.zrange(this.queue(mode), 0, -1);
      const own = entries.filter((entry) => {
        try { return (JSON.parse(entry) as { userId: string }).userId === userId; }
        catch { return false; }
      });
      if (own.length) await this.redis.client.zrem(this.queue(mode), ...own);
    }
    await this.redis.client.del(`matchmaking:user:${userId}`);
  }

  private queue(mode: GameMode): string { return `matchmaking:${mode}`; }
}
