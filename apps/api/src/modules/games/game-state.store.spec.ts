import 'reflect-metadata';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { GameStatus, Prisma, Team } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { AuthoritativeGameState, FATTAH_TARGET_TOKEN_ID_MAX } from './domain/game-state';
import { LudoEngine } from './domain/ludo-engine';
import { GameStateStore } from './game-state.store';

interface UsageRow {
  gameId: string;
  userId: string;
  targetTokenId: string;
}

interface Stub {
  /** Reject `fattahUsage.create` instead of inserting. */
  usageError?: Error;
  /** Rows matched by the optimistic snapshot write. */
  gameRows?: number;
  /** Rows matched by the balance decrement (0 means an empty inventory). */
  balanceRows?: number;
}

/**
 * The store is the only writer of `FattahUsage`, and it writes inside the same
 * transaction that moves coins. These tests pin down both: the exact row that
 * reaches PostgreSQL (a 38-character id there fails as P2000 and rolls the whole
 * strike back) and the errors a client is allowed to see.
 */
describe('GameStateStore.persistFattah', () => {
  const players = [{ userId: 'u1', team: Team.BLUE }, { userId: 'u2', team: Team.RED }];

  /** An accepted strike: u1 (blue, on turn) rockets u2's first token off cell 10. */
  function struckState(): { previousVersion: number; state: AuthoritativeGameState } {
    const engine = new LudoEngine(() => 3);
    const state = engine.create('g1', players);
    state.players[1].tokens[0] = 10;
    const result = engine.useFattah(state, 'u1', 'u2', 0);
    return { previousVersion: result.state.version - 1, state: result.state };
  }

  function harness(stub: Stub = {}) {
    const rows: UsageRow[] = [];
    const tx = {
      game: { updateMany: jest.fn(() => Promise.resolve({ count: stub.gameRows ?? 1 })) },
      user: { updateMany: jest.fn(() => Promise.resolve({ count: stub.balanceRows ?? 1 })) },
      fattahUsage: {
        create: jest.fn((args: { data: UsageRow }) => {
          if (stub.usageError) return Promise.reject(stub.usageError);
          rows.push(args.data);
          return Promise.resolve({ id: 'usage-1' });
        }),
      },
    };
    const prisma = { $transaction: jest.fn((work: (client: typeof tx) => Promise<void>) => work(tx)) };
    const queued = {
      set: jest.fn().mockReturnThis(),
      zadd: jest.fn().mockReturnThis(),
      zrem: jest.fn().mockReturnThis(),
      exec: jest.fn(() => Promise.resolve([])),
    };
    const redis = { ensureConnected: jest.fn(() => Promise.resolve()), client: { multi: () => queued } };
    const store = new GameStateStore(prisma as unknown as PrismaService, redis as unknown as RedisService);
    return { store, rows, tx, prisma, queued };
  }

  /** `clientVersion` is required by the generated client even though only `code` is read. */
  function uniqueViolation(): Prisma.PrismaClientKnownRequestError {
    return new Prisma.PrismaClientKnownRequestError('Unique constraint failed on the fields: `(gameId, userId)`', {
      code: 'P2002',
      clientVersion: 'test',
    });
  }

  it('records the board token id inside the same transaction as the snapshot', async () => {
    const { store, rows, tx, queued } = harness();
    const { previousVersion, state } = struckState();

    await store.persistFattah(previousVersion, state, 'u1', 'RT1');

    expect(rows).toEqual([{ gameId: 'g1', userId: 'u1', targetTokenId: 'RT1' }]);
    expect(rows[0].targetTokenId.length).toBeLessThanOrEqual(FATTAH_TARGET_TOKEN_ID_MAX);
    // Optimistic version and status guard on the snapshot write.
    expect(tx.game.updateMany).toHaveBeenCalledWith({
      where: { id: 'g1', version: previousVersion, status: GameStatus.ACTIVE },
      data: { state, version: state.version },
    });
    // The rocket is only taken from a player who still owns one.
    expect(tx.user.updateMany).toHaveBeenCalledWith({
      where: { id: 'u1', fattahBalance: { gt: 0 } },
      data: { fattahBalance: { decrement: 1 } },
    });
    expect(queued.exec).toHaveBeenCalledTimes(1);
  });

  it('refuses an id that would overflow FattahUsage.targetTokenId before opening a transaction', async () => {
    const { store, rows, prisma } = harness();
    const { previousVersion, state } = struckState();
    const uuidPair = `${'0'.repeat(36)}:0`;
    expect(uuidPair.length).toBeGreaterThan(FATTAH_TARGET_TOKEN_ID_MAX);

    await expect(store.persistFattah(previousVersion, state, 'u1', uuidPair)).rejects.toThrow(
      new RegExp(`1\\.\\.${FATTAH_TARGET_TOKEN_ID_MAX} characters`),
    );
    await expect(store.persistFattah(previousVersion, state, 'u1', '')).rejects.toThrow(/targetTokenId/);

    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(rows).toEqual([]);
  });

  it('reports a repeated strike as FATTAH_ALREADY_USED instead of a raw constraint error', async () => {
    const { store, rows } = harness({ usageError: uniqueViolation() });
    const { previousVersion, state } = struckState();

    const error: unknown = await store
      .persistFattah(previousVersion, state, 'u1', 'RT1')
      .catch((caught: unknown) => caught);

    expect(error).toBeInstanceOf(BadRequestException);
    expect((error as BadRequestException).getResponse()).toEqual({
      code: 'FATTAH_ALREADY_USED',
      message: 'Fattah is limited to once per game',
    });
    expect(rows).toEqual([]);
  });

  it('rethrows an unrelated database failure unchanged', async () => {
    const failure = new Error('connection terminated');
    const { store } = harness({ usageError: failure });
    const { previousVersion, state } = struckState();

    await expect(store.persistFattah(previousVersion, state, 'u1', 'RT1')).rejects.toBe(failure);
  });

  it('rejects an empty inventory without recording a usage', async () => {
    const { store, rows } = harness({ balanceRows: 0 });
    const { previousVersion, state } = struckState();

    await expect(store.persistFattah(previousVersion, state, 'u1', 'RT1')).rejects.toThrow(ConflictException);
    expect(rows).toEqual([]);
  });

  it('rejects a stale snapshot version and a lost optimistic race', async () => {
    const stale = harness();
    const { previousVersion, state } = struckState();

    await expect(stale.store.persistFattah(state.version, state, 'u1', 'RT1')).rejects.toThrow('Invalid state version');
    expect(stale.prisma.$transaction).not.toHaveBeenCalled();

    const raced = harness({ gameRows: 0 });
    await expect(raced.store.persistFattah(previousVersion, state, 'u1', 'RT1')).rejects.toThrow(ConflictException);
    expect(raced.rows).toEqual([]);
  });
});
