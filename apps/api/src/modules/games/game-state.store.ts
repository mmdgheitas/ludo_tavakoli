import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { GameStatus, Prisma, TransactionStatus, TransactionType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { AuthoritativeGameState, FATTAH_TARGET_TOKEN_ID_MAX } from './domain/game-state';

@Injectable()
export class GameStateStore {
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService) {}

  async get(gameId: string): Promise<AuthoritativeGameState> {
    await this.redis.ensureConnected();
    const cached = await this.redis.client.get(this.key(gameId));
    if (cached) return JSON.parse(cached) as AuthoritativeGameState;
    const game = await this.prisma.game.findUnique({ where: { id: gameId }, select: { state: true } });
    if (!game) throw new NotFoundException('Game not found');
    const state = game.state as unknown as AuthoritativeGameState;
    await this.cache(state);
    return state;
  }

  async persist(previousVersion: number, state: AuthoritativeGameState): Promise<void> {
    if (state.version !== previousVersion + 1) throw new ConflictException('Invalid state version');
    await this.prisma.$transaction(async (tx) => {
      const result = await tx.game.updateMany({
        where: { id: state.gameId, version: previousVersion },
        data: {
          state: state as unknown as Prisma.InputJsonValue,
          version: state.version,
          status: state.phase === 'FINISHED'
            ? (state.winnerId ? GameStatus.FINISHED : GameStatus.CANCELLED)
            : state.phase === 'WAITING_PLAYERS'
              ? GameStatus.WAITING
              : GameStatus.ACTIVE,
          winnerId: state.winnerId ?? undefined,
          finishedAt: state.phase === 'FINISHED' ? new Date() : undefined,
        },
      });
      if (result.count !== 1) throw new ConflictException('Game state changed; synchronize and retry');
      if (state.winnerId) await this.awardWinner(tx, state.gameId, state.winnerId);
    });
    await this.cache(state);
  }

  async persistFattah(
    previousVersion: number,
    state: AuthoritativeGameState,
    userId: string,
    targetTokenId: string,
  ): Promise<void> {
    if (state.version !== previousVersion + 1) throw new ConflictException('Invalid state version');
    // Check the width before opening the transaction. An oversized id otherwise
    // fails as Prisma P2000 ("value too long for the column's type") with no
    // column named, after the snapshot write and the balance decrement have
    // already run and are about to roll back with it.
    if (targetTokenId.length === 0 || targetTokenId.length > FATTAH_TARGET_TOKEN_ID_MAX) {
      throw new Error(
        `Fattah targetTokenId must be 1..${FATTAH_TARGET_TOKEN_ID_MAX} characters to fit FattahUsage.targetTokenId, got ${targetTokenId.length}`,
      );
    }
    await this.prisma.$transaction(async (tx) => {
      const game = await tx.game.updateMany({
        where: { id: state.gameId, version: previousVersion, status: GameStatus.ACTIVE },
        data: { state: state as unknown as Prisma.InputJsonValue, version: state.version },
      });
      if (game.count !== 1) throw new ConflictException('Game state changed; synchronize and retry');
      const balance = await tx.user.updateMany({
        where: { id: userId, fattahBalance: { gt: 0 } },
        data: { fattahBalance: { decrement: 1 } },
      });
      if (balance.count !== 1) throw new ConflictException('Fattah inventory is empty');
      try {
        await tx.fattahUsage.create({ data: { gameId: state.gameId, userId, targetTokenId } });
      } catch (error) {
        // A stale Redis snapshot can still report `fattahUsed: false` after this
        // game already consumed the rocket. The unique (gameId,userId) proof is
        // authoritative, so surface the same friendly rule error instead of a
        // raw constraint failure.
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
          throw new BadRequestException({ code: 'FATTAH_ALREADY_USED', message: 'Fattah is limited to once per game' });
        }
        throw error;
      }
    });
    await this.cache(state);
  }

  async invalidate(gameId: string): Promise<void> {
    await this.redis.ensureConnected();
    await this.redis.client.del(this.key(gameId));
    await this.redis.client.zrem(this.deadlinesKey, gameId);
  }

  async prime(state: AuthoritativeGameState): Promise<void> {
    await this.cache(state);
  }

  async dueGameIds(now = Date.now()): Promise<string[]> {
    await this.redis.ensureConnected();
    return this.redis.client.zrangebyscore(this.deadlinesKey, 0, now);
  }

  private async awardWinner(tx: Prisma.TransactionClient, gameId: string, userId: string): Promise<void> {
    const user = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { coinBalance: true, vipExpiresAt: true } });
    const reward = user.vipExpiresAt && user.vipExpiresAt > new Date() ? 200 : 100;
    const updated = await tx.user.update({ where: { id: userId }, data: { coinBalance: { increment: reward } }, select: { coinBalance: true } });
    await tx.game.update({ where: { id: gameId }, data: { rewardCoins: reward } });
    await tx.gameParticipant.update({ where: { gameId_userId: { gameId, userId } }, data: { placement: 1, score: reward } });
    await tx.walletTransaction.create({
      data: {
        userId,
        type: TransactionType.GAME_REWARD,
        status: TransactionStatus.SUCCEEDED,
        amount: reward,
        balanceAfter: updated.coinBalance,
        idempotencyKey: `game-reward:${gameId}:${userId}`,
        referenceId: gameId,
      },
    });
  }

  private async cache(state: AuthoritativeGameState): Promise<void> {
    await this.redis.ensureConnected();
    const transaction = this.redis.client.multi().set(this.key(state.gameId), JSON.stringify(state), 'EX', 3600);
    if (state.turnDeadlineAt && state.phase !== 'FINISHED' && state.phase !== 'WAITING_PLAYERS') {
      transaction.zadd(this.deadlinesKey, Date.parse(state.turnDeadlineAt), state.gameId);
    } else {
      transaction.zrem(this.deadlinesKey, state.gameId);
    }
    await transaction.exec();
  }

  private readonly deadlinesKey = 'game:turn-deadlines';
  private key(gameId: string): string { return `game:${gameId}:state`; }
}
