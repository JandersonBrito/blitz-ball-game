import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../../models/ball_skin.dart';
import '../../models/element.dart';
import '../ballz_flame_game.dart';
import '../components/block_component.dart';
import '../config/element_config.dart';
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

  /// Cor de fundo e ícone (sprite de elemento) de cada tipo de zona.
  static const List<int> _zoneColors = [
    0x66FF5722, // magma
    0x5567493B, // pântano
    0x4479B8FF, // campo eletrificado
    0x44CE93D8, // tempestade elétrica
    0x66FF8C42, // tornado de fogo
  ];
  static const List<ElementType> _zoneIcons = [
    ElementType.fire,
    ElementType.earth,
    ElementType.lightning,
    ElementType.lightning,
    ElementType.fire,
  ];

  // ── Blocos ───────────────────────────────────────────────────────────────
  void _emitBlocks(BallzFlameGame g) {
    final batch = _blocks..begin();

    // Zonas persistentes, desenhadas por baixo dos blocos.
    final z = g.zones;
    for (var i = 0; i < z.count; i++) {
      final kindIdx = z.kind[i] - 1;
      final scale = (z.halfW[i] * 2) / BallzFlameGame.blockSize;
      batch.addCentered(
          Spr.blockFill, z.x[i], z.y[i], scale, _zoneColors[kindIdx]);
      batch.addCentered(Spr.iconSmall + Spr.elementOffset(_zoneIcons[kindIdx]),
          z.x[i], z.y[i], 1, _white70);
      // Turnos restantes no canto da zona.
      _number(batch, z.turns[i], z.x[i] + z.halfW[i] - 6,
          z.y[i] - z.halfH[i] + 7, 9, _white70);
    }

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
        case BlockType.special:
          _special(batch, b, x, y);
        case BlockType.powerup:
          batch.add(Spr.powerup, x, y);
          if (b.powerUp != null) {
            batch.addCentered(
                Spr.powerupIcon + b.powerUp!.index,
                x + BallzFlameGame.blockSize / 2,
                y + BallzFlameGame.blockSize / 2,
                1,
                0xFF9BD1FF);
          }
        case BlockType.bomb:
          batch.add(Spr.bomb, x, y);
          _number(batch, b.charges, x + BallzFlameGame.blockSize / 2,
              y + BallzFlameGame.blockSize - 9, 9, 0xFFFF9A76);
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
    batch.add(
        Spr.blockFill, x, y, 1, _withAlpha(_bg[el], 0.45 + 0.55 * b.hpRatio));
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

  /// Bloco especial: sprite do elemento + pips com as cargas restantes.
  void _special(AtlasBatch batch, BlockComponent b, double x, double y) {
    batch.add(Spr.special + Spr.elementOffset(b.element), x, y);
    final n = b.charges;
    if (n <= 0) return;
    const h = BallzFlameGame.blockSize;
    final spacing = min(7.0, (h - 12) / n);
    var dx = (h - spacing * (n - 1)) / 2;
    final color = _ball[b.element.index];
    for (var k = 0; k < n; k++) {
      batch.addCentered(Spr.dot, x + dx, y + h - 8, 0.8, color);
      dx += spacing;
    }
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
      batch.add(
          Spr.bossGlow, x - 4, y - 4, 1, _withAlpha(bg, 0.2 + pulse * 0.15));
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
    _number(
        batch,
        hp,
        x + w / 2,
        y + (elemental ? h / 2 + 16 : h / 2 + 6),
        hp > 9999
            ? 9
            : hp > 999
                ? 11
                : 13,
        _text[el]);
  }

  void _wall(AtlasBatch batch, BlockComponent b, double x, double y) {
    const w = BallzFlameGame.blockSize, h = BallzFlameGame.blockSize;
    final ratio = b.hpRatio;
    batch.add(Spr.wallFill, x, y, 1, _lerp(0xFF0D1220, 0xFF1A2238, ratio));
    final hatchAlpha = (0x25 + 0x10 * ratio).toInt().clamp(0, 255);
    batch.add(Spr.wallHatch, x, y, 1, (hatchAlpha << 24) | 0x406090);
    final elemental = b.element != ElementType.neutral;
    final base = elemental ? _border[b.element.index] : 0xFF4D6A9A;
    batch.add(
        Spr.wallBorder, x, y, 1, _lerp(_withAlpha(base, 0.4), base, ratio));
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
      batch.addCentered(Spr.statusBurn, bx, y + 6, 1, 0xFFFF7A2E);
      bx += 7;
    }
    if (s.acid) {
      batch.addCentered(Spr.statusAcid, bx, y + 6, 1, 0xFF9BE15D);
      bx += 7;
    }
    if (s.frozen) {
      batch.addCentered(Spr.statusFrozen, bx, y + 6, 1, 0xFF8FD8FF);
      bx += 7;
    }
    if (s.softened) {
      batch.addCentered(Spr.statusSoftened, bx, y + 6, 1, 0xFFEAEAEA);
      bx += 7;
    }
    if (s.stuck) batch.addCentered(Spr.statusStuck, bx, y + 6, 1, 0xFFB08A52);
  }

  /// Linha de fogo do especial do Fogo: uma frente horizontal que sobe do
  /// chão ao topo. Núcleo brilhante, chamas tremulando e um rastro de chamas
  /// que esmaece atrás (abaixo) da frente. Só sprites do atlas, sem alocar.
  void _fireWave(AtlasBatch batch, BallzFlameGame g) {
    final y = g.fireWaveY;
    final t = g.animTime;
    final w = g.size.x;
    // Núcleo: faixa clara contínua na frente.
    for (var x = 0.0; x < w; x += 28) {
      batch.add(Spr.wallStripe, x, y - 1.5, 1, 0xFFFFF0B0);
    }
    var k = 0;
    for (var x = 7.0; x < w + 7; x += 14, k++) {
      final flick = sin(t * 18 + k * 1.7);
      final hot = k.isEven ? 0xFFFF7043 : 0xFFFFC107;
      // Chama principal (sobe um pouco acima da frente).
      final s = 1.15 + 0.35 * flick;
      batch.addCentered(Spr.fireFlame, x, y - 6 * s + 4, s, hot);
      // Rastro: chamas menores e mais transparentes atrás da frente.
      final s2 = 0.85 + 0.2 * sin(t * 14 + k);
      batch.addCentered(Spr.fireFlame, x, y + 12, s2, 0xAAFF5A1F);
      batch.addCentered(Spr.fireFlame, x + 3, y + 26, s2 * 0.75, 0x66FF3D00);
    }
  }

  /// Rajada: luas crescentes girando que cruzam a tela, uma por faixa. Cada
  /// lâmina tem um rastro de cópias que esmaecem e riscos de vento atrás.
  /// Só sprites do atlas, sem alocar.
  void _windBlades(AtlasBatch batch, BallzFlameGame g) {
    final t = g.animTime;
    for (var i = 0; i < g.windBladeLanes; i++) {
      final dir = g.windBladeDir[i];
      if (dir == 0) continue;
      final x = g.windBladeX[i], y = g.windBladeY[i];
      final spin = t * 26 * dir + i;
      // Rastro: cópias menores e transparentes, defasadas atrás da lâmina.
      for (var k = 3; k >= 1; k--) {
        batch.addRotated(Spr.windBlade, x - dir * k * 17, y, 1.9 - k * 0.2,
            spin - dir * k * 0.9, (0x99 ~/ k << 24) | 0xB7E27A);
      }
      // Riscos de vento paralelos ao deslocamento.
      batch.addCentered(Spr.wallStripe, x - dir * 34, y - 9, 1.1, 0x99E8F7C8);
      batch.addCentered(Spr.wallStripe, x - dir * 50, y + 10, 0.9, 0x77E8F7C8);
      // Lâmina principal (gira rápido).
      batch.addRotated(Spr.windBlade, x, y, 1.9, spin, 0xFFE8FFC0);
    }
  }

  /// Descarga: raio do céu até o primeiro alvo e daí de bloco em bloco, em
  /// zigue-zague que treme (~24×/s). Três camadas: halo roxo, miolo roxo e
  /// núcleo branco; clarão em cada ponto atingido. Só sprites do atlas.
  void _lightning(AtlasBatch batch, BallzFlameGame g) {
    final a = g.boltAlpha;
    final t = g.animTime;
    final seed = (t * 24).floor();
    final halo = _withAlpha(0xFFB388FF, a * 0.45);
    final body = _withAlpha(0xFFB388FF, a);
    final core = _withAlpha(0xFFFFFFFF, a);
    for (var i = 1; i < g.boltCount; i++) {
      _boltSegment(batch, g.boltX[i - 1], g.boltY[i - 1], g.boltX[i],
          g.boltY[i], i, seed, i == 1 ? 10 : 7, halo, body, core);
      // Clarão no ponto atingido: cresce e some em ~0,3 s.
      final age = t - g.boltBorn[i];
      if (age < 0.3) {
        final f = 1 - age / 0.3;
        batch.addCentered(Spr.ballGlow, g.boltX[i], g.boltY[i], 1.6 + 2.2 * age,
            _withAlpha(0xFFE9D7FF, f * a));
      }
    }
  }

  /// Um trecho do raio de (x0,y0) a (x1,y1): pedaços de ~14 px com desvio
  /// lateral pseudoaleatório (determinístico por [seed], sem alocar).
  void _boltSegment(AtlasBatch batch, double x0, double y0, double x1,
      double y1, int idx, int seed, double amp, int halo, int body, int core) {
    final dx = x1 - x0, dy = y1 - y0;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final n = max(1, (len / 14).ceil());
    final nx = -dy / len, ny = dx / len; // normal ao trecho
    var px = x0, py = y0;
    for (var k = 1; k <= n; k++) {
      var qx = x0 + dx * k / n, qy = y0 + dy * k / n;
      if (k < n) {
        final off = sin(seed * 1.7 + idx * 5.3 + k * 2.9) * amp;
        qx += nx * off;
        qy += ny * off;
      }
      final sx = qx - px, sy = qy - py;
      final sl = sqrt(sx * sx + sy * sy);
      final ang = atan2(sy, sx);
      final k0 = sl / 28;
      final mx = (px + qx) / 2, my = (py + qy) / 2;
      batch.addCentered(Spr.ballGlow, qx, qy, 0.9, halo);
      batch.addRotated(Spr.boltSeg, mx, my, k0 * 1.8, ang, body);
      batch.addRotated(Spr.boltSeg, mx, my, k0 * 1.2, ang, core);
      px = qx;
      py = qy;
    }
  }

  /// Impacto: rocha caindo com rastro e sombra no alvo; ao tocar, onda de
  /// choque circular com poeira, rachaduras radiais e clarão. Só sprites do
  /// atlas, sem alocar.
  void _quake(AtlasBatch batch, BallzFlameGame g) {
    final t = g.quakeT;
    final x = g.quakeX, y = g.quakeY;
    const fall = ElementConfig.earthFall;
    if (t < fall) {
      final p = t / fall;
      // Sombra do alvo, crescendo conforme a rocha se aproxima.
      batch.addCentered(Spr.ballGlow, x, y, 2.5 + 4.5 * p,
          _withAlpha(0xFF3E2723, 0.25 + 0.4 * p));
      const top = BallzFlameGame.topOffset - 40;
      final ry = top + (y - top) * p * p;
      // Rastro de poeira subindo atrás da rocha.
      for (var k = 1; k <= 4; k++) {
        batch.addCentered(Spr.ball, x + sin(k * 2.0 + t * 30) * 5, ry - k * 15,
            3.2 - k * 0.5, _withAlpha(0xFFBCAAA4, 0.5 - k * 0.1));
      }
      // Rocha: casca escura, corpo claro e crateras que giram.
      batch.addCentered(Spr.ball, x, ry, 4.8, 0xFF4E342E);
      batch.addCentered(Spr.ball, x - 1.5, ry - 1.5, 4.0, 0xFF8D6E63);
      for (var k = 0; k < 3; k++) {
        final a = t * 14 + k * 2.1;
        batch.addCentered(
            Spr.ball, x + cos(a) * 9, ry + sin(a) * 9, 1.1, 0xFF5D4037);
      }
      return;
    }
    final p = ((t - fall) / ElementConfig.earthShock).clamp(0.0, 1.0);
    final fade = 1 - p;
    // Alcance visual = a área que realmente leva dano (3×3 blocos + folga).
    final reach =
        (ElementConfig.earthCells / 2 + 0.5) * BlockComponent.blockSize * 1.1;
    final r = (1 - (1 - p) * (1 - p)) * reach;
    // Clarão do choque.
    if (p < 0.35) {
      batch.addCentered(Spr.ballGlow, x, y, 3 + 9 * p,
          _withAlpha(0xFFFFE0B2, (1 - p / 0.35) * 0.9));
    }
    if (r < 4) return;
    // Anel de choque (borda) e anel de poeira (atrás).
    final step = 14 / r;
    var k = 0;
    for (var a = 0.0; a < 2 * pi; a += step, k++) {
      final ca = cos(a), sa = sin(a);
      batch.addCentered(Spr.ball, x + ca * r, y + sa * r, 1.3 * fade + 0.3,
          _withAlpha(0xFF8D6E63, fade));
      if (k.isEven) {
        batch.addCentered(Spr.ball, x + ca * r * 0.72, y + sa * r * 0.72,
            1.0 + 0.5 * fade, _withAlpha(0xFFD7CCC8, fade * 0.7));
      }
    }
    // Rachaduras: 8 raios do centro até a borda do anel.
    for (var j = 0; j < 8; j++) {
      final a = j * pi / 4 + 0.3;
      final ca = cos(a), sa = sin(a);
      for (var d = 0.3; d <= 1.01; d += 0.35) {
        batch.addRotated(Spr.wallStripe, x + ca * r * d, y + sa * r * d,
            0.5 + 0.6 * d, a, _withAlpha(0xFF3E2723, fade));
      }
    }
  }

  /// Maré: anel de água que se expande a partir do ponto de lançamento.
  /// Crista de espuma (segmentos tangentes ao arco) e dois anéis de bolhas que
  /// esmaecem atrás. Só o semicírculo de cima, e só o que está dentro da tela.
  void _tideWave(AtlasBatch batch, BallzFlameGame g) {
    final ox = g.tideOriginX, oy = g.tideOriginY;
    final r = g.tideRadius;
    final t = g.animTime;
    _tideRing(batch, g, ox, oy, r, 22, 0, t); // crista
    if (r > 18) _tideRing(batch, g, ox, oy, r - 16, 18, 1, t); // corpo
    if (r > 40) _tideRing(batch, g, ox, oy, r - 36, 26, 2, t); // cauda
  }

  /// Um anel da Maré (semicírculo de cima de raio [r]), a cada ~[spacing] px,
  /// só nos pontos visíveis. [kind]: 0 crista, 1 corpo, 2 cauda. Sem closures
  /// nem listas: nada é alocado por frame.
  void _tideRing(AtlasBatch batch, BallzFlameGame g, double ox, double oy,
      double r, double spacing, int kind, double t) {
    if (r < 4) return;
    final w = g.size.x;
    const top = BallzFlameGame.topOffset;
    final step = spacing / r;
    var k = 0;
    for (var a = pi; a <= 2 * pi; a += step, k++) {
      final ca = cos(a), sa = sin(a);
      final x = ox + ca * r, y = oy + sa * r;
      if (x < -12 || x > w + 12 || y < top - 12) continue;
      switch (kind) {
        case 0:
          // Espuma: segmento tangente ao arco + gota brilhante balançando.
          batch.addRotated(Spr.wallStripe, x, y, 1.15, a + pi / 2, 0xFFE3F6FF);
          if (k % 3 == 0) {
            batch.addCentered(Spr.ball, x + ca * 3, y + sa * 3 - 2,
                0.55 + 0.25 * sin(t * 12 + k), 0xFFFFFFFF);
          }
        case 1:
          batch.addCentered(
              Spr.ball, x, y, 0.8 + 0.2 * sin(t * 9 + k * 1.3), 0xCC4FC3F7);
        default:
          batch.addCentered(
              Spr.ball, x, y, 0.55 + 0.15 * sin(t * 7 + k), 0x661E88E5);
      }
    }
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
    _aimPaint.color = _aimColors[ElementType.neutral.index];
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
      // Na mira a bola é sempre neutra: elemento só se absorve em voo.
      const el = 0;
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

    if (g.fireWaveY >= 0) _fireWave(batch, g);
    if (g.tideRadius > 0) _tideWave(batch, g);
    if (g.windElapsed >= 0) _windBlades(batch, g);
    if (g.quakeT >= 0) _quake(batch, g);
    if (g.boltClock >= 0) _lightning(batch, g);

    // Portais (par girando), buraco negro e muralha.
    if (g.portalTurns > 0) {
      final ang = g.animTime * 3;
      batch.addRotated(
          Spr.prismRing, g.portalAx, g.portalAy, 1.9, ang, 0xFF9BD1FF);
      batch.addRotated(
          Spr.prismRing, g.portalBx, g.portalBy, 1.9, -ang, 0xFFFFB46B);
    }
    if (g.blackholeActive) {
      batch.addCentered(Spr.ballGlow, g.bhX, g.bhY, 2.2, 0x885B2BA8);
      batch.addCentered(Spr.ball, g.bhX, g.bhY, 1.6, 0xFF14081f);
    }
    if (g.wallCharges > 0) {
      for (var x = 2.0; x < g.size.x - 2; x += 30) {
        batch.add(Spr.wallStripe, x, g.floorY - 6, 1, 0xFF9BD1FF);
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
