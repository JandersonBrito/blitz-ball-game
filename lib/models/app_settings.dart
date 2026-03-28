import 'package:flutter/material.dart';
import 'l10n.dart';

enum AppLanguage { pt, en, es, fr }

class AppSettings extends ChangeNotifier {
  AppLanguage _language = AppLanguage.pt;
  bool _soundEnabled = true;
  double _volume = 0.8;

  AppLanguage get language => _language;
  bool get soundEnabled => _soundEnabled;
  double get volume => _volume;
  L10n get l10n => L10n(_language);

  void setLanguage(AppLanguage lang) {
    _language = lang;
    notifyListeners();
  }

  void setSoundEnabled(bool val) {
    _soundEnabled = val;
    notifyListeners();
  }

  void setVolume(double val) {
    _volume = val;
    notifyListeners();
  }
}
