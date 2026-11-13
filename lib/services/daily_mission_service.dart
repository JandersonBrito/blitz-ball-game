import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/managers/game_state.dart';
import '../models/daily_mission.dart';

/// Três missões por dia (fácil, média, difícil) mais um bônus por resgatar
/// todas. Viram à meia-noite local; alvos e recompensas acompanham a fase em
/// que o jogador estava quando as missões do dia foram sorteadas.
class DailyMissionService extends ChangeNotifier {
  DailyMissionService._();
  static final DailyMissionService instance = DailyMissionService._();

  static const _kState = 'dm_state';
  static const missionsPerDay = 3;

  GameState? _gameState;
  int _day = 0;
  List<DailyMission> _missions = [];
  bool _bonusClaimed = false;
  int _bonusReward = 0;
  Timer? _saveTimer;
  Timer? _midnightTimer;

  /// Missão que acabou de ser concluída, para o aviso durante a partida.
  /// Quem mostra o aviso limpa com [clearJustCompleted].
  DailyMission? justCompleted;

  List<DailyMission> get missions {
    _rollIfNeeded();
    return List.unmodifiable(_missions);
  }

  int get bonusReward => _bonusReward;
  bool get bonusClaimed => _bonusClaimed;
  bool get allClaimed => _missions.isNotEmpty && _missions.every((m) => m.claimed);
  bool get bonusClaimable => allClaimed && !_bonusClaimed;

  /// Recompensas esperando resgate (inclui o bônus), para o selo do menu.
  int get claimableCount {
    _rollIfNeeded();
    return _missions.where((m) => m.claimable).length + (bonusClaimable ? 1 : 0);
  }

  /// Tempo até as próximas missões.
  Duration get timeUntilReset {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Future<void> load(GameState gameState) async {
    _gameState = gameState;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kState);
    _day = 0; // sem save válido, sorteia as missões do dia
    if (raw != null) {
      try {
        _readState(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _day = 0;
      }
    }
    _rollIfNeeded();
    _scheduleMidnight();
  }

  /// Vira as missões na meia-noite mesmo com o jogo aberto no menu.
  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(timeUntilReset + const Duration(seconds: 1), () {
      _rollIfNeeded();
      _scheduleMidnight();
    });
  }

  void _readState(Map<String, dynamic> j) {
    _day = j['day'] as int? ?? 0;
    _bonusClaimed = j['bc'] as bool? ?? false;
    _bonusReward = j['br'] as int? ?? 0;
    _missions = (j['m'] as List<dynamic>? ?? [])
        .map((e) => DailyMission.fromJson(e as Map<String, dynamic>))
        .whereType<DailyMission>()
        .toList();
  }

  Map<String, dynamic> exportState() => {
        'day': _day,
        'bc': _bonusClaimed,
        'br': _bonusReward,
        'm': [for (final m in _missions) m.toJson()],
      };

  /// Aplica as missões de um backup. Só vale se o backup for de hoje: assim
  /// quem reinstala no mesmo dia recupera o que já resgatou e não resgata de
  /// novo. Backup de outro dia é ignorado e ficam as missões de hoje.
  /// Retorna true se aplicou.
  bool applyBackup(Map<String, dynamic>? j) {
    if (j == null) return false;
    final today = _dayKey(DateTime.now());
    if (j['day'] != today) return false;
    final prev = exportState();
    try {
      _readState(j);
    } catch (_) {
      _readState(prev);
      return false;
    }
    if (_missions.length != missionsPerDay) {
      _readState(prev);
      return false;
    }
    justCompleted = null;
    _saveNow();
    notifyListeners();
    return true;
  }

  void _rollIfNeeded() {
    final today = _dayKey(DateTime.now());
    if (_day == today && _missions.length == missionsPerDay) return;
    _day = today;
    _generate(today);
    _bonusClaimed = false;
    justCompleted = null;
    _saveNow();
    // Pode ser chamado durante um build; avisa no próximo frame.
    scheduleMicrotask(notifyListeners);
  }

  void _generate(int seed) {
    final gs = _gameState;
    final stage = gs?.stage ?? 1;
    final hasCrit = (gs?.upgrades['crit'] ?? 0) > 0;
    // Mesmo dia, mesmos tipos: reinstalar o jogo não troca as missões por
    // outras mais fáceis.
    final rng = Random(seed);
    final pool = MissionType.values
        .where((t) => t != MissionType.critHits || hasCrit)
        .toList()
      ..shuffle(rng);
    final base = _baseReward(stage);
    _missions = [
      for (var i = 0; i < missionsPerDay; i++)
        DailyMission(
          type: pool[i],
          difficulty: MissionDifficulty.values[i],
          target: _target(pool[i], MissionDifficulty.values[i], stage),
          reward: base * (i + 1),
        ),
    ];
    _bonusReward = base * 2;
  }

  static int _baseReward(int stage) => _round5(min(400, 30 + stage * 4));

  static int _round5(num v) => max(5, (v / 5).round() * 5);

  static int _target(MissionType t, MissionDifficulty d, int stage) {
    final i = d.index;
    switch (t) {
      case MissionType.breakBlocks:
        return const [30, 70, 150][i];
      case MissionType.earnGold:
        // Mesmo cálculo de ouro por bloco do block_factory.
        final perBlock = (1 + stage * 0.25).ceil();
        return _round5(const [12, 30, 70][i] * perBlock);
      case MissionType.clearStages:
        return const [1, 2, 4][i];
      case MissionType.collectBalls:
        return const [10, 25, 50][i];
      case MissionType.advantageHits:
        return const [40, 100, 220][i];
      case MissionType.critHits:
        return const [15, 40, 90][i];
      case MissionType.playRounds:
        return const [10, 25, 50][i];
    }
  }

  /// Soma progresso nas missões do tipo. Chamado do loop do jogo, então só
  /// avisa a UI quando uma missão é concluída e grava com atraso.
  void track(MissionType type, [int amount = 1]) {
    if (amount <= 0) return;
    _rollIfNeeded();
    var changed = false;
    for (final m in _missions) {
      if (m.type != type || m.completed) continue;
      m.progress = min(m.target, m.progress + amount);
      changed = true;
      if (m.completed) {
        justCompleted = m;
        _saveNow();
        notifyListeners();
      }
    }
    if (changed) _scheduleSave();
  }

  void clearJustCompleted() => justCompleted = null;

  /// Credita a recompensa no ouro. Retorna o valor creditado (0 se nada).
  int claim(DailyMission mission) {
    final gs = _gameState;
    if (gs == null || !mission.claimable || !_missions.contains(mission)) return 0;
    mission.claimed = true;
    gs.addGold(mission.reward);
    _saveNow();
    notifyListeners();
    return mission.reward;
  }

  int claimBonus() {
    final gs = _gameState;
    if (gs == null || !bonusClaimable) return 0;
    _bonusClaimed = true;
    gs.addGold(_bonusReward);
    _saveNow();
    notifyListeners();
    return _bonusReward;
  }

  void _scheduleSave() {
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(seconds: 3), _saveNow);
  }

  /// Grava já; usado também quando o app vai para segundo plano.
  void flush() => _saveNow();

  void _saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final data = jsonEncode(exportState());
    SharedPreferences.getInstance().then((p) => p.setString(_kState, data));
  }
}
