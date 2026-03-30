import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/l10n.dart';

class SettingsService extends ChangeNotifier {
  static const _keyLanguage = 'language';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyVolume = 'volume';

  AppLanguage _language;
  bool _soundEnabled;
  double _volume;

  SettingsService._({
    required AppLanguage language,
    required bool soundEnabled,
    required double volume,
  })  : _language = language,
        _soundEnabled = soundEnabled,
        _volume = volume;

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final langIndex = prefs.getInt(_keyLanguage) ?? 0;
    final soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;
    final volume = prefs.getDouble(_keyVolume) ?? 0.8;
    return SettingsService._(
      language: AppLanguage.values[langIndex.clamp(0, AppLanguage.values.length - 1)],
      soundEnabled: soundEnabled,
      volume: volume,
    );
  }

  AppLanguage get language => _language;
  bool get soundEnabled => _soundEnabled;
  double get volume => _volume;
  L10n get l10n => L10n(_language);

  void setLanguage(AppLanguage value) => language = value;
  void setSoundEnabled(bool value) => soundEnabled = value;
  void setVolume(double value) => volume = value;

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

  set volume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (_volume == clamped) return;
    _volume = clamped;
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLanguage, _language.index);
    await prefs.setBool(_keySoundEnabled, _soundEnabled);
    await prefs.setDouble(_keyVolume, _volume);
  }
}
