import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

enum CloudSaveStatus { idle, loading, success, error }

class GamesCloudService extends ChangeNotifier {
  GamesCloudService._();
  static final GamesCloudService instance = GamesCloudService._();

  static const _saveSlotName = 'ballz_progress_v1';

  /// ID do placar "Fase mais alta" criado no Play Console
  /// (Play Games Services > Placares). Ex.: 'CgkI...EAIQAQ'.
  static const stageLeaderboardId = 'CgkIzYbpoPUEEAIQAw';
  bool get rankingConfigured => stageLeaderboardId.isNotEmpty;

  /// Maior fase já enviada ao placar nesta sessão (evita envios repetidos).
  int _submittedStage = 0;
  /// Maior fase alcançada que ainda não foi enviada (ex.: jogador deslogado).
  int _pendingStage = 0;

  bool _signedIn = false;
  bool get signedIn => _signedIn;

  CloudSaveStatus _saveStatus = CloudSaveStatus.idle;
  CloudSaveStatus get saveStatus => _saveStatus;

  CloudSaveStatus _restoreStatus = CloudSaveStatus.idle;
  CloudSaveStatus get restoreStatus => _restoreStatus;

  String? _lastError;
  String? get lastError => _lastError;

  /// Verificação silenciosa no startup: só consulta se o Play Games já
  /// autenticou o jogador (o SDK v2 faz isso sozinho na abertura).
  /// Não chama signIn() aqui — no Android ele abre o seletor de conta.
  /// O login interativo fica só no botão das configurações.
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      _signedIn = await GamesServices.isSignedIn
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
    } catch (_) {
      _signedIn = false;
    }
    notifyListeners();
    await _flushStage();
  }

  /// Login explícito acionado pelo usuário. Retorna true em caso de sucesso.
  Future<bool> signIn() async {
    if (kIsWeb) return false;
    try {
      await GamesServices.signIn();
      _signedIn = true;
      _lastError = null;
      notifyListeners();
      await _flushStage();
      return true;
    } catch (e) {
      _signedIn = false;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Registra a fase alcançada no placar. O Play Games guarda só o melhor
  /// valor de cada jogador, então recomeçar o jogo não derruba o ranking.
  Future<void> submitStage(int stage) async {
    if (stage <= _submittedStage || stage <= _pendingStage) return;
    _pendingStage = stage;
    await _flushStage();
  }

  Future<void> _flushStage() async {
    if (kIsWeb || !_signedIn || !rankingConfigured) return;
    final stage = _pendingStage;
    if (stage <= _submittedStage) return;
    try {
      await GamesServices.submitScore(
        score: Score(androidLeaderboardID: stageLeaderboardId, value: stage),
      );
      if (stage > _submittedStage) _submittedStage = stage;
    } catch (_) {
      // Fica pendente; tenta de novo no próximo avanço ou login.
    }
  }

  /// Abre o placar do Play Games, fazendo login antes se preciso.
  /// Retorna false se o login falhar ou o placar não estiver configurado.
  Future<bool> showStageRanking(int currentStage) async {
    if (kIsWeb || !rankingConfigured) return false;
    if (!_signedIn && !await signIn()) return false;
    await submitStage(currentStage);
    try {
      await GamesServices.showLeaderboards(
          androidLeaderboardID: stageLeaderboardId);
      return true;
    } catch (e) {
      _lastError = e.toString();
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
