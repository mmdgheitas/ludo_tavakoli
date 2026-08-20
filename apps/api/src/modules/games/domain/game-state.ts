import { Team } from '@prisma/client';

export type GamePhase = 'WAITING_PLAYERS' | 'WAITING_ROLL' | 'WAITING_MOVE' | 'FINISHED';

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
