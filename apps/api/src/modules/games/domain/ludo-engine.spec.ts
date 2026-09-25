import { Team } from '@prisma/client';
import { FATTAH_TARGET_TOKEN_ID_MAX, GameRuleError, fattahTokenId, teamsForPlayerCount } from './game-state';
import { LudoEngine } from './ludo-engine';

describe('LudoEngine', () => {
  const players = [{ userId: 'u1', team: Team.BLUE }, { userId: 'u2', team: Team.RED }];

  it('keeps dice generation server-side and only allows a six out of base', () => {
    const engine = new LudoEngine(() => 5);
    const result = engine.roll(engine.create('g1', players), 'u1');
    expect(result.dice).toBe(5);
    expect(result.state.turnIndex).toBe(1);
    expect(result.state.phase).toBe('WAITING_ROLL');
  });

  describe.each([2, 4])('%i-player roll ownership', (count) => {
    const seats = teamsForPlayerCount(count).map((team, index) => ({
      team,
      userId: index === 0 ? 'human' : `bot-${index}`,
    }));

    it('never lets a bot roll during the human turn', () => {
      const dice = jest.fn(() => 6);
      const engine = new LudoEngine(dice);
      const before = engine.create('g1', seats);
      expect(() => engine.roll(before, 'bot-1')).toThrow(GameRuleError);
      expect(dice).not.toHaveBeenCalled();
      expect(before.turnIndex).toBe(0);
      expect(before.pendingRoll).toBeNull();
    });

    it('attributes blocked rolls to the roller, not the next turn', () => {
      const engine = new LudoEngine(() => 5);
      for (let index = 0; index < seats.length; index += 1) {
        const before = engine.create('g1', seats);
        before.turnIndex = index;
        const result = engine.roll(before, seats[index].userId);
        expect(result.rolledBy).toBe(seats[index].userId);
        expect(result.dice).toBe(5);
        expect(result.state.turnIndex).toBe((index + 1) % seats.length);
        expect(result.state.players[result.state.turnIndex].userId).not.toBe(result.rolledBy);
        expect(before.turnIndex).toBe(index);
      }
    });

    it('attributes normal rolls and third sixes to the same actor', () => {
      const engine = new LudoEngine(() => 6);
      for (let index = 0; index < seats.length; index += 1) {
        const before = engine.create('g1', seats);
        before.turnIndex = index;
        const normal = engine.roll(before, seats[index].userId);
        expect(normal.rolledBy).toBe(seats[index].userId);
        expect(normal.state.turnIndex).toBe(index);
        expect(normal.state.phase).toBe('WAITING_MOVE');
        before.players[index].consecutiveSixes = 2;
        const third = engine.roll(before, seats[index].userId);
        expect(third.rolledBy).toBe(seats[index].userId);
        expect(third.dice).toBe(6);
        expect(third.state.turnIndex).toBe((index + 1) % seats.length);
      }
    });
  });

  it('rejects another player moving on the current turn', () => {
    const engine = new LudoEngine(() => 6);
    const rolled = engine.roll(engine.create('g1', players), 'u1');
    expect(() => engine.move(rolled.state, 'u2', 0)).toThrow(GameRuleError);
  });

  it('moves a token out of base after a six', () => {
    const engine = new LudoEngine(() => 6);
    const rolled = engine.roll(engine.create('g1', players), 'u1');
    const moved = engine.move(rolled.state, 'u1', 0);
    expect(moved.state.players[0].tokens[0]).toBe(0);
    expect(moved.state.turnIndex).toBe(0);
  });

  it('blocks a second Fattah use in one game', () => {
    const engine = new LudoEngine();
    const state = engine.create('g1', players);
    state.players[1].tokens[0] = 10;
    const first = engine.useFattah(state, 'u1', 'u2', 0);
    first.state.players[1].tokens[0] = 10;
    expect(() => engine.useFattah(first.state, 'u1', 'u2', 0)).toThrow('limited to once');
  });

  it('requires an exact roll to finish', () => {
    const engine = new LudoEngine();
    expect(engine.canMove(55, 1)).toBe(true);
    expect(engine.canMove(55, 2)).toBe(false);
  });

  it('advances turn on timeout and forfeits after three consecutive timeouts', () => {
    const engine = new LudoEngine();
    let state = engine.create('g1', players);
    state = engine.timeout(state).state;
    expect(state.turnIndex).toBe(1);
    state.players[0].consecutiveTimeouts = 2;
    state.turnIndex = 0;
    const result = engine.timeout(state);
    expect(result.state.players[0].forfeited).toBe(true);
    expect(result.state.winnerId).toBe('u2');
  });

  it('awards the remaining player when an opponent forfeits', () => {
    const engine = new LudoEngine();
    const result = engine.forfeit(engine.create('g1', players), 'u1');
    expect(result.state.phase).toBe('FINISHED');
    expect(result.winnerId).toBe('u2');
  });

  it('starts an online game only after every required player connects', () => {
    const engine = new LudoEngine(() => 1);
    let state = engine.create('g1', players, false, 2);
    expect(state.phase).toBe('WAITING_PLAYERS');
    expect(state.players.every((player) => !player.connected)).toBe(true);
    state = engine.setConnection(state, 'u1', true).state;
    expect(state.phase).toBe('WAITING_PLAYERS');
    state = engine.setConnection(state, 'u2', true).state;
    expect(state.phase).toBe('WAITING_ROLL');
    expect(state.turnDeadlineAt).not.toBeNull();
  });

  it('keeps the active turn deadline while a player reconnects', () => {
    const engine = new LudoEngine(() => 1);
    let state = engine.create('g1', players);
    const deadline = state.turnDeadlineAt;
    state = engine.setConnection(state, 'u2', false).state;
    expect(state.turnDeadlineAt).toBe(deadline);
    state = engine.setConnection(state, 'u2', true).state;
    expect(state.turnDeadlineAt).toBe(deadline);
  });

  it('cancels a stale game that never became ready', () => {
    const engine = new LudoEngine();
    const state = engine.create('g1', players, false, 2);
    const result = engine.cancelWaiting(state);
    expect(result.state.phase).toBe('FINISHED');
    expect(result.state.winnerId).toBeNull();
  });

  describe('Fattah rocket', () => {
    const expectRuleError = (action: () => unknown, code: string): void => {
      let caught: unknown;
      try {
        action();
      } catch (error) {
        caught = error;
      }
      expect(caught).toBeInstanceOf(GameRuleError);
      expect((caught as GameRuleError).code).toBe(code);
    };

    /** u1 is on turn; u2 (red) owns one token standing on `progress`. */
    const withExposedTarget = (progress = 10) => {
      const engine = new LudoEngine(() => 3);
      const state = engine.create('g1', players);
      state.players[1].tokens[0] = progress;
      return { engine, state };
    };

    it('sends an exposed enemy token home and attributes the strike', () => {
      const { engine, state } = withExposedTarget();
      const result = engine.useFattah(state, 'u1', 'u2', 0);
      expect(result.state.players[1].tokens[0]).toBe(-1);
      expect(result.state.players[0].fattahUsed).toBe(true);
      expect(result.state.players[1].fattahUsed).toBe(false);
      expect(result.capturedToken).toEqual({ userId: 'u2', tokenIndex: 0 });
      expect(result.fattah).toEqual({ actorId: 'u1', targetUserId: 'u2', targetTokenIndex: 0 });
      expect(result.state.version).toBe(state.version + 1);
      // The strike neither consumes the turn nor the attacker's own pieces.
      expect(result.state.turnIndex).toBe(0);
      expect(result.state.phase).toBe('WAITING_ROLL');
      expect(result.state.players[0].tokens).toEqual([-1, -1, -1, -1]);
    });

    it('names the struck token with the board id the audit column can hold', () => {
      const { engine, state } = withExposedTarget();
      const result = engine.useFattah(state, 'u1', 'u2', 0);
      const target = result.state.players.find((player) => player.userId === 'u2');
      // Same string the Flutter client derives for the rocket animation.
      expect(target?.team).toBe(Team.RED);
      expect(fattahTokenId(Team.RED, 0)).toBe('RT1');
      expect(fattahTokenId(Team.RED, 2)).toBe('RT3');
      expect(fattahTokenId(Team.BLUE, 0)).toBe('BT1');
      expect(fattahTokenId(Team.GREEN, 3)).toBe('GT4');
      expect(fattahTokenId(Team.YELLOW, 1)).toBe('YT2');
      // Every possible value must fit FattahUsage.targetTokenId VARCHAR(32);
      // a `${targetUserId}:${index}` pair is 38 characters and is rejected by
      // PostgreSQL as P2000, which used to roll the whole strike back.
      for (const team of Object.values(Team)) {
        for (let tokenIndex = 0; tokenIndex <= 3; tokenIndex += 1) {
          const id = fattahTokenId(team, tokenIndex);
          expect(id.length).toBeGreaterThan(0);
          expect(id.length).toBeLessThanOrEqual(FATTAH_TARGET_TOKEN_ID_MAX);
        }
      }
      expect(`${'0'.repeat(36)}:0`.length).toBeGreaterThan(FATTAH_TARGET_TOKEN_ID_MAX);
    });

    it('keeps a pending roll so the attacker can still move after the strike', () => {
      const engine = new LudoEngine(() => 6);
      const rolled = engine.roll(engine.create('g1', players), 'u1');
      rolled.state.players[1].tokens[2] = 20;
      expect(rolled.state.phase).toBe('WAITING_MOVE');
      const result = engine.useFattah(rolled.state, 'u1', 'u2', 2);
      expect(result.state.phase).toBe('WAITING_MOVE');
      expect(result.state.pendingRoll).toBe(6);
      expect(result.state.players[1].tokens[2]).toBe(-1);
    });

    it('bypasses safe-cell protection', () => {
      // Red progress 0 sits on shared cell 13, which shields normal captures.
      const { engine, state } = withExposedTarget(0);
      const result = engine.useFattah(state, 'u1', 'u2', 0);
      expect(result.state.players[1].tokens[0]).toBe(-1);
    });

    it('rejects every invalid target without touching the snapshot', () => {
      const { engine, state } = withExposedTarget();
      expectRuleError(() => engine.useFattah(state, 'u1', 'u1', 0), 'INVALID_TARGET');
      expectRuleError(() => engine.useFattah(state, 'u1', 'missing', 0), 'INVALID_TARGET');
      expectRuleError(() => engine.useFattah(state, 'u1', 'u2', 1), 'INVALID_TARGET');
      expectRuleError(() => engine.useFattah(state, 'u1', 'u2', 4), 'INVALID_TARGET');
      expectRuleError(() => engine.useFattah(state, 'u1', 'u2', -1), 'INVALID_TARGET');
      expectRuleError(() => engine.useFattah(withExposedTarget(56).state, 'u1', 'u2', 0), 'INVALID_TARGET');
      const forfeited = withExposedTarget().state;
      forfeited.players[1].forfeited = true;
      expectRuleError(() => engine.useFattah(forfeited, 'u1', 'u2', 0), 'INVALID_TARGET');
      expect(state.players[1].tokens[0]).toBe(10);
      expect(state.players[0].fattahUsed).toBe(false);
    });

    it('rejects a strike from a player who is not on turn', () => {
      const { engine, state } = withExposedTarget();
      state.players[0].tokens[0] = 12;
      expectRuleError(() => engine.useFattah(state, 'u2', 'u1', 0), 'NOT_YOUR_TURN');
    });

    it('rejects a strike after the game is finished', () => {
      const { engine, state } = withExposedTarget();
      state.phase = 'FINISHED';
      expectRuleError(() => engine.useFattah(state, 'u1', 'u2', 0), 'GAME_FINISHED');
    });
  });
});
