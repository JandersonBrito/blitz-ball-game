import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart' show Colors, Paint, PaintingStyle;
import '../../models/element.dart';

class BallComponent extends PositionComponent with CollisionCallbacks {
  static const double radius = 5.0;
  Vector2 velocity;
  ElementType element;
  bool active;

  BallComponent({
    required Vector2 position,
    required this.velocity,
    required this.element,
    this.active = true,
  }) : super(position: position, size: Vector2.all(radius * 2), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  Color get ballColor => elementDataMap[element]?.ballColor ?? const Color(0xFFFFFFFF);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = ballColor;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!active) return;
    position += velocity * dt;
  }
}
