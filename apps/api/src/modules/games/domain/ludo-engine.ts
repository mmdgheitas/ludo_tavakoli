import { randomInt } from 'node:crypto';
import { Team } from '@prisma/client';
import { AuthoritativeGameState, GameRuleError, MoveResult, PlayerState } from './game-state';

const FINISH = 56;
const SAFE_CELLS = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
const TEAM_OFFSET: Record<Team, number> = {
  [Team.BLUE]: 0,
  [Team.RED]: 13,
  [Team.GREEN]: 26,
  [Team.YELLOW]: 39,
};

export class LudoEngine {
  constructor(
    private readonly dice: () => number = () => randomInt(1, 7),
    private readonly turnSeconds = 30,
    private readonly reconnectGraceSeconds = 60,
  ) {}

  create(gameId: string, players: Array<{ userId: string; team: Team }>, ready = true): AuthoritativeGameState {
    if (players.length < 1 || players.length > 4) throw new GameRuleError('INVALID_PLAYERS', 'A game requires one to four players');
    const now = new Date();
    return {
      gameId,
      version: 0,
      phase: ready ? 'WAITING_ROLL' : 'WAITING_PLAYERS',
      turnIndex: 0,
      pendingRoll: null,
      players: players.map((player) => this.newPlayer(player)),
      winnerId: null,
      lastActionAt: now.toISOString(),
      turnDeadlineAt: ready ? this.deadline(now) : null,
      turnSeconds: this.turnSeconds,
      reconnectGraceSeconds: this.reconnectGraceSeconds,
    };
  }

  roll(source: AuthoritativeGameState, userId: string): MoveResult {
    const state = this.clone(source);
    this.assertTurn(state, userId);
    if (state.phase !== 'WAITING_ROLL') throw new GameRuleError('ROLL_NOT_ALLOWED', 'The game is not waiting for a dice roll');
    const value = this.dice();
    if (!Number.isInteger(value) || value < 1 || value > 6) throw new Error('Dice generator returned an invalid value');
    const player = state.players[state.turnIndex];
    player.consecutiveTimeouts = 0;
    player.consecutiveSixes = value === 6 ? player.consecutiveSixes + 1 : 0;

    if (player.consecutiveSixes >= 3) {
      player.consecutiveSixes = 0;
      this.advanceTurn(state);
      return { state: this.touch(state), dice: value };
    }

    const legalMoves = player.tokens.some((progress) => this.canMove(progress, value));
    if (!legalMoves) {
      if (value !== 6) this.advanceTurn(state);
      state.phase = 'WAITING_ROLL';
      state.pendingRoll = null;
    } else {
      state.pendingRoll = value;
      state.phase = 'WAITING_MOVE';
    }
    return { state: this.touch(state), dice: value };
  }

  move(source: AuthoritativeGameState, userId: string, tokenIndex: number): MoveResult {
    const state = this.clone(source);
    this.assertTurn(state, userId);
    if (state.phase !== 'WAITING_MOVE' || state.pendingRoll == null) throw new GameRuleError('MOVE_NOT_ALLOWED', 'Roll the dice before moving');
    if (!Number.isInteger(tokenIndex) || tokenIndex < 0 || tokenIndex > 3) throw new GameRuleError('INVALID_TOKEN', 'Token index is invalid');
    const player = state.players[state.turnIndex];
    const dice = state.pendingRoll;
    const previous = player.tokens[tokenIndex];
    if (!this.canMove(previous, dice)) throw new GameRuleError('ILLEGAL_MOVE', 'This token cannot make that move');
    player.consecutiveTimeouts = 0;
    player.tokens[tokenIndex] = previous === -1 ? 0 : previous + dice;

    const capturedToken = this.capture(state, state.turnIndex, tokenIndex);
    const hasWon = player.tokens.every((progress) => progress === FINISH);
    state.pendingRoll = null;
    if (hasWon) return this.finish(state, userId, { capturedToken });
    if (dice === 6 || capturedToken) state.phase = 'WAITING_ROLL';
    else this.advanceTurn(state);
    return { state: this.touch(state), capturedToken };
  }

