// import 'package:flame/components.dart';
// import 'package:flutter/material.dart';
// import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
// import 'package:ludo_app/features/game/game_engine/components/board/ludo_grid_component.dart';
// import 'package:ludo_app/features/game/game_engine/models/player_team.dart';
// import 'package:ludo_app/features/game/game_engine/components/home/home.dart';
// import 'package:ludo_app/features/game/game_engine/components/board/spot.dart';

// class LudoBoard extends PositionComponent {
//   LudoBoard() {
//     final layout = GameState().layoutConfig;
//     final double longDimension = layout.longDimension;
//     final double shortDimension = layout.shortDimension;

//     size = Vector2(layout.boardWidth, layout.boardHeight);
//     position = layout.boardPosition;

//     final firstComponent = RectangleComponent(
//         size: Vector2(longDimension, longDimension),
//         position: Vector2.zero(),
//         children: [
//           Home(
//             size: longDimension,
//             paint: Paint()..color = GameState().red,
//             homeSpotColor: Paint()..color = GameState().red,
//             teamCode: 'R',
//           )
//         ]);

//     final secondComponent = RectangleComponent(
//         size: Vector2(shortDimension, longDimension),
//         position: Vector2(longDimension, 0),
//         children: [
//           LudoGridComponent(
//               team: PlayerTeam.green, cellSize: shortDimension * 0.3333)
//         ]);

//     final thirdComponent = RectangleComponent(
//         size: Vector2(longDimension, longDimension),
//         position: Vector2(longDimension + shortDimension, 0),
//         children: [
//           Home(
//             size: longDimension,
//             paint: Paint()..color = GameState().green,
//             homeSpotColor: Paint()..color = GameState().green,
//             teamCode: 'G',
//           )
//         ]);

//     final fourthComponent = RectangleComponent(
//         size: Vector2(longDimension, shortDimension),
//         position: Vector2(0, longDimension),
//         children: [
//           LudoGridComponent(
//               team: PlayerTeam.red, cellSize: longDimension * 0.1666)
//         ]);

//     final fifthComponent = RectangleComponent(
//         size: Vector2(shortDimension, shortDimension),
//         position: Vector2(longDimension, longDimension),
//         children: [
//           DiagonalRectangleComponent(size: Vector2.all(shortDimension))
//         ]);

//     final sixthComponent = RectangleComponent(
//         size: Vector2(longDimension, shortDimension),
//         position: Vector2(longDimension + shortDimension, longDimension),
//         children: [
//           LudoGridComponent(
//               team: PlayerTeam.yellow, cellSize: longDimension * 0.1666)
//         ]);

//     final seventhComponent = RectangleComponent(
//         size: Vector2(longDimension, longDimension),
//         position: Vector2(0, longDimension + shortDimension),
//         children: [
//           Home(
//             size: longDimension,
//             paint: Paint()..color = GameState().blue,
//             homeSpotColor: Paint()..color = GameState().blue,
//             teamCode: 'B',
//           )
//         ]);

//     final eighthComponent = RectangleComponent(
//         size: Vector2(shortDimension, longDimension),
//         position: Vector2(longDimension, longDimension + shortDimension),
//         children: [
//           LudoGridComponent(
//               team: PlayerTeam.blue, cellSize: shortDimension * 0.3333)
//         ]);

//     final ninthComponent = RectangleComponent(
//         size: Vector2(longDimension, longDimension),
//         position: Vector2(longDimension + shortDimension,
//             longDimension + shortDimension),
//         children: [
//           Home(
//             size: longDimension,
//             paint: Paint()..color = GameState().yellow,
//             homeSpotColor: Paint()..color = GameState().yellow,
//             teamCode: 'Y',
//           )
//         ]);

//     addAll([
//       firstComponent,
//       secondComponent,
//       thirdComponent,
//       fourthComponent,
//       fifthComponent,
//       sixthComponent,
//       seventhComponent,
//       eighthComponent,
//       ninthComponent
//     ]);
//   }
// }

// class DiagonalRectangleComponent extends PositionComponent {
//   late final Vector2 centerRedTriangle;
//   late final Vector2 centerYellowTriangle;
//   late final Vector2 centerBlueTriangle;
//   late final Vector2 centerGreenTriangle;

