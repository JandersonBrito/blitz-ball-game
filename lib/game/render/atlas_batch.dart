import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'sprite_atlas.dart';

/// Desenho em lote de sprites do atlas: uma chamada `drawRawAtlas` por lote.
///
/// Mesmo papel do `SpriteBatch` do Flame, mas sem alocar por frame: o
/// `SpriteBatch` cria `RSTransform`/`Rect` por item e o `drawAtlas` converte
/// listas em buffers a cada chamada. Aqui os buffers são fixos e o desenho usa
/// views de tamanho potência de 2 criadas uma vez; as sobras viram sprites de
/// área zero, que a GPU descarta.
class AtlasBatch {
  AtlasBatch(this.atlas, [int capacity = 256]) {
    var cap = _minView;
    while (cap < capacity) {
      cap <<= 1;
    }
    _allocate(cap);
  }

  static const int _minView = 64;
  static const int white = 0xFFFFFFFF;

  final SpriteAtlas atlas;
  late Float32List _xf, _src;
  late Int32List _col;
  final List<Float32List> _xfViews = [], _srcViews = [];
  final List<Int32List> _colViews = [];
  int _capacity = 0;
  int _count = 0;

  /// Entradas escritas no frame anterior (as que sobrarem são zeradas).
  int _written = 0;

  int get length => _count;

  void _allocate(int capacity) {
    final xf = Float32List(capacity * 4), src = Float32List(capacity * 4);
    final col = Int32List(capacity);
    if (_capacity > 0) {
      xf.setRange(0, _count * 4, _xf);
      src.setRange(0, _count * 4, _src);
      col.setRange(0, _count, _col);
    }
    _xf = xf;
    _src = src;
    _col = col;
    _capacity = capacity;
    _xfViews.clear();
    _srcViews.clear();
    _colViews.clear();
    for (var n = _minView; n <= capacity; n <<= 1) {
      _xfViews.add(Float32List.sublistView(_xf, 0, n * 4));
      _srcViews.add(Float32List.sublistView(_src, 0, n * 4));
      _colViews.add(Int32List.sublistView(_col, 0, n));
    }
  }

  void begin() => _count = 0;

  int _push(int id, double scos, double ssin, double tx, double ty, int color) {
    if (_count == _capacity) _allocate(_capacity * 2);
    final i = _count * 4, s = id * 4;
    final r = atlas.rects;
    _xf[i] = scos;
    _xf[i + 1] = ssin;
    _xf[i + 2] = tx;
    _xf[i + 3] = ty;
    _src[i] = r[s];
    _src[i + 1] = r[s + 1];
    _src[i + 2] = r[s + 2];
    _src[i + 3] = r[s + 3];
    _col[_count] = color;
    return _count++;
  }

  /// Sprite com o canto superior esquerdo em ([x], [y]).
  void add(int id, double x, double y, [double scale = 1, int color = white]) {
    _push(id, scale / atlas.scales[id], 0, x, y, color);
  }

  /// Sprite centrado em ([cx], [cy]).
  void addCentered(int id, double cx, double cy,
      [double scale = 1, int color = white]) {
    final k = scale / atlas.scales[id];
    final r = atlas.rects, s = id * 4;
    final w = (r[s + 2] - r[s]) * k, h = (r[s + 3] - r[s + 1]) * k;
    _push(id, k, 0, cx - w / 2, cy - h / 2, color);
  }

  /// Sprite centrado em ([cx], [cy]) e girado [angle] radianos.
  void addRotated(int id, double cx, double cy, double scale, double angle,
      [int color = white]) {
    final k = scale / atlas.scales[id];
    final scos = cos(angle) * k, ssin = sin(angle) * k;
    final r = atlas.rects, s = id * 4;
    final u = (r[s + 2] - r[s]) / 2, v = (r[s + 3] - r[s + 1]) / 2;
    _push(id, scos, ssin, cx - (scos * u - ssin * v), cy - (ssin * u + scos * v),
        color);
  }

  /// Só a fração [fraction] da largura do sprite (barras de vida).
  void addPart(int id, double x, double y, double fraction, int color) {
    if (fraction <= 0) return;
    final i = _push(id, 1 / atlas.scales[id], 0, x, y, color) * 4;
    final f = fraction > 1 ? 1.0 : fraction;
    _src[i + 2] = _src[i] + (_src[i + 2] - _src[i]) * f;
  }

  void render(Canvas canvas, Paint paint) {
    final n = _count;
    if (_written > n) {
      _xf.fillRange(n * 4, _written * 4, 0);
      _src.fillRange(n * 4, _written * 4, 0);
      _col.fillRange(n, _written, 0);
    }
    _written = n;
    if (n == 0) return;
    var view = 0;
    for (var size = _minView; size < n; size <<= 1) {
      view++;
    }
    canvas.drawRawAtlas(atlas.image, _xfViews[view], _srcViews[view],
        _colViews[view], BlendMode.modulate, null, paint);
  }
}
