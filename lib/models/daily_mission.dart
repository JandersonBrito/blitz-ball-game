/// O que cada missão diária conta. A ordem do enum é salva no disco: só
/// adicione tipos novos no final.
enum MissionType {
  /// Blocos comuns destruídos (inclui boss).
  breakBlocks,

  /// Ouro ganho quebrando blocos (não conta compras nem recompensas).
  earnGold,

  /// Fases concluídas.
  clearStages,

  /// Bolas extras coletadas nos blocos de bônus.
  collectBalls,

  /// Acertos com vantagem elemental.
  advantageHits,

  /// Acertos críticos. Só sorteada com o upgrade de Crítico.
  critHits,

  /// Rodadas jogadas (cada lançamento).
  playRounds,
}

enum MissionDifficulty { easy, medium, hard }

class DailyMission {
  final MissionType type;
  final MissionDifficulty difficulty;
  final int target;
  final int reward;
  int progress;
  bool claimed;

  DailyMission({
    required this.type,
    required this.difficulty,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  bool get completed => progress >= target;
  bool get claimable => completed && !claimed;
  double get ratio => (progress / target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        't': type.index,
        'd': difficulty.index,
        'tg': target,
        'r': reward,
        'p': progress,
        'c': claimed,
      };

  static DailyMission? fromJson(Map<String, dynamic> j) {
    final t = j['t'] as int? ?? -1;
    final d = j['d'] as int? ?? -1;
    if (t < 0 || t >= MissionType.values.length) return null;
    if (d < 0 || d >= MissionDifficulty.values.length) return null;
    return DailyMission(
      type: MissionType.values[t],
      difficulty: MissionDifficulty.values[d],
      target: (j['tg'] as int? ?? 1).clamp(1, 1 << 30),
      reward: j['r'] as int? ?? 0,
      progress: j['p'] as int? ?? 0,
      claimed: j['c'] as bool? ?? false,
    );
  }
}
