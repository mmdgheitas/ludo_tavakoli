import { GameMode } from '@prisma/client';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { MatchmakingService } from './matchmaking.service';

interface SocketData { userId: string }
type MatchSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, SocketData>;

@WebSocketGateway({ cors: { origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3000').split(','), credentials: true }, transports: ['websocket'] })
export class MatchmakingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  constructor(private readonly matchmaking: MatchmakingService) {}

  handleConnection(client: MatchSocket): void {
    if (!client.data.userId) client.disconnect(true);
  }

  async handleDisconnect(client: MatchSocket): Promise<void> {
    if (client.data.userId) await this.matchmaking.leaveSocket(client.data.userId, client.id);
  }

  @SubscribeMessage('matchmaking:join')
  async join(@ConnectedSocket() client: MatchSocket, @MessageBody() body: { mode: GameMode }) {
    try {
      const match = await this.matchmaking.join(client.data.userId, client.id, body.mode);
      if (!match) return { event: 'matchmaking:queued', data: { mode: body.mode } };
      for (const socketId of match.socketIds) {
        this.server.to(socketId).emit('matchmaking:matched', {
          gameId: match.gameId,
          mode: match.mode,
          playerCount: match.userIds.length,
        });
      }
      return { event: 'matchmaking:ack', data: { matched: true, gameId: match.gameId } };
    } catch (error) {
      return { event: 'matchmaking:error', data: { message: error instanceof Error ? error.message : 'Matchmaking failed' } };
    }
  }

  @SubscribeMessage('matchmaking:leave')
  async leave(@ConnectedSocket() client: MatchSocket) {
    await this.matchmaking.leaveSocket(client.data.userId, client.id);
    return { event: 'matchmaking:left', data: { success: true } };
  }
}