//   late final Spot redSpot;
//   late final Spot yellowSpot;
//   late final Spot blueSpot;
//   late final Spot greenSpot;

//   DiagonalRectangleComponent({required Vector2 size}) {
//     this.size = size;

//     final rect = Rect.fromLTWH(0, 0, size.x, size.y);
//     final topLeft = rect.topLeft;
//     final topRight = rect.topRight;
//     final bottomLeft = rect.bottomLeft;
//     final bottomRight = rect.bottomRight;
//     final center = Offset(
//         (topLeft.dx + bottomRight.dx) / 2, (topLeft.dy + bottomRight.dy) / 2);

//     centerRedTriangle = Vector2((topLeft.dx + center.dx + bottomLeft.dx) / 3,
//         (topLeft.dy + center.dy + bottomLeft.dy) / 3);
//     centerYellowTriangle = Vector2(
//         (bottomRight.dx + center.dx + topRight.dx) / 3,
//         (bottomRight.dy + center.dy + topRight.dy) / 3);
//     centerBlueTriangle = Vector2(
//         (bottomLeft.dx + center.dx + bottomRight.dx) / 3,
//         (bottomLeft.dy + center.dy + bottomRight.dy) / 3);
//     centerGreenTriangle = Vector2((topRight.dx + center.dx + topLeft.dx) / 3,
//         (topRight.dy + center.dy + topLeft.dy) / 3);
//   }

//   @override
//   void onLoad() {
//     super.onLoad();

//     double rectWidth = size.x / 6;
//     double rectHeight = size.y / 6;

//     redSpot = Spot(
//       uniqueId: 'RF',
//       position: centerRedTriangle - Vector2(rectWidth / 2, rectHeight / 2),
//       size: Vector2(rectWidth, rectHeight),
//       paint: Paint()..color = GameState().red,
//     );
//     yellowSpot = Spot(
//       uniqueId: 'YF',
//       position: centerYellowTriangle - Vector2(rectWidth / 2, rectHeight / 2),
//       size: Vector2(rectWidth, rectHeight),
//       paint: Paint()..color = GameState().yellow,
//     );
//     blueSpot = Spot(
//       uniqueId: 'BF',
//       position: centerBlueTriangle - Vector2(rectWidth / 2, rectHeight / 2),
//       size: Vector2(rectWidth, rectHeight),
//       paint: Paint()..color = GameState().blue,
//     );
//     greenSpot = Spot(
//       uniqueId: 'GF',
//       position: centerGreenTriangle - Vector2(rectWidth / 2, rectHeight / 2),
//       size: Vector2(rectWidth, rectHeight),
//       paint: Paint()..color = GameState().green,
//     );

//     addAll([redSpot, yellowSpot, blueSpot, greenSpot]);
//   }

//   @override
//   void render(Canvas canvas) {
//     super.render(canvas);

//     final rect = Rect.fromLTWH(0, 0, size.x, size.y);
//     final topLeft = rect.topLeft;
//     final topRight = rect.topRight;
//     final bottomLeft = rect.bottomLeft;
//     final bottomRight = rect.bottomRight;
//     final center = Offset(
//         (topLeft.dx + bottomRight.dx) / 2, (topLeft.dy + bottomRight.dy) / 2);

//     Paint yellowPaint = Paint()..color = GameState().yellow;
//     Paint redPaint = Paint()..color = GameState().red;
//     Paint bluePaint = Paint()..color = GameState().blue;
//     Paint greenPaint = Paint()..color = GameState().green;

//     Paint borderPaint = Paint()
//       ..color = const Color(0xFFFFFFFF)
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.6;

//     _drawTriangle(canvas, redPaint, borderPaint, topLeft, center, bottomLeft);
//     _drawTriangle(
//         canvas, yellowPaint, borderPaint, bottomRight, center, topRight);
//     _drawTriangle(
//         canvas, bluePaint, borderPaint, bottomLeft, center, bottomRight);
//     _drawTriangle(canvas, greenPaint, borderPaint, topRight, center, topLeft);
//   }

//   void _drawTriangle(Canvas canvas, Paint fillPaint, Paint borderPaint,
//       Offset p1, Offset p2, Offset p3) {
//     Path triangle = Path()
//       ..moveTo(p1.dx, p1.dy)
//       ..lineTo(p2.dx, p2.dy)
//       ..lineTo(p3.dx, p3.dy);
//     canvas.drawPath(triangle, fillPaint);
//     canvas.drawPath(triangle, borderPaint);
//   }
// }

