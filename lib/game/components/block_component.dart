import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart' show Colors, Color, Paint, PaintingStyle, TextSpan, TextPainter, TextStyle, TextAlign, TextDirection;
import '../../models/element.dart';

enum BlockType { normal, bonus, gold, elemPower, triple, boss }

class BlockComponent extends PositionComponent with CollisionCallbacks {
  final BlockType type;
  int hp;
  int maxHp;
  final ElementType element;
  final int goldValue;
  final ElementType? elemPowerEl;
  final bool isBoss;

  static const double blockSize = 38.0;

  BlockComponent({
    required Vector2 position,
    required this.type,
    required this.hp,
    required this.maxHp,
    required this.element,
    this.goldValue = 0,
    this.elemPowerEl,
    this.isBoss = false,
  }) : super(
          position: position,
          size: isBoss ? Vector2(blockSize * 2, blockSize * 2) : Vector2(blockSize, blockSize),
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  bool get isAlive => hp > 0;
  double get hpRatio => maxHp > 0 ? hp / maxHp : 1.0;

  void takeDamage(int dmg) {
    hp = max(0, hp - dmg);
  }

  Color get _bgColor {
    if (type == BlockType.bonus) return const Color(0xFF534AB7);
    if (type == BlockType.triple) return const Color(0xFF1a1a2e);
    final e = elementDataMap[element]!;
    final ratio = hpRatio;
    return Color.lerp(e.blockBg.withOpacity(0.45), e.blockBg, ratio) ?? e.blockBg;
  }

  Color get _borderColor {
    if (isBoss || type == BlockType.gold) return const Color(0xFFEF9F27);
    if (type == BlockType.bonus) return const Color(0xFF7F77DD);
    if (type == BlockType.triple) return Colors.white;
    if (type == BlockType.elemPower && elemPowerEl != null) {
      return elementDataMap[elemPowerEl!]!.blockBorder;
    }
    return elementDataMap[element]!.blockBorder;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x, h = size.y;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, w - 4, h - 4),
      const Radius.circular(6),
    );

    // background
    final bgPaint = Paint()..color = _bgColor;
    canvas.drawRRect(rect, bgPaint);

    // border
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBoss ? 3.0 : (type == BlockType.gold ? 2.5 : 1.5);
    canvas.drawRRect(rect, borderPaint);

    // boss glow pulse
    if (isBoss) {
      final t = DateTime.now().millisecondsSinceEpoch / 300.0;
      final pulse = 0.5 + 0.5 * sin(t);
      final glowPaint = Paint()
        ..color = _bgColor.withOpacity(0.2 + pulse * 0.15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-4, -4, w + 8, h + 8), const Radius.circular(12)),
        glowPaint,
      );
      // hp bar
      final barX = 8.0, barY = h - 10.0, barW = w - 16;
      canvas.drawRect(Rect.fromLTWH(barX, barY, barW, 5), Paint()..color = const Color(0x66000000));
      final barColor = hpRatio > 0.5
          ? const Color(0xFF1D9E75)
          : hpRatio > 0.25
              ? const Color(0xFFBA7517)
              : const Color(0xFFE24B4A);
      canvas.drawRect(Rect.fromLTWH(barX, barY, barW * hpRatio, 5), Paint()..color = barColor);
    }

    _renderText(canvas, w, h);
  }

  void _renderText(Canvas canvas, double w, double h) {
    final center = Offset(w / 2, h / 2);
    switch (type) {
      case BlockType.bonus:
        _drawText(canvas, '+1', center, 11, Colors.white);
        break;
      case BlockType.triple:
        // 3 dots fan
        final dots = [Offset(-6, 0), const Offset(0, -7), const Offset(6, 0)];
        final dotPaint = Paint()..color = Colors.white;
        for (final d in dots) {
          canvas.drawCircle(center + d, 3, dotPaint);
        }
        break;
      case BlockType.elemPower:
        if (elemPowerEl != null) {
          _drawText(canvas, elementDataMap[elemPowerEl!]!.icon, center, 13, Colors.white);
        }
        break;
      case BlockType.gold:
        _drawText(canvas, '$hp', Offset(w / 2, h / 2 - 4), 10, elementDataMap[element]!.textColor);
        _drawText(canvas, '+$goldValue', Offset(w / 2, h / 2 + 7), 7, const Color(0xFFEF9F27));
        break;
      case BlockType.boss:
        if (element != ElementType.neutral) {
          _drawText(canvas, elementDataMap[element]!.icon, Offset(w / 2, h / 2 - 14), 20, Colors.white);
        }
        _drawText(canvas, 'BOSS', Offset(w / 2, element != ElementType.neutral ? h / 2 + 2 : h / 2 - 8),
            8, Colors.white70);
        _drawText(canvas, '$hp',
            Offset(w / 2, element != ElementType.neutral ? h / 2 + 16 : h / 2 + 6),
            hp > 9999 ? 9 : hp > 999 ? 11 : 13, elementDataMap[element]!.textColor);
        break;
      case BlockType.normal:
        _drawText(canvas, '$hp', center, hp > 99 ? 8 : 10, elementDataMap[element]!.textColor);
        if (element != ElementType.neutral) {
          _drawText(canvas, elementDataMap[element]!.icon, Offset(w - 4, 4), 7, Colors.white70,
              textAlign: TextAlign.right);
        }
        break;
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, double fontSize, Color color,
      {TextAlign textAlign = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontFamily: 'monospace', fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    )..layout();
    tp.paint(canvas, position - Offset(tp.width / 2, tp.height / 2));
  }
}
