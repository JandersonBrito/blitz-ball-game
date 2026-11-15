import 'dart:math';
import '../managers/game_state.dart';

/// Valores de dano calculados uma vez por rodada (upgrades e ajuda não mudam
/// no meio dela). Cada acerto só faz contas e sorteios: nada de procurar
/// upgrade em lista nem criar `Random`.
///
/// O antigo triângulo de vantagem elemental foi removido: o elemento da bola
/// agora serve às combinações dos blocos especiais (e, na Fase 4, aos
/// especiais de elemento), não a um multiplicador por acerto.
class DamageModel {
  DamageModel([Random? rng]) : _rng = rng ?? Random();

  final Random _rng;
  int base = 1;
  double critChance = 0;

  // Resultado do último [roll], em campo para não alocar uma tupla por acerto.
  bool lastCrit = false;

  void refresh(GameState gs) {
    base = gs.baseDamage;
    critChance = gs.critChance;
  }

  /// Dano de uma bola (peso 1).
  int roll() {
    final crit = critChance > 0 && _rng.nextDouble() < critChance;
    lastCrit = crit;
    return crit ? base * 2 : base;
  }
}
