import 'dart:math';

/// Como o especial de elemento é disparado (configurável para testes).
enum SpecialTriggerMode {
  /// Chance por batida de bola elemental.
  passiveChance,

  /// A cada N batidas de bola elemental.
  everyNBalls,

  /// Medidor carregado por batidas elementais; o jogador ativa no botão.
  meter,
}

/// Configuração central do sistema de elementos: blocos especiais,
/// combinações e especiais com upgrade por nível.
///
/// Tudo que é balanceável fica aqui, em `const`, para ajustar sem caçar
/// números pelo código.
abstract final class ElementConfig {
  // ── Blocos especiais (atravessáveis) ───────────────────────────────────────

  /// Passagens de bola até o bloco especial sumir.
  static const int specialCharges = 3;

  /// Linhas mínimas entre dois blocos especiais (spec: 1 a cada 2–3 linhas).
  static const int specialMinRowGap = 2;

  /// Chance de uma linha elegível (gap vencido) receber um bloco especial.
  static const double specialChance = 0.5;

  // ── Status nos blocos ──────────────────────────────────────────────────────

  /// Bloco amolecido (vapor) recebe dano dobrado.
  static const double softenedDamageMult = 2.0;

  /// Bloco congelado recebe mais dano (além de não descer).
  static const double frozenDamageMult = 1.5;

  // ── Combinações ────────────────────────────────────────────────────────────

  /// Depois de disparar uma combinação a bola volta a ser neutra (false) ou
  /// mantém o elemento (true).
  static const bool keepElementAfterCombo = false;

  // ── Especiais de elemento (upgrades por nível) ─────────────────────────────

  static const int specialMaxLevel = 25;

  /// Dano: `dano_da_bola × (dmgA + dmgB·nível)` — cresce ~linear, acompanhando
  /// o HP dos blocos (que sobe ~linear com a fase).
  static const double specialDmgA = 0;
  static const double specialDmgB = 1.0;

  static int specialDamage(int ballDamage, int level) =>
      max(1, (ballDamage * (specialDmgA + specialDmgB * level)).ceil());

  /// Custo: `ceil(costC · costR^nível)` — cresce exponencial.
  static const double specialCostC = 80;
  static const double specialCostR = 1.32;

  static int specialCost(int level) =>
      (specialCostC * pow(specialCostR, level)).ceil();

  /// Fogo – Linha de fogo: uma frente de fogo horizontal sobe do chão ao topo
  /// atingindo TODOS os blocos; dano = dano da bola × nível. Velocidade da
  /// frente (px/s): 600 leva ~0,9 s para cruzar o tabuleiro, visível.
  static const double fireWaveSpeed = 600;

  /// A linha também põe os blocos em chamas (dano por turno, sinergia): turnos
  /// e fração do dano da linha aplicada a cada turno.
  static const int fireWaveBurnTurns = 2;
  static const double fireWaveBurnFrac = 0.25;

  /// Água – Maré: cooldown em turnos (os níveis melhoram a frequência;
  /// a distância empurrada é SEMPRE 1 linha).
  static int tideCooldown(int level) => (5 - level ~/ 6).clamp(3, 5);

  /// Raio – Descarga: saltos entre vizinhos.
  static int lightningJumps(int level) => 2 + level ~/ 2;

  /// Terra – Impacto: fração do HP ATUAL em área (útil no late game).
  static double earthPct(int level) => (0.08 + 0.02 * level).clamp(0.0, 0.5);

  /// Raio – Descarga: o raio cai do céu no alvo e salta de bloco em bloco, um
  /// salto a cada [boltStep] s; some em [boltFade] s depois do último.
  static const double boltStep = 0.07;
  static const double boltFade = 0.35;

  /// Terra – Impacto: a rocha cai em [earthFall] s; a onda de choque dura
  /// [earthShock] s. Área de [earthCells]×[earthCells] blocos.
  static const double earthFall = 0.3;
  static const double earthShock = 0.55;
  static const int earthCells = 3;

  /// Água – Maré: onda circular que parte do ponto de lançamento e se expande
  /// atingindo TODOS os blocos. Velocidade da frente (px/s): 800 cruza o
  /// tabuleiro em ~0,9 s. Como a Maré também empurra tudo 1 linha para trás,
  /// o dano é uma fração do da Linha de Fogo.
  static const double tideSpeed = 800;
  static const double tideDmgMult = 0.7;

  /// Vento – Rajada: lâminas de vento cortam tudo e, no fim da rodada, os
  /// blocos são juntados ao centro (abre corredores nas laterais). Dano =
  /// fração do dano do especial.
  static const double windGustDmg = 0.75;

  /// Lâminas: uma por faixa horizontal ([windBladeLane] px, de cima para
  /// baixo), alternando a direção; cada uma leva [windBladeTravel] s para
  /// cruzar a tela e parte [windBladeStagger] s depois da anterior.
  /// [windBladeRadius] é o alcance de corte; precisa ser maior que metade da
  /// faixa (+ a oscilação de 8 px) para nenhum bloco escapar.
  static const double windBladeLane = 64;
  static const double windBladeTravel = 0.6;
  static const double windBladeStagger = 0.08;
  static const double windBladeRadius = 44;

  /// Modo de disparo do especial (trocar aqui para testar os três).
  static const SpecialTriggerMode triggerMode = SpecialTriggerMode.meter;

  /// passiveChance: chance por batida elemental.
  static const double passiveTriggerChance = 0.05;

  /// everyNBalls: dispara a cada N batidas elementais.
  static const int triggerEveryNBalls = 30;

  /// meter: quantos ACERTOS de bola nos blocos enchem o medidor. Acertos de
  /// grupo pesado contam pelo número de bolas do grupo.
  static const int hitsToFillMeter = 100;

  /// true: só acertos de bola com elemento contam; false: qualquer bola.
  static const bool meterCountsOnlyElementalHits = false;

  // ── Power-ups não elementais ───────────────────────────────────────────────

  /// Chance de cada vaga da linha de power-ups virar um coletável especial.
  static const double powerupChance = 0.18;

  /// Transmutação: fatia das vagas de power-up que viram este (raro). O resto
  /// sorteia uniforme entre os demais.
  static const double transmuteShare = 0.05;

  /// Chance de nascer uma bomba-relógio na linha de power-ups.
  static const double bombChance = 0.08;

  /// Perfurante: blocos atravessados antes de voltar a ricochetear.
  static const int pierceBlocks = 3;

  /// Bola gigante: raio (px; o normal é 5).
  static const double giantRadius = 10;

  /// Portais: duração em turnos.
  static const int portalTurns = 3;

  /// Buraco negro: duração em segundos.
  static const double blackholeSeconds = 3;

  /// Mira estendida: duração em turnos, quiques e alcance extras.
  static const int aimBoostTurns = 3;
  static const int aimBoostBounces = 2;
  static const double aimBoostLength = 200;

  /// Bomba-relógio: turnos até explodir e dano (× dano da bola).
  static const int bombTurns = 3;
  static const double bombDmgMult = 6;

  /// Multiplicador de moedas: rodadas com ouro em dobro (a atual + a próxima).
  static const int goldBoostRounds = 2;
}
