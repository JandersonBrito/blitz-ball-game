import '../../models/element.dart';

/// Tipos de efeito reutilizáveis. Cada combinação da tabela é uma entrada de
/// configuração ([ComboDef]) que aponta para um destes tipos; balancear é
/// mexer nos números, nunca no código do efeito.
enum ComboKind {
  /// Dano num retângulo de células centrado no disparo ([ComboDef.size] =
  /// lado em células: 3 = 3×3).
  area,

  /// Dano na linha horizontal inteira do disparo.
  row,

  /// Dano na coluna inteira do disparo.
  column,

  /// Linha + coluna (cruz).
  cross,

  /// Dano na linha mais baixa do tabuleiro.
  lowestRow,

  /// Corta uma fração do HP ATUAL de todos os blocos da coluna
  /// ([ComboDef.dmg] = fração, ex.: 0.5).
  columnPercent,

  /// Dano salta entre blocos vizinhos ([size] = saltos).
  chain,

  /// Dano nos [size] blocos com mais HP do tabuleiro.
  topHp,

  /// Dano em [size] blocos aleatórios (meteoros, gotas).
  randomBlocks,

  /// Estilhaços em 8 direções: o bloco mais próximo em cada direção.
  rays8,

  /// Aplica um status ([ComboDef.status]) nos blocos da área.
  status,

  /// Cria uma zona persistente ([ComboDef.zone]) por [turns] turnos.
  zone,

  /// Empurra a linha atingida 1 casa para trás (aplicado no fim da rodada,
  /// antes da descida — nunca com bolas em voo).
  pushRow,

  /// A bola se divide em [size] (spawna size−1 bolas extras).
  split,

  /// Bola extra pesada e temporária (peso = dano alto, só nesta rodada).
  heavyBall,

  /// A bola perfura tudo por [seconds] segundos.
  pierce,

  /// Puxa as bolas em direção à linha mais próxima do fundo por [seconds].
  magnet,
}

/// Status aplicáveis por combinação (mapeiam para BlockStatus).
enum ComboStatus { burn, acid, freeze, soften, stick }

/// Zonas persistentes por turnos.
enum ZoneKind {
  /// Poça de lava fixa: queima blocos sobre ela a cada turno.
  magma,

  /// Pântano fixo: blocos na área perdem HP a cada turno.
  swamp,

  /// Campo eletrificado: bolas que passam causam +50% de dano.
  electric,

  /// Raios aleatórios caem a cada turno ([ComboDef.size] raios por turno).
  bolts,

  /// Tornado de fogo: anda 1 coluna por turno queimando o que toca.
  fireTornado,
}

class ComboDef {
  final ElementType ball, block;

  /// Id estável para codex e l10n.
  final String id;
  final ComboKind kind;

  /// Dano base × dano da bola (em [ComboKind.columnPercent], fração do HP).
  final double dmg;

  /// Dano adicional × dano da bola por nível do especial acima de 1.
  final double dmgPerLevel;

  /// Tamanho: lado da área, saltos, contagem, divisões (conforme o tipo).
  final int size;

  /// Crescimento do tamanho por nível acima de 1 (fracionário: 0.5 = +1 a
  /// cada 2 níveis).
  final double sizePerLevel;

  /// Duração em turnos (status e zonas).
  final int turns;

  /// Duração em segundos (pierce, magnet).
  final double seconds;

  final ComboStatus? status;
  final ZoneKind? zone;

  const ComboDef(this.ball, this.block, this.id, this.kind,
      {this.dmg = 1,
      this.dmgPerLevel = 0.5,
      this.size = 3,
      this.sizePerLevel = 0,
      this.turns = 0,
      this.seconds = 0,
      this.status,
      this.zone});

  int effSize(int level) => size + (sizePerLevel * (level - 1)).floor();
  double effDmg(int level) => dmg + dmgPerLevel * (level - 1);
}

