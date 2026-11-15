import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../../models/ball_skin.dart';
import '../../models/element.dart';
import '../ballz_flame_game.dart';
import '../components/block_component.dart';
import '../physics/ball_pool.dart';
import 'atlas_batch.dart';
import 'sprite_atlas.dart';

/// Desenha o jogo com 1 picture (fundo), 2 lotes de atlas (blocos; bolas e
/// efeitos) e 1 path (mira). Nada é alocado por frame: sem `Paint`,
/// `TextPainter`, `Vector2` ou listas novas; cores são inteiros ARGB.
///
/// Sem blur, sombra dinâmica ou saveLayer: brilho e halos já estão no atlas.
class GameRenderer {
  GameRenderer(this.atlas)
      : _blocks = AtlasBatch(atlas, 512),
        _fx = AtlasBatch(atlas, 512);

  final SpriteAtlas atlas;
  final AtlasBatch _blocks, _fx;
  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _aimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Path _aimPath = Path();

  ui.Picture? _background;
  double _backgroundW = -1, _backgroundFloor = -1;

  // Bolas a desenhar no frame (posição e cor), preenchidas uma vez por frame.
  Float32List _bx = Float32List(0), _by = Float32List(0);
  Uint8List _bel = Uint8List(0);
  Int32List _bcol = Int32List(0);

  static const int _white70 = 0xB3FFFFFF;
  static const int _gold = 0xFFEF9F27;

  /// Com mais bolas em voo que isto, os halos somem (tela já cheia).
  static const int _maxGlowBalls = 150;

  static final List<int> _bg = _table((d) => d.blockBg);
  static final List<int> _border = _table((d) => d.blockBorder);
  static final List<int> _text = _table((d) => d.textColor);
  static final List<int> _ball = _table((d) => d.ballColor);
  static final List<Color> _aimColors = [
    for (final e in ElementType.values)
      elementDataMap[e]!.ballColor.withValues(alpha: 0.4),
  ];

  static List<int> _table(Color Function(ElementData) pick) => [
        for (final e in ElementType.values) pick(elementDataMap[e]!).toARGB32(),
      ];

  void dispose() {
    _background?.dispose();
    _background = null;
  }

  void render(Canvas canvas, BallzFlameGame g) {
    _drawBackground(canvas, g);
    _emitBlocks(g);
    _blocks.render(canvas, _atlasPaint);
    _drawAim(canvas, g);
    _emitFx(g);
    _fx.render(canvas, _atlasPaint);
  }

  // ── Fundo: grade e chão gravados uma vez por tamanho de tela ─────────────
  void _drawBackground(Canvas canvas, BallzFlameGame g) {
    final w = g.size.x, floor = g.floorY;
    if (_background == null || w != _backgroundW || floor != _backgroundFloor) {
      _background?.dispose();
      _background = _recordBackground(w, floor);
      _backgroundW = w;
      _backgroundFloor = floor;
    }
    canvas.drawPicture(_background!);
  }

  static ui.Picture _recordBackground(double w, double floor) {
    const s = BallzFlameGame.blockSize, top = BallzFlameGame.topOffset;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    final grid = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 0.5;
    for (var col = 0; col <= BallzFlameGame.cols; col++) {
      c.drawLine(Offset(col * s + 1, top), Offset(col * s + 1, floor), grid);
    }
    for (var row = 0; row <= BallzFlameGame.rows; row++) {
      c.drawLine(Offset(1, top + row * s), Offset(w - 1, top + row * s), grid);
    }
    c.drawLine(
      Offset(0, floor),
      Offset(w, floor),
      Paint()
        ..color = const Color(0x26FFFFFF)
        ..strokeWidth = 1,
    );
    return recorder.endRecording();
  }

