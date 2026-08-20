import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/domain/ludo_rules.dart';
import 'package:ludo_app/features/game/game_engine/ludo_game.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/managers/token_manager.dart';
import 'package:ludo_app/features/game/game_engine/models/ludo_game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/token.dart' as engine;

class OfflineSessionAdapter {
  const OfflineSessionAdapter();

  GameSnapshot capture(String gameId, int version) {
    final source = GameState();
    return GameSnapshot(
      id: gameId,
      version: version + 1,
      teams: source.players.map((player) => Team.values.byName(player.playerId.name)).toList(),
      currentTurn: source.currentPlayerIndex,
      phase: _domainPhase(source.state),
      pendingDice: source.state == LudoGameState.needMove ? source.diceNumber : null,
      winner: source.state == LudoGameState.gameOver
          ? Team.values.byName(source.players.firstWhere((player) => player.hasWon).playerId.name)
          : null,
      tokens: [
        for (final player in source.players)
          for (final token in player.tokens)
            TokenSnapshot(
              id: token.tokenId,
              team: Team.values.byName(player.playerId.name),
              progress: token.state == engine.TokenState.inBase
                  ? -1
                  : token.state == engine.TokenState.inHome
                      ? 56
                      : source.getTokenPath(player.playerId).indexOf(token.positionId),
            ),
      ],
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> restore(Ludo game, GameSnapshot snapshot) async {
    final target = GameState();
    final serverTurn = snapshot.teams.isEmpty
        ? 0
        : snapshot.currentTurn.clamp(0, snapshot.teams.length - 1).toInt();
    final currentTeam = snapshot.teams.isEmpty ? null : snapshot.teams[serverTurn];
    final mappedTurn = currentTeam == null
        ? -1
        : target.players.indexWhere((player) => player.playerId.name == currentTeam.name);
    target.currentPlayerIndex = mappedTurn >= 0 ? mappedTurn : 0;
    if (snapshot.pendingDice != null) target.diceNumber = snapshot.pendingDice!;
    target.state = _enginePhase(snapshot.phase);
    final bases = <String, String>{
      ...TokenManager().blueTokensBase,
      ...TokenManager().redTokensBase,
      ...TokenManager().greenTokensBase,
      ...TokenManager().yellowTokensBase,
    };

    for (final player in target.players) {
      player.totalTokensInHome = 0;
      player.hasWon = snapshot.winner?.name == player.playerId.name;
      final path = target.getTokenPath(player.playerId);
      for (final token in player.tokens) {
        final saved = snapshot.tokens.where((item) => item.id == token.tokenId).firstOrNull;
        if (saved == null) continue;
        token.enableToken = target.players[target.currentPlayerIndex] == player &&
            snapshot.phase == MatchPhase.waitingForMove &&
            snapshot.pendingDice != null &&
            const LudoRules().canMove(saved, snapshot.pendingDice!);
        if (saved.progress < 0) {
          token.positionId = bases[token.tokenId] ?? token.positionId;
          token.state = engine.TokenState.inBase;
          await target.getComponentForToken(token)?.animateToBase(token.positionId);
        } else {
          final progress = saved.progress.clamp(0, path.length - 1).toInt();
          token.positionId = path[progress];
          token.state = progress == path.length - 1 ? engine.TokenState.inHome : engine.TokenState.onBoard;
          if (token.state == engine.TokenState.inHome) player.totalTokensInHome += 1;
          await target.getComponentForToken(token)?.animateToSpot(token.positionId);
        }
      }
    }
    target.clearTokenTrail();
    target.resizeTokensOnSpot(game.world);
    game.blinkBaseForTeam(target.currentPlayer.playerId);
    game.syncDiceValue(snapshot.pendingDice);
  }

  MatchPhase _domainPhase(LudoGameState phase) => switch (phase) {
    LudoGameState.needMove || LudoGameState.moving => MatchPhase.waitingForMove,
    LudoGameState.gameOver => MatchPhase.finished,
    _ => MatchPhase.waitingForRoll,
  };

  LudoGameState _enginePhase(MatchPhase phase) => switch (phase) {
    MatchPhase.waitingForMove => LudoGameState.needMove,
    MatchPhase.finished => LudoGameState.gameOver,
    MatchPhase.waitingForRoll => LudoGameState.needRoll,
  };
}
