import { Logger, UsePipes, ValidationPipe } from '@nestjs/common';
import { ConnectedSocket, MessageBody, OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { SocketAuthService } from '../auth/socket-auth.service';
import { FattahDto, MoveTokenDto } from './dto/game.dto';
import { GamesService } from './games.service';

interface GameMessage { gameId: string }
interface MoveMessage extends GameMessage, MoveTokenDto {}
interface FattahMessage extends GameMessage, FattahDto {}
interface SocketData { userId: string }
type GameSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, SocketData>;

@WebSocketGateway({ cors: { origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3000').split(','), credentials: true }, transports: ['websocket'] })
@UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
export class GamesGateway implements OnGatewayConnection {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(GamesGateway.name);

  constructor(private readonly games: GamesService, private readonly socketAuth: SocketAuthService) {}

  async handleConnection(client: GameSocket): Promise<void> {
    try {
      const payload = await this.socketAuth.validate(String(client.handshake.auth.token ?? ''));
      client.data.userId = payload.sub;
    } catch {
      client.disconnect(true);
    }
  }

  @SubscribeMessage('game:subscribe')
  async subscribe(@ConnectedSocket() client: GameSocket, @MessageBody() message: GameMessage) {
    const state = await this.games.getForUser(message.gameId, client.data.userId);
    await client.join(this.room(message.gameId));
    return { event: 'game:state', data: state };
  }

  @SubscribeMessage('game:roll')
  async roll(@ConnectedSocket() client: GameSocket, @MessageBody() message: GameMessage) {
    return this.execute(message.gameId, () => this.games.roll(message.gameId, client.data.userId));
  }

  @SubscribeMessage('game:move')
  async move(@ConnectedSocket() client: GameSocket, @MessageBody() message: MoveMessage) {
    return this.execute(message.gameId, () => this.games.move(message.gameId, client.data.userId, message.tokenIndex));
  }

  @SubscribeMessage('game:fattah')
  async fattah(@ConnectedSocket() client: GameSocket, @MessageBody() message: FattahMessage) {
    return this.execute(message.gameId, () => this.games.useFattah(message.gameId, client.data.userId, message.targetUserId, message.targetTokenIndex));
  }

  private async execute(gameId: string, action: () => Promise<unknown>) {
    try {
      const result = await action();
      this.server.to(this.room(gameId)).emit('game:state', result);
      return { event: 'game:ack', data: { accepted: true } };
    } catch (error) {
      this.logger.warn(error instanceof Error ? error.message : 'Game command failed');
      return { event: 'game:error', data: { message: error instanceof Error ? error.message : 'Command rejected' } };
    }
  }

  private room(gameId: string): string { return `game:${gameId}`; }
}
