import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { ItemType, PrismaClient, UserRole } from '@prisma/client';
import { hash } from 'bcryptjs';

const connectionString = process.env.DATABASE_URL;
if (!connectionString) throw new Error('DATABASE_URL is required');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString }) });

async function main(): Promise<void> {
  const username = process.env.ADMIN_USERNAME ?? 'admin';
  const password = process.env.ADMIN_PASSWORD ?? "0123456789";
  if (!password || password.length < 10) throw new Error('Set ADMIN_PASSWORD to at least 10 characters before seeding');
  await prisma.user.upsert({
    where: { username },
    update: { role: UserRole.SUPER_ADMIN, passwordHash: await hash(password, 12) },
    create: { username, role: UserRole.SUPER_ADMIN, passwordHash: await hash(password, 12), coinBalance: 0 },
  });

  const items = [
    { sku: 'skin.turquoise', nameFa: 'مهره فیروزه‌ای', descriptionFa: 'مجموعه مهره با طرح فیروزه ایرانی', type: ItemType.PIECE_SKIN, coinPrice: 2500, sortOrder: 10 },
    { sku: 'avatar.pahlevan', nameFa: 'آواتار پهلوان', descriptionFa: 'آواتار اختصاصی پهلوان ایرانی', type: ItemType.AVATAR, coinPrice: 3000, sortOrder: 20 },
    { sku: 'fattah.single', nameFa: 'موشک فتاح', descriptionFa: 'یک‌بار استفاده در هر بازی', type: ItemType.FATTAH, coinPrice: 1200, sortOrder: 30 },
  ];
  for (const item of items) await prisma.item.upsert({ where: { sku: item.sku }, update: item, create: item });

  const chats = [
    { textFa: 'آفرین!', emoji: '👏', sortOrder: 10 },
    { textFa: 'موفق باشی', emoji: '🍀', sortOrder: 20 },
    { textFa: 'چه شانسی!', emoji: '🎲', sortOrder: 30 },
    { textFa: 'بزن بریم', emoji: '😄', sortOrder: 40 },
  ];
  for (const chat of chats) {
    const existing = await prisma.quickChat.findFirst({ where: { textFa: chat.textFa } });
    if (existing) await prisma.quickChat.update({ where: { id: existing.id }, data: chat });
    else await prisma.quickChat.create({ data: chat });
  }

  const vipOffer = { sku: 'vip.30d', durationDays: 30, priceIrr: 199000, titleFa: 'عضویت ویژه یک‌ماهه' };
  const billingProducts = { products: [
    { sku: 'vip.30d', type: 'VIP', amountIrr: 199000, value: 30 },
    { sku: 'fattah.5', type: 'FATTAH', amountIrr: 99000, value: 5 },
    { sku: 'coins.5000', type: 'COIN', amountIrr: 149000, value: 5000 },
  ] };
  await prisma.appSetting.upsert({ where: { key: 'vip_offer' }, update: { value: vipOffer }, create: { key: 'vip_offer', value: vipOffer } });
  await prisma.appSetting.upsert({ where: { key: 'billing_products' }, update: { value: billingProducts }, create: { key: 'billing_products', value: billingProducts } });
}

main().then(() => prisma.$disconnect()).catch(async (error: unknown) => {
  console.error(error);
  await prisma.$disconnect();
  process.exit(1);
});
