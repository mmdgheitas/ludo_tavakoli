import { randomUUID } from 'node:crypto';
import { ConflictException, Injectable } from '@nestjs/common';
import { RedisService } from '../../redis/redis.service';

@Injectable()
export class GameLockService {
  constructor(private readonly redis: RedisService) {}

  async run<T>(gameId: string, action: () => Promise<T>): Promise<T> {
    await this.redis.ensureConnected();
    const key = `lock:game:${gameId}`;
    const token = randomUUID();
    for (let attempt = 0; attempt < 12; attempt += 1) {
      const acquired = await this.redis.client.set(key, token, 'PX', 4000, 'NX');
      if (acquired === 'OK') {
        try { return await action(); }
        finally {
          await this.redis.client.eval(
            "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
            1, key, token,
          );
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 40 + attempt * 10));
    }
    throw new ConflictException('Game is busy; retry the action');
  }
}
