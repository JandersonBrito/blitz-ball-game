import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

enum CloudSaveStatus { idle, loading, success, error }

class GamesCloudService extends ChangeNotifier {
  GamesCloudService._();
  static final GamesCloudService instance = GamesCloudService._();

  static const _saveSlotName = 'ballz_progress_v1';

  bool _signedIn = false;
  bool get signedIn => _signedIn;

  CloudSaveStatus _saveStatus = CloudSaveStatus.idle;
  CloudSaveStatus get saveStatus => _saveStatus;

  CloudSaveStatus _restoreStatus = CloudSaveStatus.idle;
  CloudSaveStatus get restoreStatus => _restoreStatus;

  String? _lastError;
  String? get lastError => _lastError;

  /// Login silencioso no startup. Falhas são ignoradas — usuário pode tentar manualmente.
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await GamesServices.signIn();
      _signedIn = true;
      notifyListeners();
    } catch (_) {
      _signedIn = false;
    }
  }

  /// Login explícito acionado pelo usuário. Retorna true em caso de sucesso.
  Future<bool> signIn() async {
    if (kIsWeb) return false;
    try {
      await GamesServices.signIn();
      _signedIn = true;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _signedIn = false;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Salva [backupCode] (string Base64 JSON de GameState.exportBackupCode()) na nuvem.
  Future<bool> saveToCloud(String backupCode) async {
    if (kIsWeb || !_signedIn) return false;
    _saveStatus = CloudSaveStatus.loading;
    _lastError = null;
    notifyListeners();
    try {
      await GamesServices.saveGame(
        data: backupCode,
        name: _saveSlotName,
      );
      _saveStatus = CloudSaveStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _saveStatus = CloudSaveStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Carrega o save da nuvem. Retorna o backupCode ou null em caso de erro/inexistente.
  Future<String?> loadFromCloud() async {
    if (kIsWeb || !_signedIn) return null;
    _restoreStatus = CloudSaveStatus.loading;
    _lastError = null;
    notifyListeners();
    try {
      final result = await GamesServices.loadGame(name: _saveSlotName);
      if (result == null || result.isEmpty) {
        _restoreStatus = CloudSaveStatus.error;
        _lastError = 'Nenhum save na nuvem encontrado';
        notifyListeners();
        return null;
      }
      _restoreStatus = CloudSaveStatus.success;
      notifyListeners();
      return result;
    } catch (e) {
      _restoreStatus = CloudSaveStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }
}
