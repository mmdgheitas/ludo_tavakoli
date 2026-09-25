import 'package:ludo_app/features/game/domain/game_snapshot.dart';

/// A roll belongs to its actor, not necessarily the post-roll turnIndex: a
/// blocked roll or a third six can hand the turn to the next player immediately.
class OnlineDiceRoll {
  const OnlineDiceRoll({required this.team, required this.value});

  final Team team;
  final int value;

  static OnlineDiceRoll? fromEvent(
    Map<String, dynamic> event, {
    required GameSnapshot snapshot,
    required List<Map<String, dynamic>> players,
    GameSnapshot? previous,
  }) {
    final value = event['dice'];
    if (value is! int || value < 1 || value > 6) return null;

    final actorId = event['rolledBy'];
    if (actorId != null) {
      final actor = players
          .where((player) => player['userId'] == actorId)
          .firstOrNull;
      final name = actor?['team']?.toString().toLowerCase();
      final team = snapshot.teams.where((team) => team.name == name).firstOrNull;
      // An unknown actor must never fall back to somebody else's dice.
      return team == null ? null : OnlineDiceRoll(team: team, value: value);
    }

    // Compatibility with servers that send only `dice`. WAITING_MOVE still
    // belongs to the roller, even when a previous event was missed.
    if (snapshot.phase == MatchPhase.waitingForMove &&
        snapshot.pendingDice == value) {
      final team = _currentTeam(snapshot);
      return team == null ? null : OnlineDiceRoll(team: team, value: value);
    }

    // For an auto-advanced roll, only a consecutive, accepted pre-roll state
    // proves ownership. Never infer it from the lagging Flame board or guess
    // across a reconnect/version gap (players can be skipped or forfeited).
    if (previous != null &&
        previous.id == snapshot.id &&
        previous.version + 1 == snapshot.version &&
        previous.phase == MatchPhase.waitingForRoll) {
      final team = _currentTeam(previous);
      if (team != null && snapshot.teams.contains(team)) {
        return OnlineDiceRoll(team: team, value: value);
      }
    }
    return null;
  }

  static Team? _currentTeam(GameSnapshot snapshot) {
    final index = snapshot.currentTurn;
    return index >= 0 && index < snapshot.teams.length
        ? snapshot.teams[index]
        : null;
  }
}
