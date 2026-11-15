import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import '../../models/element.dart';

/// Ids dos sprites do atlas.
abstract final class Spr {
  static const blockFill = 0;
  static const blockBorder = 1;
  static const blockBorderGold = 2;
  static const wallFill = 3;
  static const wallHatch = 4;
  static const wallBorder = 5;
  static const wallStripe = 6;
  static const dot = 7;
  static const dotRing = 8;
  static const bossFill = 9;
  static const bossBorder = 10;
  static const bossGlow = 11;
  static const hpBar = 12;
  static const bonus = 13;
  static const triple = 14;

  /// Grupos por elemento: +0 fogo, +1 água, +2 vento, +3 raio, +4 terra.
  static const special = 15;
  static const iconSmall = 20;
  static const iconLarge = 25;

  static const bossLabel = 30;
  static const ball = 31;
  static const ballGlow = 32;
  static const prismRing = 33;
  static const particle = 34;

  /// Selos de status, um por forma: chamas, ácido, congelado, amolecido, preso.
  static const statusBurn = 35;
  static const statusAcid = 36;
  static const statusFrozen = 37;
  static const statusSoftened = 38;
  static const statusStuck = 39;

  /// Power-ups: fundo comum + ícone por tipo (ordem de [PowerUpKind]).
  static const powerup = 40;
  static const powerupIcon = 41; // 8 ícones: 41–48
  static const bomb = 49;

  /// '0'..'9' = glyph0..glyph0 + 9.
  static const glyph0 = 50;
  static const glyphPlus = 60;
  static const glyphX = 61;
  static const glyphDown = 62;

  /// Chama (gota afilada, branca) da linha de fogo.
  static const fireFlame = 63;

  /// Lâmina de vento (lua crescente, branca) da Rajada.
  static const windBlade = 64;

  /// Trecho de raio (barra arredondada branca) da Descarga.
  static const boltSeg = 65;
  static const count = 66;

  /// Posição do elemento nos grupos por elemento; -1 para neutro.
  static int elementOffset(ElementType e) => e.index - 1;
}

class _Def {
  _Def(this.w, this.h, this.draw, {this.res = 1});

  /// Tamanho lógico (px de tela).
  final double w, h;

  /// Fração da resolução do atlas. Brilhos usam metade: já são suaves.
  final double res;
  final void Function(Canvas c) draw;
}

/// Atlas gerado em tempo de execução com todos os sprites do jogo.
///
/// Os visuais são os mesmos que antes eram desenhados com primitivas a cada
/// frame, agora rasterizados uma única vez na resolução do aparelho. Formas
/// que mudam de cor (fundo e borda dos blocos, dígitos, bolas) são brancas e
/// recebem a cor no desenho em lote ([BlendMode.modulate]). Números de HP são
/// uma bitmap font: nenhum layout de texto durante o jogo.
class SpriteAtlas {
  SpriteAtlas._(this.image, this.rects, this.scales, this.glyphAdvance,
      this.glyphHeight, this.pixelRatio);

  static const double glyphFontSize = 13;
  static const String _glyphChars = '0123456789+x▼';

  final ui.Image image;

  /// 4 valores por sprite (left, top, right, bottom), em px do atlas.
  final Float32List rects;

  /// Px do atlas por px lógico, por sprite.
  final Float32List scales;

  /// Avanço lógico de cada glifo a [glyphFontSize].
  final Float32List glyphAdvance;

  /// Altura da linha dos dígitos a [glyphFontSize].
  final double glyphHeight;
  final double pixelRatio;

  static SpriteAtlas? _shared;

  /// Atlas compartilhado entre partidas: é imutável e ocupa ~1–2 MB de GPU.
  static SpriteAtlas shared(double pixelRatio) {
    final ratio = pixelRatio.clamp(1.0, 3.0);
    final cached = _shared;
    if (cached != null && cached.pixelRatio == ratio) return cached;
    return _shared = build(ratio);
  }

  static SpriteAtlas build(double pixelRatio) {
    final defs = List<_Def?>.filled(Spr.count, null);
    final painters = <TextPainter>[];
    TextPainter text(String s, double size) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: size,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painters.add(tp);
      return tp;
    }

