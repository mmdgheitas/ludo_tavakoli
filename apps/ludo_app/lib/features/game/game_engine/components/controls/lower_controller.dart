import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';
import 'package:ludo_app/features/game/game_engine/ludo_game.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/components/controls/dice_pointer.dart';

// user files
import 'package:ludo_app/features/game/game_engine/components/controls/controller_block.dart';

class LowerController extends RectangleComponent with HasGameReference<Ludo> {
  final RectangleComponent leftArrow;
  final RectangleComponent rightArrow;
  late final DicePointer _leftPointer;
  late final DicePointer _rightPointer;

  LowerController({
    required double width,
    required double height,
    Vector2? position,
  })  : leftArrow = RectangleComponent(
          size: Vector2(width * 0.45 * 0.3, height * 0.8),
          position: Vector2(width * 0.45 * 0.8, width * 0.45 * 0.05),
          paint: Paint()..color = Colors.transparent,
        ),
        rightArrow = RectangleComponent(
          size: Vector2(width * 0.45 * 0.3, height * 0.8),
          position: Vector2(width * 0.45 * 0.975, width * 0.45 * 0.05),
          paint: Paint()..color = Colors.transparent,
        ),
        super(
          size: Vector2(width, height),
          paint: Paint()..color = Colors.transparent,
        ) {
    final double innerWidth = width * 0.45;
    final double innerHeight = height;

    final leftToken = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
      position: Vector2(2.2, innerWidth * 0.05),
      paint: Paint()..color = GameState().blue,
      children: [
        ControllerBlock(
          transparentRight: true,
          transparentLeft: false,
          size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
          position: Vector2(0, 0),
          paint: Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = const Color(0xFF03346E),
          children: [],
        ),
      ],
    );

    final leftDice = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight),
      position: Vector2(innerWidth * 0.4, 0),
      paint: Paint()..color = GameState().blue,
      children: [
        RectangleComponent(
          size: Vector2(innerWidth * 0.4, innerHeight),
          paint: Paint()
            ..color = Colors.transparent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..color = const Color(0xFF03346E),
          children: [
            RectangleComponent(
              position: Vector2(innerWidth * 0.20, innerHeight * 0.5),
            ),
          ],
        ),
      ],
    );

    final rightDice = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight),
      position: Vector2(width - innerWidth * 0.8, 0),
      paint: Paint()..color = GameState().yellow,
      children: [
        RectangleComponent(
          size: Vector2(innerWidth * 0.4, innerHeight),
          paint: Paint()
            ..color = Colors.transparent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..color = const Color(0xFF03346E),
          children: [
            RectangleComponent(
              position: Vector2(innerWidth * 0.20, innerHeight * 0.5),
            ),
          ],
        ),
      ],
    );

    final rightToken = RectangleComponent(
      size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
      position: Vector2(width - innerWidth * 0.4 - 2.5, innerWidth * 0.05),
      paint: Paint()..color = GameState().yellow,
      children: [
        ControllerBlock(
          transparentLeft: true,
          size: Vector2(innerWidth * 0.4, innerHeight * 0.8),
          position: Vector2(0, 0),
          paint: Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = const Color(0xFF03346E),
          children: [],
        ),
      ],
    );

    // Own one pointer per slot for the controller's entire lifetime. Toggling
    // activity is synchronous, even before Flame mounts queued components.
    _leftPointer = _createPointer(PointerDirection.left);
    _rightPointer = _createPointer(PointerDirection.right);
    leftArrow.add(_leftPointer);
    rightArrow.add(_rightPointer);

    addAll([leftDice, leftToken, rightDice, rightToken, leftArrow, rightArrow]);

    this.position = position ?? Vector2.zero();
  }

  DicePointer _createPointer(PointerDirection direction) => DicePointer(
        direction: direction,
        size: size.x * 0.07,
        travelDistance: size.x * 0.02,
        paint: Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill,
        position: Vector2(size.x * 0.05, size.x * 0.04),
      );

  void showPointer(PlayerTeam playerId) {
    _leftPointer.isActive = playerId == PlayerTeam.blue;
    _rightPointer.isActive = playerId == PlayerTeam.yellow;
  }

  void hidePointer(PlayerTeam playerId) {
    if (playerId == PlayerTeam.blue) _leftPointer.isActive = false;
    if (playerId == PlayerTeam.yellow) _rightPointer.isActive = false;
  }

  void hidePointers() {
    _leftPointer.isActive = false;
    _rightPointer.isActive = false;
  }
}
