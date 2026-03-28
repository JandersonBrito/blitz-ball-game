import 'dart:math';
import 'dart:ui';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors, Color, Offset, Paint, PaintingStyle, TextDirection, TextSpan, TextStyle, TextPainter;
import 'components/block_component.dart';
import 'components/ball_component.dart';
import 'managers/game_state.dart';
import 'managers/block_factory.dart';
import '../models/element.dart';

enum GamePhase { menu, aim, shooting, returning, gameOver }

class BallzFlameGame extends FlameGame {
  final GameState gameState;

  BallzFlameGame({required this.gameState});

  // constants
  static const double blockSize = 38.0;
  static const int cols = 9;
  static const int rows = 13;
  static const double ballSpeed = 320.0;
  static const double ballRadius = 5.0;

  late double floorY;
  late double originX;

  GamePhase phase = GamePhase.menu;
  double? aimAngle;

  final List<BlockComponent> blocks = [];
  final List<BallComponent> activeBalls = [];
  final List<_ReturningBall> returningBalls = [];
  final List<_ShotEntry> shotQueue = [];

  double shotTimer = 0;
  static const double shotInterval = 0.08;
  int landed = 0;
  double? firstLandX;
  double? returnTargetX;
  double _pulseTime = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    floorY = size.y - 50;
    originX = size.x / 2;
    _loadBlocks();
  }

  void _loadBlocks() {
    blocks.clear();
    final isBoss = gameState.isBossStage;
    final newBlocks = isBoss
        ? initBossStage(gameState.level)
        : initBlocks(gameState.level);
    blocks.addAll(newBlocks);
  }

  void startWave() {
    if (phase != GamePhase.menu) return;
    gameState.startWave();
    phase = GamePhase.aim;
  }

  void shoot() {
    if (phase != GamePhase.aim || aimAngle == null) return;
    final dx = cos(aimAngle!) * ballSpeed;
    final dy = sin(aimAngle!) * ballSpeed;
    for (int i = 0; i < gameState.ballCount; i++) {
      shotQueue.add(_ShotEntry(dx: dx, dy: dy, el: gameState.ballElement));
    }
    shotTimer = 0;
    phase = GamePhase.shooting;
  }

  void forceReturn() {
    if (phase != GamePhase.shooting) return;
    shotQueue.clear();
    _startReturnPhase();
  }

  void _startReturnPhase() {
    final targetX = firstLandX ?? originX;
    returningBalls.clear();
    for (int i = 0; i < activeBalls.length; i++) {
      final b = activeBalls[i];
      returningBalls.add(_ReturningBall(
        sx: b.position.x, sy: b.position.y,
        ex: targetX, ey: floorY,
        cpx: (b.position.x + targetX) / 2,
        cpy: min(b.position.y, floorY) - 120 - (i % 4) * 35,
        el: b.element,
      ));
    }
    activeBalls.clear();
    returnTargetX = targetX;
    phase = GamePhase.returning;
  }

  void _finishRound() {
    originX = returnTargetX ?? size.x / 2;
    returningBalls.clear();
    landed = 0; firstLandX = null; returnTargetX = null;

    // descend blocks
    for (final b in blocks) {
      b.position.y += blockSize;
    }

    // game over check
    if (blocks.any((b) => b.position.y + b.size.y >= floorY)) {
      phase = GamePhase.gameOver;
      gameState.setGameOver();
      return;
    }

    final cleared = blocks.isEmpty;
    final lastWave = gameState.waveInStage >= gameState.wavesInStage;

    if (lastWave && cleared) {
      gameState.advanceStage();
      _loadBlocks();
      phase = GamePhase.menu;
    } else {
      if (!lastWave) gameState.advanceWave();
      else gameState.repeatWave();
      // add new row at top
      final dom = allElements[Random().nextInt(allElements.length)];
      final newRow = generateRow(gameState.level, dom, 0);
      blocks.addAll(newRow);
      phase = GamePhase.aim;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTime += dt;

    switch (phase) {
      case GamePhase.shooting:
        _updateShooting(dt);
        break;
      case GamePhase.returning:
        _updateReturning(dt);
        break;
      default:
        break;
    }
  }

  void _updateShooting(double dt) {
    // fire from queue
    if (shotQueue.isNotEmpty) {
      shotTimer -= dt;
      if (shotTimer <= 0) {
        final shot = shotQueue.removeAt(0);
        activeBalls.add(BallComponent(
          position: Vector2(originX, floorY),
          velocity: Vector2(shot.dx, shot.dy),
          element: shot.el,
        ));
        shotTimer = shotInterval;
      }
    }

    final canvasW = size.x;

    for (final ball in activeBalls) {
      if (!ball.active) continue;
      ball.position += ball.velocity * dt;

      // wall bounces
      if (ball.position.x - ballRadius <= 1) {
        ball.position.x = ballRadius + 1;
        ball.velocity.x = ball.velocity.x.abs();
      }
      if (ball.position.x + ballRadius >= canvasW - 1) {
        ball.position.x = canvasW - ballRadius - 1;
        ball.velocity.x = -ball.velocity.x.abs();
      }
      if (ball.position.y - ballRadius <= 1) {
        ball.position.y = ballRadius + 1;
        ball.velocity.y = ball.velocity.y.abs();
      }

      // floor
      if (ball.position.y >= floorY) {
        ball.active = false;
        landed++;
        firstLandX ??= ball.position.x;
        ball.position.x = firstLandX!;
        ball.position.y = floorY;
        continue;
      }

      // block collisions
      _handleBlockCollisions(ball);
    }

    final allDone = activeBalls.every((b) => !b.active) && shotQueue.isEmpty;
    if (allDone && activeBalls.isNotEmpty) {
      _startReturnPhase();
    }
  }

  void _handleBlockCollisions(BallComponent ball) {
    for (int bi = blocks.length - 1; bi >= 0; bi--) {
      final block = blocks[bi];
      final bLeft   = block.position.x;
      final bTop    = block.position.y;
      final bRight  = bLeft + block.size.x;
      final bBottom = bTop  + block.size.y;

      final nearX = ball.position.x.clamp(bLeft, bRight);
      final nearY = ball.position.y.clamp(bTop, bBottom);
      final dist  = sqrt(pow(ball.position.x - nearX, 2) + pow(ball.position.y - nearY, 2));

      if (dist >= ballRadius) continue;

      // hit!
      switch (block.type) {
        case BlockType.bonus:
          blocks.removeAt(bi);
          gameState.incrementBallCount();
          shotQueue.insert(0, _ShotEntry(
            dx: ball.velocity.x / ballSpeed * ballSpeed,
            dy: ball.velocity.y / ballSpeed * ballSpeed,
            el: ElementType.neutral,
          ));
          break;

        case BlockType.triple:
          blocks.removeAt(bi);
          final ang = atan2(ball.velocity.y, ball.velocity.x);
          for (final da in [-pi/3, -pi/6, pi/6, pi/3]) {
            activeBalls.add(BallComponent(
              position: ball.position.clone(),
              velocity: Vector2(cos(ang+da)*ballSpeed, sin(ang+da)*ballSpeed),
              element: ElementType.neutral,
            ));
          }
          gameState.addScore(8);
          break;

        case BlockType.elemPower:
          if (block.elemPowerEl != null) {
            gameState.ballElement = block.elemPowerEl!;
            for (final b in activeBalls) b.element = block.elemPowerEl!;
            for (final s in shotQueue) s.el = block.elemPowerEl!;
          }
          blocks.removeAt(bi);
          break;

        default:
          // damage
          final baseDmg  = gameState.baseDamage;
          final elemMult = gameState.calcElemMult(ball.element, block.element);
          final isCrit   = Random().nextDouble() < gameState.critChance;
          final dmg      = (baseDmg * elemMult * (isCrit ? 2 : 1)).ceil();
          block.takeDamage(dmg);
          gameState.addScore(1);

          if (!block.isAlive) {
            if (block.type == BlockType.gold) gameState.addGold(block.goldValue);
            if (block.isBoss) gameState.addGold(block.goldValue * 2);
            gameState.addScore(block.isBoss ? 20 : 3);
            blocks.removeAt(bi);
          } else {
            // bounce
            final overlapX = min((ball.position.x - bLeft).abs(), (ball.position.x - bRight).abs());
            final overlapY = min((ball.position.y - bTop).abs(),  (ball.position.y - bBottom).abs());
            if (overlapX < overlapY) {
              ball.velocity.x = -ball.velocity.x;
            } else {
              ball.velocity.y = -ball.velocity.y;
            }
          }
      }
    }
  }

  void _updateReturning(double dt) {
    const speed = 1 / 0.6; // complete in 0.6 seconds
    bool allArrived = true;
    for (final rb in returningBalls) {
      rb.t = min(1.0, rb.t + dt * speed);
      final t = rb.t, mt = 1 - t;
      rb.x = mt*mt*rb.sx + 2*mt*t*rb.cpx + t*t*rb.ex;
      rb.y = mt*mt*rb.sy + 2*mt*t*rb.cpy + t*t*rb.ey;
      if (rb.t < 1) allArrived = false;
    }
    if (allArrived) _finishRound();
  }

  void handlePointerPosition(Offset pos) {
    if (phase != GamePhase.aim) return;
    double ang = atan2(pos.dy - floorY, pos.dx - originX);
    ang = ang.clamp(-pi + 0.15, -0.15);
    aimAngle = ang;
  }

  void handleTap(Offset pos) {
    if (phase != GamePhase.aim) return;
    handlePointerPosition(pos);
    shoot();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBackground(canvas);
    _drawBlocks(canvas);
    _drawAimLine(canvas);
    _drawReturningBalls(canvas);
    _drawActiveBalls(canvas);
    _drawOriginBall(canvas);
  }

  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF0a0a14),
    );
    // grid
    final gridPaint = Paint()..color = const Color(0x0AFFFFFF)..strokeWidth = 0.5;
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * blockSize + 1, 0), Offset(c * blockSize + 1, floorY), gridPaint);
    }
    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(1, r * blockSize.toDouble()), Offset(size.x - 1, r * blockSize.toDouble()), gridPaint);
    }
    // floor line
    canvas.drawLine(
      Offset(0, floorY), Offset(size.x, floorY),
      Paint()..color = const Color(0x26FFFFFF)..strokeWidth = 1,
    );
  }

  void _drawBlocks(Canvas canvas) {
    for (final b in blocks) {
      canvas.save();
      canvas.translate(b.position.x, b.position.y);
      b.render(canvas);
      canvas.restore();
    }
  }

  void _drawAimLine(Canvas canvas) {
    if (phase != GamePhase.aim || aimAngle == null) return;
    final elColor = elementDataMap[gameState.ballElement]?.ballColor ?? const Color(0xFFFFFFFF);
    final aimBonus = gameState.aimBonus;
    final maxBounces = gameState.maxBounces;
    final aimLen = (55 + aimBonus) / 3;

    final dashPath = Path();
    void drawSeg(double sx, double sy, double dx, double dy, int bounceIdx) {
      if (bounceIdx > maxBounces) return;
      double cx2 = sx, cy2 = sy, cdx = dx, cdy = dy;
      dashPath.moveTo(cx2, cy2);
      for (int i = 0; i < aimLen; i++) {
        cx2 += cdx * 3; cy2 += cdy * 3;
        bool hit = false;
        if (cx2 <= ballRadius + 1)           { cx2 = ballRadius + 1;           cdx =  cdx.abs(); hit = true; }
        if (cx2 >= size.x - ballRadius - 1)  { cx2 = size.x - ballRadius - 1; cdx = -cdx.abs(); hit = true; }
        if (cy2 <= ballRadius)               { cy2 = ballRadius;               cdy =  cdy.abs(); hit = true; }
        if (cy2 >= floorY) break;
        dashPath.lineTo(cx2, cy2);
        if (hit) { drawSeg(cx2, cy2, cdx, cdy, bounceIdx + 1); return; }
      }
    }

    drawSeg(originX, floorY, cos(aimAngle!), sin(aimAngle!), 0);
    canvas.drawPath(dashPath, Paint()
      ..color = elColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  void _drawReturningBalls(Canvas canvas) {
    for (final rb in returningBalls) {
      final col = elementDataMap[rb.el]?.ballColor ?? const Color(0xFFFFFFFF);
      canvas.drawCircle(
        Offset(rb.x, rb.y), ballRadius,
        Paint()..color = col.withOpacity(0.4 + 0.6 * (1 - rb.t)),
      );
    }
  }

  void _drawActiveBalls(Canvas canvas) {
    for (final b in activeBalls) {
      final col = elementDataMap[b.element]?.ballColor ?? const Color(0xFFFFFFFF);
      canvas.drawCircle(Offset(b.position.x, b.position.y), ballRadius, Paint()..color = col);
    }
  }

  void _drawOriginBall(Canvas canvas) {
    if (phase != GamePhase.aim) return;
    final col = elementDataMap[gameState.ballElement]?.ballColor ?? const Color(0xFFFFFFFF);
    canvas.drawCircle(Offset(originX, floorY), ballRadius, Paint()..color = col);
    final tp = TextPainter(
      text: TextSpan(
        text: 'x${gameState.ballCount}',
        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(originX - tp.width / 2, floorY + ballRadius + 5));
  }
}

class _ShotEntry {
  double dx, dy;
  ElementType el;
  _ShotEntry({required this.dx, required this.dy, required this.el});
}

class _ReturningBall {
  final double sx, sy, ex, ey, cpx, cpy;
  final ElementType el;
  double t = 0, x, y;
  _ReturningBall({
    required this.sx, required this.sy,
    required this.ex, required this.ey,
    required this.cpx, required this.cpy,
    required this.el,
  }) : x = sx, y = sy;
}
