import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'settings_service.dart';

/// Vibração curta ao acertar e ao quebrar blocos.
///
/// Usa o pacote `vibration` em vez do HapticFeedback do Flutter porque este
/// depende da opção "vibração ao toque" do sistema, que muitos Android
/// deixam desligada.
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  // Intervalo mínimo entre vibrações: com muitas bolas viraria vibração contínua.
  static const _minIntervalMs = 70;

  SettingsService? _settings;
  bool _hasVibrator = false;
  bool _hasAmplitude = false;
  final Stopwatch _clock = Stopwatch()..start();
  int? _lastMs;

  Future<void> init(SettingsService settings) async {
    _settings = settings;
    if (kIsWeb) return;
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _hasAmplitude = _hasVibrator && await Vibration.hasAmplitudeControl();
    } catch (e) {
      debugPrint('HapticService: $e');
    }
  }

  /// Toque leve: bola acertou um bloco sem quebrar.
  void hit() => _vibrate(durationMs: 12, amplitude: 50);

  /// Toque mais forte: bloco quebrado. Fura o limite de intervalo de um hit.
  void blockBreak() => _vibrate(durationMs: 25, amplitude: 140, priority: true);

  void _vibrate({required int durationMs, required int amplitude, bool priority = false}) {
    if (!_hasVibrator || !(_settings?.vibrationEnabled ?? false)) return;
    final now = _clock.elapsedMilliseconds;
    final last = _lastMs;
    final minGap = priority ? _minIntervalMs ~/ 2 : _minIntervalMs;
    if (last != null && now - last < minGap) return;
    _lastMs = now;
    Vibration.vibrate(
      duration: durationMs,
      amplitude: _hasAmplitude ? amplitude : -1,
    ).then((_) {}, onError: (Object e) => debugPrint('HapticService: $e'));
  }
}
