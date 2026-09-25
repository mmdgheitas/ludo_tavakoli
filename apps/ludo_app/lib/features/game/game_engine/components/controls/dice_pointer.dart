import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum PointerDirection { left, right }

class DicePointer extends PositionComponent {
  final Paint paint;
  final PointerDirection direction;
  final double travelDistance;
  final double _originX;
  double _elapsed = 0;
  bool _isActive = false;

  bool get isActive => _isActive;

  set isActive(bool value) {
    if (_isActive == value) return;
    _isActive = value;
    _elapsed = 0;
    position.x = _originX;
  }

  DicePointer({
    required double size,
    required this.paint,
    required this.direction,
    required this.travelDistance,
    Vector2? position,
  })  : _originX = position?.x ?? 0,
        super(size: Vector2.all(size), position: position);

  @override
  void update(double dt) {
    super.update(dt);
    if (!isActive) return;

    // Same 0.2s out / 0.2s back motion, without allocating infinite effects
    // on every turn. Keep elapsed time bounded even in a long-running match.
    _elapsed = (_elapsed + dt) % 0.4;
    final progress = _elapsed <= 0.2
        ? _elapsed / 0.2
        : (0.4 - _elapsed) / 0.2;
    position.x = _originX + travelDistance * progress;
  }

  @override
  void render(Canvas canvas) {
    if (!isActive) return;
    super.render(canvas);

    final path = Path();

    if (direction == PointerDirection.left) {
      path
        ..moveTo(size.x, 0) // Right corner
        ..lineTo(0, size.y / 2) // Left corner (new "top")
        ..lineTo(size.x, size.y) // Bottom corner
        ..close();
    } else if (direction == PointerDirection.right) {
      path
        ..moveTo(0, 0) // Left corner
        ..lineTo(size.x, size.y / 2) // Right corner (new "top")
        ..lineTo(0, size.y) // Bottom corner
        ..close();
    }

    canvas.drawPath(path, paint);
  }
}
