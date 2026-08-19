import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller';
import { AdminModule } from './modules/admin/admin.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { AuthModule } from './modules/auth/auth.module';
import { ChatModule } from './modules/chat/chat.module';
import { FattahModule } from './modules/fattah/fattah.module';
import { GamesModule } from './modules/games/games.module';
import { MatchmakingModule } from './modules/matchmaking/matchmaking.module';
import { PaymentsModule } from './modules/payments/payments.module';
import { ShopModule } from './modules/shop/shop.module';
import { UsersModule } from './modules/users/users.module';
import { SupportModule } from './modules/support/support.module';
import { VipModule } from './modules/vip/vip.module';
import { WalletModule } from './modules/wallet/wallet.module';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { validateEnvironment } from './config/env.validation';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, cache: true, validate: validateEnvironment }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
    ScheduleModule.forRoot(),
    PrismaModule,
    RedisModule,
    AuthModule,
    UsersModule,
    GamesModule,
    MatchmakingModule,
    WalletModule,
    ShopModule,
    VipModule,
    FattahModule,
    PaymentsModule,
    ChatModule,
    SupportModule,
    AdminModule,
    AnalyticsModule,
  ],
  controllers: [AppController],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
