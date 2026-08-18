import { Injectable } from '@nestjs/common';
import { GameStatus, TransactionStatus, TransactionType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../../redis/redis.service';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService, private readonly redis: RedisService) {}

  async dashboard() {
    const now = new Date();
    const dayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
    await this.redis.ensureConnected();
    await this.redis.client.zremrangebyscore('presence:online', 0, Date.now() - 120_000);
    const [totalUsers, dailyActiveUsers, onlineMembers, gamesPlayed, finishedGames, vipPurchases, fattahPurchases, revenue] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({ where: { lastSeenAt: { gte: dayStart } } }),
      this.redis.client.zrange('presence:online', 0, -1),
      this.prisma.game.count({ where: { createdAt: { gte: dayStart } } }),
      this.prisma.game.count({ where: { status: GameStatus.FINISHED, finishedAt: { gte: dayStart } } }),
      this.prisma.vipPurchase.count({ where: { createdAt: { gte: monthStart } } }),
      this.prisma.walletTransaction.count({ where: { type: TransactionType.FATTAH_PURCHASE, status: TransactionStatus.SUCCEEDED, createdAt: { gte: monthStart } } }),
      this.prisma.payment.aggregate({ where: { status: TransactionStatus.SUCCEEDED, createdAt: { gte: monthStart } }, _sum: { amountIrr: true } }),
    ]);
    const onlineUsers = new Set(onlineMembers.map((member) => member.split(':')[0])).size;
    return { totalUsers, dailyActiveUsers, onlineUsers, gamesPlayed, finishedGames, vipPurchases, fattahPurchases, revenueIrr: revenue._sum.amountIrr ?? 0 };
  }

  async trends() {
    const since = new Date(Date.now() - 6 * 86_400_000);
    since.setUTCHours(0, 0, 0, 0);
    const [users, games, payments] = await Promise.all([
      this.prisma.user.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
      this.prisma.game.findMany({ where: { createdAt: { gte: since } }, select: { createdAt: true } }),
      this.prisma.payment.findMany({ where: { createdAt: { gte: since }, status: TransactionStatus.SUCCEEDED }, select: { createdAt: true, amountIrr: true } }),
    ]);
    return Array.from({ length: 7 }, (_, offset) => {
      const date = new Date(since.getTime() + offset * 86_400_000);
      const key = date.toISOString().slice(0, 10);
      return {
        date: key,
        users: users.filter((item) => item.createdAt.toISOString().startsWith(key)).length,
        games: games.filter((item) => item.createdAt.toISOString().startsWith(key)).length,
        revenueIrr: payments.filter((item) => item.createdAt.toISOString().startsWith(key)).reduce((sum, item) => sum + item.amountIrr, 0),
      };
    });
  }
}
