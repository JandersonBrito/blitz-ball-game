import 'dart:async';
import 'dart:math';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

/// Música de fundo e efeitos sonoros, com volumes separados.
///
/// Os arquivos ficam em `assets/audio/` (prefixo padrão do flame_audio).
///
/// Efeitos e vinhetas usam `PlayerMode.lowLatency` (SoundPool no Android).
/// No modo MediaPlayer, alguns aparelhos informam duração 0 para WAVs curtos;
/// o audioplayers trata isso como live stream e chama `prepareAsync()` ao fim
/// do som, o que lança IllegalStateException e derruba o app. O SoundPool não
/// passa por esse caminho. Só a música (longa, em loop) fica no MediaPlayer.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _music = 'music_loop_long.ogg';
  static const _hits = ['hit_1.wav', 'hit_2.wav', 'hit_3.wav', 'hit_4.wav'];
  static const _break = 'block_break.wav';
  static const _wall = 'wall_bounce.wav';
  static const _waveClear = 'wave_clear.wav';
  static const _stageComplete = 'level_complete.wav';

  // Players fixos por efeito, usados em rodízio. Nunca são criados outros,
  // então o consumo de recursos nativos fica constante.
  static const _voices = {
    'hit_1.wav': 2,
    'hit_2.wav': 2,
    'hit_3.wav': 2,
    'hit_4.wav': 2,
    _break: 4,
    _wall: 2,
    _waveClear: 1,
    _stageComplete: 1,
  };

  // Intervalo mínimo entre repetições do mesmo tipo de som. Com dezenas de
  // bolas, sem isso o mesmo efeito tocaria centenas de vezes por segundo.
  // Índices: 0 = hit, 1 = break, 2 = wall. Checado antes de qualquer outra
  // coisa: a física chama isto a cada quique.
  static const _minIntervalMs = [35, 45, 60];
  static const _kindHit = 0, _kindBreak = 1, _kindWall = 2;
  final List<int> _lastPlayMs = [-1000000, -1000000, -1000000];

  final Map<String, List<AudioPlayer>> _players = {};
  final Map<String, int> _nextVoice = {};

  /// Último volume aplicado em cada player: evita um setVolume (platform
  /// channel) por efeito quando o volume não mudou.
  final Map<AudioPlayer, double> _appliedVolume = {};
  final Stopwatch _clock = Stopwatch()..start();
  final Random _rng = Random();

  SettingsService? _settings;
  bool _musicLoaded = false;

  // Vinheta tocando agora: tocar uma interrompe a outra.
  AudioPlayer? _currentJingle;

  Future<void> init(SettingsService settings) async {
    _settings = settings;
    try {
      await FlameAudio.bgm.initialize(); // pausa/retoma junto com o app
      // Não pede foco de áudio, senão pausaria a música de fundo.
      final ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
      await Future.wait([
        for (final entry in _voices.entries)
          _createVoices(entry.key, entry.value, ctx).then((list) => _players[entry.key] = list),
      ]);
    } catch (e) {
      debugPrint('AudioService: falha ao carregar efeitos: $e');
    }
    settings.addListener(_syncMusic);
    await _syncMusic();
  }

  Future<List<AudioPlayer>> _createVoices(String file, int count, AudioContext ctx) async {
    final list = <AudioPlayer>[];
    for (var i = 0; i < count; i++) {
      final p = AudioPlayer()..audioCache = FlameAudio.audioCache;
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setAudioContext(ctx);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(file));
      list.add(p);
    }
    return list;
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

  void playHit() {
    if (_throttled(_kindHit)) return;
    _play(_hits[_rng.nextInt(_hits.length)]);
  }

  void playBreak() {
    if (_throttled(_kindBreak)) return;
    _play(_break);
  }

  void playWall() {
    if (_throttled(_kindWall)) return;
    _play(_wall, volumeScale: 0.6);
  }

  /// True se o som deve ser pulado (desligado ou repetido rápido demais).
  bool _throttled(int kind) {
    if (!_sfxOn) return true;
    final now = _clock.elapsedMilliseconds;
    if (now - _lastPlayMs[kind] < _minIntervalMs[kind]) return true;
    _lastPlayMs[kind] = now;
    return false;
  }

  void playWaveClear() => _playJingle(_waveClear);
  void playStageComplete() => _playJingle(_stageComplete);

  bool get _sfxOn => (_settings?.soundEnabled ?? false) && (_settings?.sfxVolume ?? 0) > 0;

  void _playJingle(String file) {
    if (!_sfxOn) return;
    final player = _players[file]?.first;
    if (player == null) return;
    final previous = _currentJingle;
    _currentJingle = player;
    if (previous != null && previous != player) {
      previous.stop().catchError((Object e) => debugPrint('AudioService: $e'));
    }
    _trigger(player, _settings!.sfxVolume);
  }

  void _play(String file, {double volumeScale = 1.0}) {
    final voices = _players[file];
    if (voices == null || voices.isEmpty) return;

    final i = _nextVoice[file] ?? 0;
    _nextVoice[file] = (i + 1) % voices.length;
    _trigger(voices[i], (_settings!.sfxVolume * volumeScale).clamp(0.0, 1.0));
  }

  /// Reinicia o player do começo. No SoundPool não há aviso de fim de som,
  /// então o `stop()` é necessário para que o `resume()` toque de novo.
  void _trigger(AudioPlayer p, double volume) {
    final setVolume = _appliedVolume[p] != volume;
    if (setVolume) _appliedVolume[p] = volume;
    () async {
      await p.stop();
      if (setVolume) await p.setVolume(volume);
      await p.resume();
    }()
        .catchError((Object e) => debugPrint('AudioService: falha no efeito: $e'));
  }
}
