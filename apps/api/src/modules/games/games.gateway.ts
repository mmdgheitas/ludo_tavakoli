import { BadRequestException, HttpException, Logger, UsePipes, ValidationPipe } from '@nestjs/common';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { FattahSocketDto, GameCommandDto, MoveSocketDto } from './dto/game.dto';
import { GamesService } from './games.service';

interface SocketData { userId: string; subscribedGames: string[] }
type GameSocket = Socket<Record<string, never>, Record<string, never>, Record<string, never>, SocketData>;

@WebSocketGateway({ cors: { origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3000').split(','), credentials: true }, transports: ['websocket'] })
@UsePipes(new ValidationPipe({ whitelist: true, transform: true }))
export class GamesGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(GamesGateway.name);

  constructor(private readonly games: GamesService) {}

  handleConnection(client: GameSocket): void {
    if (!client.data.userId) client.disconnect(true);
    client.data.subscribedGames ??= [];
  }

  async handleDisconnect(client: GameSocket): Promise<void> {
    for (const gameId of client.data.subscribedGames ?? []) {
      try {
        const sockets = await this.server.in(this.room(gameId)).fetchSockets();
        const hasAnotherConnection = sockets.some((socket) =>
          socket.id !== client.id &&
          (socket.data as Partial<SocketData>).userId === client.data.userId,
        );
        if (hasAnotherConnection) continue;
        const result = await this.games.markConnection(gameId, client.data.userId, false);
        if (result.state) this.broadcast(gameId, result);
      } catch (error) { this.logger.debug(error instanceof Error ? error.message : 'Disconnect update skipped'); }
    }
  }

  @SubscribeMessage('game:subscribe')
  async subscribe(@ConnectedSocket() client: GameSocket, @MessageBody() message: GameCommandDto) {
    try {
      if (!message?.gameId) throw new Error('Game id is required');
      let state = await this.games.getForUser(message.gameId, client.data.userId);
      await client.join(this.room(message.gameId));
      if (!client.data.subscribedGames.includes(message.gameId)) client.data.subscribedGames.push(message.gameId);
      const connection = await this.games.markConnection(message.gameId, client.data.userId, true);
      if (connection.state.version !== state.version) {
        state = connection.state;
        this.broadcast(message.gameId, connection);
      }
      return { event: 'game:state', data: { state } };
    } catch (error) {
      return this.reject(error, 'Could not subscribe to the game');
    }
  }

  @SubscribeMessage('game:roll')
  roll(@ConnectedSocket() client: GameSocket, @MessageBody() message: GameCommandDto) {
    return this.execute(message.gameId, () => this.games.roll(message.gameId, client.data.userId));
  }

  @SubscribeMessage('game:move')
  move(@ConnectedSocket() client: GameSocket, @MessageBody() message: MoveSocketDto) {
    return this.execute(message.gameId, () => this.games.move(message.gameId, client.data.userId, message.tokenIndex));
  }

  @SubscribeMessage('game:fattah')
  fattah(@ConnectedSocket() client: GameSocket, @MessageBody() message: FattahSocketDto) {
    return this.execute(message.gameId, () => this.games.useFattah(message.gameId, client.data.userId, message.targetUserId, message.targetTokenIndex));
  }

  @SubscribeMessage('game:forfeit')
  forfeit(@ConnectedSocket() client: GameSocket, @MessageBody() message: GameCommandDto) {
    return this.execute(message.gameId, () => this.games.forfeit(message.gameId, client.data.userId));
  }

  broadcast(gameId: string, result: unknown): void {
    this.server.to(this.room(gameId)).emit('game:state', result);
  }

  private async execute(gameId: string, action: () => Promise<unknown>) {
    try {
      const result = await action();
      this.broadcast(gameId, result);
      return { event: 'game:ack', data: { accepted: true } };
    } catch (error) {
      return this.reject(error);
    }
  }

  /**
   * Logs the real cause and answers with text a player is allowed to see.
   * Rule rejections are expected and stay at `warn`; anything else is an
   * internal failure and is logged with its stack.
   */
  private reject(error: unknown, fallback = 'Command failed; please retry') {
    if (error instanceof HttpException) this.logger.warn(error.message);
    else this.logger.error(error instanceof Error ? error.stack ?? error.message : fallback);
    return { event: 'game:error', data: { message: describeGameCommandError(error, fallback) } };
  }

  private room(gameId: string): string { return `game:${gameId}`; }
}

/** Code the client translates when a command fails for a reason it cannot act on. */
export const INTERNAL_COMMAND_ERROR = 'INTERNAL_ERROR';

/**
 * Text a player may see when a real-time command fails.
 *
 * `HttpException` messages in this module are written for players (rule
 * rejections, an empty rocket inventory, an optimistic-lock retry), so they pass
 * through. Everything else is an internal failure - a database constraint, a
 * driver timeout - and must stay in the server log: echoing it leaks schema and
 * driver details, and no client can translate it.
 */
export function describeGameCommandError(error: unknown, fallback = 'Command failed; please retry'): string {
  if (error instanceof BadRequestException) {
    const response: unknown = error.getResponse();
    if (typeof response === 'string') return response;
    if (response && typeof response === 'object') {
      const nested = response as { code?: unknown; message?: unknown };
      const code = typeof nested.code === 'string' ? nested.code : undefined;
      const text = typeof nested.message === 'string' ? nested.message : undefined;
      // Rule rejections carry a code the client translates; a bare message is
      // already written for the player. Unknown shapes fall through rather than
      // stringifying an object into `[object Object]`.
      if (code) return text ? `${code}: ${text}` : `${code}: Command rejected`;
      if (text) return text;
    }
  }
  if (error instanceof HttpException) return error.message;
  return `${INTERNAL_COMMAND_ERROR}: ${fallback}`;
}
