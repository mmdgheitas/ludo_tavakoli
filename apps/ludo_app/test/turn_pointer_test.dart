import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_app/features/game/data/online_session_adapter.dart';
import 'package:ludo_app/features/game/domain/game_snapshot.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/dice_pointer.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/ludo_dice.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/lower_controller.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/upper_controller.dart';
import 'package:ludo_app/features/game/game_engine/ludo_game.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/managers/token_manager.dart';
import 'package:ludo_app/features/game/game_engine/models/ludo_game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/player.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';
import 'package:mocktail/mocktail.dart';

const _teams = [
  PlayerTeam.red,
  PlayerTeam.green,
  PlayerTeam.blue,
  PlayerTeam.yellow,
];

Iterable<Component> _tree(Component root) sync* {
  yield root;
  for (final child in root.children) {
    yield* _tree(child);
  }
}

List<DicePointer> _pointers(Component root) =>
    _tree(root).whereType<DicePointer>().toList();

void _expectActiveTeam(Ludo game, PlayerTeam? team) {
  final upper = game.world.children.whereType<UpperController>().single;
  final lower = game.world.children.whereType<LowerController>().single;
  final slots = {
    PlayerTeam.red: upper.leftArrow,
    PlayerTeam.green: upper.rightArrow,
    PlayerTeam.blue: lower.leftArrow,
    PlayerTeam.yellow: lower.rightArrow,
  };
  expect(_pointers(game), hasLength(4));
  for (final entry in slots.entries) {
    final pointer = entry.value.children.whereType<DicePointer>().single;
    expect(pointer.isActive, entry.key == team, reason: entry.key.name);
    expect(pointer.children, isEmpty, reason: 'No accumulating effect children');
  }
}

