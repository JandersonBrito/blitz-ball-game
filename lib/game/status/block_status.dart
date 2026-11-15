/// Status de um bloco que duram turnos (rodadas): chamas, ácido, congelado.
///
/// Regra de performance: status nunca são processados por frame. O jogo chama
/// [tick] uma vez por bloco no fim de cada rodada e o desenho é um selo
/// estático no canto do bloco. Quem for criar as features de status só
/// precisa aplicar ([applyBurn], [applyAcid], [applyFreeze]) e, se o efeito
/// mudar regras (ex.: bloco congelado não desce), consultar os getters.
class BlockStatus {
  int burnTurns = 0;
  int burnDamage = 0;
  int acidTurns = 0;
  int acidDamage = 0;
  int frozenTurns = 0;

  bool get isEmpty => burnTurns == 0 && acidTurns == 0 && frozenTurns == 0;
  bool get burning => burnTurns > 0;
  bool get acid => acidTurns > 0;
  bool get frozen => frozenTurns > 0;

  /// Reaplicar não acumula: fica a maior duração e o maior dano.
  void applyBurn({required int turns, required int damage}) {
    if (turns > burnTurns) burnTurns = turns;
    if (damage > burnDamage) burnDamage = damage;
  }

  void applyAcid({required int turns, required int damage}) {
    if (turns > acidTurns) acidTurns = turns;
    if (damage > acidDamage) acidDamage = damage;
  }

  void applyFreeze({required int turns}) {
    if (turns > frozenTurns) frozenTurns = turns;
  }

  /// Avança um turno e devolve o dano a aplicar agora.
  int tick() {
    var damage = 0;
    if (burnTurns > 0) {
      damage += burnDamage;
      if (--burnTurns == 0) burnDamage = 0;
    }
    if (acidTurns > 0) {
      damage += acidDamage;
      if (--acidTurns == 0) acidDamage = 0;
    }
    if (frozenTurns > 0) frozenTurns--;
    return damage;
  }

  void clear() {
    burnTurns = burnDamage = acidTurns = acidDamage = frozenTurns = 0;
  }
}
