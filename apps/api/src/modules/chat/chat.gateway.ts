import { ConnectedSocket, MessageBody, OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';

interface SocketData { userId: string }
type ChatSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, SocketData>;

@WebSocketGateway({ cors: { origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3000').split(','), credentials: true }, transports: ['websocket'] })
export class ChatGateway implements OnGatewayConnection {
  @WebSocketServer() server!: Server;
  constructor(private readonly chat: ChatService) {}

  handleConnection(client: ChatSocket): void {
    if (!client.data.userId) client.disconnect(true);
  }

  @SubscribeMessage('chat:send')
  async send(@ConnectedSocket() client: ChatSocket, @MessageBody() body: { gameId: string; messageId: string }) {
    try {
      const message = await this.chat.validate(client.data.userId, body.gameId, body.messageId);
      this.server.to(`game:${body.gameId}`).emit('chat:message', message);
      return { event: 'chat:ack', data: { accepted: true } };
    } catch (error) {
      return { event: 'chat:error', data: { message: error instanceof Error ? error.message : 'Message rejected' } };
    }
  }
}
