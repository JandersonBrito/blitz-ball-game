import 'dart:async';
import 'dart:math';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

/// Música de fundo e efeitos sonoros, com volumes separados.
///
/// Os arquivos ficam em `assets/audio/` (prefixo padrão do flame_audio).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _music = 'music_loop_long.ogg';
  static const _hits = ['hit_1.wav', 'hit_2.wav', 'hit_3.wav', 'hit_4.wav'];
  static const _break = 'block_break.wav';
  static const _wall = 'wall_bounce.wav';

  // Intervalo mínimo entre repetições do mesmo tipo de som. Com dezenas de
  // bolas, sem isso o mesmo efeito tocaria centenas de vezes por segundo.
  static const _minIntervalMs = {'hit': 35, 'break': 45, 'wall': 60};

  final Map<String, AudioPool> _pools = {};
  final Map<String, int> _lastPlayMs = {};
  final Stopwatch _clock = Stopwatch()..start();
  final Random _rng = Random();

  SettingsService? _settings;
  bool _musicLoaded = false;

  Future<void> init(SettingsService settings) async {
    _settings = settings;
    try {
      await FlameAudio.bgm.initialize(); // pausa/retoma junto com o app
      final pools = await Future.wait([
        for (final f in _hits) FlameAudio.createPool(f, minPlayers: 1, maxPlayers: 3),
        FlameAudio.createPool(_break, minPlayers: 1, maxPlayers: 4),
        FlameAudio.createPool(_wall, minPlayers: 1, maxPlayers: 3),
      ]);
      final names = [..._hits, _break, _wall];
      for (var i = 0; i < names.length; i++) {
        _pools[names[i]] = pools[i];
      }
    } catch (e) {
      debugPrint('AudioService: falha ao carregar efeitos: $e');
    }
    settings.addListener(_syncMusic);
    await _syncMusic();
  }

  bool get _musicOn =>
      (_settings?.soundEnabled ?? false) && (_settings?.musicVolume ?? 0) > 0;

  Future<void> _syncMusic() async {
    final s = _settings;
    if (s == null) return;
    try {
      if (!_musicOn) {
        if (FlameAudio.bgm.isPlaying) await FlameAudio.bgm.pause();
        return;
      }
      if (!_musicLoaded) {
        _musicLoaded = true;
        await FlameAudio.bgm.play(_music, volume: s.musicVolume);
        return;
      }
      await FlameAudio.bgm.audioPlayer.setVolume(s.musicVolume);
      if (!FlameAudio.bgm.isPlaying) await FlameAudio.bgm.resume();
    } catch (e) {
      debugPrint('AudioService: falha na música: $e');
    }
  }

  void playHit() => _play('hit', _hits[_rng.nextInt(_hits.length)]);
  void playBreak() => _play('break', _break);
  void playWall() => _play('wall', _wall, volumeScale: 0.6);

  void _play(String kind, String file, {double volumeScale = 1.0}) {
    final s = _settings;
    if (s == null || !s.soundEnabled || s.sfxVolume <= 0) return;
    final pool = _pools[file];
    if (pool == null) return;

    final now = _clock.elapsedMilliseconds;
    final last = _lastPlayMs[kind];
    if (last != null && now - last < (_minIntervalMs[kind] ?? 0)) return;
    _lastPlayMs[kind] = now;

    pool.start(volume: (s.sfxVolume * volumeScale).clamp(0.0, 1.0)).then(
          (_) {},
          onError: (Object e) => debugPrint('AudioService: falha no efeito: $e'),
        );
  }
}
