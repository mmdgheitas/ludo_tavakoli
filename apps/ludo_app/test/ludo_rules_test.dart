import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/domain/ludo_rules.dart';

void main() {
  const rules = LudoRules();
  test('token exits base only with six', () {
    const token = TokenSnapshot(id: 'BT1', team: Team.blue, progress: -1);
    expect(rules.canMove(token, 5), isFalse);
    expect(rules.canMove(token, 6), isTrue);
  });
  test('finish requires exact roll', () {
    const token = TokenSnapshot(id: 'BT1', team: Team.blue, progress: 55);
    expect(rules.canMove(token, 1), isTrue);
    expect(rules.canMove(token, 2), isFalse);
  });

  GameSnapshot snapshotWithTokens(List<int> progress, {int dice = 3}) => GameSnapshot(
        id: 'g1',
        version: 1,
        teams: const [Team.blue, Team.green],
        currentTurn: 0,
        phase: MatchPhase.waitingForMove,
        tokens: [
          for (var index = 0; index < progress.length; index++)
            TokenSnapshot(id: 'BT${index + 1}', team: Team.blue, progress: progress[index]),
          const TokenSnapshot(id: 'GT1', team: Team.green, progress: -1),
          const TokenSnapshot(id: 'GT2', team: Team.green, progress: -1),
          const TokenSnapshot(id: 'GT3', team: Team.green, progress: -1),
          const TokenSnapshot(id: 'GT4', team: Team.green, progress: -1),
        ],
        updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        pendingDice: dice,
      );

  test('auto-move helper finds exactly one legal token', () {
    // Only BT2 (progress 10) can advance by three; BT1 is finished, others base.
    final snapshot = snapshotWithTokens(const [56, 10, -1, -1]);
    expect(rules.legalTokenIds(snapshot), const ['BT2']);
  });

  test('auto-move helper stays silent with several legal tokens', () {
    final snapshot = snapshotWithTokens(const [56, 10, 20, -1]);
    expect(rules.legalTokenIds(snapshot).length, 2);
  });

  test('auto-move helper includes a base token when a six was rolled', () {
    final snapshot = snapshotWithTokens(const [56, -1, -1, -1], dice: 6);
    expect(rules.legalTokenIds(snapshot), const ['BT2', 'BT3', 'BT4']);
  });
}
