import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/domain/ludo_rules.dart';

/// One enemy token the server would accept as a Fattah target right now.
class FattahTarget {
  const FattahTarget({
    required this.userId,
    required this.team,
    required this.tokenIndex,
    required this.progress,
  });

  final String userId;
  final Team team;
  final int tokenIndex;

  /// Authoritative progress when the target was listed (`0..55`).
  final int progress;

  /// Board token id used by the Flame renderer (`BT1`, `GT3`, `RT2`, `YT4`).
  String get tokenId => '${team.name[0].toUpperCase()}T${tokenIndex + 1}';

  @override
  bool operator ==(Object other) =>
      other is FattahTarget &&
      other.userId == userId &&
      other.team == team &&
      other.tokenIndex == tokenIndex;

  @override
  int get hashCode => Object.hash(userId, team, tokenIndex);
}

/// Pure selection rules for the Fattah rocket. They mirror the authoritative
/// `LudoEngine.useFattah` checks so the client never offers a shot the server
/// would reject, and they stay free of Flutter/Flame imports so they are unit
/// testable.
class FattahRules {
  const FattahRules();

  /// Server phases in which the current player is allowed to fire.
  static const List<String> firingPhases = ['WAITING_ROLL', 'WAITING_MOVE'];

  /// The launcher is offered whenever this player could legally fire in this
  /// game — even with an empty inventory, where it renders disabled and points
  /// to the shop instead of silently failing on the server.
  bool isLauncherVisible({
    required String phase,
    required bool myTurn,
    required bool usedThisGame,
  }) =>
      myTurn && !usedThisGame && firingPhases.contains(phase);

  /// Firing additionally needs inventory; the server decrements it atomically.
  bool canFire({
    required String phase,
    required bool myTurn,
    required bool usedThisGame,
    required int balance,
  }) =>
      isLauncherVisible(phase: phase, myTurn: myTurn, usedThisGame: usedThisGame) &&
      balance > 0;

  /// A token is exposed when it stands on the shared loop or its home lane.
  /// Safe cells are *not* protected: the rocket ignores them, exactly like the
  /// server rule.
  static bool isExposed(int progress) => progress >= 0 && progress < LudoRules.finishProgress;

  /// Maps a server `team` string (`BLUE`, `green`, …) onto the domain enum.
  static Team? teamOf(dynamic raw) {
    if (raw is! String) return null;
    final lowered = raw.toLowerCase();
    for (final team in Team.values) {
      if (team.name == lowered) return team;
    }
    return null;
  }

  /// Every legal target in the authoritative player list, newest snapshot first.
  /// Defensive on purpose: socket payloads are untyped maps.
  List<FattahTarget> targets(List<Map<String, dynamic>> players, String? myUserId) {
    if (myUserId == null || myUserId.isEmpty) return const [];
    final result = <FattahTarget>[];
    for (final player in players) {
      final String? userId = player['userId']?.toString();
      if (userId == null || userId.isEmpty || userId == myUserId) continue;
      if (player['forfeited'] == true) continue;
      final team = teamOf(player['team']);
      if (team == null) continue;
      final tokens = player['tokens'];
      if (tokens is! List) continue;
      for (var index = 0; index < tokens.length; index++) {
        final raw = tokens[index];
        if (raw is! num) continue;
        final progress = raw.toInt();
        if (!isExposed(progress)) continue;
        result.add(FattahTarget(userId: userId, team: team, tokenIndex: index, progress: progress));
      }
    }
    return result;
  }

  /// Re-checks a chosen target against the freshest player list. The sheet can
  /// stay open while newer snapshots arrive, so the pick is validated again
  /// before it is spent.
  FattahTarget? validate(List<Map<String, dynamic>> players, String? myUserId, String userId, int tokenIndex) {
    for (final target in targets(players, myUserId)) {
      if (target.userId == userId && target.tokenIndex == tokenIndex) return target;
    }
    return null;
  }
}