// final Paint transparentPaint = Paint()..color = const Color(0x00000000);


import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:ludo_app/features/game/game_engine/components/board/spot.dart';
import 'package:ludo_app/features/game/game_engine/components/home/home.dart';
import 'package:ludo_app/features/game/game_engine/managers/game_state.dart';
import 'package:ludo_app/features/game/game_engine/models/player_team.dart';

/// Wooden Ludo board inspired by the physical reference board.
///
/// Important compatibility details:
///
/// 1. The board still has nine direct children in the same order as the old
///    implementation. Ludo.blinkBaseForTeam currently relies on those indexes.
///
/// 2. Every track location keeps its original ID, such as B04, R22, G21,
///    and Y42. Existing movement paths therefore continue to work.
///
/// 3. Hidden [Home] components are retained so HomeSpot registration and the
///    existing game initializer continue to work.
///
/// 4. Team-to-letter mapping:
///      Blue   = A
///      Red    = B
///      Green  = C
///      Yellow = D
class LudoBoard extends PositionComponent {
  late final double _unit;
  late final ui.Picture _backgroundPicture;

  static const Color _woodDark = Color(0xFF24130D);
  static const Color _woodMiddle = Color(0xFF3D2116);
  static const Color _woodLight = Color(0xFF5A3320);
  static const Color _engraving = Color(0xFFD7A36B);
  static const Color _engravingSoft = Color(0xFFB67D4E);

  LudoBoard() {
    final layout = GameState().layoutConfig;

    _unit = layout.boardWidth / 15;
    size = Vector2.all(_unit * 15);
    position = layout.boardPosition;

    // Keep the old nine-section child order:
    //
    // 0 red home      1 green arm      2 green home
    // 3 red arm       4 center         5 yellow arm
    // 6 blue home     7 blue arm       8 yellow home

    final redHome = _HomeSection(
      side: _unit * 6,
      unit: _unit,
      team: PlayerTeam.red,
      teamCode: 'R',
      position: Vector2.zero(),
    );

    final greenArm = _TrackSection(
      team: PlayerTeam.green,
      unit: _unit,
      position: Vector2(_unit * 6, 0),
    );

    final greenHome = _HomeSection(
      side: _unit * 6,
      unit: _unit,
      team: PlayerTeam.green,
      teamCode: 'G',
      position: Vector2(_unit * 9, 0),
    );

    final redArm = _TrackSection(
      team: PlayerTeam.red,
      unit: _unit,
      position: Vector2(0, _unit * 6),
    );

    final center = _CenterSection(
      unit: _unit,
      position: Vector2(_unit * 6, _unit * 6),
    );

    final yellowArm = _TrackSection(
      team: PlayerTeam.yellow,
      unit: _unit,
      position: Vector2(_unit * 9, _unit * 6),
    );

    final blueHome = _HomeSection(
      side: _unit * 6,
      unit: _unit,
      team: PlayerTeam.blue,
      teamCode: 'B',
      position: Vector2(0, _unit * 9),
    );

    final blueArm = _TrackSection(
      team: PlayerTeam.blue,
      unit: _unit,
      position: Vector2(_unit * 6, _unit * 9),
    );

    final yellowHome = _HomeSection(
      side: _unit * 6,
      unit: _unit,
      team: PlayerTeam.yellow,
      teamCode: 'Y',
      position: Vector2(_unit * 9, _unit * 9),
    );

    addAll([
      redHome,
      greenArm,
      greenHome,
      redArm,
      center,
      yellowArm,
      blueHome,
      blueArm,
      yellowHome,
    ]);
    _backgroundPicture = _recordBackground();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawPicture(_backgroundPicture);
  }

  ui.Picture _recordBackground() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = Radius.circular(_unit * 0.42);
    final boardShape = RRect.fromRectAndRadius(rect, radius);

