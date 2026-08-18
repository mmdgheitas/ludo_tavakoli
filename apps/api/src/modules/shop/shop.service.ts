import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ItemType, TransactionStatus, TransactionType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ShopService {
  constructor(private readonly prisma: PrismaService) {}

  list() {
    return this.prisma.item.findMany({
      where: { active: true }, orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
      select: { id: true, sku: true, nameFa: true, descriptionFa: true, type: true, coinPrice: true, realPriceIrr: true, metadata: true },
    });
  }

  inventory(userId: string) {
    return this.prisma.inventory.findMany({ where: { userId, quantity: { gt: 0 } }, include: { item: true }, orderBy: { updatedAt: 'desc' } });
  }

  async purchase(userId: string, itemId: string, idempotencyKey: string) {
    const previous = await this.prisma.walletTransaction.findUnique({ where: { idempotencyKey } });
    if (previous) {
      if (previous.userId !== userId) throw new ConflictException('Idempotency key belongs to another user');
      return previous;
    }
    return this.prisma.$transaction(async (tx) => {
      const item = await tx.item.findUnique({ where: { id: itemId } });
      if (!item?.active) throw new NotFoundException('Item is not available');
      if (item.coinPrice == null || item.coinPrice < 0) throw new BadRequestException('Item is not purchasable with coins');
      const charged = await tx.user.updateMany({
        where: { id: userId, coinBalance: { gte: item.coinPrice } },
        data: {
          coinBalance: { decrement: item.coinPrice },
          fattahBalance: item.type === ItemType.FATTAH ? { increment: 1 } : undefined,
        },
      });
      if (charged.count !== 1) throw new BadRequestException('Insufficient coin balance');
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { coinBalance: true } });
      if (item.type !== ItemType.FATTAH) {
        await tx.inventory.upsert({
          where: { userId_itemId: { userId, itemId } },
          create: { userId, itemId, quantity: 1 },
          update: { quantity: { increment: 1 } },
        });
      }
      return tx.walletTransaction.create({
        data: {
          userId, type: item.type === ItemType.FATTAH ? TransactionType.FATTAH_PURCHASE : TransactionType.SHOP_PURCHASE,
          status: TransactionStatus.SUCCEEDED, amount: -item.coinPrice, balanceAfter: user.coinBalance,
          idempotencyKey, referenceId: item.id, metadata: { sku: item.sku },
        },
      });
    });
  }
}
