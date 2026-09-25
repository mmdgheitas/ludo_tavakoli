import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/domain/online_dice_roll.dart';

const _players = [
  {'userId': 'human', 'team': 'BLUE'},
  {'userId': 'bot', 'team': 'GREEN'},
];

GameSnapshot _snapshot({
  int version = 11,
  int turn = 0,
  MatchPhase phase = MatchPhase.waitingForRoll,
  int? dice,
}) => GameSnapshot(
  id: 'match',
  version: version,
  teams: const [Team.blue, Team.green],
  currentTurn: turn,
  phase: phase,
  tokens: const [],
  pendingDice: dice,
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('a bot roll that already advanced to the human still belongs to the bot', () {
    final roll = OnlineDiceRoll.fromEvent(
      {'dice': 4, 'rolledBy': 'bot'},
      snapshot: _snapshot(turn: 0),
      players: _players,
    );
    expect(roll?.team, Team.green);
    expect(roll?.value, 4);
  });

  test('explicit ownership wins over a stale previous turn and version gaps', () {
    final roll = OnlineDiceRoll.fromEvent(
      {'dice': 6, 'rolledBy': 'bot'},
      snapshot: _snapshot(version: 30, turn: 0),
      previous: _snapshot(version: 10, turn: 0),
      players: _players,
    );
    expect(roll?.team, Team.green);
  });

  test('human blocked roll is not attributed to the next bot', () {
    final roll = OnlineDiceRoll.fromEvent(
      {'dice': 3, 'rolledBy': 'human'},
      snapshot: _snapshot(turn: 1),
      players: _players,
    );
    expect(roll?.team, Team.blue);
  });

  test('legacy no-move and third-six rolls use the accepted pre-roll owner', () {
    for (final value in [3, 6]) {
      final roll = OnlineDiceRoll.fromEvent(
        {'dice': value},
        snapshot: _snapshot(turn: 0),
        previous: _snapshot(version: 10, turn: 1),
        players: _players,
      );
      expect(roll?.team, Team.green);
      expect(roll?.value, value);
    }
  });

  test('legacy WAITING_MOVE identifies the roller even after missed events', () {
    final roll = OnlineDiceRoll.fromEvent(
      {'dice': 6},
      snapshot: _snapshot(
        turn: 1,
        phase: MatchPhase.waitingForMove,
        dice: 6,
      ),
      previous: _snapshot(version: 5, turn: 0),
      players: _players,
    );
    expect(roll?.team, Team.green);
  });

  test('unknown legacy owner skips animation rather than using another dice', () {
    for (final previous in [null, _snapshot(version: 5, turn: 1)]) {
      expect(
        OnlineDiceRoll.fromEvent(
          {'dice': 3},
          snapshot: _snapshot(turn: 0),
          previous: previous,
          players: _players,
        ),
        isNull,
      );
    }
  });

  test('unknown explicit actor never falls back to a guessed owner', () {
    expect(
      OnlineDiceRoll.fromEvent(
        {'dice': 6, 'rolledBy': 'not-a-player'},
        snapshot: _snapshot(phase: MatchPhase.waitingForMove, dice: 6),
        previous: _snapshot(version: 10),
        players: _players,
      ),
      isNull,
    );
  });

  test('invalid dice and non-roll events produce no roll animation', () {
    for (final value in [null, 0, 7, '6', 2.5]) {
      expect(
        OnlineDiceRoll.fromEvent(
          {'dice': value, 'rolledBy': 'human'},
          snapshot: _snapshot(),
          players: _players,
        ),
        isNull,
      );
    }
  });
}
