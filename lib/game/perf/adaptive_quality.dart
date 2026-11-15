/// Mede o FPS no começo da partida para o ajuste automático de qualidade.
///
/// Conta só frames de jogada (quem chama decide), descarta o aquecimento e
/// ignora pausas longas (anúncio, app em segundo plano, GC raro). Quando a
/// janela fecha, [addFrame] devolve true se o FPS médio ficou abaixo do
/// mínimo.
class AdaptiveQuality {
  AdaptiveQuality({this.warmup = 0.5, this.window = 3.0});

  /// Segundos descartados no início (cache de shaders, primeiro layout).
  final double warmup;

  /// Segundos de frames medidos.
  final double window;

  /// Frames mais longos que isto são pausas, não lentidão do jogo.
  static const double maxFrameDt = 0.25;

  double _skipped = 0;
  double _time = 0;
  int _frames = 0;
  bool _done = false;

  /// FPS médio da última janela fechada.
  double? lastFps;

  bool get done => _done;

  void restart() {
    _skipped = 0;
    _time = 0;
    _frames = 0;
    _done = false;
  }

  void finish() => _done = true;

  bool addFrame(double dt, double minFps) {
    if (_done || dt <= 0 || dt > maxFrameDt) return false;
    if (_skipped < warmup) {
      _skipped += dt;
      return false;
    }
    _time += dt;
    _frames++;
    if (_time < window) return false;
    final fps = _frames / _time;
    lastFps = fps;
    _done = true;
    return fps < minFps;
  }
}
