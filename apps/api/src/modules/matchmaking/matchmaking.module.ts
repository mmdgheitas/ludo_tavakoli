import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { GamesModule } from '../games/games.module';
import { MatchmakingGateway } from './matchmaking.gateway';
import { MatchmakingService } from './matchmaking.service';

@Module({ imports: [AuthModule, GamesModule], providers: [MatchmakingService, MatchmakingGateway] })
export class MatchmakingModule {}
