import { randomInt, randomUUID } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Team } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';
import { GameStateStore } from './game-state.store';
import { GameLockService } from './game-lock.service';
import { GamesGateway } from './games.gateway';
import { LudoEngine } from './domain/ludo-engine';

export type BotDifficulty = 'EASY' | 'HARD' | 'VERY_HARD';

export interface BotInfo {
  userId: string;
  username: string;
  difficulty: BotDifficulty;
}

const PERSIAN_FIRST_NAMES = [
  'آرش','کیان','سینا','امیر','علی','محمد','حسین','رضا','مهدی','سجاد',
  'پویا','نیما','بهنام','فرهاد','کامران','سامان','آرمان','بردیا','کوروش','داریوش',
  'بهزاد','سیاوش','کیارش','امین','احسان','فرشاد','مسعود','میلاد','اشکان','رامین',
  'سارا','نگار','نازنین','الهه','مریم','زهرا','فاطمه','نرگس','باران','دریا',
  'آوا','آیدا','تینا','شقایق','لیلا','ستاره','غزل','هانیه','مهسا','پریسا',
  'نیلوفر','سحر','یاسمن','کیمیا','رویا','ساناز','شیدا','ترنم','بیتا','مونا',
  'پارسا','آریا','عرشیا','ایلیا','مانی','پرهام','سهیل','کاوه','بابک','بهروز',
  'یاسر','وحید','حمید','سعید','جواد','نوید','فرزین','شهاب','امید','آراد',
];

const PERSIAN_LAST_NAMES = [
  'احمدی','حسینی','کریمی','محمدی','رضایی','موسوی','جعفری','صادقی','اکبری','حسنی',
  'مرادی','عباسی','باقری','رحیمی','امینی','حیدری','نوری','کاظمی','قاسمی','صالحی',
  'هاشمی','امامی','سلطانی','شریفی','نجفی','فرهادی','رستمی','بهرامی','سلیمانی','رحمانی',
  'یوسفی','اسدی','زارعی','نظری','عزیزی','خانی','شفیعی','ملکی','حسینی‌نژاد','رضوی',
];

const BOT_DIFFICULTIES: BotDifficulty[] = ['EASY','HARD','VERY_HARD'];

const TEAM_OFFSET: Record<Team, number> = {
  [Team.BLUE]: 0,
  [Team.RED]: 13,
  [Team.GREEN]: 26,
  [Team.YELLOW]: 39,
};
const SAFE_CELLS = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
const FINISH = 56;

