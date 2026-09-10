import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/domain/ludo_rules.dart';
import 'package:ludo_app/features/game/game_engine/ludo_game.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/managers/token_manager.dart';
import 'package:ludo_app/features/game/game_engine/models/ludo_game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/player.dart';
import 'package:ludo_app/features/game/game_engine/models/token.dart' as engine;

/// How a token transitioned between the previously shown state and the
/// incoming authoritative snapshot.
enum _TokenMoveKind {
  /// Same progress; only enforce the exact spot (drift protection).
  stay,

  /// Left the base and now stands on the first path cell.
  enter,

  /// Advanced along the path; animated cell by cell like offline moves.
  forward,

  /// Captured (or hit by a Fattah rocket); walks backward home like offline.
  captured,

  /// Missing or impossible data; the whole update falls back to fast-forward.
  unknown,
}

class _TokenPlan {
  const _TokenPlan(
    this.token,
    this.player,
    this.path,
    this.from,
    this.to,
    this.kind,
    this.baseSpot,
  );

  final engine.Token token;
  final Player player;
  final List<String> path;
  final int from;
  final int? to;
  final _TokenMoveKind kind;
  final String? baseSpot;
}

/// Applies authoritative online snapshots to the Flame board with the same
/// movement animations the offline engine plays: per-cell hops with sound and
/// size pulse for forward moves, a launch out of the base, and a backward walk
/// home for captured tokens. Transitions that are not a normal single move
/// (initial sync, reconnect gaps, timeouts, forfeits) fast-forward instead, so
/// animation backlogs can never accumulate between authoritative updates.
class OnlineSessionAdapter {
  const OnlineSessionAdapter();

  static const _finishProgress = 56;
  static const _detailedBudget = Duration(seconds: 15);
  static const _fastForwardBudget = Duration(seconds: 1);

