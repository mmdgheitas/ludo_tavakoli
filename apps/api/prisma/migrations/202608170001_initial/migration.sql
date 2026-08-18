CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE "UserRole" AS ENUM ('PLAYER', 'SUPPORT', 'ADMIN', 'SUPER_ADMIN');
CREATE TYPE "UserStatus" AS ENUM ('ACTIVE', 'BANNED', 'DELETED');
CREATE TYPE "GameMode" AS ENUM ('OFFLINE_2P', 'OFFLINE_4P', 'ONLINE_2P', 'ONLINE_4P');
CREATE TYPE "GameStatus" AS ENUM ('WAITING', 'ACTIVE', 'FINISHED', 'ABANDONED', 'CANCELLED');
CREATE TYPE "Team" AS ENUM ('BLUE', 'RED', 'GREEN', 'YELLOW');
CREATE TYPE "ItemType" AS ENUM ('PIECE_SKIN', 'AVATAR', 'FATTAH', 'SPECIAL');
CREATE TYPE "CurrencyType" AS ENUM ('COIN', 'IRR');
CREATE TYPE "TransactionType" AS ENUM ('GAME_REWARD', 'DAILY_REWARD', 'ADMIN_REWARD', 'SHOP_PURCHASE', 'VIP_PURCHASE', 'FATTAH_PURCHASE', 'PAYMENT', 'REFUND');
CREATE TYPE "TransactionStatus" AS ENUM ('PENDING', 'SUCCEEDED', 'FAILED', 'REFUNDED');
CREATE TYPE "PaymentProvider" AS ENUM ('CAFE_BAZAAR', 'MYKET');

CREATE TABLE "User" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "username" VARCHAR(32) NOT NULL,
  "avatarUrl" VARCHAR(512),
  "coinBalance" INTEGER NOT NULL DEFAULT 500,
  "fattahBalance" INTEGER NOT NULL DEFAULT 0,
  "vipExpiresAt" TIMESTAMP(3),
  "role" "UserRole" NOT NULL DEFAULT 'PLAYER',
  "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
  "passwordHash" TEXT,
  "deviceId" VARCHAR(128),
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "User_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "User_coin_nonnegative" CHECK ("coinBalance" >= 0),
  CONSTRAINT "User_fattah_nonnegative" CHECK ("fattahBalance" >= 0)
);

CREATE TABLE "RefreshSession" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "tokenHash" TEXT NOT NULL,
  "userAgent" VARCHAR(256), "ipAddress" VARCHAR(64), "expiresAt" TIMESTAMP(3) NOT NULL,
  "revokedAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RefreshSession_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Game" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "mode" "GameMode" NOT NULL,
  "status" "GameStatus" NOT NULL DEFAULT 'WAITING', "state" JSONB NOT NULL,
  "version" INTEGER NOT NULL DEFAULT 0, "winnerId" UUID, "rewardCoins" INTEGER NOT NULL DEFAULT 0,
  "startedAt" TIMESTAMP(3), "finishedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Game_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "GameParticipant" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "gameId" UUID NOT NULL, "userId" UUID NOT NULL,
  "team" "Team" NOT NULL, "placement" INTEGER, "score" INTEGER NOT NULL DEFAULT 0,
  "disconnectedAt" TIMESTAMP(3), "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "GameParticipant_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Item" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "sku" VARCHAR(64) NOT NULL,
  "nameFa" VARCHAR(100) NOT NULL, "descriptionFa" VARCHAR(500), "type" "ItemType" NOT NULL,
  "coinPrice" INTEGER, "realPriceIrr" INTEGER, "metadata" JSONB, "active" BOOLEAN NOT NULL DEFAULT true,
  "sortOrder" INTEGER NOT NULL DEFAULT 0, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Item_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Item_prices_nonnegative" CHECK (("coinPrice" IS NULL OR "coinPrice" >= 0) AND ("realPriceIrr" IS NULL OR "realPriceIrr" >= 0))
);

CREATE TABLE "Inventory" (
  "userId" UUID NOT NULL, "itemId" UUID NOT NULL, "quantity" INTEGER NOT NULL DEFAULT 0,
  "equipped" BOOLEAN NOT NULL DEFAULT false, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Inventory_pkey" PRIMARY KEY ("userId", "itemId"),
  CONSTRAINT "Inventory_quantity_nonnegative" CHECK ("quantity" >= 0)
);

CREATE TABLE "WalletTransaction" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "type" "TransactionType" NOT NULL,
  "status" "TransactionStatus" NOT NULL DEFAULT 'PENDING', "currency" "CurrencyType" NOT NULL DEFAULT 'COIN',
  "amount" INTEGER NOT NULL, "balanceAfter" INTEGER, "idempotencyKey" VARCHAR(128) NOT NULL,
  "referenceId" VARCHAR(128), "metadata" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "WalletTransaction_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Payment" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "provider" "PaymentProvider" NOT NULL,
  "productSku" VARCHAR(100) NOT NULL, "purchaseTokenHash" TEXT NOT NULL,
  "providerTransactionId" VARCHAR(128), "amountIrr" INTEGER NOT NULL,
  "status" "TransactionStatus" NOT NULL DEFAULT 'PENDING', "verifiedAt" TIMESTAMP(3),
  "rawVerification" JSONB, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Payment_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "VipPurchase" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "userId" UUID NOT NULL,
  "startDate" TIMESTAMP(3) NOT NULL, "expireDate" TIMESTAMP(3) NOT NULL, "priceIrr" INTEGER NOT NULL,
  "paymentId" UUID, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "VipPurchase_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "FattahUsage" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "gameId" UUID NOT NULL, "userId" UUID NOT NULL,
  "targetTokenId" VARCHAR(32) NOT NULL, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "FattahUsage_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "QuickChat" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "textFa" VARCHAR(80) NOT NULL, "emoji" VARCHAR(16),
  "active" BOOLEAN NOT NULL DEFAULT true, "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "QuickChat_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "DailyReward" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "userId" UUID NOT NULL, "rewardDay" DATE NOT NULL,
  "coins" INTEGER NOT NULL, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "DailyReward_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "AppSetting" (
  "key" VARCHAR(64) NOT NULL, "value" JSONB NOT NULL, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "AppSetting_pkey" PRIMARY KEY ("key")
);

