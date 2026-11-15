import 'dart:typed_data';

/// Bolas da rodada em estrutura de arrays: nenhum objeto por bola e nada
/// alocado durante a rodada (a capacidade só cresce se faltar espaço, o que
/// não acontece com os limites de [PerfConfig]). Os índices valem até [clear].
class BallPool {
  BallPool([int capacity = 256]) {
    _allocate(capacity);
  }

  static const int free = 0;
  static const int flying = 1;
  static const int landed = 2;
  static const int returning = 3;

  /// Posições guardadas por bola para o rastro (anel).
  static const int trailCapacity = 4;

  int count = 0;
  int flyingCount = 0;
  int _capacity = 0;
  int get capacity => _capacity;

  late Float64List x, y, vx, vy;

  /// Posição no passo anterior, para interpolar o desenho entre passos fixos.
  late Float64List px, py;

  /// Segundos desde o último bloco quebrável atingido (anti-loop).
  late Float64List idle;

  /// Curva de retorno (Bézier quadrática): início, controle e progresso.
  late Float64List sx, sy, cx, cy, t;

  late Uint8List state, element, trailCount, trailHead;

  /// Quantas bolas este objeto representa (agrupamento acima do limite).
  late Int32List weight;

  late Float32List trailX, trailY;

  void _allocate(int capacity) {
    final old = _capacity > 0;
    final n = count;
    Float64List f64(Float64List? src) {
      final l = Float64List(capacity);
      if (src != null) l.setRange(0, n, src);
      return l;
    }

    Uint8List u8(Uint8List? src) {
      final l = Uint8List(capacity);
      if (src != null) l.setRange(0, n, src);
      return l;
    }

    x = f64(old ? x : null);
    y = f64(old ? y : null);
    vx = f64(old ? vx : null);
    vy = f64(old ? vy : null);
    px = f64(old ? px : null);
    py = f64(old ? py : null);
    idle = f64(old ? idle : null);
    sx = f64(old ? sx : null);
    sy = f64(old ? sy : null);
    cx = f64(old ? cx : null);
    cy = f64(old ? cy : null);
    t = f64(old ? t : null);
    state = u8(old ? state : null);
    element = u8(old ? element : null);
    trailCount = u8(old ? trailCount : null);
    trailHead = u8(old ? trailHead : null);
    final w = Int32List(capacity);
    if (old) w.setRange(0, n, weight);
    weight = w;
    final tx = Float32List(capacity * trailCapacity);
    final ty = Float32List(capacity * trailCapacity);
    if (old) {
      tx.setRange(0, n * trailCapacity, trailX);
      ty.setRange(0, n * trailCapacity, trailY);
    }
    trailX = tx;
    trailY = ty;
    _capacity = capacity;
  }

  int spawn(double x0, double y0, double vx0, double vy0, int el, int w) {
    if (count == _capacity) _allocate(_capacity * 2);
    final i = count++;
    x[i] = x0;
    y[i] = y0;
    px[i] = x0;
    py[i] = y0;
    vx[i] = vx0;
    vy[i] = vy0;
    idle[i] = 0;
    state[i] = flying;
    element[i] = el;
    weight[i] = w;
    trailCount[i] = 0;
    trailHead[i] = 0;
    flyingCount++;
    return i;
  }

  void land(int i, double atX, double atY) {
    if (state[i] == flying) flyingCount--;
    state[i] = landed;
    x[i] = px[i] = atX;
    y[i] = py[i] = atY;
    trailCount[i] = 0;
  }

  void beginReturn(int i, double endX, double endY, double controlY) {
    if (state[i] == flying) flyingCount--;
    state[i] = returning;
    sx[i] = x[i];
    sy[i] = y[i];
    cx[i] = (x[i] + endX) / 2;
    cy[i] = controlY;
    t[i] = 0;
    trailCount[i] = 0;
  }

  void setAllElements(int el) {
    for (var i = 0; i < count; i++) {
      element[i] = el;
    }
  }

  void pushTrail(int i) {
    final base = i * trailCapacity;
    final h = trailHead[i];
    trailX[base + h] = x[i];
    trailY[base + h] = y[i];
    trailHead[i] = (h + 1) % trailCapacity;
    if (trailCount[i] < trailCapacity) trailCount[i]++;
  }

  /// Índice no anel da k-ésima posição mais recente do rastro (k = 0 é a última).
  int trailIndex(int i, int k) {
    final h = trailHead[i] - 1 - k;
    return i * trailCapacity + (h < 0 ? h + trailCapacity : h);
  }

  void clear() {
    count = 0;
    flyingCount = 0;
  }
}

/// Fila de tiros em anel: tirar da frente e inserir na frente (bola bônus)
/// são O(1) e não alocam.
class ShotQueue {
  ShotQueue([int capacity = 256]) {
    _allocate(capacity);
  }

  late Float64List _dx, _dy;
  late Uint8List _el;
  late Int32List _w;
  int _head = 0;
  int _capacity = 0;
  int length = 0;

  // Saída de [popFront], em campos para não alocar uma tupla por tiro.
  double outDx = 0, outDy = 0;
  int outEl = 0, outWeight = 1;

  void _allocate(int capacity) {
    final dx = Float64List(capacity), dy = Float64List(capacity);
    final el = Uint8List(capacity);
    final w = Int32List(capacity);
    for (var k = 0; k < length; k++) {
      final j = (_head + k) % _capacity;
      dx[k] = _dx[j];
      dy[k] = _dy[j];
      el[k] = _el[j];
      w[k] = _w[j];
    }
    _dx = dx;
    _dy = dy;
    _el = el;
    _w = w;
    _head = 0;
    _capacity = capacity;
  }

  void pushBack(double dx, double dy, int el, int weight) {
    if (length == _capacity) _allocate(_capacity * 2);
    final j = (_head + length) % _capacity;
    _dx[j] = dx;
    _dy[j] = dy;
    _el[j] = el;
    _w[j] = weight;
    length++;
  }

  void pushFront(double dx, double dy, int el, int weight) {
    if (length == _capacity) _allocate(_capacity * 2);
    _head = (_head - 1 + _capacity) % _capacity;
    _dx[_head] = dx;
    _dy[_head] = dy;
    _el[_head] = el;
    _w[_head] = weight;
    length++;
  }

  bool popFront() {
    if (length == 0) return false;
    outDx = _dx[_head];
    outDy = _dy[_head];
    outEl = _el[_head];
    outWeight = _w[_head];
    _head = (_head + 1) % _capacity;
    length--;
    return true;
  }

  void setAllElements(int el) {
    for (var k = 0; k < length; k++) {
      _el[(_head + k) % _capacity] = el;
    }
  }

  /// Soma dos pesos na fila (quantas bolas ainda vão sair).
  int get totalWeight {
    var sum = 0;
    for (var k = 0; k < length; k++) {
      sum += _w[(_head + k) % _capacity];
    }
    return sum;
  }

  void clear() {
    _head = 0;
    length = 0;
  }
}
