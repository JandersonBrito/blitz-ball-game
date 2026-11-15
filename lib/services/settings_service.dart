import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/graphics_quality.dart';
import '../models/l10n.dart';

class SettingsService extends ChangeNotifier {
  static const _keyLanguage = 'language';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyVolume = 'volume'; // legado: volume único
  static const _keyMusicVolume = 'music_volume';
  static const _keySfxVolume = 'sfx_volume';
  static const _keyTutorialSeen = 'tutorial_seen';
  static const _keyVibration = 'vibration_enabled';
  static const _keyQuality = 'graphics_quality';
  static const _keyAutoQuality = 'graphics_auto';
  static const _keyFpsLock = 'fps_lock_30';

  AppLanguage _language;
  bool _soundEnabled;
  double _musicVolume;
  double _sfxVolume;
  bool _tutorialSeen;
  bool _vibrationEnabled;
  GraphicsQuality _graphicsQuality;
  bool _autoQuality;
  bool _fpsLock30;

  SettingsService._({
    required AppLanguage language,
    required bool soundEnabled,
    required double musicVolume,
    required double sfxVolume,
    required bool tutorialSeen,
    required bool vibrationEnabled,
    required GraphicsQuality graphicsQuality,
    required bool autoQuality,
    required bool fpsLock30,
  })  : _language = language,
        _soundEnabled = soundEnabled,
        _musicVolume = musicVolume,
        _sfxVolume = sfxVolume,
        _tutorialSeen = tutorialSeen,
        _vibrationEnabled = vibrationEnabled,
        _graphicsQuality = graphicsQuality,
        _autoQuality = autoQuality,
        _fpsLock30 = fpsLock30;

  /// O consentimento aparece antes de o jogador poder escolher o idioma.
  static AppLanguage languageForCode(String code) => AppLanguage.values.firstWhere(
        (lang) => lang.name == code,
        orElse: () => AppLanguage.en,
      );

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final langIndex = prefs.getInt(_keyLanguage) ??
        languageForCode(PlatformDispatcher.instance.locale.languageCode).index;
    final soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
    final legacyVolume = prefs.getDouble(_keyVolume) ?? 0.8;
    final musicVolume = prefs.getDouble(_keyMusicVolume) ?? legacyVolume * 0.6;
    final sfxVolume = prefs.getDouble(_keySfxVolume) ?? legacyVolume;
    final tutorialSeen = prefs.getBool(_keyTutorialSeen) ?? false;
    final qualityIndex = prefs.getInt(_keyQuality) ?? GraphicsQuality.high.index;
    return SettingsService._(
      language: AppLanguage.values[langIndex.clamp(0, AppLanguage.values.length - 1)],
      soundEnabled: soundEnabled,
      musicVolume: musicVolume,
      sfxVolume: sfxVolume,
      tutorialSeen: tutorialSeen,
      vibrationEnabled: prefs.getBool(_keyVibration) ?? true,
      // Começa no Alto; o ajuste automático desce em aparelhos fracos.
      graphicsQuality: GraphicsQuality
          .values[qualityIndex.clamp(0, GraphicsQuality.values.length - 1)],
      autoQuality: prefs.getBool(_keyAutoQuality) ?? true,
      fpsLock30: prefs.getBool(_keyFpsLock) ?? false,
    );
  }

  AppLanguage get language => _language;
  bool get soundEnabled => _soundEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get tutorialSeen => _tutorialSeen;
  bool get vibrationEnabled => _vibrationEnabled;
  GraphicsQuality get graphicsQuality => _graphicsQuality;

  /// Medir o FPS no começo da partida e baixar a qualidade se ficar lento.
  bool get autoQuality => _autoQuality;

  /// Travar o jogo em 30 FPS (bateria e aquecimento).
  bool get fpsLock30 => _fpsLock30;
  L10n get l10n => L10n(_language);

  Future<void> markTutorialSeen() async {
    if (_tutorialSeen) return;
    _tutorialSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialSeen, true);
  }

  void setLanguage(AppLanguage value) => language = value;
  void setSoundEnabled(bool value) => soundEnabled = value;
  void setVibrationEnabled(bool value) {
    if (_vibrationEnabled == value) return;
    _vibrationEnabled = value;
    _save();
    notifyListeners();
  }
  void setGraphicsQuality(GraphicsQuality value) {
    if (_graphicsQuality == value) return;
    _graphicsQuality = value;
    _save();
    notifyListeners();
  }

  void setAutoQuality(bool value) {
    if (_autoQuality == value) return;
    _autoQuality = value;
    _save();
    notifyListeners();
  }

  void setFpsLock30(bool value) {
    if (_fpsLock30 == value) return;
    _fpsLock30 = value;
    _save();
    notifyListeners();
  }

  void setMusicVolume(double value) => musicVolume = value;
  void setSfxVolume(double value) => sfxVolume = value;

  set language(AppLanguage value) {
    if (_language == value) return;
    _language = value;
    _save();
    notifyListeners();
  }

  set soundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    _save();
    notifyListeners();
  }

  set musicVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_musicVolume == clamped) return;
    _musicVolume = clamped;
    _save();
    notifyListeners();
  }

  set sfxVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_sfxVolume == clamped) return;
    _sfxVolume = clamped;
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLanguage, _language.index);
    await prefs.setBool(_keySoundEnabled, _soundEnabled);
    await prefs.setDouble(_keyMusicVolume, _musicVolume);
    await prefs.setDouble(_keySfxVolume, _sfxVolume);
    await prefs.setBool(_keyVibration, _vibrationEnabled);
    await prefs.setInt(_keyQuality, _graphicsQuality.index);
    await prefs.setBool(_keyAutoQuality, _autoQuality);
    await prefs.setBool(_keyFpsLock, _fpsLock30);
  }
}
