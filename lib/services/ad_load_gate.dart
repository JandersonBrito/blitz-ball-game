import 'dart:async';
import 'dart:math';

/// Decide quando carregar um anúncio.
///
/// Carregar (rede, disco, WebView do SDK) pesa em aparelho fraco, então nunca
/// acontece durante a jogada: o pedido espera a rodada acabar. Se o
/// carregamento falhar, tenta de novo com espera crescente (30 s, 60 s, 120 s,
/// até 5 min), também fora da jogada. Assim o anúncio já está pronto quando o
/// jogo precisar mostrar.
class AdLoadGate {
  AdLoadGate(this._load, {required bool Function() isBlocked})
      : _isBlocked = isBlocked;

  final void Function() _load;
  final bool Function() _isBlocked;

  bool _pending = false;
  int _failures = 0;
  Timer? _retry;

  bool get pending => _pending;
  int get failures => _failures;

  static Duration backoff(int failures) =>
      Duration(seconds: min(300, 30 * (1 << (failures - 1).clamp(0, 4))));

  /// Pede um carregamento: agora, ou quando a jogada acabar.
  void request() {
    _retry?.cancel();
    _retry = null;
    if (_isBlocked()) {
      _pending = true;
      return;
    }
    _pending = false;
    _load();
  }

  /// A jogada acabou: faz o que ficou esperando.
  void flush() {
    if (_pending) request();
  }

  void loaded() => _failures = 0;

  void failed() {
    _failures++;
    _retry?.cancel();
    _retry = Timer(backoff(_failures), request);
  }

  void cancel() {
    _retry?.cancel();
    _retry = null;
    _pending = false;
  }
}
