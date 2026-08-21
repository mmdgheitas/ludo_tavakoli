import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { GamesGateway } from './games.gateway';
import { GamesService } from './games.service';

@Injectable()
export class GameLifecycleService implements OnModuleInit {
  private readonly logger = new Logger(GameLifecycleService.name);
  private running = false;

  constructor(private readonly games: GamesService, private readonly gateway: GamesGateway) {}

  async onModuleInit(): Promise<void> {
    await this.games.rebuildLifecycleIndex();
  }

  @Interval(5000)
  async enforceDeadlines(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const [dueGameIds, disconnected, waitingGames] = await Promise.all([
        this.games.dueTurnGameIds(),
        this.games.disconnectedCandidates(),
        this.games.staleWaitingGames(),
      ]);

      for (const game of waitingGames) {
        try {
          const result = await this.games.cancelWaiting(game.id);
          if (result.state.version !== game.state.version) this.gateway.broadcast(game.id, result);
        } catch (error) {
          this.logger.debug(`Waiting-game race for ${game.id}: ${error instanceof Error ? error.message : 'skipped'}`);
        }
      }

      for (const gameId of dueGameIds) {
        try {
          const result = await this.games.timeout(gameId);
          this.gateway.broadcast(gameId, result);
        } catch (error) {
          this.logger.debug(`Turn-timeout race for ${gameId}: ${error instanceof Error ? error.message : 'skipped'}`);
        }
      }

      for (const participant of disconnected) {
        try {
          const result = await this.games.disconnectForfeit(participant.gameId, participant.userId);
          this.gateway.broadcast(participant.gameId, result);
        } catch (error) {
          this.logger.debug(`Disconnect race for ${participant.gameId}: ${error instanceof Error ? error.message : 'skipped'}`);
        }
      }
    } finally {
      this.running = false;
    }
  }
}
