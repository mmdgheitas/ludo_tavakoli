-- AlterTable
ALTER TABLE "AdminAudit" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "DailyReward" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "FattahUsage" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "Game" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "GameParticipant" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "Item" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "PasswordResetToken" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "Payment" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "QuickChat" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "RefreshSession" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "SupportTicket" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "User" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "VipPurchase" ALTER COLUMN "id" DROP DEFAULT;

-- AlterTable
ALTER TABLE "WalletTransaction" ALTER COLUMN "id" DROP DEFAULT;
