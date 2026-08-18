import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { GameLockService } from './game-lock.service';
import { GameStateStore } from './game-state.store';
import { GamesController } from './games.controller';
import { GamesGateway } from './games.gateway';
import { GamesService } from './games.service';

@Module({
  imports: [AuthModule],
  controllers: [GamesController],
  providers: [GamesService, GamesGateway, GameStateStore, GameLockService],
  exports: [GamesService],
})
export class GamesModule {}