@Injectable()
export class BotService {
  private readonly logger = new Logger(BotService.name);
  private readonly engine = new LudoEngine();
  private readonly botGamesKey = 'bot:games';
  private readonly running = new Set<string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly store: GameStateStore,
    private readonly lock: GameLockService,
    private readonly gateway: GamesGateway,
  ) {}

  private randomPersianName(): string {
    const first = PERSIAN_FIRST_NAMES[randomInt(PERSIAN_FIRST_NAMES.length)];
    const last = PERSIAN_LAST_NAMES[randomInt(PERSIAN_LAST_NAMES.length)];
    // 70% full name, 30% just first name for natural look
    if (randomInt(10) < 7) return `${first} ${last}`;
    return first;
  }

  private randomDifficulty(): BotDifficulty {
    return BOT_DIFFICULTIES[randomInt(BOT_DIFFICULTIES.length)];
  }

  private randomUsernameFromPersian(persianName: string): string {
    // Keep Persian readable but ensure uniqueness with random suffix
    const base = persianName.replace(/\s+/g, '_');
    const suffix = randomInt(100, 9999);
    // 50% chance to add suffix, to keep some names clean and real
    if (randomInt(10) < 5) return `${base}_${suffix}`;
    return base;
  }

  async createBots(count: number): Promise<BotInfo[]> {
    const bots: BotInfo[] = [];
    for (let i = 0; i < count; i++) {
      const persianName = this.randomPersianName();
      const difficulty = this.randomDifficulty();
      let username = this.randomUsernameFromPersian(persianName);
      let attempts = 0;
      let userId: string | null = null;
      while (attempts < 5) {
        try {
          const user = await this.prisma.user.create({
            data: {
              id: randomUUID(),
              username,
              // Bot identification via deviceId prefix, invisible to client
              deviceId: `bot-${randomUUID()}`,
              coinBalance: 500,
              fattahBalance: 0,
              // No email, no password - bot account
            },
            select: { id: true, username: true },
          });
          userId = user.id;
          username = user.username;
          break;
        } catch (_e: unknown) {
          // Unique constraint violation -> retry with new suffix
          attempts++;
          username = `${persianName.replace(/\s+/g, '_')}_${randomInt(1000, 99999)}`;
          if (attempts >= 5) {
            // Last resort: uuid based username
            username = `بازیکن_${randomInt(10000, 99999)}`;
          }
        }
      }
      if (!userId) {
        // Fallback: create with uuid username
        const fallback = await this.prisma.user.create({
          data: {
            id: randomUUID(),
            username: `بازیکن_${randomInt(100000, 999999)}`,
            deviceId: `bot-${randomUUID()}`,
            coinBalance: 500,
            fattahBalance: 0,
          },
          select: { id: true, username: true },
        });
        userId = fallback.id;
        username = fallback.username;
      }
      bots.push({ userId: userId!, username, difficulty });
    }
    return bots;
  }

  async registerBotGame(gameId: string, bots: BotInfo[]): Promise<void> {
    await this.redis.ensureConnected();
    if (bots.length === 0) return;
    const multi = this.redis.client.multi();
    multi.sadd(this.botGamesKey, gameId);
    for (const bot of bots) {
      multi.hset(`bot:game:${gameId}`, bot.userId, bot.difficulty);
    }
    // Expire bot game tracking after 1 hour (game should be finished by then)
    multi.expire(`bot:game:${gameId}`, 3600 * 2);
    await multi.exec();
  }

  async isBotUser(userId: string): Promise<boolean> {
    try {
      const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { deviceId: true } });
      return !!user?.deviceId?.startsWith('bot-');
    } catch {
      return false;
    }
  }

  async getBotDifficulty(gameId: string, userId: string): Promise<BotDifficulty | null> {
    await this.redis.ensureConnected();
    const diff = await this.redis.client.hget(`bot:game:${gameId}`, userId);
    if (diff && BOT_DIFFICULTIES.includes(diff as BotDifficulty)) return diff as BotDifficulty;
    return null;
  }

  async removeBotGame(gameId: string): Promise<void> {
    await this.redis.ensureConnected();
    await this.redis.client.multi().srem(this.botGamesKey, gameId).del(`bot:game:${gameId}`).exec();
  }

  private sharedCell(team: Team, progress: number): number | null {
    return progress >= 0 && progress <= 50 ? (TEAM_OFFSET[team] + progress) % 52 : null;
  }

  private canMove(progress: number, dice: number): boolean {
    if (progress === FINISH) return false;
    if (progress === -1) return dice === 6;
    return progress >= 0 && progress + dice <= FINISH;
  }

  private chooseTokenIndex(
    playerTokens: [number, number, number, number],
    playerTeam: Team,
    dice: number,
    allPlayers: Array<{ userId: string; team: Team; tokens: [number, number, number, number]; forfeited: boolean }>,
    difficulty: BotDifficulty,
  ): number {
    const legal: number[] = [];
    for (let i = 0; i < 4; i++) {
      if (this.canMove(playerTokens[i], dice)) legal.push(i);
    }
    if (legal.length === 0) return -1;
    if (legal.length === 1) return legal[0];

    if (difficulty === 'EASY') {
      // Easy: completely random, sometimes even suboptimal
      return legal[randomInt(legal.length)];
    }

    // Score each legal move
    const scores = new Map<number, number>();
    for (const idx of legal) {
      const from = playerTokens[idx];
      const to = from === -1 ? 0 : from + dice;
      let score = 0;

      // Finishing move - highest priority
      if (to === FINISH) score += 1000;
      // Close to finish
      else if (to >= 50) score += 200 + (to - 50) * 10;
      else if (to >= 40) score += 80;
      
      // Entering board from base
      if (from === -1) score += 120;

      // Capture detection
      const targetCell = this.sharedCell(playerTeam, to);
      if (targetCell != null && !SAFE_CELLS.has(targetCell)) {
        for (const opponent of allPlayers) {
          if (opponent.team === playerTeam || opponent.forfeited) continue;
          for (let t = 0; t < opponent.tokens.length; t++) {
            const oppProgress = opponent.tokens[t];
            const oppCell = this.sharedCell(opponent.team, oppProgress);
            if (oppCell === targetCell) {
              score += 300; // Capture is valuable
            }
          }
        }
      }

      // Landing on safe cell
      if (targetCell != null && SAFE_CELLS.has(targetCell)) score += 60;

      // Avoid leaving token vulnerable? If token currently on safe, moving away might be risky
      const currentCell = this.sharedCell(playerTeam, from);
      if (currentCell != null && SAFE_CELLS.has(currentCell) && targetCell != null && !SAFE_CELLS.has(targetCell)) {
        score -= 20; // Slight penalty for leaving safe
      }

      // Prefer tokens that are behind (to bring them forward) for VERY_HARD
      if (difficulty === 'VERY_HARD') {
        // Prefer more advanced tokens when close to win, otherwise distribute
        const avgProgress = playerTokens.filter(p => p >= 0).reduce((a,b)=>a+b,0) / Math.max(1, playerTokens.filter(p=>p>=0).length);
        if (from >= 0 && from < avgProgress) score += 10; // Bring lagging tokens
      }

      // Small random factor to avoid deterministic play
      score += randomInt(10);

      scores.set(idx, score);
    }

    // Sort by score descending
    const sorted = legal.sort((a,b) => (scores.get(b) ?? 0) - (scores.get(a) ?? 0));
    
    if (difficulty === 'VERY_HARD') {
      return sorted[0];
    }
    // HARD: 80% best, 20% second best or random
    if (difficulty === 'HARD') {
      if (randomInt(10) < 8) return sorted[0];
      return sorted.length > 1 ? sorted[1] : sorted[0];
    }
    return sorted[0];
  }

  @Interval(1200)
  async playBotTurns(): Promise<void> {
    try {
      await this.redis.ensureConnected();
      const gameIds = await this.redis.client.smembers(this.botGamesKey);
      if (!gameIds.length) return;

      for (const gameId of gameIds) {
        if (this.running.has(gameId)) continue;
        this.running.add(gameId);
        try {
          await this.playSingleGame(gameId);
        } catch (e) {
          this.logger.debug(`Bot play failed for ${gameId}: ${e instanceof Error ? e.message : 'unknown'}`);
        } finally {
          this.running.delete(gameId);
        }
      }
    } catch (e) {
      this.logger.debug(`Bot interval error: ${e instanceof Error ? e.message : 'unknown'}`);
    }
  }

  private async playSingleGame(gameId: string): Promise<void> {
    // Load state without lock first to check if bot turn
    let state;
    try {
      state = await this.store.get(gameId);
    } catch {
      // Game not found or finished - cleanup
      await this.removeBotGame(gameId);
      return;
    }

    if (state.phase === 'FINISHED') {
      await this.removeBotGame(gameId);
      return;
    }

    if (state.phase === 'WAITING_PLAYERS') {
      // Still waiting for real players to connect, skip
      return;
    }

    const currentPlayer = state.players[state.turnIndex];
    if (!currentPlayer || currentPlayer.forfeited) return;

    const difficulty = await this.getBotDifficulty(gameId, currentPlayer.userId);
    if (!difficulty) {
      // Not a bot game or not bot's turn - check if any player in game is bot, if none, cleanup
      await this.redis.ensureConnected();
      const exists = await this.redis.client.exists(`bot:game:${gameId}`);
      if (!exists) {
        // No bot mapping, but gameId still in set - check if game has any bot user via DB
        const hasBot = await this.checkGameHasBot(gameId);
        if (!hasBot) {
          await this.removeBotGame(gameId);
          return;
        }
      } else {
        // Current player is not bot, skip
        return;
      }
    }

    // It's bot's turn
    // Add small random delay to simulate human thinking, based on difficulty
    const thinkDelay = difficulty === 'EASY' ? randomInt(800, 2500) : difficulty === 'HARD' ? randomInt(600, 1800) : randomInt(400, 1200);
    await new Promise(res => setTimeout(res, thinkDelay));

    // Now perform action with lock
    await this.lock.run(gameId, async () => {
      const freshState = await this.store.get(gameId);
      if (freshState.phase === 'FINISHED') {
        await this.removeBotGame(gameId);
        return;
      }
      const player = freshState.players[freshState.turnIndex];
      if (!player) return;
      const freshDifficulty = await this.getBotDifficulty(gameId, player.userId);
      if (!freshDifficulty) return; // No longer bot's turn

      try {
        let result;
        if (freshState.phase === 'WAITING_ROLL') {
          result = this.engine.roll(freshState, player.userId);
          await this.store.persist(freshState.version, result.state);
          this.gateway.broadcast(gameId, result);
        } else if (freshState.phase === 'WAITING_MOVE' && freshState.pendingRoll != null) {
          const tokenIdx = this.chooseTokenIndex(
            player.tokens,
            player.team,
            freshState.pendingRoll,
            freshState.players as Array<{ userId: string; team: Team; tokens: [number, number, number, number]; forfeited: boolean }>,
            freshDifficulty,
          );
          if (tokenIdx < 0) {
            // No legal move - should not happen, but timeout will handle
            return;
          }
          result = this.engine.move(freshState, player.userId, tokenIdx);
          await this.store.persist(freshState.version, result.state);
          this.gateway.broadcast(gameId, result);
        }
      } catch (e) {
        this.logger.debug(`Bot action failed in ${gameId}: ${e instanceof Error ? e.message : 'unknown'}`);
      }
    });
  }

  private async checkGameHasBot(gameId: string): Promise<boolean> {
    try {
      const game = await this.prisma.game.findUnique({
        where: { id: gameId },
        select: { participants: { select: { user: { select: { deviceId: true } } } } },
      });
      if (!game) return false;
      return game.participants.some((p: { user: { deviceId: string | null } }) => p.user.deviceId?.startsWith('bot-'));
    } catch {
      return false;
    }
  }
}