    canvas.save();
    canvas.clipRRect(boardShape);

    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _woodDark,
          _woodMiddle,
          _woodLight,
          _woodMiddle,
          _woodDark,
        ],
        stops: [0, 0.28, 0.52, 0.77, 1],
      ).createShader(rect);

    canvas.drawRect(rect, backgroundPaint);

    _drawWoodPlanks(canvas);
    _drawWoodGrain(canvas);
    _drawCenterSeam(canvas);

    canvas.restore();

    final borderPaint = Paint()
      ..color = _engraving.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, _unit * 0.045);

    canvas.drawRRect(boardShape, borderPaint);
    return recorder.endRecording();
  }

  @override
  void onRemove() {
    _backgroundPicture.dispose();
    super.onRemove();
  }

  void _drawWoodPlanks(Canvas canvas) {
    final plankPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.09)
      ..strokeWidth = math.max(1, _unit * 0.025);

    for (var column = 1; column < 15; column++) {
      final x = column * _unit;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        plankPaint,
      );
    }

    final highlightPaint = Paint()
      ..color = _engravingSoft.withValues(alpha: 0.025)
      ..strokeWidth = math.max(1, _unit * 0.018);

    for (var column = 0; column < 15; column += 2) {
      final x = column * _unit + (_unit * 0.08);

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.y),
        highlightPaint,
      );
    }
  }

  void _drawWoodGrain(Canvas canvas) {
    final grainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, _unit * 0.018);

    final lightGrainPaint = Paint()
      ..color = _engravingSoft.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, _unit * 0.012);

    for (var index = 0; index < 38; index++) {
      final baseX = ((index * 37) % 150) / 10 * _unit;
      final path = Path()..moveTo(baseX, 0);

      for (var step = 1; step <= 12; step++) {
        final y = size.y * step / 12;
        final wave =
            math.sin((step * 0.9) + index) * _unit * 0.11;
        final secondaryWave =
            math.sin((step * 0.31) + index * 0.45) * _unit * 0.06;

        path.lineTo(baseX + wave + secondaryWave, y);
      }

      canvas.drawPath(
        path,
        index.isEven ? grainPaint : lightGrainPaint,
      );
    }

    // A few subtle knots make the procedural wood less uniform.
    final knotPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, _unit * 0.02);

    final knots = [
      Offset(_unit * 2.3, _unit * 3.8),
      Offset(_unit * 11.8, _unit * 2.2),
      Offset(_unit * 3.6, _unit * 11.9),
      Offset(_unit * 12.2, _unit * 10.5),
    ];

    for (final knot in knots) {
      canvas.drawOval(
        Rect.fromCenter(
          center: knot,
          width: _unit * 0.75,
          height: _unit * 0.28,
        ),
        knotPaint,
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: knot,
          width: _unit * 0.46,
          height: _unit * 0.16,
        ),
        knotPaint,
      );
    }
  }

  void _drawCenterSeam(Canvas canvas) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.34)
      ..strokeWidth = math.max(2, _unit * 0.085);

    final highlight = Paint()
      ..color = _engravingSoft.withValues(alpha: 0.13)
      ..strokeWidth = math.max(1, _unit * 0.025);

    canvas.drawLine(
      Offset(size.x / 2, 0),
      Offset(size.x / 2, size.y),
      shadow,
    );

    canvas.drawLine(
      Offset(size.x / 2 + _unit * 0.055, 0),
      Offset(size.x / 2 + _unit * 0.055, size.y),
      highlight,
    );
  }
}

/// One of the four 6×6 corner areas.
///
/// A normal [Home] remains as an invisible child because the current game
/// initializer uses its HomeSpot children for initial token placement.
class _HomeSection extends PositionComponent {
  final double side;
  final double unit;
  final PlayerTeam team;
  final String teamCode;

  _HomeSection({
    required this.side,
    required this.unit,
    required this.team,
    required this.teamCode,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2.all(side),
        ) {
    _createFunctionalHome();
    _createVisibleHomeRings();
  }

  void _createFunctionalHome() {
    final hiddenHome = Home(
      size: side,
      paint: Paint()..color = Colors.transparent,
      homeSpotColor: Paint()..color = Colors.transparent,
      teamCode: teamCode,
    );

    // It must stay mounted for HomeSpot registration, but should not render
    // the old colored square home design.
    hiddenHome.opacity = 0;

    add(hiddenHome);
  }

  void _createVisibleHomeRings() {
    // These centers match the HomeSpot positions generated by the existing
    // Home -> HomePlate -> HomeSpotContainer implementation.
    final centers = [
      Vector2(unit * 2.1667, unit * 2.1667),
      Vector2(unit * 3.8333, unit * 2.1667),
      Vector2(unit * 2.1667, unit * 3.8333),
      Vector2(unit * 3.8333, unit * 3.8333),
    ];

    for (final center in centers) {
      add(
        _WoodRing(
          size: Vector2.all(unit),
          position: center - Vector2.all(unit / 2),
          radiusFactor: 0.40,
          strokeWidth: unit * 0.065,
          lineColor: LudoBoard._engraving,
          glow: true,
        ),
      );
    }
  }
}

/// Creates one of the four 3×6 or 6×3 track arms.
class _TrackSection extends PositionComponent {
  final PlayerTeam team;
  final double unit;

