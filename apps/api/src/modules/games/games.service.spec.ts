import 'reflect-metadata';
import { BadRequestException } from '@nestjs/common';
import { Team } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthoritativeGameState, FATTAH_TARGET_TOKEN_ID_MAX } from './domain/game-state';
import { LudoEngine } from './domain/ludo-engine';
import { GameLockService } from './game-lock.service';
import { GameStateStore } from './game-state.store';
import { GamesService } from './games.service';

/**
 * Real-width user ids: the bug this suite guards was `${targetUserId}:${index}`,
 * which is 38 characters against a `VARCHAR(32)` column. Short fixtures such as
 * `u1` would have fit and hidden it.
 */
const ACTOR = '11111111-1111-4111-8111-111111111111';
const VICTIM = '22222222-2222-4222-8222-222222222222';
const THIRD = '33333333-3333-4333-8333-333333333333';
const FOURTH = '44444444-4444-4444-8444-444444444444';

interface PersistedStrike {
  previousVersion: number;
  state: AuthoritativeGameState;
  userId: string;
  targetTokenId: string;
}

interface Stub {
  /** Participant row for the acting user; `null` means a stranger. */
  participant?: { id: string } | null;
}

/**
 * `FattahUsage.targetTokenId` is `VARCHAR(32)`. Persisting a UUID pair there is
 * rejected by PostgreSQL as Prisma P2000 ("value too long for the column's
 * type"), which rolls the whole transaction back: the snapshot is not written,
 * the rocket is not deducted and the player only sees a database error.
 */
describe('GamesService.useFattah', () => {
  const gameId = 'g1';
  type Seating = Array<{ userId: string; team: Team }>;
  const duel: Seating = [{ userId: ACTOR, team: Team.BLUE }, { userId: VICTIM, team: Team.RED }];
  const table: Seating = [
    { userId: ACTOR, team: Team.BLUE },
    { userId: VICTIM, team: Team.RED },
    { userId: THIRD, team: Team.GREEN },
    { userId: FOURTH, team: Team.YELLOW },
  ];

  /** The actor is on turn with one enemy token of every colour exposed on cell 10. */
  function harness(players: Seating = duel, stub: Stub = {}) {
    const engine = new LudoEngine(() => 3);
    const source = engine.create(gameId, players);
    for (const player of source.players.slice(1)) player.tokens[0] = 10;

    const persisted: PersistedStrike[] = [];
    const locked: string[] = [];
    const participant = stub.participant === undefined ? { id: 'p1' } : stub.participant;

    const persistFattah = jest.fn(
      (previousVersion: number, state: AuthoritativeGameState, userId: string, targetTokenId: string) => {
        persisted.push({ previousVersion, state, userId, targetTokenId });
        return Promise.resolve();
      },
    );
    const store = { get: jest.fn(() => Promise.resolve(source)), persistFattah };
    const prisma = { gameParticipant: { findUnique: jest.fn(() => Promise.resolve(participant)) } };
    const lock = {
      run: jest.fn((lockedGameId: string, action: () => Promise<unknown>) => {
        locked.push(lockedGameId);
        return action();
      }),
    };
    const service = new GamesService(
      prisma as unknown as PrismaService,
      store as unknown as GameStateStore,
      lock as unknown as GameLockService,
    );
    return { service, persisted, locked, source };
  }

  it('persists the board token id instead of a UUID pair', async () => {
    const { service, persisted, source } = harness();

    const result = await service.useFattah(gameId, ACTOR, VICTIM, 0);

    expect(persisted).toHaveLength(1);
    expect(persisted[0].targetTokenId).toBe('RT1');
    expect(persisted[0].targetTokenId).not.toContain(VICTIM);
    expect(persisted[0].targetTokenId.length).toBeLessThanOrEqual(FATTAH_TARGET_TOKEN_ID_MAX);
    expect(persisted[0].previousVersion).toBe(source.version);
    expect(persisted[0].userId).toBe(ACTOR);
    expect(persisted[0].state.players[1].tokens[0]).toBe(-1);
    // The broadcast marker keeps its shape: clients drive the animation from it.
    expect(result.fattah).toEqual({ actorId: ACTOR, targetUserId: VICTIM, targetTokenIndex: 0 });
  });

  it('would have overflowed the audit column with the old UUID pair', () => {
    expect(`${VICTIM}:0`.length).toBe(38);
    expect(`${VICTIM}:0`.length).toBeGreaterThan(FATTAH_TARGET_TOKEN_ID_MAX);
  });

  it('names the token by the colour of the player who was hit', async () => {
    const { service, persisted } = harness(table);

    await service.useFattah(gameId, ACTOR, THIRD, 0);
    await service.useFattah(gameId, ACTOR, FOURTH, 0);

    expect(persisted.map((strike) => strike.targetTokenId)).toEqual(['GT1', 'YT1']);
  });

  it('takes the game lock before reading the snapshot', async () => {
    const { service, locked } = harness();

    await service.useFattah(gameId, ACTOR, VICTIM, 0);

    expect(locked).toEqual([gameId]);
  });

  it('rejects an invalid target without persisting anything', async () => {
    const { service, persisted } = harness();

    await expect(service.useFattah(gameId, ACTOR, ACTOR, 0)).rejects.toThrow(BadRequestException);
    await expect(service.useFattah(gameId, ACTOR, 'nobody', 0)).rejects.toThrow(BadRequestException);
    await expect(service.useFattah(gameId, ACTOR, VICTIM, 1)).rejects.toThrow(BadRequestException);
    expect(persisted).toEqual([]);
  });

  it('refuses a player who is not in the game', async () => {
    const { service, persisted } = harness(duel, { participant: null });

    await expect(service.useFattah(gameId, 'intruder', VICTIM, 0)).rejects.toThrow('not a participant');
    expect(persisted).toEqual([]);
  });
});
