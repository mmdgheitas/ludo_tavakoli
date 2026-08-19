import 'package:ludo_app/features/game/domain/game_snapshot.dart';

/// Pure domain rules shared conceptually with the authoritative server.
/// Flame components only animate snapshots produced by this layer; they do not
/// decide whether a move is legal.
class LudoRules {
  const LudoRules();
  static const finishProgress = 56;
  static const safeCells = {0, 8, 13, 21, 26, 34, 39, 47};
  static const offsets = {Team.blue: 0, Team.red: 13, Team.green: 26, Team.yellow: 39};

  List<String> legalTokenIds(GameSnapshot state) {
    final dice = state.pendingDice;
    if (dice == null || state.phase != MatchPhase.waitingForMove) return const [];
    final team = state.teams[state.currentTurn];
    return state.tokens
        .where((token) => token.team == team && canMove(token, dice))
        .map((token) => token.id)
        .toList(growable: false);
  }

  bool canMove(TokenSnapshot token, int dice) {
    if (dice < 1 || dice > 6 || token.progress == finishProgress) return false;
    if (token.progress == -1) return dice == 6;
    return token.progress + dice <= finishProgress;
  }

  int? sharedCell(TokenSnapshot token) {
    if (token.progress < 0 || token.progress > 50) return null;
    return (offsets[token.team]! + token.progress) % 52;
  }

  bool canCapture(TokenSnapshot attacker, TokenSnapshot target) {
    final attackerCell = sharedCell(attacker);
    return attacker.team != target.team &&
        attackerCell != null &&
        attackerCell == sharedCell(target) &&
        !safeCells.contains(attackerCell);
  }
}
