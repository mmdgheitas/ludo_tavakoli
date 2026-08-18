import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
import { PresenceGateway } from './presence.gateway';

@Module({ imports: [AuthModule], controllers: [AnalyticsController], providers: [AnalyticsService, PresenceGateway] })
export class AnalyticsModule {}
