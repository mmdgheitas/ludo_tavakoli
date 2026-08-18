import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { GamesModule } from '../games/games.module';
import { ChatController } from './chat.controller';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';

@Module({ imports: [AuthModule, GamesModule], controllers: [ChatController], providers: [ChatService, ChatGateway] })
export class ChatModule {}
