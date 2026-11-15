import 'dart:typed_data';
import 'combo_defs.dart';

/// Zonas persistentes no tabuleiro (magma, pântano, campo elétrico, raios,
/// tornado de fogo), em estrutura de arrays com capacidade fixa: nada é
/// alocado durante o jogo.
///
/// A lógica por turno (dano, mover tornado) fica no jogo, que tem acesso aos
/// blocos; aqui ficam os dados e as consultas baratas feitas no caminho
/// quente (ex.: [ballDamageMultAt], chamada a cada acerto quando há zonas).
class ZoneSystem {
  static const int capacity = 8;

  /// ZoneKind.index + 1; 0 = slot livre (slots são compactados).
  final Uint8List kind = Uint8List(capacity);
  final Float32List x = Float32List(capacity);
  final Float32List y = Float32List(capacity);
  final Float32List halfW = Float32List(capacity);
  final Float32List halfH = Float32List(capacity);
  final Uint8List turns = Uint8List(capacity);
  final Uint8List level = Uint8List(capacity);

  /// Dano por turno da zona (já em HP, calculado no disparo).
  final Int32List dmg = Int32List(capacity);

  /// Raios por turno (bolts) ou outras contagens.
  final Uint8List size = Uint8List(capacity);

  int count = 0;

  /// Multiplicador de dano do campo eletrificado (spec: +50%).
  static const double electricMult = 1.5;

  void add(ZoneKind k, double cx, double cy, double hw, double hh,
      {required int durTurns, required int lvl, int damage = 0, int n = 0}) {
    var i = count;
    if (i == capacity) {
      // Cheio: recicla o slot com menos turnos restantes.
      i = 0;
      for (var j = 1; j < capacity; j++) {
        if (turns[j] < turns[i]) i = j;
      }
    } else {
      count++;
    }
    kind[i] = k.index + 1;
    x[i] = cx;
    y[i] = cy;
    halfW[i] = hw;
    halfH[i] = hh;
    turns[i] = durTurns.clamp(1, 250);
    level[i] = lvl.clamp(1, 250);
    dmg[i] = damage;
    size[i] = n;
  }

  bool contains(int i, double px, double py) =>
      (px - x[i]).abs() <= halfW[i] && (py - y[i]).abs() <= halfH[i];

  /// Multiplicador de dano para uma bola em ([px], [py]): campo eletrificado.
  double ballDamageMultAt(double px, double py) {
    for (var i = 0; i < count; i++) {
      if (kind[i] == ZoneKind.electric.index + 1 && contains(i, px, py)) {
        return electricMult;
      }
    }
    return 1.0;
  }

  /// Desconta 1 turno de todas e remove as que zeraram (troca com a última).
  void tickTurns() {
    var i = 0;
    while (i < count) {
      if (--turns[i] == 0) {
        final last = --count;
        kind[i] = kind[last];
        x[i] = x[last];
        y[i] = y[last];
        halfW[i] = halfW[last];
        halfH[i] = halfH[last];
        turns[i] = turns[last];
        level[i] = level[last];
        dmg[i] = dmg[last];
        size[i] = size[last];
        continue;
      }
      i++;
    }
  }

  void clear() => count = 0;
}