  _TrackSection({
    required this.team,
    required this.unit,
    required Vector2 position,
  }) : super(
          position: position,
          size: _sectionSize(team, unit),
        ) {
    _createTrack();
    _createStartCaption();
  }

  static Vector2 _sectionSize(PlayerTeam team, double unit) {
    final vertical =
        team == PlayerTeam.green || team == PlayerTeam.blue;

    return vertical
        ? Vector2(unit * 3, unit * 6)
        : Vector2(unit * 6, unit * 3);
  }

  void _createTrack() {
    final vertical =
        team == PlayerTeam.green || team == PlayerTeam.blue;

    final columns = vertical ? 3 : 6;
    final rows = vertical ? 6 : 3;

    for (var column = 0; column < columns; column++) {
      for (var row = 0; row < rows; row++) {
        final id = '${team.id}$column$row';
        final isStart = _isStartSpot(team, column, row);
        final isFinishLane = _isFinishLane(team, column, row);
        final isSafe = _isSafeSpot(team, column, row);

        final spot = Spot(
          uniqueId: id,
          position: Vector2(column * unit, row * unit),
          size: Vector2.all(unit),
          paint: Paint()..color = Colors.transparent,
          children: [
            _BoardHole(
              unit: unit,
              team: team,
              isStart: isStart,
              isFinishLane: isFinishLane,
              isSafe: isSafe,
            ),
          ],
        );

        add(spot);
      }
    }
  }

  void _createStartCaption() {
    final data = switch (team) {
      PlayerTeam.green => (
          position: Vector2(unit * 2.02, unit * 0.02),
          size: Vector2(unit * 0.92, unit * 0.74),
          arrow: '↓',
          turns: 0,
        ),
      PlayerTeam.blue => (
          position: Vector2(unit * 0.04, unit * 5.17),
          size: Vector2(unit * 0.92, unit * 0.74),
          arrow: '↑',
          turns: 0,
        ),
      PlayerTeam.red => (
          position: Vector2(unit * 0.02, unit * 0.04),
          size: Vector2(unit * 0.90, unit * 0.72),
          arrow: '→',
          turns: 0,
        ),
      PlayerTeam.yellow => (
          position: Vector2(unit * 5.05, unit * 2.18),
          size: Vector2(unit * 0.90, unit * 0.72),
          arrow: '←',
          turns: 0,
        ),
    };

    add(
      _StartCaption(
        position: data.position,
        size: data.size,
        arrow: data.arrow,
      ),
    );
  }

  static bool _isStartSpot(
    PlayerTeam team,
    int column,
    int row,
  ) {
    return switch (team) {
      PlayerTeam.green => column == 2 && row == 1, // G21
      PlayerTeam.blue => column == 0 && row == 4, // B04
      PlayerTeam.red => column == 1 && row == 0, // R10
      PlayerTeam.yellow => column == 4 && row == 2, // Y42
    };
  }

  static bool _isFinishLane(
    PlayerTeam team,
    int column,
    int row,
  ) {
    return switch (team) {
      PlayerTeam.green => column == 1 && row > 0,
      PlayerTeam.blue => column == 1 && row < 5,
      PlayerTeam.red => row == 1 && column > 0,
      PlayerTeam.yellow => row == 1 && column < 5,
    };
  }

