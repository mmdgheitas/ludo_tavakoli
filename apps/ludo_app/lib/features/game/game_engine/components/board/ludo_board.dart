import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ludo_app/features/game/game_engine/components/board/spot.dart';
import 'package:ludo_app/features/game/game_engine/components/home/home_spot.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';

/// Lightweight board renderer.
///
/// The full wooden artwork is a pre-rendered asset, so the UI thread draws one
/// image instead of rebuilding gradients, blur masks, text and roughly ninety
/// decorative components on every frame. Functional [Spot] and [Home]
/// components remain mounted and transparent for gameplay coordinates.
class LudoBoard extends PositionComponent {
  late final double _unit;
  ui.Image? _boardImage;

  LudoBoard() {
    final layout = GameState().layoutConfig;
    _unit = layout.boardWidth / 15;
    size = Vector2.all(_unit * 15);
    position = layout.boardPosition;

    // Preserve the nine-child section order expected by the existing engine.
    addAll([
      _HomeSection(side: _unit * 6, teamCode: 'R', position: Vector2.zero()),
      _TrackSection(team: PlayerTeam.green, unit: _unit, position: Vector2(_unit * 6, 0)),
      _HomeSection(side: _unit * 6, teamCode: 'G', position: Vector2(_unit * 9, 0)),
      _TrackSection(team: PlayerTeam.red, unit: _unit, position: Vector2(0, _unit * 6)),
      _CenterSection(unit: _unit, position: Vector2(_unit * 6, _unit * 6)),
      _TrackSection(team: PlayerTeam.yellow, unit: _unit, position: Vector2(_unit * 9, _unit * 6)),
      _HomeSection(side: _unit * 6, teamCode: 'B', position: Vector2(0, _unit * 9)),
      _TrackSection(team: PlayerTeam.blue, unit: _unit, position: Vector2(_unit * 6, _unit * 9)),
      _HomeSection(side: _unit * 6, teamCode: 'Y', position: Vector2(_unit * 9, _unit * 9)),
    ]);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final data = await rootBundle.load('assets/images/ludo_board.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 1024, targetHeight: 1024);
    final frame = await codec.getNextFrame();
    _boardImage = frame.image;
    codec.dispose();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final image = _boardImage;
    final destination = Rect.fromLTWH(0, 0, size.x, size.y);
    if (image == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(destination, Radius.circular(_unit * .4)),
        Paint()..color = const Color(0xFF3D2116),
      );
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  void onRemove() {
    _boardImage?.dispose();
    _boardImage = null;
    super.onRemove();
  }
}

class _HomeSection extends PositionComponent {
  _HomeSection({required double side, required String teamCode, required Vector2 position})
      : super(position: position, size: Vector2.all(side)) {
    final radius = side / 12;
    final near = side * 5 / 18;
    final far = side * 10 / 18;
    final positions = [Vector2(near, near), Vector2(far, near), Vector2(near, far), Vector2(far, far)];
    for (var index = 0; index < positions.length; index++) {
      add(HomeSpot(
        radius: radius,
        position: positions[index],
        paint: Paint()..color = Colors.transparent,
        uniqueId: '$teamCode${index + 1}',
      ));
    }
  }
}

class _TrackSection extends PositionComponent {
  _TrackSection({required PlayerTeam team, required double unit, required Vector2 position})
      : super(
          position: position,
          size: team == PlayerTeam.green || team == PlayerTeam.blue
              ? Vector2(unit * 3, unit * 6)
              : Vector2(unit * 6, unit * 3),
        ) {
    final vertical = team == PlayerTeam.green || team == PlayerTeam.blue;
    final columns = vertical ? 3 : 6;
    final rows = vertical ? 6 : 3;
    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        add(Spot(
          uniqueId: '${team.id}$column$row',
          position: Vector2(column * unit, row * unit),
          size: Vector2.all(unit),
          paint: Paint()..color = Colors.transparent,
        ));
      }
    }
  }
}

class _CenterSection extends PositionComponent {
  _CenterSection({required double unit, required Vector2 position})
      : super(position: position, size: Vector2.all(unit * 3)) {
    _finish('GF', 1, 0, unit);
    _finish('RF', 0, 1, unit);
    _finish('YF', 2, 1, unit);
    _finish('BF', 1, 2, unit);
  }

  void _finish(String id, int column, int row, double unit) {
    add(Spot(
      uniqueId: id,
      position: Vector2(column * unit, row * unit),
      size: Vector2.all(unit),
      paint: Paint()..color = Colors.transparent,
    ));
  }
}
