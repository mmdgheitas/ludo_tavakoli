import { ConflictException, Injectable } from '@nestjs/common';
import { TransactionStatus, TransactionType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class WalletService {
  constructor(private readonly prisma: PrismaService) {}

  async history(userId: string, page = 1) {
    const take = 30;
    return this.prisma.walletTransaction.findMany({
      where: { userId }, orderBy: { createdAt: 'desc' }, take, skip: (Math.max(1, page) - 1) * take,
      select: { id: true, type: true, status: true, currency: true, amount: true, balanceAfter: true, createdAt: true },
    });
  }

  async claimDaily(userId: string) {
    const now = new Date();
    const day = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const reward = 100;
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.dailyReward.findUnique({ where: { userId_rewardDay: { userId, rewardDay: day } } });
      if (existing) throw new ConflictException('Daily reward already claimed');
      await tx.dailyReward.create({ data: { userId, rewardDay: day, coins: reward } });
      const user = await tx.user.update({ where: { id: userId }, data: { coinBalance: { increment: reward } }, select: { coinBalance: true } });
      await tx.walletTransaction.create({
        data: {
          userId, type: TransactionType.DAILY_REWARD, status: TransactionStatus.SUCCEEDED,
          amount: reward, balanceAfter: user.coinBalance, idempotencyKey: `daily:${userId}:${day.toISOString()}`,
        },
      });
      return { amount: reward, balance: user.coinBalance };
    });
  }

  async adminReward(userId: string, amount: number, reason: string, actorId: string) {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.update({ where: { id: userId }, data: { coinBalance: { increment: amount } }, select: { coinBalance: true } });
      const transaction = await tx.walletTransaction.create({
        data: {
          userId, type: TransactionType.ADMIN_REWARD, status: TransactionStatus.SUCCEEDED,
          amount, balanceAfter: user.coinBalance, idempotencyKey: `admin:${actorId}:${crypto.randomUUID()}`,
          metadata: { reason, actorId },
        },
      });
      await tx.adminAudit.create({ data: { actorId, action: 'wallet.reward', targetType: 'User', targetId: userId, metadata: { amount, reason } } });
      return transaction;
    });
  }
}