/// A tabela da spec, na ordem bola × bloco (a ORDEM importa:
/// fogo×água = Ácido; água×fogo = Vapor).
const List<ComboDef> comboDefs = [
  // ── Bola de FOGO ──
  ComboDef(ElementType.fire, ElementType.fire, 'explosion', ComboKind.area,
      dmg: 3, size: 3, sizePerLevel: 0.25),
  ComboDef(ElementType.fire, ElementType.water, 'acid_pool', ComboKind.status,
      status: ComboStatus.acid, turns: 3, dmg: 1, size: 3),
  ComboDef(ElementType.fire, ElementType.wind, 'fire_tornado', ComboKind.zone,
      zone: ZoneKind.fireTornado, turns: 3, dmg: 2, size: 1),
  ComboDef(ElementType.fire, ElementType.lightning, 'plasma', ComboKind.row,
      dmg: 2.5),
  ComboDef(ElementType.fire, ElementType.earth, 'meteor_rain',
      ComboKind.randomBlocks, dmg: 3, size: 5, sizePerLevel: 0.5),

  // ── Bola de ÁGUA ──
  ComboDef(ElementType.water, ElementType.fire, 'vapor', ComboKind.status,
      status: ComboStatus.soften, turns: 1, dmg: 0, size: 3,
      sizePerLevel: 0.25),
  ComboDef(ElementType.water, ElementType.water, 'wave', ComboKind.pushRow,
      dmg: 1.5),
  ComboDef(ElementType.water, ElementType.wind, 'rainstorm',
      ComboKind.randomBlocks, dmg: 1.5, size: 6, sizePerLevel: 1),
  ComboDef(ElementType.water, ElementType.lightning, 'electric_field',
      ComboKind.zone, zone: ZoneKind.electric, turns: 2, size: 3),
  ComboDef(ElementType.water, ElementType.earth, 'mud', ComboKind.status,
      status: ComboStatus.stick, turns: 1, dmg: 0, size: 3,
      sizePerLevel: 0.25),

  // ── Bola de VENTO ──
  ComboDef(ElementType.wind, ElementType.fire, 'embers', ComboKind.status,
      status: ComboStatus.burn, turns: 2, dmg: 1, size: 3),
  ComboDef(ElementType.wind, ElementType.water, 'blizzard', ComboKind.status,
      status: ComboStatus.freeze, turns: 1, dmg: 0.5, size: 3,
      sizePerLevel: 0.25),
  ComboDef(ElementType.wind, ElementType.wind, 'hurricane', ComboKind.split,
      size: 3, sizePerLevel: 0.25),
  ComboDef(ElementType.wind, ElementType.lightning, 'thunderstorm',
      ComboKind.zone, zone: ZoneKind.bolts, turns: 2, dmg: 2, size: 3,
      sizePerLevel: 0.5),
  ComboDef(ElementType.wind, ElementType.earth, 'sandstorm', ComboKind.rays8,
      dmg: 1.5),

  // ── Bola de RAIO ──
  ComboDef(ElementType.lightning, ElementType.fire, 'overload', ComboKind.cross,
      dmg: 2),
  ComboDef(ElementType.lightning, ElementType.water, 'chain_current',
      ComboKind.chain, dmg: 1.5, size: 6),
  ComboDef(ElementType.lightning, ElementType.wind, 'flash', ComboKind.pierce,
      seconds: 2),
  ComboDef(ElementType.lightning, ElementType.lightning, 'thunder',
      ComboKind.topHp, dmg: 2.5, size: 5),
  ComboDef(ElementType.lightning, ElementType.earth, 'magnetism',
      ComboKind.magnet, seconds: 3),

  // ── Bola de TERRA ──
  ComboDef(ElementType.earth, ElementType.fire, 'magma', ComboKind.zone,
      zone: ZoneKind.magma, turns: 3, dmg: 1.5, size: 3),
  ComboDef(ElementType.earth, ElementType.water, 'swamp', ComboKind.zone,
      zone: ZoneKind.swamp, turns: 3, dmg: 1, size: 3),
  ComboDef(ElementType.earth, ElementType.wind, 'boulder', ComboKind.heavyBall,
      size: 6, sizePerLevel: 1),
  ComboDef(ElementType.earth, ElementType.lightning, 'earthquake',
      ComboKind.lowestRow, dmg: 2),
  ComboDef(ElementType.earth, ElementType.earth, 'fissure',
      ComboKind.columnPercent, dmg: 0.5, dmgPerLevel: 0.05),
];

/// Índice 0..24 da combinação (bola × bloco), usado no codex.
int comboIndex(ElementType ball, ElementType block) =>
    (ball.index - 1) * 5 + (block.index - 1);

/// Def da combinação bola × bloco (ambos não neutros).
ComboDef comboFor(ElementType ball, ElementType block) =>
    comboDefs[comboIndex(ball, block)];
