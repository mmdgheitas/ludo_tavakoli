import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:ludo_app/features/game/game_engine/managers/audio_manager.dart';

/// Cosmetic overlay for an accepted Fattah rocket: it flies from the attacker's
/// home area to the struck token, detonates and removes itself.
///
/// The authoritative snapshot has already sent the piece home, so this
/// component never mutates game state — it only explains *why* the piece moved,
/// which a plain capture animation cannot express. The body is drawn with canvas
/// primitives (no image assets), and `assets/audio/rocket.mp3` is timed to the
/// same 0.55 s flight and impact below, so one sample covers launch and blast.
/// The flight is integrated in [update] so no effect backlog can survive a
/// teardown: [finished] always resolves, and [onRemove] resolves it early.
class RocketComponent extends PositionComponent {
  RocketComponent({
    required Vector2 from,
    required Vector2 to,
    required this.bodyColor,
    this.rocketSize = 30,
  })  : _fromX = from.x,
        _fromY = from.y,
        _toX = to.x,
        _toY = to.y,
        super(position: from.clone(), size: Vector2.all(30));

  final double _fromX;
  final double _fromY;
  final double _toX;
  final double _toY;

  /// Team colour of the attacker, used for the fins and the blast ring.
  final Color bodyColor;
  final double rocketSize;

  static const double flightSeconds = 0.55;
  static const double blastSeconds = 0.32;
  static const double _puffLifeSeconds = 0.34;

  final Completer<void> _done = Completer<void>();

  /// Resolves after the detonation, or immediately if the board tears down.
  Future<void> get finished => _done.future;

