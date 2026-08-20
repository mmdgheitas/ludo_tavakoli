import { INestApplicationContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';
import { Server, ServerOptions, Socket } from 'socket.io';

interface AuthenticatedSocketData {
  userId: string;
  subscribedGames: string[];
}
type AuthenticatedSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, AuthenticatedSocketData>;
import { SocketAuthService } from '../modules/auth/socket-auth.service';

export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor?: ReturnType<typeof createAdapter>;
  private pubClient?: Redis;
  private subClient?: Redis;

  constructor(
    app: INestApplicationContext,
    private readonly config: ConfigService,
    private readonly socketAuth: SocketAuthService,
  ) {
    super(app);
  }

  async connectToRedis(): Promise<void> {
    const url = this.config.get<string>('REDIS_URL') ?? 'redis://:redis_dev@127.0.0.1:6379';
    this.pubClient = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: null });
    this.subClient = this.pubClient.duplicate();
    await Promise.all([this.pubClient.connect(), this.subClient.connect()]);
    this.adapterConstructor = createAdapter(this.pubClient, this.subClient);
  }

  createIOServer(port: number, options?: ServerOptions): Server {
    const server = super.createIOServer(port, options) as Server;
    if (!this.adapterConstructor) throw new Error('Redis Socket.IO adapter is not initialized');
    server.adapter(this.adapterConstructor);
    server.use((socket, next) => {
      const token = String(socket.handshake.auth.token ?? '');
      this.socketAuth.validate(token)
        .then((payload) => {
          const authenticatedSocket = socket as AuthenticatedSocket;
          authenticatedSocket.data.userId = payload.sub;
          authenticatedSocket.data.subscribedGames = [];
          next();
        })
        .catch(() => next(new Error('Unauthorized socket')));
    });
    return server;
  }
}
