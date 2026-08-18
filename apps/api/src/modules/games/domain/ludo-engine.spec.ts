import { Team } from '@prisma/client';
import { GameRuleError } from './game-state';
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
});