  static bool _isSafeSpot(
    PlayerTeam team,
    int column,
    int row,
  ) {
    return switch (team) {
      PlayerTeam.green => column == 0 && row == 2, // G02
      PlayerTeam.blue => column == 2 && row == 3, // B23
      PlayerTeam.red => column == 2 && row == 2, // R22
      PlayerTeam.yellow => column == 3 && row == 0, // Y30
    };
  }
}

/// The 3×3 center.
///
/// The old board used four triangles with RF/GF/BF/YF spots. This design
/// continues each lettered path one more circular step into the center.
class _CenterSection extends PositionComponent {
  final double unit;

  _CenterSection({
    required this.unit,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2.all(unit * 3),
        ) {
    _createFinishSpot(
      id: 'GF',
      team: PlayerTeam.green,
      column: 1,
      row: 0,
    );

    _createFinishSpot(
      id: 'RF',
      team: PlayerTeam.red,
      column: 0,
      row: 1,
    );

    _createFinishSpot(
      id: 'YF',
      team: PlayerTeam.yellow,
      column: 2,
      row: 1,
    );

    _createFinishSpot(
      id: 'BF',
      team: PlayerTeam.blue,
      column: 1,
      row: 2,
    );

    add(
      _CenterMedallion(
        position: Vector2(unit, unit),
        size: Vector2.all(unit),
      ),
    );
  }

  void _createFinishSpot({
    required String id,
    required PlayerTeam team,
    required int column,
    required int row,
  }) {
    add(
      Spot(
        uniqueId: id,
        position: Vector2(column * unit, row * unit),
        size: Vector2.all(unit),
        paint: Paint()..color = Colors.transparent,
        children: [
          _BoardHole(
            unit: unit,
            team: team,
            isFinishLane: true,
            isFinal: true,
          ),
        ],
      ),
    );
  }
}

/// One circular playable position.
class _BoardHole extends PositionComponent {
  final double unit;
  final PlayerTeam team;
  final bool isStart;
  final bool isFinishLane;
  final bool isSafe;
  final bool isFinal;

  _BoardHole({
    required this.unit,
    required this.team,
    this.isStart = false,
    this.isFinishLane = false,
    this.isSafe = false,
    this.isFinal = false,
  }) : super(size: Vector2.all(unit));

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(unit / 2, unit / 2);
    final radius = unit * (isFinal ? 0.41 : 0.385);

    if (isFinishLane || isStart) {
      _drawFilledLetterSpace(canvas, center, radius);
    } else {
      _drawEmptySpace(canvas, center, radius);
    }

    if (isSafe && !isStart && !isFinishLane) {
      _drawSafeMark(canvas, center, radius);
    }
  }

  void _drawEmptySpace(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final outerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.095;

    final engravedLine = Paint()
      ..color = LudoBoard._engraving
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.055;

    final innerHighlight = Paint()
      ..color = const Color(0xFFFFD59C).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.018;

    canvas.drawCircle(
      center.translate(unit * 0.025, unit * 0.035),
      radius,
      outerShadow,
    );

    canvas.drawCircle(center, radius, engravedLine);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - unit * 0.035),
      math.pi * 1.08,
      math.pi * 0.86,
      false,
      innerHighlight,
    );
  }

  void _drawFilledLetterSpace(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final isDarkPiece =
        team == PlayerTeam.blue || team == PlayerTeam.green;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.48)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        unit * 0.07,
      );

    canvas.drawCircle(
      center.translate(unit * 0.035, unit * 0.06),
      radius * 0.95,
      shadow,
    );

    final discRect = Rect.fromCircle(
      center: center,
      radius: radius * 0.92,
    );

    final discPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDarkPiece
            ? const [
                Color(0xFF513223),
                Color(0xFF1D100C),
                Color(0xFF392016),
              ]
            : const [
                Color(0xFFFFE6B8),
                Color(0xFFC99B62),
                Color(0xFFF0C98D),
              ],
      ).createShader(discRect);

    canvas.drawCircle(center, radius * 0.92, discPaint);

    final rimPaint = Paint()
      ..color = isDarkPiece
          ? LudoBoard._engraving.withValues(alpha: 0.72)
          : const Color(0xFF6A3C24).withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * (isStart ? 0.06 : 0.035);

    canvas.drawCircle(center, radius * 0.92, rimPaint);

    _drawCenteredText(
      canvas,
      _letterForTeam(team),
      center,
      fontSize: unit * 0.48,
      color: isDarkPiece
          ? const Color(0xFFE5B477)
          : const Color(0xFF5A321F),
      fontWeight: FontWeight.w800,
    );

    if (isStart) {
      final startRing = Paint()
        ..color = const Color(0xFFFFD79A).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.025;

      canvas.drawCircle(center, radius, startRing);
    }
  }

  void _drawSafeMark(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final paint = Paint()
      ..color = LudoBoard._engraving.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    final smallRadius = radius * 0.16;

    final path = Path()
      ..moveTo(center.dx, center.dy - smallRadius)
      ..lineTo(center.dx + smallRadius * 0.42, center.dy - smallRadius * 0.42)
      ..lineTo(center.dx + smallRadius, center.dy)
      ..lineTo(center.dx + smallRadius * 0.42, center.dy + smallRadius * 0.42)
      ..lineTo(center.dx, center.dy + smallRadius)
      ..lineTo(center.dx - smallRadius * 0.42, center.dy + smallRadius * 0.42)
      ..lineTo(center.dx - smallRadius, center.dy)
      ..lineTo(center.dx - smallRadius * 0.42, center.dy - smallRadius * 0.42)
      ..close();

    canvas.drawPath(path, paint);
  }
}

