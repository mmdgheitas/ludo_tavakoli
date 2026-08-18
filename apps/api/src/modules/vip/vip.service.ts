import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class VipService {
  constructor(private readonly prisma: PrismaService) {}

  async offer() {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: 'vip_offer' } });
    return setting?.value ?? { sku: 'vip.30d', durationDays: 30, priceIrr: 199000, titleFa: 'عضویت ویژه یک‌ماهه' };
  }

  async status(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { vipExpiresAt: true } });
    return { active: user.vipExpiresAt != null && user.vipExpiresAt > new Date(), expiresAt: user.vipExpiresAt, rewardMultiplier: user.vipExpiresAt != null && user.vipExpiresAt > new Date() ? 2 : 1 };
  }
}