Future<_PointerTestGame> _loadGame(List<PlayerTeam> teams) async {
  final game = _PointerTestGame(teams, _MockContext());
  addTearDown(() {
    game.dispose();
    game.onRemove();
  });
  game.onGameResize(Vector2(400, 800));
  // Same initialization as flame_test, without adding another dependency.
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  game.update(0);
  await game.ready();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pointer moves only while active and repeated show does not restart it', () {
    final pointer = DicePointer(
      size: 20,
      paint: Paint()..color = Colors.green,
      direction: PointerDirection.left,
      travelDistance: 8,
      position: Vector2(10, 4),
    );
    pointer.update(0.1);
    expect(pointer.position.x, 10);

    pointer.isActive = true;
    pointer.update(0.1);
    expect(pointer.position.x, closeTo(14, 0.00001));
    pointer.isActive = true;
    pointer.update(0.1);
    expect(pointer.position.x, closeTo(18, 0.00001));
    pointer.update(0.1);
    expect(pointer.position.x, closeTo(14, 0.00001));

    pointer.isActive = false;
    pointer.update(3600);
    expect(pointer.position, Vector2(10, 4));
    pointer.isActive = true;
    pointer.update(0.1);
    expect(pointer.position.x, closeTo(14, 0.00001));
    expect(pointer.children, isEmpty);
  });

  test('one hour of pointer updates keeps motion bounded with no effects', () {
    final pointer = DicePointer(
      size: 20,
      paint: Paint(),
      direction: PointerDirection.right,
      travelDistance: 8,
      position: Vector2(10, 4),
    )..isActive = true;
    for (var frame = 0; frame < 60 * 60 * 60; frame++) {
      pointer.update(1 / 60);
      expect(pointer.position.x, inInclusiveRange(10, 18));
    }
    expect(pointer.position.y, 4);
    expect(pointer.children, isEmpty);
  });

  test('rapid show/hide calls before mounting reuse exactly four pointers', () {
    final upper = UpperController(width: 400, height: 80);
    final lower = LowerController(width: 400, height: 80);
    final original = [..._pointers(upper), ..._pointers(lower)];
    expect(original, hasLength(4));

    for (var turn = 0; turn < 10000; turn++) {
      final team = _teams[turn % _teams.length];
      upper.showPointer(team);
      lower.showPointer(team);
      upper.showPointer(team);
      lower.showPointer(team);
      expect(original.where((pointer) => pointer.isActive), hasLength(1));
      upper.hidePointer(team);
      lower.hidePointer(team);
      expect(original.where((pointer) => pointer.isActive), isEmpty);
      // hide -> show in the same frame must not lose the next turn's pointer.
      upper.showPointer(team);
      lower.showPointer(team);
    }

    expect([..._pointers(upper), ..._pointers(lower)], orderedEquals(original));
    expect(_tree(upper).whereType<Effect>(), isEmpty);
    expect(_tree(lower).whereType<Effect>(), isEmpty);
    upper.hidePointers();
    lower.hidePointers();
    expect(original.where((pointer) => pointer.isActive), isEmpty);
  });

  test('same-team phase changes update pointers and hide clears all slots', () async {
    final game = await _loadGame(_teams);
    game.blinkBaseForTeam(PlayerTeam.red);
    await game.ready();
    _expectActiveTeam(game, PlayerTeam.red);

    GameState().state = LudoGameState.needMove;
    game.blinkBaseForTeam(PlayerTeam.red);
    _expectActiveTeam(game, null);

    GameState().state = LudoGameState.needRoll;
    game.blinkBaseForTeam(PlayerTeam.red);
    _expectActiveTeam(game, PlayerTeam.red);

    // A snapshot may already have changed the index when a hide is requested.
    GameState().currentPlayerIndex = 1;
    game.switchOffPointer();
    _expectActiveTeam(game, null);
    game.blinkBaseForTeam(PlayerTeam.green);
    await game.ready();
    _expectActiveTeam(game, PlayerTeam.green);

    GameState().state = LudoGameState.gameOver;
    game.blinkBaseForTeam(PlayerTeam.green);
    _expectActiveTeam(game, null);
  });

  test('turn switches and dice sync before a Flame tick keep the right owner', () async {
    final game = await _loadGame(_teams);
    game.blinkBaseForTeam(PlayerTeam.red);
    await game.ready();
    final red = _tree(game).whereType<LudoDice>().single;
    game.syncDiceValue(2, team: PlayerTeam.red);

    // No await/update between switching and writing the roll. The outgoing
    // upper dice used to be found before the incoming lower dice was mounted.
    game.blinkBaseForTeam(PlayerTeam.blue);
    game.syncDiceValue(5, team: PlayerTeam.blue);
    expect(red.diceFace.diceValue, 2);
    expect(red.isVisible, isFalse);
    expect(red.containsLocalPoint(Vector2.zero()), isFalse);
    await game.ready();
    final blue = _tree(game).whereType<LudoDice>()
        .singleWhere((dice) => dice.player.playerId == PlayerTeam.blue);
    expect(blue.isVisible, isTrue);
    expect(blue.diceFace.diceValue, 5);

    // Returning to a team before a queued removal completed used to leave
    // _activeTeam cached with no dice. Rapid changes must now reuse the dice.
    game.blinkBaseForTeam(PlayerTeam.green);
    game.blinkBaseForTeam(PlayerTeam.blue);
    await game.ready();
    expect(
      _tree(game).whereType<LudoDice>().where((dice) => dice.isVisible),
      [blue],
    );
    game.blinkBaseForTeam(PlayerTeam.red);
    game.syncDiceValue(3, team: PlayerTeam.red);
    await game.ready();
    final visible = _tree(game).whereType<LudoDice>()
        .where((dice) => dice.isVisible).toList();
    expect(visible, [red]);
    expect(red.diceFace.diceValue, 3);
    expect(blue.diceFace.diceValue, 5);
  });

  test('a bot roll targets its own dice even while a different turn is drawn', () async {
    final game = await _loadGame(_teams);
    GameState().currentPlayerIndex = _teams.indexOf(PlayerTeam.blue);
    game.blinkBaseForTeam(PlayerTeam.blue);
    game.syncDiceValue(2, team: PlayerTeam.blue);
    await game.ready();
    final human = _tree(game).whereType<LudoDice>().single;

    // Simulate an owned GREEN bot roll arriving while BLUE is still drawn.
    game.animateDiceValue(4, team: PlayerTeam.green);
    expect(human.isVisible, isFalse);
    expect(human.diceFace.diceValue, 2);
    await game.ready();
    final bot = _tree(game).whereType<LudoDice>()
        .singleWhere((dice) => dice.player.playerId == PlayerTeam.green);
    expect(bot.isVisible, isTrue);
    expect(bot.diceFace.diceValue, 4);
    expect(bot.children.whereType<RotateEffect>(), hasLength(1));
    expect(human.children.whereType<RotateEffect>(), isEmpty);
    _expectActiveTeam(game, null);

    // The cosmetic roll must not change gameplay turn or generate a roll.
    expect(GameState().currentPlayer.playerId, PlayerTeam.blue);
    game.update(0.15);
    expect(bot.angle, greaterThan(0));
    game.update(0.2);
    game.blinkBaseForTeam(PlayerTeam.blue);
    await game.ready();
    expect(bot.isVisible, isFalse);
    expect(bot.children.whereType<RotateEffect>(), isEmpty);
    expect(human.isVisible, isTrue);
    expect(human.diceFace.diceValue, 2);
  });

  for (final playerCount in [2, 4]) {
    test('$playerCount-player online snapshots never accumulate turn arrows', () async {
      final teams = playerCount == 2
          ? const [PlayerTeam.blue, PlayerTeam.green]
          : const [
              PlayerTeam.blue,
              PlayerTeam.red,
              PlayerTeam.green,
              PlayerTeam.yellow,
            ];
      final game = await _loadGame(teams);
      final original = _pointers(game);
      const adapter = OnlineSessionAdapter();
      var version = 0;

      Future<void> apply(int turn, MatchPhase phase) async {
        final pending = adapter.apply(
          game,
          GameSnapshot(
            id: 'pointer-regression',
            version: ++version,
            teams: teams.map((team) => Team.values.byName(team.name)).toList(),
            currentTurn: turn,
            phase: phase,
            pendingDice: phase == MatchPhase.waitingForMove ? 6 : null,
            tokens: const [],
            updatedAt: DateTime.utc(2026),
          ),
          myTurn: turn == 0,
          animate: false,
        );
        // The old arrow must stop before asynchronous snapshot work completes.
        _expectActiveTeam(game, null);
        await pending;
        await game.ready();
        _expectActiveTeam(
          game,
          phase == MatchPhase.waitingForRoll ? teams[turn] : null,
        );
        expect(_pointers(game), orderedEquals(original));
        final dice = _tree(game).whereType<LudoDice>().toList();
        expect(dice.length, lessThanOrEqual(playerCount));
        if (phase != MatchPhase.finished) {
          final active = dice.where((dice) => dice.isVisible).single;
          expect(active.player.playerId, teams[turn]);
          if (phase == MatchPhase.waitingForMove) {
            expect(active.diceFace.diceValue, 6);
          }
        }
      }

      for (var turn = 0; turn < 200; turn++) {
        final index = turn % playerCount;
        await apply(index, MatchPhase.waitingForRoll);
        await apply(index, MatchPhase.waitingForRoll); // Repeated state sync.
        await apply(index, MatchPhase.waitingForMove);
        await apply(index, MatchPhase.waitingForRoll); // Same-team bonus roll.
      }
      // Finished takes an early return in the adapter; it must still hide.
      await apply(0, MatchPhase.finished);
    });
  }
}

class _MockContext extends Mock implements BuildContext {}

/// Exercise the real Ludo controllers and online adapter, but skip audio and
/// token initialization: these tests isolate turn-indicator lifecycle behavior.
class _PointerTestGame extends Ludo {
  _PointerTestGame(super.teams, super.context);

  @override
  Future<void> startGame() async {
    await GameState().clearPlayers();
    await TokenManager().clearTokens();
    GameState().players.addAll([
      for (final team in teams) Player(playerId: team, tokens: []),
    ]);
  }
}
