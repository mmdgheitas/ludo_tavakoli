import { GameMode } from '@prisma/client';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { MatchmakingService } from './matchmaking.service';

interface SocketData { userId: string }
type MatchSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, SocketData>;

@WebSocketGateway({ cors: { origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3000').split(','), credentials: true }, transports: ['websocket'] })
export class MatchmakingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(MatchmakingGateway.name);
  private readonly botTimers = new Map<string, NodeJS.Timeout>();
  private readonly BOT_WAIT_MS = 15_000;

  constructor(private readonly matchmaking: MatchmakingService) {}

  handleConnection(client: MatchSocket): void {
    if (!client.data.userId) client.disconnect(true);
  }

  async handleDisconnect(client: MatchSocket): Promise<void> {
    if (client.data.userId) {
      this.clearBotTimer(client.data.userId);
      await this.matchmaking.leaveSocket(client.data.userId, client.id);
    }
  }

  @SubscribeMessage('matchmaking:join')
  async join(@ConnectedSocket() client: MatchSocket, @MessageBody() body: { mode: GameMode }) {
    try {
      const mode = body?.mode;
      if (mode !== GameMode.ONLINE_2P && mode !== GameMode.ONLINE_4P) {
        return { event: 'matchmaking:error', data: { message: 'Unsupported mode' } };
      }

      // Clear any previous bot timer for this user
      this.clearBotTimer(client.data.userId);

      const match = await this.matchmaking.join(client.data.userId, client.id, mode);
      if (!match) {
        // Queued - schedule bot fallback after 15s
        this.scheduleBotFallback(client.data.userId, mode);
        return { event: 'matchmaking:queued', data: { mode } };
      }

      // Immediate real match found - clear timers for all matched users
      for (const uid of match.userIds) this.clearBotTimer(uid);

      for (const socketId of match.socketIds) {
        this.server.to(socketId).emit('matchmaking:matched', {
          gameId: match.gameId,
          mode: match.mode,
          playerCount: match.userIds.length,
        });
      }
      return { event: 'matchmaking:ack', data: { matched: true, gameId: match.gameId } };
    } catch (error) {
      this.logger.warn(`Matchmaking join failed: ${error instanceof Error ? error.message : 'unknown'}`);
      return { event: 'matchmaking:error', data: { message: error instanceof Error ? error.message : 'Matchmaking failed' } };
    }
  }

  @SubscribeMessage('matchmaking:leave')
  async leave(@ConnectedSocket() client: MatchSocket) {
    this.clearBotTimer(client.data.userId);
    await this.matchmaking.leaveSocket(client.data.userId, client.id);
    return { event: 'matchmaking:left', data: { success: true } };
  }

  private scheduleBotFallback(userId: string, mode: GameMode): void {
    this.clearBotTimer(userId);
    const timer = setTimeout(async () => {
      this.botTimers.delete(userId);
      try {
        // Double-check if still queued
        const stillQueued = await this.matchmaking.isQueued(userId, mode);
        if (!stillQueued) return;

        const botMatch = await this.matchmaking.tryCreateBotMatch(userId, mode);
        if (!botMatch) return;

        // Clear timers for all real users in this bot match
        for (const uid of botMatch.userIds) this.clearBotTimer(uid);

        for (const socketId of botMatch.socketIds) {
          this.server.to(socketId).emit('matchmaking:matched', {
            gameId: botMatch.gameId,
            mode: botMatch.mode,
            playerCount: botMatch.userIds.length,
          });
        }

        this.logger.log(`Bot fallback matched: game=${botMatch.gameId} mode=${mode} real=${botMatch.socketIds.length} total=${botMatch.userIds.length}`);
      } catch (error) {
        this.logger.warn(`Bot fallback failed for ${userId}: ${error instanceof Error ? error.message : 'unknown'}`);
      }
    }, this.BOT_WAIT_MS);

    this.botTimers.set(userId, timer);
  }

  private clearBotTimer(userId: string): void {
    const existing = this.botTimers.get(userId);
    if (existing) {
      clearTimeout(existing);
      this.botTimers.delete(userId);
    }
  }
}