    void centered(Canvas c, TextPainter tp, double cx, double cy) =>
        tp.paint(c, Offset(cx - tp.width / 2, cy - tp.height / 2));

    const white = Color(0xFFFFFFFF);
    final fill = Paint()..color = white;
    Paint stroke(double width, [Color color = white]) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    RRect inset(double w, double h, double radius) => RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, w - 4, h - 4), Radius.circular(radius));

    const b = 38.0; // bloco
    const bb = 76.0; // boss
    final cell = inset(b, b, 6);
    final wallCell = inset(b, b, 4);

    defs[Spr.blockFill] = _Def(b, b, (c) => c.drawRRect(cell, fill));
    defs[Spr.blockBorder] = _Def(b, b, (c) => c.drawRRect(cell, stroke(1.5)));
    defs[Spr.blockBorderGold] =
        _Def(b, b, (c) => c.drawRRect(cell, stroke(2.5)));
    defs[Spr.wallFill] = _Def(b, b, (c) => c.drawRRect(wallCell, fill));
    defs[Spr.wallHatch] = _Def(b, b, (c) {
      c.save();
      c.clipRRect(wallCell);
      final p = stroke(1.5);
      for (double s = -b; s < b + b; s += 7) {
        c.drawLine(Offset(s + 2, 2), Offset(s + b - 2, b - 2), p);
      }
      c.restore();
    });
    defs[Spr.wallBorder] = _Def(b, b, (c) => c.drawRRect(wallCell, stroke(2)));
    defs[Spr.wallStripe] = _Def(28, 3,
        (c) => c.drawLine(const Offset(0, 1.5), const Offset(28, 1.5), stroke(2.5)));
    defs[Spr.dot] =
        _Def(6, 6, (c) => c.drawCircle(const Offset(3, 3), 2.5, fill));
    defs[Spr.dotRing] =
        _Def(6, 6, (c) => c.drawCircle(const Offset(3, 3), 2.5, stroke(0.8)));
    final bossCell = inset(bb, bb, 6);
    defs[Spr.bossFill] = _Def(bb, bb, (c) => c.drawRRect(bossCell, fill));
    defs[Spr.bossBorder] = _Def(bb, bb, (c) => c.drawRRect(bossCell, stroke(3)));
    defs[Spr.bossGlow] = _Def(
        84,
        84,
        (c) => c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(0, 0, 84, 84), const Radius.circular(12)),
            fill),
        res: 0.5);
    defs[Spr.hpBar] =
        _Def(60, 5, (c) => c.drawRect(const Rect.fromLTWH(0, 0, 60, 5), fill));

    final plusOne = text('+1', 11);
    defs[Spr.bonus] = _Def(b, b, (c) {
      c.drawRRect(cell, Paint()..color = const Color(0xFF534AB7));
      c.drawRRect(cell, stroke(1.5, const Color(0xFF7F77DD)));
      centered(c, plusOne, b / 2, b / 2);
    });
    defs[Spr.triple] = _Def(b, b, (c) {
      c.drawRRect(cell, Paint()..color = const Color(0xFF1a1a2e));
      c.drawRRect(cell, stroke(1.5));
      c.drawCircle(const Offset(b / 2 - 6, b / 2), 3, fill);
      c.drawCircle(const Offset(b / 2, b / 2 - 7), 3, fill);
      c.drawCircle(const Offset(b / 2 + 6, b / 2), 3, fill);
    });

    const elemental = kCombatElements;
    for (var i = 0; i < elemental.length; i++) {
      final data = elementDataMap[elemental[i]]!;
      final big = text(data.icon, 13);
      defs[Spr.special + i] = _Def(b, b, (c) {
        // Bloco especial (atravessável): fundo escuro translúcido e borda
        // dupla na cor do elemento, para não parecer sólido.
        c.drawRRect(cell, Paint()..color = const Color(0xCC14141f));
        c.drawRRect(cell, stroke(1.5, data.blockBorder));
        c.drawRRect(inset(b - 6, b - 6, 4).shift(const Offset(3, 3)),
            stroke(1, data.ballColor.withValues(alpha: 0.7)));
        centered(c, big, b / 2, b / 2 - 3);
      });
      final small = text(data.icon, 10);
      defs[Spr.iconSmall + i] =
          _Def(small.width, small.height, (c) => small.paint(c, Offset.zero));
      final large = text(data.icon, 20);
      defs[Spr.iconLarge + i] =
          _Def(large.width, large.height, (c) => large.paint(c, Offset.zero));
    }

    final boss = text('BOSS', 8);
    defs[Spr.bossLabel] =
        _Def(boss.width, boss.height, (c) => boss.paint(c, Offset.zero));

    defs[Spr.ball] =
        _Def(12, 12, (c) => c.drawCircle(const Offset(6, 6), 5, fill));
    defs[Spr.ballGlow] = _Def(
        20,
        20,
        (c) => c.drawCircle(
            const Offset(10, 10),
            10,
            Paint()
              ..shader = ui.Gradient.radial(const Offset(10, 10), 10, const [
                Color(0xFFFFFFFF),
                Color(0x59FFFFFF),
                Color(0x00FFFFFF),
              ], const [
                0,
                0.45,
                1,
              ])),
        res: 0.5);
    defs[Spr.prismRing] = _Def(16, 16, (c) {
      const center = Offset(8, 8);
      c.drawCircle(
          center,
          6,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..shader = const SweepGradient(colors: [
              Color(0xFFFF5E5E),
              Color(0xFFFFD25E),
              Color(0xFF7CFF5E),
              Color(0xFF5EE1FF),
              Color(0xFFB45EFF),
              Color(0xFFFF5E5E),
            ]).createShader(Rect.fromCircle(center: center, radius: 6)));
    });
    defs[Spr.particle] = _Def(
        6,
        6,
        (c) => c.drawCircle(
            const Offset(3, 3),
            3,
            Paint()
              ..shader = ui.Gradient.radial(const Offset(3, 3), 3, const [
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ])));
    // Power-ups: célula comum (fundo petróleo, borda clara tracejada) e um
    // ícone por tipo, na ordem de PowerUpKind.
    defs[Spr.powerup] = _Def(b, b, (c) {
      c.drawRRect(cell, Paint()..color = const Color(0xFF18283a));
      c.drawRRect(cell, stroke(1.5, const Color(0xFF9BD1FF)));
    });
    const powerupIcons = ['»', '◎', '∞', '●', '▄', '+', '2x', 'U'];
    for (var k = 0; k < powerupIcons.length; k++) {
      final tp = text(powerupIcons[k], 13);
      defs[Spr.powerupIcon + k] =
          _Def(tp.width, tp.height, (c) => tp.paint(c, Offset.zero));
    }
    final bombTp = text('💣', 13);
    defs[Spr.bomb] = _Def(b, b, (c) {
      c.drawRRect(cell, Paint()..color = const Color(0xFF3a1414));
      c.drawRRect(cell, stroke(1.5, const Color(0xFFFF7043)));
      centered(c, bombTp, b / 2, b / 2 - 4);
    });

    // Chama da linha de fogo: gota afilada 14×18, branca (cor vem do lote).
    defs[Spr.fireFlame] = _Def(14, 18, (c) {
      final flame = Path()
        ..moveTo(7, 0)
        ..cubicTo(8, 5, 13, 8, 13, 13)
        ..cubicTo(13, 16.5, 10.3, 18, 7, 18)
        ..cubicTo(3.7, 18, 1, 16.5, 1, 13)
        ..cubicTo(1, 9, 4.5, 8, 5.5, 3.5)
        ..cubicTo(5.9, 2, 6.4, 1, 7, 0)
        ..close();
      c.drawPath(flame, fill);
    });

    // Lâmina de vento: lua crescente 24×24, branca (cor vem do lote).
    defs[Spr.windBlade] = _Def(24, 24, (c) {
      final outer = Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 11));
      final cut = Path()
        ..addOval(Rect.fromCircle(center: const Offset(16, 9), radius: 9.5));
      c.drawPath(Path.combine(PathOperation.difference, outer, cut), fill);
    });

    // Trecho de raio: barra 28×8 de pontas redondas, branca.
    defs[Spr.boltSeg] = _Def(
        28,
        8,
        (c) => c.drawLine(const Offset(4, 4), const Offset(24, 4),
            stroke(7)..strokeCap = StrokeCap.round));

    // Selos de status (7×7, brancos: a cor vem do lote). Formas distintas
    // para dar para diferenciar mesmo com daltonismo.
    final badgeOutline = stroke(1, const Color(0x99000000));
    defs[Spr.statusBurn] = _Def(7, 7, (c) {
      final flame = Path()
        ..moveTo(3.5, 0.5)
        ..lineTo(6.5, 6.5)
        ..lineTo(0.5, 6.5)
        ..close();
      c.drawPath(flame, fill);
      c.drawPath(flame, badgeOutline);
    });
    defs[Spr.statusAcid] = _Def(7, 7, (c) {
      c.drawCircle(const Offset(3.5, 3.5), 3, fill);
      c.drawCircle(const Offset(3.5, 3.5), 3, badgeOutline);
    });
    defs[Spr.statusFrozen] = _Def(7, 7, (c) {
      final diamond = Path()
        ..moveTo(3.5, 0.2)
        ..lineTo(6.8, 3.5)
        ..lineTo(3.5, 6.8)
        ..lineTo(0.2, 3.5)
        ..close();
      c.drawPath(diamond, fill);
      c.drawPath(diamond, badgeOutline);
    });
    defs[Spr.statusSoftened] = _Def(7, 7, (c) {
      final wave = stroke(1.6);
      c.drawLine(const Offset(0.5, 2), const Offset(6.5, 2), wave);
      c.drawLine(const Offset(0.5, 5), const Offset(6.5, 5), wave);
    });
    defs[Spr.statusStuck] = _Def(7, 7, (c) {
      c.drawRect(const Rect.fromLTWH(0.8, 0.8, 5.4, 5.4), fill);
      c.drawRect(const Rect.fromLTWH(0.8, 0.8, 5.4, 5.4), badgeOutline);
    });

    final advance = Float32List(_glyphChars.length);
    var glyphHeight = 0.0;
    for (var g = 0; g < _glyphChars.length; g++) {
      final tp = text(_glyphChars[g], glyphFontSize);
      advance[g] = tp.width;
      if (g < 10) glyphHeight = max(glyphHeight, tp.height);
      defs[Spr.glyph0 + g] =
          _Def(tp.width, tp.height, (c) => tp.paint(c, Offset.zero));
    }

    // Empacotamento em prateleiras, maiores primeiro, com 2 px de folga
    // para o filtro bilinear não puxar o vizinho.
    const pad = 2;
    const width = 1024;
    final order = List<int>.generate(Spr.count, (i) => i);
    int devH(int id) => (defs[id]!.h * pixelRatio * defs[id]!.res).ceil();
    order.sort((a, b) => devH(b).compareTo(devH(a)));
    final rects = Float32List(Spr.count * 4);
    final scales = Float32List(Spr.count);
    final slots = Int32List(Spr.count * 2);
    var x = pad, y = pad, rowH = 0;
    for (final id in order) {
      final d = defs[id]!;
      final f = pixelRatio * d.res;
      final pw = (d.w * f).ceil(), ph = (d.h * f).ceil();
      if (x + pw + pad > width) {
        x = pad;
        y += rowH + pad;
        rowH = 0;
      }
      slots[id * 2] = x;
      slots[id * 2 + 1] = y;
      rects[id * 4] = x.toDouble();
      rects[id * 4 + 1] = y.toDouble();
      rects[id * 4 + 2] = x + d.w * f;
      rects[id * 4 + 3] = y + d.h * f;
      scales[id] = f;
      x += pw + pad;
      if (ph > rowH) rowH = ph;
    }
    final height = y + rowH + pad;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var id = 0; id < Spr.count; id++) {
      canvas
        ..save()
        ..translate(slots[id * 2].toDouble(), slots[id * 2 + 1].toDouble())
        ..scale(scales[id]);
      defs[id]!.draw(canvas);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    picture.dispose();
    for (final tp in painters) {
      tp.dispose();
    }
    return SpriteAtlas._(
        image, rects, scales, advance, glyphHeight, pixelRatio);
  }
}