  useFattah(source: AuthoritativeGameState, userId: string, targetUserId: string, targetTokenIndex: number): MoveResult {
    const state = this.clone(source);
    this.assertTurn(state, userId);
    const actor = state.players[state.turnIndex];
    if (actor.fattahUsed) throw new GameRuleError('FATTAH_ALREADY_USED', 'Fattah is limited to once per game');
    const target = state.players.find((player) => player.userId === targetUserId);
    if (!target || target.userId === userId || target.forfeited) throw new GameRuleError('INVALID_TARGET', 'Target player is invalid');
    if (!Number.isInteger(targetTokenIndex) || targetTokenIndex < 0 || targetTokenIndex > 3) throw new GameRuleError('INVALID_TARGET', 'Target token is invalid');
    const progress = target.tokens[targetTokenIndex];
    if (progress < 0 || progress >= FINISH) throw new GameRuleError('INVALID_TARGET', 'Target token is not exposed');
    target.tokens[targetTokenIndex] = -1;
    actor.fattahUsed = true;
    return { state: this.touch(state), capturedToken: { userId: target.userId, tokenIndex: targetTokenIndex } };
  }

  timeout(source: AuthoritativeGameState): MoveResult {
    const state = this.clone(source);
    if (state.phase === 'FINISHED' || state.phase === 'WAITING_PLAYERS') throw new GameRuleError('TIMEOUT_NOT_ALLOWED', 'Game has no active turn');
    const player = state.players[state.turnIndex];
    player.consecutiveTimeouts += 1;
    player.consecutiveSixes = 0;
    state.pendingRoll = null;
    if (player.consecutiveTimeouts >= 3) player.forfeited = true;
    const winner = this.remainingWinner(state);
    if (winner) return this.finish(state, winner.userId, { reason: 'TURN_TIMEOUT' });
    this.advanceTurn(state);
    return { state: this.touch(state), reason: 'TURN_TIMEOUT' };
  }

  forfeit(source: AuthoritativeGameState, userId: string, disconnected = false): MoveResult {
    const state = this.clone(source);
    if (state.phase === 'FINISHED') throw new GameRuleError('GAME_FINISHED', 'The game is finished');
    const index = state.players.findIndex((player) => player.userId === userId);
    if (index < 0) throw new GameRuleError('NOT_A_PLAYER', 'Player is not in this game');
    state.players[index].forfeited = true;
    if (state.phase === 'WAITING_PLAYERS') {
      state.phase = 'FINISHED';
      state.turnDeadlineAt = null;
      return { state: this.touch(state, false), reason: 'FORFEIT' };
    }
    state.players[index].connected = false;
    state.pendingRoll = null;
    const winner = this.remainingWinner(state);
    const reason = disconnected ? 'DISCONNECTED' : 'FORFEIT';
    if (winner) return this.finish(state, winner.userId, { reason });
    if (state.turnIndex === index) this.advanceTurn(state);
    return { state: this.touch(state), reason };
  }

  setConnection(source: AuthoritativeGameState, userId: string, connected: boolean): MoveResult {
    const state = this.clone(source);
    const player = state.players.find((item) => item.userId === userId);
    if (!player || player.forfeited || state.phase === 'FINISHED' || player.connected === connected) return { state: source };
    player.connected = connected;
    player.disconnectedAt = connected ? null : new Date().toISOString();
    return { state: this.touch(state, false) };
  }

  canMove(progress: number, dice: number): boolean {
    if (progress === FINISH) return false;
    if (progress === -1) return dice === 6;
    return progress >= 0 && progress + dice <= FINISH;
  }

