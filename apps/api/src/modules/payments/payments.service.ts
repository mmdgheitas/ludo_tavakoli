import { createHash } from 'node:crypto';
import { BadRequestException, ConflictException, Injectable } from '@nestjs/common';
import { CurrencyType, Prisma, TransactionStatus, TransactionType } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { VerifyPurchaseDto } from './dto/verify-purchase.dto';
import { ProviderVerifierService } from './provider-verifier.service';

type Product = { sku: string; type: 'VIP' | 'FATTAH' | 'COIN'; amountIrr: number; value: number };

@Injectable()
export class PaymentsService {
  constructor(private readonly prisma: PrismaService, private readonly verifier: ProviderVerifierService) {}

  async verify(userId: string, dto: VerifyPurchaseDto) {
    const tokenHash = createHash('sha256').update(dto.purchaseToken).digest('hex');
    const existing = await this.prisma.payment.findUnique({ where: { purchaseTokenHash: tokenHash } });
    if (existing) {
      if (existing.userId !== userId) throw new ConflictException('Receipt was already used by another account');
      return existing;
    }
    const product = await this.findProduct(dto.productSku);
    const verified = await this.verifier.verify(dto.provider, dto.purchaseToken, dto.productSku);
    if (verified.transactionId !== dto.providerTransactionId) throw new BadRequestException('Transaction identifier does not match receipt');

    return this.prisma.$transaction(async (tx) => {
      const payment = await tx.payment.create({
        data: {
          userId,
          provider: dto.provider,
          productSku: product.sku,
          purchaseTokenHash: tokenHash,
          providerTransactionId: verified.transactionId,
          amountIrr: product.amountIrr,
          status: TransactionStatus.SUCCEEDED,
          verifiedAt: new Date(),
          rawVerification: verified.raw,
        },
      });
      await this.fulfill(tx, userId, payment.id, product);
      return payment;
    });
  }

  history(userId: string) {
    return this.prisma.payment.findMany({
      where: { userId }, orderBy: { createdAt: 'desc' },
      select: { id: true, provider: true, productSku: true, amountIrr: true, status: true, verifiedAt: true, createdAt: true },
    });
  }

  private async fulfill(tx: Prisma.TransactionClient, userId: string, paymentId: string, product: Product): Promise<void> {
    if (product.type === 'VIP') {
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { vipExpiresAt: true } });
      const start = user.vipExpiresAt && user.vipExpiresAt > new Date() ? user.vipExpiresAt : new Date();
      const expireDate = new Date(start.getTime() + product.value * 86_400_000);
      await tx.user.update({ where: { id: userId }, data: { vipExpiresAt: expireDate } });
      await tx.vipPurchase.create({ data: { userId, startDate: start, expireDate, priceIrr: product.amountIrr, paymentId } });
    } else if (product.type === 'FATTAH') {
      await tx.user.update({ where: { id: userId }, data: { fattahBalance: { increment: product.value } } });
    } else {
      await tx.user.update({ where: { id: userId }, data: { coinBalance: { increment: product.value } } });
    }
    await tx.walletTransaction.create({
      data: {
        userId, type: product.type === 'VIP' ? TransactionType.VIP_PURCHASE : product.type === 'FATTAH' ? TransactionType.FATTAH_PURCHASE : TransactionType.PAYMENT,
        status: TransactionStatus.SUCCEEDED, currency: CurrencyType.IRR, amount: -product.amountIrr,
        idempotencyKey: `payment:${paymentId}`, referenceId: paymentId, metadata: { sku: product.sku },
      },
    });
  }

  private async findProduct(sku: string): Promise<Product> {
    const setting = await this.prisma.appSetting.findUnique({ where: { key: 'billing_products' } });
    const value = setting?.value as { products?: unknown[] } | null;
    const products = value?.products ?? [];
    const candidate = products.find((item) => typeof item === 'object' && item != null && (item as Record<string, unknown>).sku === sku);
    if (!this.isProduct(candidate)) throw new BadRequestException('Unknown billing product');
    return candidate;
  }

  private isProduct(value: unknown): value is Product {
    if (typeof value !== 'object' || value == null) return false;
    const item = value as Record<string, unknown>;
    return typeof item.sku === 'string' && ['VIP', 'FATTAH', 'COIN'].includes(String(item.type)) &&
      Number.isInteger(item.amountIrr) && Number(item.amountIrr) > 0 && Number.isInteger(item.value) && Number(item.value) > 0;
  }
}
