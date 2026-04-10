import 'package:shared_preferences/shared_preferences.dart';

class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  static const _kConsented  = 'gdpr_consented';
  static const _kAsked      = 'gdpr_asked';

  bool _consented = false;
  bool _asked     = false;

  bool get consented  => _consented;
  bool get hasBeenAsked => _asked;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _asked     = prefs.getBool(_kAsked)     ?? false;
    _consented = prefs.getBool(_kConsented) ?? false;
  }

  Future<void> setConsent(bool value) async {
    _consented = value;
    _asked     = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConsented, value);
    await prefs.setBool(_kAsked, true);
  }
}
