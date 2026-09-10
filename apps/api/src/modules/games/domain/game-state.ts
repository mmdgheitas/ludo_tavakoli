import { Team } from '@prisma/client';

export type GamePhase = 'WAITING_PLAYERS' | 'WAITING_ROLL' | 'WAITING_MOVE' | 'FINISHED';

/** Seat order per mode: 2P sits on the diagonal (blue/green) like offline games. */
export function teamsForPlayerCount(count: number): Team[] {
  return count === 2 ? [Team.BLUE, Team.GREEN] : [Team.BLUE, Team.RED, Team.GREEN, Team.YELLOW];
}

export interface PlayerState {
  userId: string;
  team: Team;
  tokens: [number, number, number, number];
  consecutiveSixes: number;
  consecutiveTimeouts: number;
  fattahUsed: boolean;
  forfeited: boolean;
  connected: boolean;
  disconnectedAt: string | null;
}

export interface AuthoritativeGameState {
  gameId: string;
  version: number;
  phase: GamePhase;
  turnIndex: number;
  pendingRoll: number | null;
  players: PlayerState[];
  winnerId: string | null;
  lastActionAt: string;
  turnDeadlineAt: string | null;
  turnSeconds: number;
  reconnectGraceSeconds: number;
  requiredPlayers: number;
}

export interface MoveResult {
  state: AuthoritativeGameState;
  dice?: number;
  capturedToken?: { userId: string; tokenIndex: number };
  winnerId?: string;
  reason?: 'TURN_TIMEOUT' | 'FORFEIT' | 'DISCONNECTED';
}

export class GameRuleError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = 'GameRuleError';
  }
}
