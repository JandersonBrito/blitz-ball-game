/// Status de um bloco que duram turnos (rodadas): em chamas, corroído (ácido),
/// congelado, amolecido (vapor) e preso (lama).
///
/// Regra de performance: status nunca são processados por frame. O jogo chama
/// [tick] uma vez por bloco no fim de cada rodada e o desenho é um selo
/// estático no canto do bloco. Efeitos que mudam regras são lidos por getters:
/// [holdsDescent] (congelado/preso não desce) e [damageMult] (amolecido e
/// congelado recebem mais dano), checados no acerto — só leitura de campo.
class BlockStatus {
  int burnTurns = 0;
  int burnDamage = 0;
  int acidTurns = 0;
  int acidDamage = 0;
  int frozenTurns = 0;
  int softenedTurns = 0;
  int stuckTurns = 0;

  bool get isEmpty =>
      burnTurns == 0 &&
      acidTurns == 0 &&
      frozenTurns == 0 &&
      softenedTurns == 0 &&
      stuckTurns == 0;
  bool get burning => burnTurns > 0;
  bool get acid => acidTurns > 0;
  bool get frozen => frozenTurns > 0;
  bool get softened => softenedTurns > 0;
  bool get stuck => stuckTurns > 0;

  /// Congelado ou preso: o bloco não desce no próximo turno (e segura os de
  /// cima na mesma coluna). Lido ANTES de [tick] na rodada.
  bool get holdsDescent => frozenTurns > 0 || stuckTurns > 0;

  /// Multiplicador de dano recebido ([softenedMult] × [frozenMult] quando os
  /// status estão ativos). 1.0 sem status.
  double damageMult(double softenedMult, double frozenMult) {
    var m = 1.0;
    if (softenedTurns > 0) m *= softenedMult;
    if (frozenTurns > 0) m *= frozenMult;
    return m;
  }

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

  void applySoften({required int turns}) {
    if (turns > softenedTurns) softenedTurns = turns;
  }

  void applyStick({required int turns}) {
    if (turns > stuckTurns) stuckTurns = turns;
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
    if (softenedTurns > 0) softenedTurns--;
    if (stuckTurns > 0) stuckTurns--;
    return damage;
  }

  void clear() {
    burnTurns = burnDamage = acidTurns = acidDamage = frozenTurns = 0;
    softenedTurns = stuckTurns = 0;
  }
}
