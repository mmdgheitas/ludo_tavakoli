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
    const roomCode = await this.uniqueRoomCode();
    const state = this.engine.create(gameId, [{ userId: hostId, team: Team.BLUE }], false, required);
    return this.prisma.game.create({
      data: {
        id: gameId,
        roomCode,
        mode,
        status: GameStatus.WAITING,
        state: state as unknown as Prisma.InputJsonValue,
        participants: { create: { userId: hostId, team: Team.BLUE, disconnectedAt: new Date() } },
      },
      select: { id: true, roomCode: true, mode: true, status: true, state: true, createdAt: true },
    });
  }

  async joinRoomByCode(roomCode: string, userId: string): Promise<{ gameId: string; mode: GameMode; state: AuthoritativeGameState }> {
    const game = await this.prisma.game.findUnique({ where: { roomCode: roomCode.trim().toUpperCase() }, select: { id: true, mode: true } });
    if (!game) throw new NotFoundException('Room code is invalid or expired');
    const state = await this.joinRoom(game.id, userId);
    return { gameId: game.id, mode: game.mode, state };
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
      const previous = game.state as unknown as AuthoritativeGameState;
      const state = this.engine.create(gameId, players, false, required);
      for (const player of state.players) {
        const oldPlayer = previous.players.find((item) => item.userId === player.userId);
        if (oldPlayer) {
          player.connected = oldPlayer.connected;
          player.disconnectedAt = oldPlayer.disconnectedAt;
        }
      }
      state.version = game.version + 1;
      await this.prisma.$transaction([
        this.prisma.gameParticipant.create({ data: { gameId, userId, team, disconnectedAt: new Date() } }),
        this.prisma.game.update({
          where: { id: gameId },
          data: {
            state: state as unknown as Prisma.InputJsonValue,
            version: state.version,
            status: GameStatus.WAITING,
          },
        }),
      ]);
      await this.store.invalidate(gameId);
      return state;
    });
  }

  async createMatch(userIds: string[], mode: GameMode): Promise<AuthoritativeGameState> {
    const required = this.playerCount(mode);
    if (userIds.length !== required || new Set(userIds).size !== userIds.length) throw new BadRequestException('Incorrect number of unique players');
    const gameId = randomUUID();
    const players = userIds.map((userId, index) => ({ userId, team: TEAMS[index] }));
    const state = this.engine.create(gameId, players, false, required);
    const disconnectedAt = new Date();
    await this.prisma.game.create({
      data: {
        id: gameId,
        mode,
        status: GameStatus.WAITING,
        state: state as unknown as Prisma.InputJsonValue,
        participants: { create: players.map((player) => ({ ...player, disconnectedAt })) },
      },
    });
    return state;
  }

  async activeForUser(userId: string) {
    const participants = await this.prisma.gameParticipant.findMany({
      where: { userId, game: { status: { in: [GameStatus.WAITING, GameStatus.ACTIVE] } } },
      orderBy: { joinedAt: 'desc' },
      take: 5,
      include: { game: { select: { id: true, roomCode: true, mode: true, status: true, state: true, updatedAt: true } } },
    });
    return participants.map((participant) => participant.game);
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

  forfeit(gameId: string, userId: string): Promise<MoveResult> {
    return this.command(gameId, userId, (state) => this.engine.forfeit(state, userId));
  }

  timeout(gameId: string): Promise<MoveResult> {
    return this.lock.run(gameId, async () => {
      const source = await this.store.get(gameId);
      if (!source.turnDeadlineAt || Date.parse(source.turnDeadlineAt) > Date.now()) return { state: source };
      const result = this.engine.timeout(source);
      await this.store.persist(source.version, result.state);
      return result;
    });
  }

  disconnectForfeit(gameId: string, userId: string): Promise<MoveResult> {
    return this.lock.run(gameId, async () => {
      const participant = await this.prisma.gameParticipant.findUnique({ where: { gameId_userId: { gameId, userId } }, select: { disconnectedAt: true } });
      const source = await this.store.get(gameId);
      const grace = (source.reconnectGraceSeconds ?? 60) * 1000;
      if (!participant?.disconnectedAt || participant.disconnectedAt.getTime() + grace > Date.now()) return { state: source };
      const result = this.engine.forfeit(source, userId, true);
      await this.store.persist(source.version, result.state);
      return result;
    });
  }

  async markConnection(gameId: string, userId: string, connected: boolean): Promise<MoveResult> {
    return this.lock.run(gameId, async () => {
      await this.assertParticipant(gameId, userId);
      const source = await this.store.get(gameId);
      const result = this.engine.setConnection(source, userId, connected);
      await this.prisma.gameParticipant.update({
        where: { gameId_userId: { gameId, userId } },
        data: { disconnectedAt: connected ? null : new Date() },
      });
      if (result.state.version !== source.version) {
        await this.store.persist(source.version, result.state);
        if (source.phase === 'WAITING_PLAYERS' && result.state.phase === 'WAITING_ROLL') {
          await this.prisma.game.update({
            where: { id: gameId },
            data: { status: GameStatus.ACTIVE, startedAt: new Date() },
          });
        }
      }
      return result;
    });
  }

  async staleWaitingGames(): Promise<Array<{ id: string; state: AuthoritativeGameState }>> {
    const quickCutoff = new Date(Date.now() - 2 * 60_000);
    const privateCutoff = new Date(Date.now() - 15 * 60_000);
    const games = await this.prisma.game.findMany({
      where: {
        status: GameStatus.WAITING,
        OR: [
          { roomCode: null, updatedAt: { lt: quickCutoff } },
          { roomCode: { not: null }, updatedAt: { lt: privateCutoff } },
        ],
      },
      select: { id: true, state: true },
    });
    return games.map((game) => ({ id: game.id, state: game.state as unknown as AuthoritativeGameState }));
  }

  cancelWaiting(gameId: string): Promise<MoveResult> {
    return this.lock.run(gameId, async () => {
      const source = await this.store.get(gameId);
      const result = this.engine.cancelWaiting(source);
      if (result.state.version !== source.version) await this.store.persist(source.version, result.state);
      return result;
    });
  }

  async rebuildLifecycleIndex(): Promise<void> {
    const games = await this.prisma.game.findMany({
      where: { status: GameStatus.ACTIVE },
      select: { state: true },
    });
    await Promise.all(games.map((game) => this.store.prime(game.state as unknown as AuthoritativeGameState)));
  }

  dueTurnGameIds(): Promise<string[]> {
    return this.store.dueGameIds();
  }

  async disconnectedCandidates(): Promise<Array<{ gameId: string; userId: string }>> {
    const cutoff = new Date(Date.now() - 60_000);
    const participants = await this.prisma.gameParticipant.findMany({
      where: {
        disconnectedAt: { lte: cutoff },
        game: { status: GameStatus.ACTIVE },
      },
      select: { gameId: true, userId: true },
    });
    return participants;
  }

  async useFattah(gameId: string, userId: string, targetUserId: string, targetTokenIndex: number): Promise<MoveResult> {
    return this.lock.run(gameId, async () => {
      await this.assertParticipant(gameId, userId);
      const source = await this.store.get(gameId);
      try {
        const result = this.engine.useFattah(source, userId, targetUserId, targetTokenIndex);
        await this.store.persistFattah(source.version, result.state, userId, `${targetUserId}:${targetTokenIndex}`);
        return result;
      } catch (error) { this.rethrowRule(error); }
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
      } catch (error) { this.rethrowRule(error); }
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

  private async uniqueRoomCode(): Promise<string> {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const code = randomUUID().replaceAll('-', '').slice(0, 6).toUpperCase();
      if (!(await this.prisma.game.findUnique({ where: { roomCode: code }, select: { id: true } }))) return code;
    }
    throw new BadRequestException('Could not allocate room code');
  }

  private rethrowRule(error: unknown): never {
    if (error instanceof GameRuleError) throw new BadRequestException({ code: error.code, message: error.message });
    throw error;
  }
}
