import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/scheduler.dart';

/// Limita o jogo a ~30 FPS pulando vsyncs de verdade.
///
/// O motor do Flame fica pausado (sem ticker) e este pacer só pede um frame a
/// cada ~33 ms. Nos vsyncs pulados nada é montado nem rasterizado: CPU e GPU
/// ficam livres, o que economiza bateria e segura o aquecimento. Funciona em
/// telas de 60, 90 e 120 Hz (pede o frame meio vsync antes do alvo).
class FramePacer {
  FramePacer(this._onFrame);

  /// Recebe o dt real entre frames, em segundos.
  final void Function(double dt) _onFrame;

  static const double targetFps = 30;
  static const int _intervalUs = 1000000 ~/ targetFps;

  final Stopwatch _clock = Stopwatch()..start();
  bool _running = false;
  Duration? _last;
  Timer? _timer;
  int? _callbackId;
  int _halfVsyncUs = 8333;

  bool get running => _running;

  void start() {
    if (_running) return;
    _running = true;
    _last = null;
    final hz = PlatformDispatcher.instance.implicitView?.display.refreshRate;
    _halfVsyncUs = (500000 / (hz != null && hz > 0 ? hz : 60)).round();
    _requestFrame();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    final id = _callbackId;
    if (id != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(id);
      _callbackId = null;
    }
  }

  void _requestFrame() {
    _timer = null;
    if (!_running) return;
    _callbackId = SchedulerBinding.instance.scheduleFrameCallback(_tick);
  }

  void _tick(Duration timestamp) {
    _callbackId = null;
    if (!_running) return;
    final startUs = _clock.elapsedMicroseconds;
    final last = _last;
    _last = timestamp;
    _onFrame(last == null ? 0 : (timestamp - last).inMicroseconds / 1e6);
    if (!_running) return;
    final waitUs = startUs + _intervalUs - _halfVsyncUs - _clock.elapsedMicroseconds;
    if (waitUs <= 0) {
      _requestFrame();
    } else {
      _timer = Timer(Duration(microseconds: waitUs), _requestFrame);
    }
  }
}
