import { ConnectedSocket, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway } from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { RedisService } from '../../redis/redis.service';
import { SocketAuthService } from '../auth/socket-auth.service';

interface SocketData { userId: string; presenceMember: string }
type PresenceSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, SocketData>;

@WebSocketGateway({ cors: { origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3000').split(','), credentials: true }, transports: ['websocket'] })
export class PresenceGateway implements OnGatewayConnection, OnGatewayDisconnect {
  constructor(private readonly redis: RedisService, private readonly socketAuth: SocketAuthService) {}
  async handleConnection(client: PresenceSocket): Promise<void> {
    try {
      const payload = await this.socketAuth.validate(String(client.handshake.auth.token ?? ''));
      client.data.userId = payload.sub;
      client.data.presenceMember = `${payload.sub}:${client.id}`;
      await this.touch(client.data.presenceMember);
    } catch { client.disconnect(true); }
  }
  async handleDisconnect(client: PresenceSocket): Promise<void> {
    if (client.data.presenceMember) await this.redis.client.zrem('presence:online', client.data.presenceMember);
  }
  @SubscribeMessage('presence:heartbeat')
  async heartbeat(@ConnectedSocket() client: PresenceSocket) { await this.touch(client.data.presenceMember); return { event: 'presence:ack', data: { at: Date.now() } }; }
  private async touch(member: string): Promise<void> { await this.redis.ensureConnected(); await this.redis.client.zadd('presence:online', Date.now(), member); }
}