/// Decorative home-position ring.
class _WoodRing extends PositionComponent {
  final double radiusFactor;
  final double strokeWidth;
  final Color lineColor;
  final bool glow;

  _WoodRing({
    required Vector2 size,
    required Vector2 position,
    required this.radiusFactor,
    required this.strokeWidth,
    required this.lineColor,
    this.glow = false,
  }) : super(
          size: size,
          position: position,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x * radiusFactor;

    if (glow) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.9;

      canvas.drawCircle(
        center.translate(size.x * 0.02, size.y * 0.035),
        radius,
        shadowPaint,
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, linePaint);

    final highlightPaint = Paint()
      ..color = const Color(0xFFFFD59C).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.28;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth * 0.55),
      math.pi * 1.08,
      math.pi * 0.78,
      false,
      highlightPaint,
    );
  }
}

class _StartCaption extends PositionComponent {
  final String arrow;

  _StartCaption({
    required Vector2 position,
    required Vector2 size,
    required this.arrow,
  }) : super(
          position: position,
          size: size,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);

    _drawCenteredText(
      canvas,
      arrow,
      Offset(center.dx, size.y * 0.25),
      fontSize: size.y * 0.39,
      color: LudoBoard._engraving,
      fontWeight: FontWeight.w800,
    );

    _drawCenteredText(
      canvas,
      'START',
      Offset(center.dx, size.y * 0.72),
      fontSize: size.y * 0.17,
      color: LudoBoard._engraving,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
  }
}

class _CenterMedallion extends PositionComponent {
  _CenterMedallion({
    required Vector2 position,
    required Vector2 size,
  }) : super(
          position: position,
          size: size,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x * 0.27;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.50);

    canvas.drawCircle(
      center.translate(size.x * 0.025, size.y * 0.045),
      radius,
      shadowPaint,
    );

    final fillPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF6B412B),
          Color(0xFF2A160F),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, fillPaint);

    final rimPaint = Paint()
      ..color = LudoBoard._engraving.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.025;

    canvas.drawCircle(center, radius, rimPaint);

    // Simple engraved destination symbol.
    final diamondPaint = Paint()
      ..color = LudoBoard._engraving.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.025;

    final diamondRadius = radius * 0.38;

    final path = Path()
      ..moveTo(center.dx, center.dy - diamondRadius)
      ..lineTo(center.dx + diamondRadius, center.dy)
      ..lineTo(center.dx, center.dy + diamondRadius)
      ..lineTo(center.dx - diamondRadius, center.dy)
      ..close();

    canvas.drawPath(path, diamondPaint);
  }
}

String _letterForTeam(PlayerTeam team) {
  return switch (team) {
    PlayerTeam.blue => 'A',
    PlayerTeam.red => 'B',
    PlayerTeam.green => 'C',
    PlayerTeam.yellow => 'D',
  };
}

void _drawCenteredText(
  Canvas canvas,
  String text,
  Offset center, {
  required double fontSize,
  required Color color,
  FontWeight fontWeight = FontWeight.normal,
  double letterSpacing = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: 1,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();

  painter.paint(
    canvas,
    Offset(
      center.dx - painter.width / 2,
      center.dy - painter.height / 2,
    ),
  );
}