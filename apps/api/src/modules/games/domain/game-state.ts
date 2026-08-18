import { Team } from '@prisma/client';

export type GamePhase = 'WAITING_PLAYERS' | 'WAITING_ROLL' | 'WAITING_MOVE' | 'FINISHED';

export interface PlayerState {
  userId: string;
  team: Team;
  tokens: [number, number, number, number];
  consecutiveSixes: number;
  fattahUsed: boolean;
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
}

export interface MoveResult {
  state: AuthoritativeGameState;
  dice?: number;
  capturedToken?: { userId: string; tokenIndex: number };
  winnerId?: string;
}

export class GameRuleError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = 'GameRuleError';
  }
}
