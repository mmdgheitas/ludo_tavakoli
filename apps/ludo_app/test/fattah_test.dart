import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_app/features/game/domain/fattah.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';

/// Player payloads exactly as the authoritative `game:state` broadcast carries
/// them, so the selection rules are tested against real socket shapes.
Map<String, dynamic> player(
  String userId,
  String team,
  List<int> tokens, {
  bool forfeited = false,
  bool fattahUsed = false,
}) =>
    {
      'userId': userId,
      'team': team,
      'tokens': tokens,
      'forfeited': forfeited,
      'fattahUsed': fattahUsed,
    };

void main() {
  const rules = FattahRules();

  group('FattahRules.targets', () {
    test('lists only exposed enemy tokens', () {
      final players = [
        player('me', 'BLUE', const [12, -1, 56, 30]),
        player('rival', 'RED', const [-1, 8, 55, 56]),
      ];
      final targets = rules.targets(players, 'me');
      expect(targets.map((target) => target.tokenIndex).toList(), const [1, 2]);
      expect(targets.first.userId, 'rival');
      expect(targets.first.team, Team.red);
      expect(targets.first.progress, 8);
    });

    test('skips the local player, forfeited rivals and safe-cell exceptions', () {
      final players = [
        player('me', 'BLUE', const [10, 11]),
        player('gone', 'RED', const [10, 11], forfeited: true),
        // Shared cell 13 is safe for ordinary captures; the rocket ignores it.
        player('rival', 'GREEN', const [0, -1]),
      ];
      final targets = rules.targets(players, 'me');
      expect(targets.map((target) => target.userId).toSet(), const {'rival'});
      expect(targets.single.tokenIndex, 0);
    });

    test('survives malformed socket payloads', () {
      final players = <Map<String, dynamic>>[
        {'userId': 'rival', 'team': 'PURPLE', 'tokens': const [10]},
        {'userId': 'rival', 'team': 'RED'},
        {'team': 'RED', 'tokens': const [10]},
        {'userId': '', 'team': 'RED', 'tokens': const [10]},
      ];
      expect(rules.targets(players, 'me'), const <FattahTarget>[]);
      expect(rules.targets(const [], null), const <FattahTarget>[]);
    });

    test('skips unreadable token entries but keeps the valid ones', () {
      final targets = rules.targets(
        [{'userId': 'rival', 'team': 'RED', 'tokens': const [null, 'x', 10]}],
        'me',
      );
      expect(targets.single.tokenIndex, 2);
      expect(targets.single.progress, 10);
    });

    test('maps a target onto the Flame token id', () {
      final target = rules.targets([player('rival', 'YELLOW', const [-1, 0, -1, -1])], 'me').single;
      expect(target.tokenId, 'YT2');
    });
  });

  group('FattahRules.validate', () {
    test('re-checks a pick against the freshest snapshot', () {
      final before = [player('rival', 'RED', const [10, 20])];
      final chosen = rules.targets(before, 'me').first;
      expect(rules.validate(before, 'me', chosen.userId, chosen.tokenIndex), isNotNull);

      // A normal capture sent the same piece home while the sheet was open.
      final after = [player('rival', 'RED', const [-1, 20])];
      expect(rules.validate(after, 'me', chosen.userId, chosen.tokenIndex), isNull());
    });
  });

  group('launcher availability', () {
    test('is offered on both turn phases and hidden otherwise', () {
      for (final phase in FattahRules.firingPhases) {
        expect(
          rules.isLauncherVisible(phase: phase, myTurn: true, usedThisGame: false),
          isTrue,
          reason: phase,
        );
      }
      expect(rules.isLauncherVisible(phase: 'WAITING_PLAYERS', myTurn: true, usedThisGame: false), isFalse);
      expect(rules.isLauncherVisible(phase: 'FINISHED', myTurn: true, usedThisGame: false), isFalse);
      expect(rules.isLauncherVisible(phase: 'WAITING_ROLL', myTurn: false, usedThisGame: false), isFalse);
      expect(rules.isLauncherVisible(phase: 'WAITING_ROLL', myTurn: true, usedThisGame: true), isFalse);
    });

    test('stays visible but cannot fire with an empty inventory', () {
      expect(
        rules.canFire(phase: 'WAITING_ROLL', myTurn: true, usedThisGame: false, balance: 0),
        isFalse,
      );
      expect(
        rules.isLauncherVisible(phase: 'WAITING_ROLL', myTurn: true, usedThisGame: false),
        isTrue,
      );
      expect(
        rules.canFire(phase: 'WAITING_MOVE', myTurn: true, usedThisGame: false, balance: 2),
        isTrue,
      );
    });
  });

  group('team parsing', () {
    test('accepts server casing and rejects unknown teams', () {
      expect(FattahRules.teamOf('BLUE'), Team.blue);
      expect(FattahRules.teamOf('green'), Team.green);
      expect(FattahRules.teamOf('PURPLE'), isNull);
      expect(FattahRules.teamOf(null), isNull);
      expect(FattahRules.teamOf(3), isNull);
    });
  });

  test('a decoded strike addresses the struck Flame token', () {
    const strike = FattahStrike(attackerTeam: Team.blue, targetTeam: Team.red, targetTokenIndex: 2);
    expect(strike.targetTokenId, 'RT3');
  });
}
