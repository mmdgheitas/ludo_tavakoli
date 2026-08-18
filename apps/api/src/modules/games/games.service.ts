import { randomUUID } from 'node:crypto';
import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { GameMode, GameStatus, Prisma, Team } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthoritativeGameState, GameRuleError, MoveResult } from './domain/game-state';
import { LudoEngine } from './domain/ludo-engine';
import { GameLockService } from './game-lock.service';
import { GameStateStore } from './game-state.store';

const TEAMS = [Team.BLUE, Team.RED, Team.GREEN, Team.YELLOW];

@Injectable()
export class GamesService {
  private readonly engine = new LudoEngine();
  constructor(
    private readonly prisma: PrismaService,
    private readonly store: GameStateStore,
    private readonly lock: GameLockService,
  ) {}

  async createRoom(hostId: string, mode: GameMode) {
    const required = this.playerCount(mode);
    const gameId = randomUUID();
    const state = this.engine.create(gameId, [{ userId: hostId, team: Team.BLUE }], required === 1);
    return this.prisma.game.create({
      data: {
        id: gameId,
        mode,
        status: required === 1 ? GameStatus.ACTIVE : GameStatus.WAITING,
        state: state as unknown as Prisma.InputJsonValue,
        startedAt: required === 1 ? new Date() : undefined,
        participants: { create: { userId: hostId, team: Team.BLUE } },
      },
      select: { id: true, mode: true, status: true, state: true, createdAt: true },
    });
  }

  async joinRoom(gameId: string, userId: string): Promise<AuthoritativeGameState> {
    return this.lock.run(gameId, async () => {
      const game = await this.prisma.game.findUnique({ where: { id: gameId }, include: { participants: true } });
      if (!game) throw new NotFoundException('Room not found');
      if (game.status !== GameStatus.WAITING) throw new BadRequestException('Room is not accepting players');
      if (game.participants.some((participant) => participant.userId === userId)) return game.state as unknown as AuthoritativeGameState;
      const required = this.playerCount(game.mode);
      if (game.participants.length >= required) throw new BadRequestException('Room is full');
      const team = TEAMS[game.participants.length];
      const players = [...game.participants.map((participant) => ({ userId: participant.userId, team: participant.team })), { userId, team }];
      const ready = players.length === required;
      const previous = game.state as unknown as AuthoritativeGameState;
      const state = this.engine.create(gameId, players, ready);
      state.version = game.version + 1;
      await this.prisma.$transaction([
        this.prisma.gameParticipant.create({ data: { gameId, userId, team } }),
        this.prisma.game.update({
          where: { id: gameId },
          data: {
            state: state as unknown as Prisma.InputJsonValue,
            version: state.version,
            status: ready ? GameStatus.ACTIVE : GameStatus.WAITING,
            startedAt: ready ? new Date() : undefined,
          },
        }),
      ]);
      if (previous.version > game.version) throw new BadRequestException('Invalid room state');
      await this.store.invalidate(gameId);
      return state;
    });
  }

  async createMatch(userIds: string[], mode: GameMode): Promise<AuthoritativeGameState> {
    const required = this.playerCount(mode);
    if (userIds.length !== required || new Set(userIds).size !== userIds.length) {
      throw new BadRequestException('Incorrect number of unique players');
    }
    const gameId = randomUUID();
    const players = userIds.map((userId, index) => ({ userId, team: TEAMS[index] }));
    const state = this.engine.create(gameId, players, true);
    await this.prisma.game.create({
      data: {
        id: gameId,
        mode,
        status: GameStatus.ACTIVE,
        state: state as unknown as Prisma.InputJsonValue,
        startedAt: new Date(),
        participants: { create: players },
      },
    });
    return state;
  }

  async getForUser(gameId: string, userId: string): Promise<AuthoritativeGameState> {
    await this.assertParticipant(gameId, userId);
    return this.store.get(gameId);
  }

  roll(gameId: string, userId: string): Promise<MoveResult> {
    return this.command(gameId, userId, (state) => this.engine.roll(state, userId));
  }

  move(gameId: string, userId: string, tokenIndex: number): Promise<MoveResult> {
    return this.command(gameId, userId, (state) => this.engine.move(state, userId, tokenIndex));
  }

  async useFattah(gameId: string, userId: string, targetUserId: string, targetTokenIndex: number): Promise<MoveResult> {
    return this.lock.run(gameId, async () => {
      await this.assertParticipant(gameId, userId);
      const source = await this.store.get(gameId);
      try {
        const result = this.engine.useFattah(source, userId, targetUserId, targetTokenIndex);
        await this.store.persistFattah(source.version, result.state, userId, `${targetUserId}:${targetTokenIndex}`);
        return result;
      } catch (error) {
        this.rethrowRule(error);
      }
    });
  }

  private async command(gameId: string, userId: string, action: (state: AuthoritativeGameState) => MoveResult): Promise<MoveResult> {
    return this.lock.run(gameId, async () => {
      await this.assertParticipant(gameId, userId);
      const source = await this.store.get(gameId);
      try {
        const result = action(source);
        await this.store.persist(source.version, result.state);
        return result;
      } catch (error) {
        this.rethrowRule(error);
      }
    });
  }

  private async assertParticipant(gameId: string, userId: string): Promise<void> {
    const participant = await this.prisma.gameParticipant.findUnique({ where: { gameId_userId: { gameId, userId } }, select: { id: true } });
    if (!participant) throw new ForbiddenException('You are not a participant in this game');
  }

  private playerCount(mode: GameMode): number {
    if (mode === GameMode.ONLINE_2P) return 2;
    if (mode === GameMode.ONLINE_4P) return 4;
    throw new BadRequestException('Offline modes are managed on device');
  }

  private rethrowRule(error: unknown): never {
    if (error instanceof GameRuleError) throw new BadRequestException({ code: error.code, message: error.message });
    throw error;
  }
}