CREATE TABLE "AdminAudit" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(), "actorId" UUID NOT NULL, "action" VARCHAR(100) NOT NULL,
  "targetType" VARCHAR(64) NOT NULL, "targetId" VARCHAR(128), "metadata" JSONB,
  "ipAddress" VARCHAR(64), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AdminAudit_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "User_username_key" ON "User"("username");
CREATE UNIQUE INDEX "User_deviceId_key" ON "User"("deviceId");
CREATE INDEX "User_createdAt_idx" ON "User"("createdAt");
CREATE INDEX "User_lastSeenAt_idx" ON "User"("lastSeenAt");
CREATE INDEX "User_status_idx" ON "User"("status");
CREATE UNIQUE INDEX "RefreshSession_tokenHash_key" ON "RefreshSession"("tokenHash");
CREATE INDEX "RefreshSession_userId_expiresAt_idx" ON "RefreshSession"("userId", "expiresAt");
CREATE INDEX "Game_status_createdAt_idx" ON "Game"("status", "createdAt");
CREATE INDEX "Game_winnerId_idx" ON "Game"("winnerId");
CREATE UNIQUE INDEX "GameParticipant_gameId_userId_key" ON "GameParticipant"("gameId", "userId");
CREATE UNIQUE INDEX "GameParticipant_gameId_team_key" ON "GameParticipant"("gameId", "team");
CREATE INDEX "GameParticipant_userId_joinedAt_idx" ON "GameParticipant"("userId", "joinedAt");
CREATE UNIQUE INDEX "Item_sku_key" ON "Item"("sku");
CREATE INDEX "Item_active_type_sortOrder_idx" ON "Item"("active", "type", "sortOrder");
CREATE UNIQUE INDEX "WalletTransaction_idempotencyKey_key" ON "WalletTransaction"("idempotencyKey");
CREATE INDEX "WalletTransaction_userId_createdAt_idx" ON "WalletTransaction"("userId", "createdAt");
CREATE INDEX "WalletTransaction_status_createdAt_idx" ON "WalletTransaction"("status", "createdAt");
CREATE UNIQUE INDEX "Payment_purchaseTokenHash_key" ON "Payment"("purchaseTokenHash");
CREATE UNIQUE INDEX "Payment_providerTransactionId_key" ON "Payment"("providerTransactionId");
CREATE INDEX "Payment_userId_createdAt_idx" ON "Payment"("userId", "createdAt");
CREATE INDEX "Payment_provider_status_idx" ON "Payment"("provider", "status");
CREATE UNIQUE INDEX "VipPurchase_paymentId_key" ON "VipPurchase"("paymentId");
CREATE INDEX "VipPurchase_userId_expireDate_idx" ON "VipPurchase"("userId", "expireDate");
CREATE UNIQUE INDEX "FattahUsage_gameId_userId_key" ON "FattahUsage"("gameId", "userId");
CREATE INDEX "QuickChat_active_sortOrder_idx" ON "QuickChat"("active", "sortOrder");
CREATE UNIQUE INDEX "DailyReward_userId_rewardDay_key" ON "DailyReward"("userId", "rewardDay");
CREATE INDEX "AdminAudit_actorId_createdAt_idx" ON "AdminAudit"("actorId", "createdAt");
CREATE INDEX "AdminAudit_targetType_targetId_idx" ON "AdminAudit"("targetType", "targetId");

ALTER TABLE "RefreshSession" ADD CONSTRAINT "RefreshSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Game" ADD CONSTRAINT "Game_winnerId_fkey" FOREIGN KEY ("winnerId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "GameParticipant" ADD CONSTRAINT "GameParticipant_gameId_fkey" FOREIGN KEY ("gameId") REFERENCES "Game"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "GameParticipant" ADD CONSTRAINT "GameParticipant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Inventory" ADD CONSTRAINT "Inventory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Inventory" ADD CONSTRAINT "Inventory_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "Item"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "WalletTransaction" ADD CONSTRAINT "WalletTransaction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "VipPurchase" ADD CONSTRAINT "VipPurchase_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "VipPurchase" ADD CONSTRAINT "VipPurchase_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "Payment"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "FattahUsage" ADD CONSTRAINT "FattahUsage_gameId_fkey" FOREIGN KEY ("gameId") REFERENCES "Game"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FattahUsage" ADD CONSTRAINT "FattahUsage_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "DailyReward" ADD CONSTRAINT "DailyReward_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AdminAudit" ADD CONSTRAINT "AdminAudit_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
