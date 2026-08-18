import 'package:flutter_test/flutter_test.dart';
import 'package:manche_irani/features/game/domain/game_snapshot.dart';
import 'package:manche_irani/features/game/domain/ludo_rules.dart';

void main() {
  const rules = LudoRules();

  test('a token may only leave base on six', () {
    const token = TokenSnapshot(id: 'B1', team: Team.blue, progress: -1);
    expect(rules.canMove(token, 5), isFalse);
    expect(rules.canMove(token, 6), isTrue);
  });

  test('overshooting finish is illegal', () {
    const token = TokenSnapshot(id: 'B1', team: Team.blue, progress: 54);
    expect(rules.canMove(token, 2), isTrue);
    expect(rules.canMove(token, 3), isFalse);
  });

  test('tokens on safe cells cannot be captured', () {
    const blue = TokenSnapshot(id: 'B1', team: Team.blue, progress: 0);
    const yellow = TokenSnapshot(id: 'Y1', team: Team.yellow, progress: 13);
    expect(rules.sharedCell(blue), 0);
    expect(rules.sharedCell(yellow), 0);
    expect(rules.canCapture(blue, yellow), isFalse);
  });
}
