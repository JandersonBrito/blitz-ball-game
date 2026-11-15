import 'dart:math';
import 'dart:typed_data';

/// Partículas de efeito (quebra de bloco), num pool fixo em estrutura de
/// arrays: nada é alocado durante o jogo.
///
/// [limit] vem do nível de qualidade e vale para o jogo todo. Com muita coisa
/// acontecendo, cada estouro fica menor e, no limite, deixa de soltar
/// partículas. O dano já foi aplicado antes do efeito: o corte só muda o
/// visual.
class ParticlePool {
  ParticlePool(this.capacity)
      : x = Float32List(capacity),
        y = Float32List(capacity),
        vx = Float32List(capacity),
        vy = Float32List(capacity),
        life = Float32List(capacity),
        maxLife = Float32List(capacity),
        radius = Float32List(capacity),
        color = Int32List(capacity);

  final int capacity;
  final Float32List x, y, vx, vy, life, maxLife, radius;

  /// ARGB, guardado em 32 bits.
  final Int32List color;
  final Random _rng = Random();

  int count = 0;
  int _limit = 0;

  static const double _gravity = 260;

  int get limit => _limit;
  set limit(int value) => _limit = value.clamp(0, capacity);

  /// Ocupação do limite (0 a 1): a partir de 0,5 os estouros encolhem.
  double get load => _limit == 0 ? 1 : count / _limit;

  /// Quantas partículas um estouro de [wanted] pode soltar agora.
  int budget(int wanted) {
    if (_limit == 0 || wanted <= 0) return 0;
    final l = load;
    var n = wanted;
    if (l >= 0.75) {
      n = wanted ~/ 4;
    } else if (l >= 0.5) {
      n = wanted ~/ 2;
    }
    final room = _limit - count;
    if (room <= 0) return 0; // limite baixou com partículas ainda vivas
    return n < room ? n : room;
  }

  void burst(double cx, double cy, int argb, int wanted, {double speed = 110}) {
    final n = budget(wanted);
    for (var k = 0; k < n; k++) {
      final i = count++;
      final a = _rng.nextDouble() * 2 * pi;
      final s = speed * (0.4 + _rng.nextDouble() * 0.8);
      x[i] = cx;
      y[i] = cy;
      vx[i] = cos(a) * s;
      vy[i] = sin(a) * s - 40;
      final l = 0.3 + _rng.nextDouble() * 0.25;
      life[i] = l;
      maxLife[i] = l;
      radius[i] = 1.4 + _rng.nextDouble() * 1.6;
      color[i] = argb;
    }
  }

  void update(double dt) {
    var i = 0;
    while (i < count) {
      final l = life[i] - dt;
      if (l <= 0) {
        // Troca com a última: remove em O(1) sem buracos.
        final last = --count;
        x[i] = x[last];
        y[i] = y[last];
        vx[i] = vx[last];
        vy[i] = vy[last];
        life[i] = life[last];
        maxLife[i] = maxLife[last];
        radius[i] = radius[last];
        color[i] = color[last];
        continue;
      }
      life[i] = l;
      vy[i] += _gravity * dt;
      x[i] += vx[i] * dt;
      y[i] += vy[i] * dt;
      i++;
    }
  }

  void clear() => count = 0;
}