  // ── Blocos ───────────────────────────────────────────────────────────────
  void _emitBlocks(BallzFlameGame g) {
    final batch = _blocks..begin();
    final blocks = g.blocks;
    final glow = g.profile.glow;
    final pulse = 0.5 + 0.5 * sin(g.animTime * 1000 / 300);
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final x = b.position.x + b.shakeOffsetX;
      final y = b.position.y + b.shakeOffsetY;
      switch (b.type) {
        case BlockType.wall:
          _wall(batch, b, x, y);
        case BlockType.bonus:
          batch.add(Spr.bonus, x, y);
        case BlockType.triple:
          batch.add(Spr.triple, x, y);
        case BlockType.elemPower:
          _elemPower(batch, b, x, y);
        case BlockType.boss:
          _boss(batch, b, x, y, glow, pulse);
        case BlockType.normal || BlockType.gold:
          _numbered(batch, b, x, y);
      }
      if (!b.status.isEmpty) _status(batch, b, x, y);
    }
  }

  void _numbered(AtlasBatch batch, BlockComponent b, double x, double y) {
    final el = b.element.index;
    final gold = b.type == BlockType.gold;
    batch.add(Spr.blockFill, x, y, 1, _withAlpha(_bg[el], 0.45 + 0.55 * b.hpRatio));
    batch.add(gold ? Spr.blockBorderGold : Spr.blockBorder, x, y, 1,
        gold ? _gold : _border[el]);
    const half = BallzFlameGame.blockSize / 2;
    if (gold || b.goldValue > 0) {
      _number(batch, b.hp, x + half, y + half - 4, !gold && b.hp > 99 ? 8 : 10,
          _text[el]);
      _number(batch, b.goldValue, x + half, y + half + 7, 7, _gold,
          prefix: Spr.glyphPlus);
      return;
    }
    _number(batch, b.hp, x + half, y + half, b.hp > 99 ? 8 : 10, _text[el]);
    if (b.element != ElementType.neutral) {
      batch.addCentered(Spr.iconSmall + Spr.elementOffset(b.element),
          x + BallzFlameGame.blockSize - 4, y + 4, 0.7, _white70);
    }
  }

  void _elemPower(AtlasBatch batch, BlockComponent b, double x, double y) {
    final e = b.elemPowerEl;
    if (e == null || e == ElementType.neutral) {
      batch.add(Spr.blockFill, x, y, 1, _bg[ElementType.neutral.index]);
      batch.add(Spr.blockBorder, x, y, 1, _border[b.element.index]);
      return;
    }
    batch.add(Spr.elemPower + Spr.elementOffset(e), x, y);
  }

  void _boss(AtlasBatch batch, BlockComponent b, double x, double y, bool glow,
      double pulse) {
    final el = b.element.index;
    final ratio = b.hpRatio;
    final bg = _withAlpha(_bg[el], 0.45 + 0.55 * ratio);
    final w = b.size.x, h = b.size.y;
    batch.add(Spr.bossFill, x, y, 1, bg);
    batch.add(Spr.bossBorder, x, y, 1, _gold);
    if (glow) {
      batch.add(Spr.bossGlow, x - 4, y - 4, 1, _withAlpha(bg, 0.2 + pulse * 0.15));
    }
    batch.add(Spr.hpBar, x + 8, y + h - 10, 1, 0x66000000);
    final bar = ratio > 0.5
        ? 0xFF1D9E75
        : ratio > 0.25
            ? 0xFFBA7517
            : 0xFFE24B4A;
    batch.addPart(Spr.hpBar, x + 8, y + h - 10, ratio, bar);
    final elemental = b.element != ElementType.neutral;
    if (elemental) {
      batch.addCentered(Spr.iconLarge + Spr.elementOffset(b.element), x + w / 2,
          y + h / 2 - 14);
    }
    batch.addCentered(Spr.bossLabel, x + w / 2,
        y + (elemental ? h / 2 + 2 : h / 2 - 8), 1, _white70);
    final hp = b.hp;
    _number(batch, hp, x + w / 2, y + (elemental ? h / 2 + 16 : h / 2 + 6),
        hp > 9999 ? 9 : hp > 999 ? 11 : 13, _text[el]);
  }

  void _wall(AtlasBatch batch, BlockComponent b, double x, double y) {
    const w = BallzFlameGame.blockSize, h = BallzFlameGame.blockSize;
    final ratio = b.hpRatio;
    batch.add(Spr.wallFill, x, y, 1, _lerp(0xFF0D1220, 0xFF1A2238, ratio));
    final hatchAlpha = (0x25 + 0x10 * ratio).toInt().clamp(0, 255);
    batch.add(Spr.wallHatch, x, y, 1, (hatchAlpha << 24) | 0x406090);
    final elemental = b.element != ElementType.neutral;
    final base = elemental ? _border[b.element.index] : 0xFF4D6A9A;
    batch.add(Spr.wallBorder, x, y, 1, _lerp(_withAlpha(base, 0.4), base, ratio));
    batch.add(Spr.wallStripe, x + 5, y + h - 5 - 1.5, 1, 0xFFFF8C00);
    if (elemental) {
      batch.addCentered(Spr.iconSmall + Spr.elementOffset(b.element), x + w - 6,
          y + 7, 0.9, _white70);
    }
    if (b.maxHp > 1) {
      const dotR = 2.5;
      final spacing = min(7.0, (w - 12) / b.maxHp);
      final totalW = spacing * (b.maxHp - 1) + dotR * 2;
      var dx = (w - totalW) / 2 + dotR;
      for (var k = 0; k < b.maxHp; k++) {
        final filled = k < b.hp;
        batch.addCentered(Spr.dot, x + dx, y + h / 2 - 1, 1,
            filled ? 0xFF7799CC : 0xFF2A3550);
        if (filled) {
          batch.addCentered(Spr.dotRing, x + dx, y + h / 2 - 1, 1, 0xFF4D6A9A);
        }
        dx += spacing;
      }
    } else {
      batch.addCentered(Spr.glyphDown, x + w / 2, y + h / 2 - 1,
          11 / SpriteAtlas.glyphFontSize, 0xFF7799CC);
    }
  }

  void _status(AtlasBatch batch, BlockComponent b, double x, double y) {
    final s = b.status;
    var bx = x + 6;
    if (s.burning) {
      batch.addCentered(Spr.statusBadge, bx, y + 6, 1, 0xFFFF7A2E);
      bx += 6;
    }
    if (s.acid) {
      batch.addCentered(Spr.statusBadge, bx, y + 6, 1, 0xFF9BE15D);
      bx += 6;
    }
    if (s.frozen) batch.addCentered(Spr.statusBadge, bx, y + 6, 1, 0xFF8FD8FF);
  }

  /// Número centrado em ([cx], [cy]) com a bitmap font do atlas.
  void _number(AtlasBatch batch, int value, double cx, double cy,
      double fontSize, int color,
      {int prefix = -1}) {
    final adv = atlas.glyphAdvance;
    final k = fontSize / SpriteAtlas.glyphFontSize;
    final v0 = value < 0 ? 0 : value;
    var div = 1;
    while (v0 ~/ div >= 10) {
      div *= 10;
    }
    var width = prefix >= 0 ? adv[prefix - Spr.glyph0] : 0.0;
    for (var d = div, v = v0; d > 0; d ~/= 10) {
      width += adv[v ~/ d];
      v %= d;
    }
    var x = cx - width * k / 2;
    final y = cy - atlas.glyphHeight * k / 2;
    if (prefix >= 0) {
      batch.add(prefix, x, y, k, color);
      x += adv[prefix - Spr.glyph0] * k;
    }
    for (var d = div, v = v0; d > 0; d ~/= 10) {
      final digit = v ~/ d;
      batch.add(Spr.glyph0 + digit, x, y, k, color);
      x += adv[digit] * k;
      v %= d;
    }
  }

  // ── Mira ─────────────────────────────────────────────────────────────────
  void _drawAim(Canvas canvas, BallzFlameGame g) {
    final angle = g.aimAngle;
    if (g.phase != GamePhase.aim || angle == null) return;
    const r = BallzFlameGame.ballRadius, top = BallzFlameGame.topOffset;
    final w = g.size.x, floor = g.floorY;
    final steps = g.aimSteps;
    final path = _aimPath..reset();
    var sx = g.originX, sy = floor, dx = cos(angle), dy = sin(angle);
    for (var bounce = 0; bounce <= g.aimBounces; bounce++) {
      path.moveTo(sx, sy);
      var x = sx, y = sy;
      var hitWall = false;
      for (var i = 0; i < steps; i++) {
        x += dx * 3;
        y += dy * 3;
        var hit = false;
        if (x <= r + 1) {
          x = r + 1;
          dx = dx.abs();
          hit = true;
        }
        if (x >= w - r - 1) {
          x = w - r - 1;
          dx = -dx.abs();
          hit = true;
        }
        if (y <= top + r) {
          y = top + r;
          dy = dy.abs();
          hit = true;
        }
        if (y >= floor) break;
        path.lineTo(x, y);
        if (hit) {
          hitWall = true;
          break;
        }
      }
      if (!hitWall) break;
      sx = x;
      sy = y;
    }
    _aimPaint.color = _aimColors[g.gameState.ballElement.index];
    canvas.drawPath(path, _aimPaint);
  }

  // ── Bolas e efeitos ──────────────────────────────────────────────────────
  void _ensureScratch(int n) {
    if (_bx.length >= n) return;
    var cap = 64;
    while (cap < n) {
      cap <<= 1;
    }
    _bx = Float32List(cap);
    _by = Float32List(cap);
    _bel = Uint8List(cap);
    _bcol = Int32List(cap);
  }

  void _emitFx(BallzFlameGame g) {
    final batch = _fx..begin();
    final pool = g.balls;
    final profile = g.profile;
    final a = g.renderAlpha;
    final n = pool.count;
    final flying = pool.flyingCount;

    // Rastro (só no Alto, com pouca coisa na tela).
    if (profile.trailLength > 0 &&
        flying <= profile.maxTrailBalls &&
        g.particles.load < 0.75) {
      final len = min(profile.trailLength, BallPool.trailCapacity);
      for (var i = 0; i < n; i++) {
        if (pool.state[i] != BallPool.flying) continue;
        final color = _ball[pool.element[i]];
        final count = min(len, pool.trailCount[i]);
        for (var k = 0; k < count; k++) {
          final idx = pool.trailIndex(i, k);
          final f = 1 - (k + 1) / (len + 1);
          batch.addCentered(Spr.ball, pool.trailX[idx], pool.trailY[idx],
              0.45 + 0.4 * f, _fade(color, 0.3 * f));
        }
      }
    }

    // Posição e cor de cada bola visível, uma vez.
    _ensureScratch(n + 2);
    var m = 0;
    for (var i = 0; i < n; i++) {
      final s = pool.state[i];
      final el = pool.element[i];
      if (s == BallPool.flying) {
        _bx[m] = pool.px[i] + (pool.x[i] - pool.px[i]) * a;
        _by[m] = pool.py[i] + (pool.y[i] - pool.py[i]) * a;
        _bcol[m] = _ball[el];
      } else if (s == BallPool.returning) {
        _bx[m] = pool.x[i];
        _by[m] = pool.y[i];
        _bcol[m] = _fade(_ball[el], 0.4 + 0.6 * (1 - pool.t[i]));
      } else {
        continue; // no chão: vira um marcador só, abaixo
      }
      _bel[m++] = el;
    }
    final landX = g.firstLandX;
    if (g.phase == GamePhase.shooting && landX != null && g.landed > 0) {
      _bx[m] = landX;
      _by[m] = g.floorY;
      _bel[m] = g.lastLandedElement;
      _bcol[m++] = _ball[g.lastLandedElement];
    }
    if (g.phase == GamePhase.aim) {
      final el = g.gameState.ballElement.index;
      _bx[m] = g.originX;
      _by[m] = g.floorY;
      _bel[m] = el;
      _bcol[m++] = _ball[el];
    }

    final prism = g.gameState.activeSkin == BallSkin.prism;
    if (profile.glow && flying <= _maxGlowBalls) {
      for (var i = 0; i < m; i++) {
        if (prism) {
          batch.addCentered(Spr.ballGlow, _bx[i], _by[i], 0.95, 0x66FFD27A);
        } else if (_bel[i] != 0) {
          batch.addCentered(Spr.ballGlow, _bx[i], _by[i], 0.85,
              _withAlpha(_ball[_bel[i]], 0.35));
        }
      }
    }
    for (var i = 0; i < m; i++) {
      batch.addCentered(Spr.ball, _bx[i], _by[i], 1, _bcol[i]);
    }
    if (prism) {
      final angle = g.animTime * 4;
      for (var i = 0; i < m; i++) {
        batch.addRotated(Spr.prismRing, _bx[i], _by[i], 1, angle);
      }
    }

    final p = g.particles;
    for (var i = 0; i < p.count; i++) {
      batch.addCentered(Spr.particle, p.x[i], p.y[i], p.radius[i] / 3,
          _fade(p.color[i] & 0xFFFFFFFF, p.life[i] / p.maxLife[i]));
    }

    if (g.phase == GamePhase.aim) {
      const size = 11.0;
      const k = size / SpriteAtlas.glyphFontSize;
      final top = g.floorY + BallzFlameGame.ballRadius + 5;
      _number(batch, g.gameState.ballCount, g.originX,
          top + atlas.glyphHeight * k / 2, size, 0xCCFFFFFF,
          prefix: Spr.glyphX);
    }
  }
}

/// Troca o alfa (como `Color.withOpacity`).
int _withAlpha(int argb, double alpha) =>
    ((alpha * 255).round().clamp(0, 255) << 24) | (argb & 0xFFFFFF);

/// Multiplica o alfa atual por [f].
int _fade(int argb, double f) =>
    ((((argb >> 24) & 0xFF) * f).round().clamp(0, 255) << 24) |
    (argb & 0xFFFFFF);

/// Interpolação por canal (como `Color.lerp`).
int _lerp(int a, int b, double t) {
  final aa = (a >> 24) & 0xFF, ar = (a >> 16) & 0xFF;
  final ag = (a >> 8) & 0xFF, ab = a & 0xFF;
  final ba = (b >> 24) & 0xFF, br = (b >> 16) & 0xFF;
  final bg = (b >> 8) & 0xFF, bb = b & 0xFF;
  final na = (aa + (ba - aa) * t).round() & 0xFF;
  final nr = (ar + (br - ar) * t).round() & 0xFF;
  final ng = (ag + (bg - ag) * t).round() & 0xFF;
  final nb = (ab + (bb - ab) * t).round() & 0xFF;
  return (na << 24) | (nr << 16) | (ng << 8) | nb;
}