  private newPlayer(player: { userId: string; team: Team }): PlayerState {
    return { ...player, tokens: [-1, -1, -1, -1], consecutiveSixes: 0, consecutiveTimeouts: 0, fattahUsed: false, forfeited: false, connected: true, disconnectedAt: null };
  }

  private clone(source: AuthoritativeGameState): AuthoritativeGameState {
    const state = structuredClone(source);
    state.turnSeconds ??= this.turnSeconds;
    state.reconnectGraceSeconds ??= this.reconnectGraceSeconds;
    state.turnDeadlineAt ??= state.phase === 'WAITING_PLAYERS' || state.phase === 'FINISHED' ? null : this.deadline();
    state.players = state.players.map((player) => ({
      ...player,
      consecutiveTimeouts: player.consecutiveTimeouts ?? 0,
      forfeited: player.forfeited ?? false,
      connected: player.connected ?? true,
      disconnectedAt: player.disconnectedAt ?? null,
    }));
    return state;
  }

  private capture(state: AuthoritativeGameState, attackerIndex: number, tokenIndex: number): { userId: string; tokenIndex: number } | undefined {
    const attacker = state.players[attackerIndex];
    const cell = this.sharedCell(attacker.team, attacker.tokens[tokenIndex]);
    if (cell == null || SAFE_CELLS.has(cell)) return undefined;
    for (let playerIndex = 0; playerIndex < state.players.length; playerIndex += 1) {
      if (playerIndex === attackerIndex || state.players[playerIndex].forfeited) continue;
      const target = state.players[playerIndex];
      for (let index = 0; index < target.tokens.length; index += 1) {
        if (this.sharedCell(target.team, target.tokens[index]) === cell) {
          target.tokens[index] = -1;
          return { userId: target.userId, tokenIndex: index };
        }
      }
    }
    return undefined;
  }

  private sharedCell(team: Team, progress: number): number | null {
    return progress >= 0 && progress <= 50 ? (TEAM_OFFSET[team] + progress) % 52 : null;
  }

  private assertTurn(state: AuthoritativeGameState, userId: string): void {
    if (state.phase === 'FINISHED') throw new GameRuleError('GAME_FINISHED', 'The game is finished');
    if (state.phase === 'WAITING_PLAYERS') throw new GameRuleError('GAME_NOT_READY', 'Waiting for players');
    const player = state.players[state.turnIndex];
    if (player?.userId !== userId || player.forfeited) throw new GameRuleError('NOT_YOUR_TURN', 'It is not your turn');
  }

  private advanceTurn(state: AuthoritativeGameState): void {
    for (let offset = 1; offset <= state.players.length; offset += 1) {
      const index = (state.turnIndex + offset) % state.players.length;
      if (!state.players[index].forfeited) {
        state.turnIndex = index;
        break;
      }
    }
    state.phase = 'WAITING_ROLL';
    state.pendingRoll = null;
  }

  private remainingWinner(state: AuthoritativeGameState): PlayerState | undefined {
    const active = state.players.filter((player) => !player.forfeited);
    return active.length === 1 ? active[0] : undefined;
  }

  private finish(state: AuthoritativeGameState, winnerId: string, extra: Omit<MoveResult, 'state' | 'winnerId'> = {}): MoveResult {
    state.phase = 'FINISHED';
    state.winnerId = winnerId;
    state.pendingRoll = null;
    state.turnDeadlineAt = null;
    return { state: this.touch(state, false), winnerId, ...extra };
  }

  private touch(state: AuthoritativeGameState, resetDeadline = true): AuthoritativeGameState {
    state.version += 1;
    state.lastActionAt = new Date().toISOString();
    if (resetDeadline && state.phase !== 'FINISHED' && state.phase !== 'WAITING_PLAYERS') state.turnDeadlineAt = this.deadline();
    return state;
  }

  private deadline(from = new Date()): string {
    return new Date(from.getTime() + this.turnSeconds * 1000).toISOString();
  }
}
