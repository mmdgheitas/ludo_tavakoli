import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { GamesGateway } from './games.gateway';
import { GamesService } from './games.service';

@Injectable()
export class GameLifecycleService {
  private readonly logger = new Logger(GameLifecycleService.name);
  private running = false;

  constructor(private readonly games: GamesService, private readonly gateway: GamesGateway) {}

  @Interval(5000)
  async enforceDeadlines(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const games = await this.games.activeStates();
      const now = Date.now();
      for (const game of games) {
        try {
          if (game.state.turnDeadlineAt && Date.parse(game.state.turnDeadlineAt) <= now) {
            const result = await this.games.timeout(game.id);
            if (result.state.version !== game.state.version) this.gateway.broadcast(game.id, result);
          }
          const graceMs = (game.state.reconnectGraceSeconds ?? 60) * 1000;
          for (const participant of game.participants) {
            const statePlayer = game.state.players.find((player) => player.userId === participant.userId);
            if (participant.disconnectedAt && !statePlayer?.forfeited && participant.disconnectedAt.getTime() + graceMs <= now) {
              const result = await this.games.disconnectForfeit(game.id, participant.userId);
              if (result.state.version !== game.state.version) this.gateway.broadcast(game.id, result);
            }
          }
        } catch (error) {
          this.logger.debug(`Lifecycle race for ${game.id}: ${error instanceof Error ? error.message : 'skipped'}`);
        }
      }
    } finally { this.running = false; }
  }
}
