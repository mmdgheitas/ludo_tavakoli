import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:ludo_app/features/game/game_engine/managers/tile_manager.dart';

class HomeSpot extends CircleComponent {
  final String uniqueId;

  HomeSpot({
    required double radius,
    required Vector2 position,
    required Paint paint,
    required this.uniqueId,
  }) : super(radius: radius, position: position, paint: paint) {
    TileManager().registerHomeSpot(uniqueId, this);
  }

  @override
  void render(Canvas canvas) {
    if (paint.color != Colors.transparent) super.render(canvas);
  }
}