  double _elapsed = 0;
  double _blast = 0;
  bool _impacted = false;
  bool _finished = false;
  double _angle = -math.pi / 2;
  double _controlX = 0;
  double _controlY = 0;
  final List<_Puff> _puffs = [];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2.all(rocketSize);
    _recomputeControl();
    _placeAt(0);
    unawaited(AudioManager.playRocketSound());
  }

  /// Arcs the flight away from the straight line so the rocket reads as a shot
  /// across the board instead of a teleport; the bulge always points up-screen.
  void _recomputeControl() {
    final midX = (_fromX + _toX) / 2.0;
    final midY = (_fromY + _toY) / 2.0;
    final deltaX = _toX - _fromX;
    final deltaY = _toY - _fromY;
    final length = math.sqrt(deltaX * deltaX + deltaY * deltaY);
    if (length < 1) {
      _controlX = midX;
      _controlY = midY;
      return;
    }
    final lift = length * 0.30;
    var normalX = -deltaY / length;
    var normalY = deltaX / length;
    if (normalY > 0) {
      normalX = -normalX;
      normalY = -normalY;
    }
    _controlX = midX + normalX * lift;
    _controlY = midY + normalY * lift;
  }

  void _placeAt(double t) {
    final double inv = 1.0 - t;
    final double x = inv * inv * _fromX + 2.0 * inv * t * _controlX + t * t * _toX;
    final double y = inv * inv * _fromY + 2.0 * inv * t * _controlY + t * t * _toY;
    final double aheadT = math.min(1.0, t + 0.02);
    final double aheadInv = 1.0 - aheadT;
    final double aheadX = aheadInv * aheadInv * _fromX +
        2.0 * aheadInv * aheadT * _controlX +
        aheadT * aheadT * _toX;
    final double aheadY = aheadInv * aheadInv * _fromY +
        2.0 * aheadInv * aheadT * _controlY +
        aheadT * aheadT * _toY;
    if (aheadX != x || aheadY != y) _angle = math.atan2(aheadY - y, aheadX - x);
    // Default anchor (top-left), like every other board component: keep the
    // drawn centre on the path.
    position = Vector2(x - size.x / 2.0, y - size.y / 2.0);
    _puffs.add(_Puff(x, y));
    if (_puffs.length > 16) _puffs.removeAt(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    if (!_impacted) {
      _elapsed += dt;
      final t = math.min(1.0, _elapsed / flightSeconds);
      for (final puff in _puffs) {
        puff.age += dt;
      }
      _puffs.removeWhere((puff) => puff.age > _puffLifeSeconds);
      _placeAt(t);
      if (t >= 1) _impacted = true;
      return;
    }
    _blast += dt;
    if (_blast >= blastSeconds) _complete();
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    if (!_done.isCompleted) _done.complete();
    removeFromParent();
  }

  @override
  void onRemove() {
    if (!_done.isCompleted) _done.complete();
    _puffs.clear();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final centre = Offset(size.x / 2.0, size.y / 2.0);
    _renderTrail(canvas);
    if (_impacted) {
      _renderBlast(canvas, centre);
      return;
    }
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      // The body is drawn pointing up, so +90° aligns it with the flight path.
      ..rotate(_angle + math.pi / 2);
    _renderBody(canvas);
    canvas.restore();
  }

  void _renderTrail(Canvas canvas) {
    for (final puff in _puffs) {
      final double life = 1.0 - (puff.age / _puffLifeSeconds).clamp(0.0, 1.0).toDouble();
      final local = Offset(puff.x - position.x, puff.y - position.y);
      canvas.drawCircle(
        local,
        size.x * 0.16 * life + 1,
        Paint()..color = Colors.white.withValues(alpha: 0.30 * life),
      );
    }
  }

  void _renderBody(Canvas canvas) {
    final h = size.y;
    final w = size.x;

    final exhaust = Path()
      ..moveTo(-w * 0.15, h * 0.28)
      ..lineTo(0, h * 0.56)
      ..lineTo(w * 0.15, h * 0.28)
      ..close();
    canvas.drawPath(exhaust, Paint()..color = const Color(0xFFFFB43D));

    final fins = Path()
      ..moveTo(-w * 0.18, h * 0.06)
      ..lineTo(-w * 0.40, h * 0.34)
      ..lineTo(-w * 0.14, h * 0.26)
      ..close()
      ..moveTo(w * 0.18, h * 0.06)
      ..lineTo(w * 0.40, h * 0.34)
      ..lineTo(w * 0.14, h * 0.26)
      ..close();
    canvas.drawPath(fins, Paint()..color = bodyColor);

    final body = Path()
      ..moveTo(0, -h * 0.48)
      ..quadraticBezierTo(w * 0.26, -h * 0.08, w * 0.18, h * 0.28)
      ..lineTo(-w * 0.18, h * 0.28)
      ..quadraticBezierTo(-w * 0.26, -h * 0.08, 0, -h * 0.48)
      ..close();
    canvas
      ..drawPath(body, Paint()..color = Colors.white)
      ..drawPath(
        body,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      )
      ..drawCircle(Offset(0, -h * 0.10), w * 0.09, Paint()..color = bodyColor);
  }

  void _renderBlast(Canvas canvas, Offset centre) {
    final double t = (_blast / blastSeconds).clamp(0.0, 1.0).toDouble();
    final double fade = 1.0 - t;
    final outer = size.x * (0.34 + t * 1.20);
    canvas
      ..drawCircle(centre, outer, Paint()..color = const Color(0xFFFFB43D).withValues(alpha: 0.45 * fade))
      ..drawCircle(centre, size.x * (0.20 + t * 0.70), Paint()..color = Colors.white.withValues(alpha: 0.70 * fade))
      ..drawCircle(
        centre,
        outer,
        Paint()
          ..color = bodyColor.withValues(alpha: 0.55 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    for (var shard = 0; shard < 8; shard++) {
      final double angle = (math.pi * 2.0 / 8.0) * shard + t;
      final distance = size.x * (0.30 + t * 1.25);
      canvas.drawCircle(
        Offset(centre.dx + math.cos(angle) * distance, centre.dy + math.sin(angle) * distance),
        0.6 + 2.2 * fade,
        Paint()..color = Colors.white.withValues(alpha: 0.75 * fade),
      );
    }
  }
}

class _Puff {
  _Puff(this.x, this.y);
  final double x;
  final double y;
  double age = 0;
}
