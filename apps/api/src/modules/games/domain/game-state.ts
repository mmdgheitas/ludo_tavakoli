import { Team } from '@prisma/client';

export type GamePhase = 'WAITING_PLAYERS' | 'WAITING_ROLL' | 'WAITING_MOVE' | 'FINISHED';

/** Seat order per mode: 2P sits on the diagonal (blue/green) like offline games. */
export function teamsForPlayerCount(count: number): Team[] {
  return count === 2 ? [Team.BLUE, Team.GREEN] : [Team.BLUE, Team.RED, Team.GREEN, Team.YELLOW];
}

/** Width of `FattahUsage.targetTokenId`. A longer value fails as Prisma P2000. */
export const FATTAH_TARGET_TOKEN_ID_MAX = 32;

/**
 * Board identifier of a token, e.g. `RT3` for red's third token. The Flutter
 * client derives the identical string (`FattahStrike.targetTokenId`), so a
 * stored strike names exactly the token every player watched get hit.
 *
 * Never substitute `${targetUserId}:${targetTokenIndex}` here: that is 38
 * characters and overflows the audit column. The struck player stays
 * recoverable without it, because a team is unique per game
 * (`GameParticipant @@unique([gameId, team])`).
 */
export function fattahTokenId(team: Team, tokenIndex: number): string {
  return `${team.charAt(0).toUpperCase()}T${tokenIndex + 1}`;
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
  /**
   * Present only on an accepted rocket attack. `capturedToken` alone cannot
   * distinguish a Fattah strike from a normal capture, so every client needs
   * this marker to attribute and animate the hit.
   */
  fattah?: { actorId: string; targetUserId: string; targetTokenIndex: number };
  winnerId?: string;
  reason?: 'TURN_TIMEOUT' | 'FORFEIT' | 'DISCONNECTED';
}

export class GameRuleError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
    this.name = 'GameRuleError';
  }
}
