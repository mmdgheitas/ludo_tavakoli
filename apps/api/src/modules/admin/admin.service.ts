import { Injectable } from '@nestjs/common';
import { GameStatus, Prisma, TransactionStatus, UserStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { WalletService } from '../wallet/wallet.service';
import { CreateChatDto, CreateItemDto, UpdateChatDto, UpdateItemDto, VipSettingDto } from './dto/admin.dto';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService, private readonly wallet: WalletService) {}

  async users(page: number, search?: string) {
    const take = 25;
    const where = search ? { username: { contains: search, mode: 'insensitive' as const } } : {};
    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({ where, skip: (page - 1) * take, take, orderBy: { createdAt: 'desc' }, select: { id: true, username: true, avatarUrl: true, coinBalance: true, fattahBalance: true, vipExpiresAt: true, status: true, role: true, lastSeenAt: true, createdAt: true } }),
      this.prisma.user.count({ where }),
    ]);
    return { items, total, page, pageSize: take };
  }

  async changeStatus(actorId: string, userId: string, status: UserStatus, reason: string) {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.update({ where: { id: userId }, data: { status } });
      if (status === UserStatus.BANNED) await tx.refreshSession.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } });
      await tx.adminAudit.create({ data: { actorId, action: 'user.status', targetType: 'User', targetId: userId, metadata: { status, reason } } });
      return user;
    });
  }

  reward(actorId: string, userId: string, amount: number, reason: string) {
    return this.wallet.adminReward(userId, amount, reason, actorId);
  }

  games(page: number) {
    const take = 25;
    return this.prisma.game.findMany({ skip: (page - 1) * take, take, orderBy: { createdAt: 'desc' }, include: { participants: { select: { team: true, user: { select: { id: true, username: true } } } }, winner: { select: { id: true, username: true } } } });
  }

  transactions(page: number) {
    const take = 25;
    return this.prisma.walletTransaction.findMany({ skip: (page - 1) * take, take, orderBy: { createdAt: 'desc' }, include: { user: { select: { id: true, username: true } } } });
  }

  items() { return this.prisma.item.findMany({ orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }] }); }
  createItem(dto: CreateItemDto) { return this.prisma.item.create({ data: dto }); }
  updateItem(id: string, dto: UpdateItemDto) { return this.prisma.item.update({ where: { id }, data: dto }); }

  chats() { return this.prisma.quickChat.findMany({ orderBy: { sortOrder: 'asc' } }); }
  createChat(dto: CreateChatDto) { return this.prisma.quickChat.create({ data: dto }); }
  updateChat(id: string, dto: UpdateChatDto) { return this.prisma.quickChat.update({ where: { id }, data: dto }); }

  vipPurchases(page: number) { return this.prisma.vipPurchase.findMany({ take: 25, skip: (page - 1) * 25, orderBy: { createdAt: 'desc' }, include: { user: { select: { username: true } } } }); }

  async updateVipSetting(actorId: string, dto: VipSettingDto) {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: 'billing_products' } });
    const current = setting?.value as { products?: Array<Record<string, unknown>> } | undefined;
    const products = [...(current?.products ?? [])];
    const index = products.findIndex((product) => product.sku === dto.sku);
    const billingProduct = { sku: dto.sku, type: 'VIP', amountIrr: dto.priceIrr, value: dto.durationDays };
    if (index >= 0) products[index] = billingProduct;
    else products.push(billingProduct);
    const offer = { sku: dto.sku, titleFa: dto.titleFa, durationDays: dto.durationDays, priceIrr: dto.priceIrr };
    await this.prisma.$transaction([
      this.prisma.appSetting.upsert({ where: { key: 'vip_offer' }, create: { key: 'vip_offer', value: offer }, update: { value: offer } }),
      this.prisma.appSetting.upsert({ where: { key: 'billing_products' }, create: { key: 'billing_products', value: { products } as Prisma.InputJsonValue }, update: { value: { products } as Prisma.InputJsonValue } }),
      this.prisma.adminAudit.create({ data: { actorId, action: 'vip.setting.update', targetType: 'AppSetting', targetId: 'vip_offer', metadata: offer } }),
    ]);
    return offer;
  }

  payments(page: number) { return this.prisma.payment.findMany({ take: 25, skip: (page - 1) * 25, orderBy: { createdAt: 'desc' }, include: { user: { select: { username: true } } } }); }

  async operationalSummary() {
    const [waitingGames, activeGames, failedTransactions] = await Promise.all([
      this.prisma.game.count({ where: { status: GameStatus.WAITING } }),
      this.prisma.game.count({ where: { status: GameStatus.ACTIVE } }),
      this.prisma.walletTransaction.count({ where: { status: TransactionStatus.FAILED } }),
    ]);
    return { waitingGames, activeGames, failedTransactions };
  }
}
