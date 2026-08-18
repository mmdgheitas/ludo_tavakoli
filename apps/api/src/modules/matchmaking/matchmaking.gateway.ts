import { GameMode } from '@prisma/client';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { SocketAuthService } from '../auth/socket-auth.service';
import { MatchmakingService } from './matchmaking.service';

interface SocketData { userId: string }
type MatchSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, SocketData>;

@WebSocketGateway({ cors: { origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3000').split(','), credentials: true }, transports: ['websocket'] })
export class MatchmakingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  constructor(private readonly matchmaking: MatchmakingService, private readonly socketAuth: SocketAuthService) {}

  async handleConnection(client: MatchSocket): Promise<void> {
    try {
      const payload = await this.socketAuth.validate(String(client.handshake.auth.token ?? ''));
      client.data.userId = payload.sub;
    } catch { client.disconnect(true); }
  }

  async handleDisconnect(client: MatchSocket): Promise<void> {
    if (client.data.userId) await this.matchmaking.leave(client.data.userId);
  }

  @SubscribeMessage('matchmaking:join')
  async join(@ConnectedSocket() client: MatchSocket, @MessageBody() body: { mode: GameMode }) {
    try {
      const match = await this.matchmaking.join(client.data.userId, client.id, body.mode);
      if (!match) return { event: 'matchmaking:queued', data: { mode: body.mode } };
      for (const socketId of match.socketIds) {
        this.server.to(socketId).emit('matchmaking:matched', { gameId: match.gameId });
      }
      return { event: 'matchmaking:ack', data: { matched: true, gameId: match.gameId } };
    } catch (error) {
      return { event: 'matchmaking:error', data: { message: error instanceof Error ? error.message : 'Matchmaking failed' } };
    }
  }

  @SubscribeMessage('matchmaking:leave')
  async leave(@ConnectedSocket() client: MatchSocket) {
    await this.matchmaking.leave(client.data.userId);
    return { event: 'matchmaking:left', data: { success: true } };
  }
}