  Future<void> apply(
    Ludo game,
    GameSnapshot snapshot, {
    required bool myTurn,
    required bool animate,
  }) async {
    final target = GameState();
    if (target.players.isEmpty || snapshot.teams.isEmpty) return;

    final serverTurn =
        snapshot.currentTurn.clamp(0, snapshot.teams.length - 1).toInt();
    final mappedTurn = target.players
        .indexWhere((player) => player.playerId.name == snapshot.teams[serverTurn].name);
    if (mappedTurn < 0) return;

    target.currentPlayerIndex = mappedTurn;
    if (snapshot.pendingDice != null) target.diceNumber = snapshot.pendingDice!;
    target.state = _enginePhase(snapshot.phase);
    target.clearTokenTrail();

    final bases = <String, String>{
      ...TokenManager().blueTokensBase,
      ...TokenManager().redTokensBase,
      ...TokenManager().greenTokensBase,
      ...TokenManager().yellowTokensBase,
    };
    final savedById = {for (final token in snapshot.tokens) token.id: token};

    final plans = <_TokenPlan>[];
    var detailed = animate;
    for (final player in target.players) {
      final path = target.getTokenPath(player.playerId);
      for (final token in player.tokens) {
        final saved = savedById[token.tokenId];
        final from = _progressOf(token, path);
        final to = saved?.progress;
        final kind = to == null ? _TokenMoveKind.unknown : _classify(from, to);
        if (kind == _TokenMoveKind.unknown) detailed = false;
        plans.add(_TokenPlan(token, player, path, from, to, kind, bases[token.tokenId]));
      }
    }

    final moverCount = plans
        .where((plan) => plan.kind == _TokenMoveKind.enter || plan.kind == _TokenMoveKind.forward)
        .length;
    if (moverCount > 1) detailed = false;

    // 1) Logical state first: positions, home counts and win flags are exact
    //    before any animation starts, so rules checks stay correct even if a
    //    newer snapshot interrupts the visuals.
    for (final player in target.players) {
      player.totalTokensInHome = 0;
      player.hasWon = snapshot.winner?.name == player.playerId.name;
    }
    for (final plan in plans) {
      final token = plan.token;
      switch (plan.kind) {
        case _TokenMoveKind.stay ||
              _TokenMoveKind.enter ||
              _TokenMoveKind.forward:
          final progress = (plan.to ?? 0).clamp(0, _finishProgress).toInt();
          token.positionId = plan.path[progress];
          token.state = progress == _finishProgress
              ? engine.TokenState.inHome
              : engine.TokenState.onBoard;
          if (token.state == engine.TokenState.inHome) {
            plan.player.totalTokensInHome += 1;
          }
        case _TokenMoveKind.captured:
          token.positionId = plan.baseSpot ?? token.positionId;
          token.state = engine.TokenState.inBase;
        case _TokenMoveKind.unknown:
          break; // Leave untouched; the snapshot will be corrected later.
      }
    }

    // 2) Play the movement animations, offline style: the mover hops cell by
    //    cell first, then captured tokens walk back home — the exact order the
    //    offline engine produces with moveForward() + tokenCollision().
    final animations = <Future<void>>[];
    final moveFutures = <Future<void>>[];
    final captureFutures = <Future<void>>[];
    final glideFutures = <Future<void>>[];
    for (final plan in plans) {
      final component = target.getComponentForToken(plan.token);
      if (component == null) continue;
      if (detailed) {
        switch (plan.kind) {
          case _TokenMoveKind.enter:
            moveFutures.add(component.animateToSpot(plan.path.first));
          case _TokenMoveKind.forward:
            moveFutures.add(component.animatePath(plan.path, plan.from + 1, plan.to ?? plan.from));
          case _TokenMoveKind.captured when plan.baseSpot != null:
            captureFutures.add(() async {
              await component.animatePathBackward(plan.path, plan.from, 0);
              await component.animateToBase(plan.baseSpot!);
            }());
          case _TokenMoveKind.stay ||
                _TokenMoveKind.captured ||
                _TokenMoveKind.unknown:
            break;
        }
      } else if (plan.kind == _TokenMoveKind.captured && plan.baseSpot != null) {
        glideFutures.add(component.animateToBase(plan.baseSpot!));
      } else if (plan.kind == _TokenMoveKind.enter || plan.kind == _TokenMoveKind.forward) {
        final progress = (plan.to ?? 0).clamp(0, _finishProgress).toInt();
        glideFutures.add(component.animateToSpot(plan.path[progress]));
      }
    }
    if (detailed) {
      animations.add(() async {
        await Future.wait(moveFutures);
        await Future.wait(captureFutures);
      }());
    } else {
      animations.addAll(glideFutures);
    }
    try {
      await Future.wait(animations).timeout(
            detailed ? _detailedBudget : _fastForwardBudget,
            onTimeout: () => const [],
          );
    } catch (_) {
      // A failed animation must never poison later authoritative updates.
    }

    // 3) Finalize: selection, dice and active-base effects.
    target.clearTokenTrail();
    target.resizeTokensOnSpot(game.world);

    if (snapshot.phase == MatchPhase.finished) {
      for (final player in target.players) {
        for (final token in player.tokens) {
          token.enableToken = false;
        }
      }
      return;
    }

    game.blinkBaseForTeam(target.currentPlayer.playerId);
    game.syncDiceValue(snapshot.pendingDice);

    final rules = const LudoRules();
    final current = target.currentPlayer;
    final canSelect = myTurn &&
        snapshot.phase == MatchPhase.waitingForMove &&
        snapshot.pendingDice != null;
    for (final player in target.players) {
      for (final token in player.tokens) {
        final saved = savedById[token.tokenId];
        token.enableToken = canSelect &&
            identical(player, current) &&
            saved != null &&
            rules.canMove(saved, snapshot.pendingDice!);
      }
    }
    if (canSelect) {
      // Offline parity: movable tokens pulse so the local player sees the
      // legal choices exactly like in a pass-and-play game.
      target.addTokenTrail(
        current.tokens.where((token) => token.state == engine.TokenState.inBase).toList(),
        current.tokens.where((token) => token.state == engine.TokenState.onBoard).toList(),
      );
    }
  }

  int _progressOf(engine.Token token, List<String> path) {
    if (token.state == engine.TokenState.inHome) return _finishProgress;
    if (token.state == engine.TokenState.inBase) return -1;
    final index = path.indexOf(token.positionId);
    return index >= 0 ? index : -1;
  }

  _TokenMoveKind _classify(int from, int to) {
    if (to == from) return _TokenMoveKind.stay;
    if (from == -1 && to == 0) return _TokenMoveKind.enter;
    if (from >= 0 && to > from && to <= _finishProgress) {
      return _TokenMoveKind.forward;
    }
    if (from >= 0 && to == -1) return _TokenMoveKind.captured;
    return _TokenMoveKind.unknown;
  }

  LudoGameState _enginePhase(MatchPhase phase) => switch (phase) {
    MatchPhase.waitingForMove => LudoGameState.needMove,
    MatchPhase.finished => LudoGameState.gameOver,
    MatchPhase.waitingForRoll => LudoGameState.needRoll,
  };
}
