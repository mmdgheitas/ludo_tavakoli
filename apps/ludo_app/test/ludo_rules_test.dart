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
}
