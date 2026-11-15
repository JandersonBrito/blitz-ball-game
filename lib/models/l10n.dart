import 'app_settings.dart';
import 'element.dart';
import 'daily_mission.dart';
import 'graphics_quality.dart';

class L10n {
  final AppLanguage lang;
  L10n(this.lang);

  String _t(List<String> t) => t[AppLanguage.values.indexOf(lang)];

  // ── Stage / Wave ──────────────────────────────────────────────────────────
  String get stage =>   _t(['FASE', 'STAGE', 'ETAPA', 'NIVEAU']);
  String get boss =>    _t(['BOSS', 'BOSS', 'JEFE', 'BOSS']);
  String get bossTip => _t([
    'derrote o boss para avançar',
    'defeat the boss to advance',
    'derrota al jefe para avanzar',
    'battez le boss pour avancer',
  ]);
  String get waveCleared => _t(['Wave concluída!', 'Wave cleared!', '¡Oleada completada!', 'Vague terminée!']);
  String get nextWave => _t(['Próxima wave', 'Next wave', 'Siguiente oleada', 'Vague suivante']);

  String waveOf(int w, int t) {
    final wl = _t(['wave', 'wave', 'oleada', 'vague']);
    final of = _t(['de', 'of', 'de', 'sur']);
    return '$wl $w $of $t';
  }
  String get clearAll => _t([
    'limpe todos os blocos para avançar',
    'clear all blocks to advance',
    'elimina todos los bloques para avanzar',
    'éliminez tous les blocs pour avancer',
  ]);
  String get clearLast => _t([
    'limpe tudo para avançar',
    'clear all to advance',
    'elimina todo para avanzar',
    'tout éliminer pour avancer',
  ]);

  // ── Elements ──────────────────────────────────────────────────────────────
  String get elemNeutral =>   _t(['Neutro', 'Neutral', 'Neutro', 'Neutre']);
  String get elemFire =>      _t(['Fogo', 'Fire', 'Fuego', 'Feu']);
  String get elemWater =>     _t(['Água', 'Water', 'Agua', 'Eau']);
  String get elemWind =>      _t(['Vento', 'Wind', 'Viento', 'Vent']);
  String get elemLightning => _t(['Raio', 'Lightning', 'Rayo', 'Foudre']);
  String get elemEarth =>     _t(['Terra', 'Earth', 'Tierra', 'Terre']);

  String elemName(ElementType el) => switch (el) {
    ElementType.neutral   => elemNeutral,
    ElementType.fire      => elemFire,
    ElementType.water     => elemWater,
    ElementType.wind      => elemWind,
    ElementType.lightning => elemLightning,
    ElementType.earth     => elemEarth,
  };

  // ── Especiais de elemento ─────────────────────────────────────────────────
  String get specialsTitle => _t(['ESPECIAIS', 'SPECIALS', 'ESPECIALES', 'SPÉCIAUX']);
  String get specialLevel => _t(['nível', 'level', 'nivel', 'niveau']);
  String get specialBuy => _t(['Comprar', 'Buy', 'Comprar', 'Acheter']);
  String get specialUpgrade => _t(['Evoluir', 'Upgrade', 'Mejorar', 'Améliorer']);
  String get specialReady => _t(['ESPECIAL PRONTO!', 'SPECIAL READY!', '¡ESPECIAL LISTO!', 'SPÉCIAL PRÊT!']);
  String get specialCooldown => _t(['recarregando', 'cooldown', 'recargando', 'recharge']);
  String get specialAdBtn => _t(['▶ Especial agora', '▶ Special now', '▶ Especial ya', '▶ Spécial direct']);

  String specialDesc(ElementType el) => switch (el) {
    ElementType.fire => _t([
      'Linha de fogo: sobe do chão ao topo queimando todos os blocos; dano cresce com o nível',
      'Fire line: rises from floor to top burning every block; damage grows with level',
      'Línea de fuego: sube del suelo al techo quemando todos los bloques; el daño crece con el nivel',
      'Ligne de feu : monte du sol au plafond en brûlant tous les blocs ; dégâts selon le niveau',
    ]),
    ElementType.water => _t([
      'Maré: uma onda parte de você, atinge todos os blocos e empurra tudo 1 linha para trás (com recarga)',
      'Tide: a wave rolls out from you, hits every block and pushes all 1 row back (has cooldown)',
      'Marea: una ola parte de ti, golpea todos los bloques y empuja todo 1 fila atrás (con recarga)',
      'Marée : une vague part de vous, frappe tous les blocs et repousse tout d\'une ligne (recharge)',
    ]),
    ElementType.wind => _t([
      'Rajada: lâminas de vento cortam todos os blocos e juntam tudo no centro, abrindo corredores',
      'Gust: wind blades slice every block and pull everything to the center, opening lanes',
      'Ráfaga: cuchillas de viento cortan todos los bloques y juntan todo al centro, abriendo pasillos',
      'Rafale : des lames de vent tranchent tous les blocs et regroupent tout au centre',
    ]),
    ElementType.lightning => _t([
      'Descarga: o dano salta entre blocos vizinhos; saltos crescem com o nível',
      'Discharge: damage jumps between neighbors; jumps grow with level',
      'Descarga: el daño salta entre vecinos; los saltos crecen con el nivel',
      'Décharge : les dégâts sautent entre voisins ; portée selon le niveau',
    ]),
    ElementType.earth => _t([
      'Impacto: dano % do HP atual em área; útil até no late game',
      'Impact: % of current HP as area damage; scales into late game',
      'Impacto: daño % del HP actual en área; útil en el late game',
      'Impact : dégâts en % des PV actuels en zone',
    ]),
    ElementType.neutral => '',
  };

  // ── Avisos durante a partida (power-ups e especiais) ───────────────────────
  String powerUpName(int kind) {
    const names = <List<String>>[
      ['Perfuração', 'Pierce', 'Perforación', 'Perforation'],
      ['Bola Gigante', 'Giant Ball', 'Bola Gigante', 'Balle Géante'],
      ['Portais', 'Portals', 'Portales', 'Portails'],
      ['Buraco Negro', 'Black Hole', 'Agujero Negro', 'Trou Noir'],
      ['Muralha', 'Wall', 'Muralla', 'Muraille'],
      ['Mira Longa', 'Long Aim', 'Mira Larga', 'Visée Longue'],
      ['Ouro em Dobro', 'Double Gold', 'Oro Doble', 'Or Double'],
      ['Ímã', 'Magnet', 'Imán', 'Aimant'],
    ];
    return kind >= 0 && kind < names.length ? _t(names[kind]) : '';
  }

  String powerUpDesc(int kind) {
    const descs = <List<String>>[
      ['As bolas atravessam vários blocos', 'Balls pass through several blocks', 'Las bolas atraviesan varios bloques', 'Les balles traversent plusieurs blocs'],
      ['Bolas maiores nesta rodada: acertam mais blocos', 'Bigger balls this round: hit more blocks', 'Bolas más grandes esta ronda: golpean más bloques', 'Balles plus grosses ce tour : touchent plus de blocs'],
      ['Um par de portais teletransporta as bolas', 'A pair of portals teleports the balls', 'Un par de portales teletransporta las bolas', 'Deux portails téléportent les balles'],
      ['Puxa as bolas para um ponto por alguns segundos', 'Pulls the balls to one spot for a few seconds', 'Atrae las bolas a un punto unos segundos', 'Attire les balles vers un point quelques secondes'],
      ['Uma muralha no fundo segura a próxima descida', 'A wall at the bottom blocks the next descent', 'Una muralla al fondo detiene el próximo descenso', 'Une muraille en bas bloque la prochaine descente'],
      ['A mira mostra mais ricochetes por alguns turnos', 'The aim shows more bounces for a few turns', 'La mira muestra más rebotes unos turnos', 'La visée montre plus de rebonds quelques tours'],
      ['Moedas em dobro nesta rodada e na próxima', 'Double coins this round and the next', 'Monedas dobles esta ronda y la siguiente', 'Pièces doublées ce tour et le suivant'],
      ['Coleta todas as moedas e bolas extras do tabuleiro', 'Collects every coin and extra ball on the board', 'Recoge todas las monedas y bolas extra del tablero', 'Récupère toutes les pièces et balles bonus du plateau'],
    ];
    return kind >= 0 && kind < descs.length ? _t(descs[kind]) : '';
  }

  /// Nome do especial de cada elemento (índice de [ElementType]).
  String specialName(int elementIndex) {
    const names = <List<String>>[
      ['', '', '', ''], // neutro
      ['Linha de Fogo', 'Fire Line', 'Línea de Fuego', 'Ligne de feu'],
      ['Maré', 'Tide', 'Marea', 'Marée'],
      ['Rajada', 'Gust', 'Ráfaga', 'Rafale'],
      ['Descarga', 'Discharge', 'Descarga', 'Décharge'],
      ['Impacto', 'Impact', 'Impacto', 'Impact'],
    ];
    return elementIndex >= 0 && elementIndex < names.length
        ? _t(names[elementIndex])
        : '';
  }

  // ── Codex ─────────────────────────────────────────────────────────────────
  String get codexBtn => _t(['📖 Codex', '📖 Codex', '📖 Códice', '📖 Codex']);
  String get codexTitle => _t(['Codex de Combinações', 'Combo Codex', 'Códice de Combos', 'Codex des Combos']);
  String codexProgress(int found, int total) =>
      _t(['descobertas', 'discovered', 'descubiertas', 'découvertes']) + ': $found/$total';
  String get codexHint => _t([
    'Bola com elemento × bloco especial: a ordem importa',
    'Elemental ball × special block: order matters',
    'Bola con elemento × bloque especial: el orden importa',
    'Balle élémentaire × bloc spécial : l\'ordre compte',
  ]);
  String get newComboToast => _t([
    '✨ Nova combinação descoberta!',
    '✨ New combo discovered!',
    '✨ ¡Nueva combinación descubierta!',
    '✨ Nouvelle combinaison découverte!',
  ]);

  String comboName(String id) {
    const map = <String, List<String>>{
      'explosion':      ['Explosão', 'Explosion', 'Explosión', 'Explosion'],
      'acid_pool':      ['Ácido', 'Acid', 'Ácido', 'Acide'],
      'fire_tornado':   ['Tornado de fogo', 'Fire tornado', 'Tornado de fuego', 'Tornade de feu'],
      'plasma':         ['Plasma', 'Plasma', 'Plasma', 'Plasma'],
      'meteor_rain':    ['Chuva de meteoros', 'Meteor rain', 'Lluvia de meteoros', 'Pluie de météores'],
      'vapor':          ['Vapor', 'Steam', 'Vapor', 'Vapeur'],
      'wave':           ['Onda', 'Wave', 'Ola', 'Vague'],
      'rainstorm':      ['Tempestade', 'Rainstorm', 'Tormenta', 'Tempête'],
      'electric_field': ['Campo eletrificado', 'Electric field', 'Campo eléctrico', 'Champ électrique'],
      'mud':            ['Lama', 'Mud', 'Lodo', 'Boue'],
      'embers':         ['Brasas', 'Embers', 'Brasas', 'Braises'],
      'blizzard':       ['Nevasca', 'Blizzard', 'Ventisca', 'Blizzard'],
      'hurricane':      ['Furacão', 'Hurricane', 'Huracán', 'Ouragan'],
      'thunderstorm':   ['Tempestade elétrica', 'Thunderstorm', 'Tormenta eléctrica', 'Orage'],
      'sandstorm':      ['Tempestade de areia', 'Sandstorm', 'Tormenta de arena', 'Tempête de sable'],
      'overload':       ['Sobrecarga', 'Overload', 'Sobrecarga', 'Surcharge'],
      'chain_current':  ['Corrente em cadeia', 'Chain current', 'Corriente en cadena', 'Courant en chaîne'],
      'flash':          ['Relâmpago', 'Flash', 'Relámpago', 'Éclair'],
      'thunder':        ['Trovão', 'Thunder', 'Trueno', 'Tonnerre'],
      'magnetism':      ['Magnetismo', 'Magnetism', 'Magnetismo', 'Magnétisme'],
      'magma':          ['Magma', 'Magma', 'Magma', 'Magma'],
      'swamp':          ['Pântano', 'Swamp', 'Pantano', 'Marais'],
      'boulder':        ['Pedregulho', 'Boulder', 'Peñasco', 'Rocher'],
      'earthquake':     ['Terremoto', 'Earthquake', 'Terremoto', 'Séisme'],
      'fissure':        ['Fissura', 'Fissure', 'Fisura', 'Fissure'],
    };
    final t = map[id];
    return t != null ? _t(t) : id;
  }

  String comboDesc(String id) {
    const map = <String, List<String>>{
      'explosion':      ['Dano em área 3×3', '3×3 area damage', 'Daño en área 3×3', 'Dégâts de zone 3×3'],
      'acid_pool':      ['Corrói os blocos em volta por 3 turnos', 'Corrodes nearby blocks for 3 turns', 'Corroe los bloques cercanos por 3 turnos', 'Corrode les blocs proches pendant 3 tours'],
      'fire_tornado':   ['Redemoinho que anda pelo tabuleiro queimando', 'Whirlwind that roams the board burning', 'Remolino que recorre el tablero quemando', 'Tourbillon qui parcourt le plateau en brûlant'],
      'plasma':         ['Feixe que atinge a linha inteira', 'Beam that hits the whole row', 'Rayo que golpea toda la fila', 'Rayon qui frappe toute la ligne'],
      'meteor_rain':    ['Meteoros caem em blocos aleatórios', 'Meteors strike random blocks', 'Meteoros caen en bloques al azar', 'Des météores frappent des blocs au hasard'],
      'vapor':          ['Blocos da área recebem dano dobrado por 1 turno', 'Area blocks take double damage for 1 turn', 'Los bloques del área reciben daño doble 1 turno', 'Les blocs de la zone subissent le double de dégâts 1 tour'],
      'wave':           ['Empurra a linha atingida 1 casa para trás', 'Pushes the hit row 1 step back', 'Empuja la fila golpeada 1 casilla atrás', 'Repousse la ligne touchée d\'une case'],
      'rainstorm':      ['Gotas caem em vários blocos', 'Drops strike several blocks', 'Gotas caen en varios bloques', 'Des gouttes frappent plusieurs blocs'],
      'electric_field': ['Bolas na área causam +50% de dano', 'Balls inside deal +50% damage', 'Las bolas dentro causan +50% de daño', 'Les balles y infligent +50% de dégâts'],
      'mud':            ['Blocos da área não descem no próximo turno', 'Area blocks don\'t descend next turn', 'Los bloques del área no bajan el próximo turno', 'Les blocs de la zone ne descendent pas au prochain tour'],
      'embers':         ['Blocos vizinhos ficam em chamas', 'Nearby blocks catch fire', 'Los bloques vecinos arden', 'Les blocs voisins s\'enflamment'],
      'blizzard':       ['Congela: não descem e recebem mais dano', 'Freezes: no descent and extra damage taken', 'Congela: no bajan y reciben más daño', 'Gèle : pas de descente et dégâts accrus'],
      'hurricane':      ['A bola se divide em 3', 'The ball splits into 3', 'La bola se divide en 3', 'La balle se divise en 3'],
      'thunderstorm':   ['Raios aleatórios caem por 2 turnos', 'Random bolts strike for 2 turns', 'Rayos aleatorios caen por 2 turnos', 'Des éclairs tombent pendant 2 tours'],
      'sandstorm':      ['Estilhaços saem em 8 direções', 'Shards fly in 8 directions', 'Esquirlas salen en 8 direcciones', 'Des éclats partent dans 8 directions'],
      'overload':       ['Explosão em cruz: linha + coluna', 'Cross explosion: row + column', 'Explosión en cruz: fila + columna', 'Explosion en croix : ligne + colonne'],
      'chain_current':  ['O dano salta entre até 6 blocos vizinhos', 'Damage jumps across up to 6 neighbors', 'El daño salta entre hasta 6 bloques', 'Les dégâts sautent entre 6 blocs max'],
      'flash':          ['A bola perfura tudo por 2 segundos', 'The ball pierces everything for 2 seconds', 'La bola perfora todo por 2 segundos', 'La balle transperce tout pendant 2 s'],
      'thunder':        ['Atinge os 5 blocos com mais HP', 'Strikes the 5 highest-HP blocks', 'Golpea los 5 bloques con más HP', 'Frappe les 5 blocs avec le plus de PV'],
      'magnetism':      ['Puxa as bolas para a linha mais baixa', 'Pulls balls toward the lowest row', 'Atrae las bolas a la fila más baja', 'Attire les balles vers la ligne la plus basse'],
      'magma':          ['Lava fixa que queima quem desce sobre ela', 'Fixed lava that burns blocks landing on it', 'Lava fija que quema a quien baja sobre ella', 'Lave fixe qui brûle les blocs qui y descendent'],
      'swamp':          ['Área que corrói os blocos por 3 turnos', 'Area that corrodes blocks for 3 turns', 'Área que corroe los bloques por 3 turnos', 'Zone qui corrode les blocs pendant 3 tours'],
      'boulder':        ['Cria uma bola pesada temporária de dano alto', 'Spawns a temporary heavy high-damage ball', 'Crea una bola pesada temporal de daño alto', 'Crée une balle lourde temporaire à gros dégâts'],
      'earthquake':     ['Dano em toda a linha mais baixa', 'Damages the entire lowest row', 'Daño en toda la fila más baja', 'Dégâts sur toute la ligne la plus basse'],
      'fissure':        ['Corta 50% do HP dos blocos da coluna', 'Cuts 50% of the column blocks\' HP', 'Corta 50% del HP de la columna', 'Réduit de 50% les PV de la colonne'],
    };
    final t = map[id];
    return t != null ? _t(t) : '';
  }

  // ── Rewarded (fim de partida) ─────────────────────────────────────────────
  String doubleGoldAd(int amount) =>
      '▶ ${_t(['Dobrar moedas', 'Double coins', 'Duplicar monedas', 'Doubler les pièces'])} (+$amount)';

  // ── Stats ─────────────────────────────────────────────────────────────────
  String balls(int n) => '${_t(['bolas', 'balls', 'bolas', 'balles'])}: $n';
  String pts(int n)   => 'pts: $n';

  // ── Menu buttons ──────────────────────────────────────────────────────────
  String startWave(int n) =>
      '▶ ${_t(['Iniciar wave', 'Start wave', 'Iniciar oleada', 'Démarrer vague'])} $n';
  String get fightBoss =>
      '👹 ${_t(['Enfrentar Boss', 'Fight Boss', 'Enfrentar Jefe', 'Affronter Boss'])}';
  String get upgradesBtn =>
      '⬤ ${_t(['Upgrades', 'Upgrades', 'Mejoras', 'Améliorations'])}';
  String get settingsBtn =>
      '⚙ ${_t(['Configurações', 'Settings', 'Configuración', 'Paramètres'])}';

  // ── HUD ───────────────────────────────────────────────────────────────────
  String get hudStage => _t(['Fase', 'Stage', 'Etapa', 'Niveau']);
  String get hudWave  => 'wave';
  String get hudPts   => 'Pts';

  // ── Upgrade screen ────────────────────────────────────────────────────────
  String get upgradesTitle => _t(['Upgrades', 'Upgrades', 'Mejoras', 'Améliorations']);
  String get maxLevel =>      _t(['Nível máximo', 'Max level', 'Nivel máximo', 'Niveau max']);
  String get back =>          _t(['← voltar', '← back', '← volver', '← retour']);

  String upgradeLabel(String id) {
    const map = <String, List<String>>{
      'aim':       ['Mira',          'Aim',            'Mira',           'Visée'],
      'balls':     ['Bolas iniciais','Starting Balls', 'Bolas iniciales','Balles initiales'],
      'power':     ['Força',         'Power',          'Fuerza',         'Force'],
      'crit':      ['Crítico',       'Critical',       'Crítico',        'Critique'],
      'bounce':    ['Ricochete',     'Bounce',         'Rebote',         'Rebond'],
      'speed':     ['Acelerar',      'Fast Forward',   'Acelerar',       'Accélérer'],
    };
    final t = map[id];
    return t != null ? _t(t) : id;
  }

  /// O que o upgrade faz, em linguagem de jogador.
  String upgradeDesc(String id) {
    const map = <String, List<String>>{
      'aim':       ['Linha de mira mais longa', 'Longer aiming line', 'Línea de mira más larga', 'Ligne de visée plus longue'],
      'balls':     ['Bolas no início de cada fase', 'Balls at the start of each stage', 'Bolas al inicio de cada etapa', 'Balles au début de chaque niveau'],
      'power':     ['Dano de cada acerto', 'Damage per hit', 'Daño por golpe', 'Dégâts par coup'],
      'crit':      ['Chance de causar dano dobrado', 'Chance to deal double damage', 'Probabilidad de daño doble', 'Chance d\'infliger double dégâts'],
      'bounce':    ['Quiques extras mostrados na mira', 'Extra bounces shown on the aim line', 'Rebotes extra mostrados en la mira', 'Rebonds supplémentaires sur la visée'],
      'speed':     ['Botão ▶▶ no jogo: rodada em 2x', 'In-game ▶▶ button: round at 2x', 'Botón ▶▶ en el juego: ronda a 2x', 'Bouton ▶▶ en jeu : manche en 2x'],
    };
    final t = map[id];
    return t != null ? _t(t) : '';
  }

  /// Valor efetivo do upgrade, formatado. [value] é o valor do nível
  /// (null = nível 0, sem upgrade).
  String upgradeValue(String id, double? value) {
    String pct(double v) => '${(v * 100).round()}%';
    switch (id) {
      case 'aim':
        return '+${(value ?? 0).round()}';
      case 'balls':
        final n = value == null ? 1 : value.toInt() + 1;
        return '$n ${_t(n == 1 ? ['bola', 'ball', 'bola', 'balle'] : ['bolas', 'balls', 'bolas', 'balles'])}';
      case 'power':
        return '${(value ?? 1).toInt()}';
      case 'crit':
        return pct(value ?? 0);
      case 'bounce':
        return '${(value ?? 0).toInt()}';
      case 'speed':
        return '${(value ?? 1).toInt()}x';
      default:
        return value?.toString() ?? '-';
    }
  }

  // ── Stage Complete ────────────────────────────────────────────────────────
  String stageCompleteTitle(int s) {
    final label = _t(['FASE', 'STAGE', 'ETAPA', 'NIVEAU']);
    final done  = _t(['COMPLETA!', 'COMPLETE!', '¡COMPLETA!', 'TERMINÉE!']);
    return '$label $s $done';
  }
  String get nextStage =>
      _t(['Próxima Fase', 'Next Stage', 'Siguiente Etapa', 'Étape suivante']);
  String get backToMenu =>
      _t(['Menu Principal', 'Main Menu', 'Menú Principal', 'Menu Principal']);

  // ── Game Over ─────────────────────────────────────────────────────────────
  String get gameOver => 'Game Over';
  String stageWave(int s, int w, int t) {
    final sl = _t(['Fase', 'Stage', 'Etapa', 'Niveau']);
    final wl = _t(['Wave', 'Wave', 'Oleada', 'Vague']);
    return '$sl $s · $wl $w/$t';
  }
  String scoreLabel(int n) =>
      '${_t(['Pontuação', 'Score', 'Puntuación', 'Score'])}: $n';
  String goldLabel(int n) =>
      '⬤ $n ${_t(['ouro', 'gold', 'oro', 'or'])}';
  String get playAgain =>
      _t(['Jogar novamente', 'Play again', 'Jugar de nuevo', 'Rejouer']);

  // ── Pause ─────────────────────────────────────────────────────────────────
  String get paused =>       _t(['PAUSADO', 'PAUSED', 'PAUSADO', 'PAUSE']);
  String get continueGame => '▶ ${_t(['Continuar', 'Continue', 'Continuar', 'Continuer'])}';
  String get quit =>         '✕ ${_t(['Desistir', 'Quit', 'Rendirse', 'Abandonner'])}';

  // ── Settings screen ───────────────────────────────────────────────────────
  String get settingsTitle    => _t(['Configurações', 'Settings', 'Configuración', 'Paramètres']);
  String get settingsLanguage => _t(['Idioma', 'Language', 'Idioma', 'Langue']);
  String get settingsSound    => _t(['Som', 'Sound', 'Sonido', 'Son']);
  String get settingsVolume   => _t(['Volume', 'Volume', 'Volumen', 'Volume']);
  String get settingsMusic    => _t(['Música', 'Music', 'Música', 'Musique']);
  String get settingsVibration => _t(['Vibração', 'Vibration', 'Vibración', 'Vibration']);
  String get settingsSfx      => _t(['Efeitos sonoros', 'Sound effects', 'Efectos de sonido', 'Effets sonores']);

  // ── Gráficos ──────────────────────────────────────────────────────────────
  String get settingsGraphics => _t(['Gráficos', 'Graphics', 'Gráficos', 'Graphismes']);
  String qualityName(GraphicsQuality q) => switch (q) {
    GraphicsQuality.low    => _t(['Baixa', 'Low', 'Baja', 'Basse']),
    GraphicsQuality.medium => _t(['Média', 'Medium', 'Media', 'Moyenne']),
    GraphicsQuality.high   => _t(['Alta', 'High', 'Alta', 'Haute']),
  };
  String get autoQuality => _t(['Ajuste automático', 'Auto-adjust', 'Ajuste automático', 'Ajustement auto']);
  String get autoQualityHint => _t([
    'Baixa a qualidade se o jogo ficar abaixo de 45 FPS',
    'Lowers quality if the game drops below 45 FPS',
    'Baja la calidad si el juego cae por debajo de 45 FPS',
    'Baisse la qualité si le jeu passe sous 45 FPS',
  ]);
  String get fpsLock => _t(['Limitar a 30 FPS', 'Cap at 30 FPS', 'Limitar a 30 FPS', 'Limiter à 30 FPS']);
  String get fpsLockHint => _t([
    'Economiza bateria e esquenta menos',
    'Saves battery and runs cooler',
    'Ahorra batería y calienta menos',
    'Économise la batterie et chauffe moins',
  ]);

  // ── Tutorial ──────────────────────────────────────────────────────────────
  String get rankingBtn => _t(['🏆 Ranking', '🏆 Leaderboard', '🏆 Clasificación', '🏆 Classement']);
  String get rankingFailed => _t([
    'Não foi possível abrir o ranking. Entre no Google Play Games e tente de novo.',
    "Couldn't open the leaderboard. Sign in to Google Play Games and try again.",
    'No se pudo abrir la clasificación. Inicia sesión en Google Play Juegos e inténtalo de nuevo.',
    "Impossible d'ouvrir le classement. Connectez-vous à Google Play Jeux et réessayez.",
  ]);
  String get tutorialBtn =>   _t(['? Tutorial', '? Tutorial', '? Tutorial', '? Tutoriel']);
  String get tutorialTitle => _t(['TUTORIAL', 'TUTORIAL', 'TUTORIAL', 'TUTORIEL']);
  String get tutorialNext =>  _t(['Próximo →', 'Next →', 'Siguiente →', 'Suivant →']);
  String get tutorialPrev =>  _t(['← Anterior', '← Previous', '← Anterior', '← Précédent']);
  String get tutorialPlay =>  _t(['▶ Jogar!', '▶ Play!', '▶ Jugar!', '▶ Jouer!']);
  String get tutorialSkip =>  _t(['Pular', 'Skip', 'Omitir', 'Passer']);

  // Slide 1 – Como Jogar
  String get tutSlide1Title => _t(['Como Jogar', 'How to Play', 'Cómo Jugar', 'Comment Jouer']);
  String get tutSlide1Sub => _t([
    'Aponte, toque e destrua todos os blocos\nantes que alcancem o chão!',
    'Aim, tap and destroy all blocks\nbefore they reach the floor!',
    '¡Apunta, toca y destruye todos los bloques\nantes de que lleguen al suelo!',
    'Visez, touchez et détruisez tous les blocs\navant qu\'ils atteignent le sol!',
  ]);
  /// Each item is [icon, label, desc]
  List<List<String>> get tutSlide1Items => [
    ['🎯', _t(['Mirando', 'Aiming', 'Apuntando', 'Visée']),
          _t(['Arraste o dedo para definir o ângulo de tiro',
              'Drag your finger to set the shooting angle',
              'Arrastra el dedo para definir el ángulo de disparo',
              'Faites glisser le doigt pour définir l\'angle de tir'])],
    ['🔮', _t(['Lançando', 'Shooting', 'Disparando', 'Tir']),
          _t(['Solte para lançar todas as bolas de uma vez',
              'Release to launch all balls at once',
              'Suelta para lanzar todas las bolas a la vez',
              'Relâchez pour lancer toutes les balles'])],
    ['💥', _t(['Quique', 'Bounce', 'Rebote', 'Rebond']),
          _t(['As bolas ricocheteiam nas paredes e nos blocos',
              'Balls bounce off walls and blocks',
              'Las bolas rebotan en las paredes y bloques',
              'Les balles rebondissent sur les murs et blocs'])],
  ];

  // Slide 2 – Blocos Especiais
  String get tutSlide2Title => _t(['Blocos Especiais', 'Special Blocks', 'Bloques Especiales', 'Blocs Spéciaux']);
  String get tutSlide2Sub => _t([
    'Destrua blocos especiais para ganhar\npoder extra durante o jogo!',
    'Destroy special blocks to gain\nextra power during the game!',
    '¡Destruye bloques especiales para obtener\npoder extra durante el juego!',
    'Détruisez des blocs spéciaux pour obtenir\nun pouvoir supplémentaire en jeu!',
  ]);
  List<List<String>> get tutSlide2Items => [
    ['🟣', _t(['+1 Bola', '+1 Ball', '+1 Bola', '+1 Balle']),
          _t(['Ganha +1 bola até o fim da fase atual',
              'Gain +1 ball until the end of the current stage',
              'Gana +1 bola hasta el final de la etapa actual',
              'Gagnez +1 balle jusqu\'à la fin du niveau en cours'])],
    ['🟠', _t(['Ouro', 'Gold', 'Oro', 'Or']),
          _t(['Recompensa moedas para comprar upgrades',
              'Rewards coins to buy upgrades',
              'Recompensa monedas para comprar mejoras',
              'Récompense des pièces pour acheter des améliorations'])],
    ['⬜', _t(['Quadruplicar', 'Quadruple', 'Cuadruplicar', 'Quadrupler']),
          _t(['Divide a bola em 4 ao ser atingida',
              'Splits the ball into 4 when hit',
              'Divide la bola en 4 al ser golpeada',
              'Divise la balle en 4 quand elle est touchée'])],
    ['🌀', _t(['Bloco Elemental', 'Elemental Block', 'Bloque Elemental', 'Bloc Élémentaire']),
          _t(['A bola ATRAVESSA e absorve o elemento; aguenta 3 passagens',
              'The ball PASSES THROUGH and absorbs the element; lasts 3 passes',
              'La bola lo ATRAVIESA y absorbe el elemento; dura 3 pases',
              'La balle le TRAVERSE et absorbe l\'élément ; dure 3 passages'])],
    ['🎁', _t(['Power-up', 'Power-up', 'Power-up', 'Power-up']),
          _t(['Células azuis: ímã, portais, muralha, bola gigante e mais',
              'Blue cells: magnet, portals, wall, giant ball and more',
              'Celdas azules: imán, portales, muralla, bola gigante y más',
              'Cases bleues : aimant, portails, muraille, balle géante et plus'])],
    ['💣', _t(['Bomba-relógio', 'Time Bomb', 'Bomba de tiempo', 'Bombe à retardement']),
          _t(['Conta 3 turnos e explode sozinha em área',
              'Counts 3 turns and explodes on its own in an area',
              'Cuenta 3 turnos y explota sola en área',
              'Compte 3 tours puis explose en zone toute seule'])],
  ];

  // Slide 3 – Elementos e Combinações
  String get tutSlide3Title => _t(['Elementos & Combos', 'Elements & Combos', 'Elementos & Combos', 'Éléments & Combos']);
  String get tutSlide3Sub => _t([
    'A bola começa neutra. Atravesse blocos\nelementais para ganhar poder!',
    'Balls start neutral. Pass through\nelemental blocks to gain power!',
    'La bola empieza neutra. ¡Atraviesa bloques\nelementales para ganar poder!',
    'La balle commence neutre. Traversez des blocs\nélémentaires pour gagner du pouvoir!',
  ]);
  List<List<String>> get tutSlide3Items => [
    ['🔮', _t(['Absorção', 'Absorption', 'Absorción', 'Absorption']),
          _t(['Bola neutra que atravessa um bloco elemental ganha a cor dele',
              'A neutral ball passing through an elemental block takes its color',
              'La bola neutra que atraviesa un bloque elemental toma su color',
              'Une balle neutre qui traverse un bloc élémentaire prend sa couleur'])],
    ['💥', _t(['Combinação', 'Combo', 'Combinación', 'Combo']),
          _t(['Bola COM elemento × outro bloco elemental dispara um efeito',
              'An elemental ball × another elemental block triggers an effect',
              'Bola CON elemento × otro bloque elemental dispara un efecto',
              'Balle élémentaire × autre bloc élémentaire déclenche un effet'])],
    ['🔁', _t(['A ordem importa', 'Order matters', 'El orden importa', 'L\'ordre compte']),
          _t(['Fogo×Água vira Ácido; Água×Fogo vira Vapor — 25 combos',
              'Fire×Water makes Acid; Water×Fire makes Steam — 25 combos',
              'Fuego×Agua da Ácido; Agua×Fuego da Vapor — 25 combos',
              'Feu×Eau donne Acide ; Eau×Feu donne Vapeur — 25 combos'])],
    ['📖', _t(['Codex', 'Codex', 'Códice', 'Codex']),
          _t(['Cada combinação nova descoberta fica registrada no Codex',
              'Every newly discovered combo is recorded in the Codex',
              'Cada combinación nueva queda registrada en el Códice',
              'Chaque combo découvert est enregistré dans le Codex'])],
  ];

  // Slide – Status e Zonas
  String get tutSlideStatusTitle => _t(['Status & Zonas', 'Status & Zones', 'Estados & Zonas', 'Statuts & Zones']);
  String get tutSlideStatusSub => _t([
    'Combinações deixam marcas nos blocos\nque duram vários turnos!',
    'Combos leave marks on blocks\nthat last several turns!',
    '¡Las combinaciones dejan marcas en los bloques\nque duran varios turnos!',
    'Les combos laissent des marques sur les blocs\nqui durent plusieurs tours!',
  ]);
  List<List<String>> get tutSlideStatusItems => [
    ['🔥', _t(['Em chamas & ácido', 'Burning & acid', 'En llamas & ácido', 'En feu & acide']),
          _t(['O bloco perde HP a cada turno até o efeito passar',
              'The block loses HP each turn until the effect ends',
              'El bloque pierde HP cada turno hasta que pase el efecto',
              'Le bloc perd des PV à chaque tour jusqu\'à la fin de l\'effet'])],
    ['❄', _t(['Congelado & lama', 'Frozen & mud', 'Congelado & lodo', 'Gelé & boue']),
          _t(['O bloco não desce e segura a coluna inteira acima dele',
              'The block doesn\'t descend and holds the whole column above',
              'El bloque no baja y sostiene toda la columna de arriba',
              'Le bloc ne descend pas et retient toute la colonne au-dessus'])],
    ['💨', _t(['Vapor', 'Steam', 'Vapor', 'Vapeur']),
          _t(['Blocos amolecidos recebem dano dobrado por 1 turno',
              'Softened blocks take double damage for 1 turn',
              'Los bloques ablandados reciben daño doble por 1 turno',
              'Les blocs ramollis subissent le double de dégâts 1 tour'])],
    ['🟧', _t(['Zonas', 'Zones', 'Zonas', 'Zones']),
          _t(['Magma, pântano e campo elétrico agem no tabuleiro por turnos',
              'Magma, swamp and electric field act on the board for turns',
              'Magma, pantano y campo eléctrico actúan en el tablero por turnos',
              'Magma, marais et champ électrique agissent pendant des tours'])],
  ];

  // Slide – Especiais de elemento
  String get tutSlideSpecialsTitle => _t(['Especiais', 'Specials', 'Especiales', 'Spéciaux']);
  String get tutSlideSpecialsSub => _t([
    'Cada elemento tem um poder. Compre e evolua\nna tela de Upgrades e solte pelo botão!',
    'Each element has a power. Buy and level it up\nin Upgrades, then unleash it with the button!',
    'Cada elemento tiene un poder. Cómpralo y mejóralo\nen Mejoras y suéltalo con el botón!',
    'Chaque élément a un pouvoir. Achetez et améliorez-le\ndans Améliorations, puis libérez-le avec le bouton!',
  ]);
  List<List<String>> get tutSlideSpecialsItems => [
    ['⚡', _t(['Botão do especial', 'Special button', 'Botón del especial', 'Bouton du spécial']),
          _t(['Fica no canto inferior direito. Toque nos ícones ao lado para ESCOLHER qual poder usar',
              'Sits at the bottom right. Tap the icons beside it to CHOOSE which power to use',
              'Está abajo a la derecha. Toca los iconos de al lado para ELEGIR qué poder usar',
              'En bas à droite. Touchez les icônes à côté pour CHOISIR le pouvoir à utiliser'])],
    ['🔵', _t(['100 acertos', '100 hits', '100 golpes', '100 coups']),
          _t(['A cada 100 acertos de bola nos blocos, o anel do botão enche',
              'Every 100 ball hits on blocks fills the button\'s ring',
              'Cada 100 golpes de bola en los bloques llena el anillo del botón',
              'Tous les 100 coups de balle sur les blocs remplissent l\'anneau'])],
    ['👆', _t(['Ativar', 'Activate', 'Activar', 'Activer']),
          _t(['Com o anel cheio, o botão acende: toque para soltar o poder escolhido',
              'When the ring is full the button lights up: tap to unleash the chosen power',
              'Con el anillo lleno el botón se enciende: toca para soltar el poder elegido',
              'Anneau plein, le bouton s\'allume : touchez pour libérer le pouvoir choisi'])],
    ['🌊', _t(['Maré', 'Tide', 'Marea', 'Marée']),
          _t(['Onda circular que atinge tudo e empurra 1 linha para trás; precisa recarregar',
              'A circular wave that hits everything and pushes 1 row back; needs to recharge',
              'Ola circular que golpea todo y empuja 1 fila atrás; necesita recargar',
              'Vague circulaire qui frappe tout et repousse d\'une ligne ; doit se recharger'])],
    ['▶', _t(['Anúncio', 'Ad', 'Anuncio', 'Annonce']),
          _t(['Uma vez por partida: assista um anúncio e ative na hora',
              'Once per run: watch an ad and activate instantly',
              'Una vez por partida: mira un anuncio y actívalo al instante',
              'Une fois par partie : regardez une annonce et activez direct'])],
  ];

  // Slide 4 – Boss
  String get tutSlide4Title => _t(['Fases Boss', 'Boss Stages', 'Fases de Jefe', 'Niveaux Boss']);
  String get tutSlide4Sub => _t([
    'A cada 5 fases um Boss poderoso aparece.\nDerrote-o para avançar!',
    'Every 5 stages a powerful Boss appears.\nDefeat it to advance!',
    'Cada 5 fases aparece un poderoso Jefe.\n¡Derrótalo para avanzar!',
    'Toutes les 5 étapes un Boss puissant apparaît.\nDéfeated pour avancer!',
  ]);
  List<List<String>> get tutSlide4Items => [
    ['👹', _t(['Boss Central', 'Central Boss', 'Jefe Central', 'Boss Central']),
          _t(['Bloco gigante com HP muito elevado no centro',
              'Giant block with very high HP in the center',
              'Bloque gigante con HP muy alto en el centro',
              'Bloc géant avec HP très élevé au centre'])],
    ['🛡', _t(['Guardiões', 'Guardians', 'Guardianes', 'Gardiens']),
          _t(['8 blocos menores protegem o boss ao redor',
              '8 smaller blocks protect the boss around it',
              '8 bloques pequeños protegen al jefe a su alrededor',
              '8 petits blocs protègent le boss autour de lui'])],
    ['⚡', _t(['Dica', 'Tip', 'Consejo', 'Conseil']),
          _t(['Guarde o medidor do especial e as combinações para o boss',
              'Save your special meter and combos for the boss',
              'Guarda el medidor del especial y los combos para el jefe',
              'Gardez la jauge du spécial et les combos pour le boss'])],
  ];

  // Slide 5 – Upgrades
  String get tutSlide5Title => _t(['Upgrades', 'Upgrades', 'Mejoras', 'Améliorations']);
  String get tutSlide5Sub => _t([
    'Colete ouro destruindo blocos e invista\nem melhorias permanentes!',
    'Collect gold by destroying blocks and invest\nin permanent improvements!',
    '¡Recoge oro destruyendo bloques e invierte\nen mejoras permanentes!',
    'Collectez de l\'or en détruisant des blocs\net investissez en améliorations permanentes!',
  ]);
  List<List<String>> get tutSlide5Items => [
    ['◎', _t(['Mira', 'Aim', 'Mira', 'Visée']),
          _t(['Aumenta o comprimento da linha de mira',
              'Increases the length of the aiming line',
              'Aumenta la longitud de la línea de mira',
              'Augmente la longueur de la ligne de visée'])],
    ['⚡', _t(['Força & Crítico', 'Power & Crit', 'Fuerza & Crítico', 'Force & Critique']),
          _t(['Aumente o dano base e a chance de crítico',
              'Increase base damage and critical hit chance',
              'Aumenta el daño base y la probabilidad de crítico',
              'Augmentez les dégâts de base et la chance de coup critique'])],
    ['↗', _t(['Ricochete', 'Bounce', 'Rebote', 'Rebond']),
          _t(['A linha de mira mostra quiques extras nas paredes',
              'The aiming line shows extra bounces off walls',
              'La línea de mira muestra rebotes extra en las paredes',
              'La ligne de visée affiche des rebonds supplémentaires'])],
    ['🌀', _t(['Especiais', 'Specials', 'Especiales', 'Spéciaux']),
          _t(['O dano sobe a cada nível; o custo cresce rápido — invista cedo',
              'Damage rises each level; cost grows fast — invest early',
              'El daño sube por nivel; el costo crece rápido — invierte pronto',
              'Les dégâts montent par niveau ; le coût grimpe vite — investissez tôt'])],
  ];

  // ── Legend ────────────────────────────────────────────────────────────────
  String get legend => _t([
    'Aponte e toque  ●=+1 bola  ⬤=ouro  ⊙=quadruplicar',
    'Aim and tap  ●=+1 ball  ⬤=gold  ⊙=quadruple',
    'Apunta y toca  ●=+1 bola  ⬤=oro  ⊙=cuadruplicar',
    'Vise et touche  ●=+1 balle  ⬤=or  ⊙=quadrupler',
  ]);

  // ── Consentimento, compras, nuvem e ajuda ─────────────────────────────────
  String get consentTitle => _t(["Anúncios e Privacidade", "Ads and Privacy", "Anuncios y privacidad", "Annonces et confidentialité"]);
  String get consentBody => _t(["Este jogo exibe anúncios para se manter gratuito. Para oferecer anúncios relevantes, parceiros podem coletar e usar dados do seu dispositivo conforme a nossa política de privacidade.", "This game shows ads to stay free. To offer relevant ads, partners may collect and use data from your device as described in our privacy policy.", "Este juego muestra anuncios para seguir siendo gratuito. Para ofrecer anuncios relevantes, nuestros socios pueden recopilar y usar datos de tu dispositivo según nuestra política de privacidad.", "Ce jeu affiche des annonces pour rester gratuit. Pour proposer des annonces pertinentes, des partenaires peuvent collecter et utiliser des données de votre appareil conformément à notre politique de confidentialité."]);
  String get consentViewPolicy => _t(["Ver Política de Privacidade", "View Privacy Policy", "Ver política de privacidad", "Voir la politique de confidentialité"]);
  String get decline => _t(["Recusar", "Decline", "Rechazar", "Refuser"]);
  String get accept => _t(["Aceitar", "Accept", "Aceptar", "Accepter"]);
  String get consentChangeLater => _t(["Você pode alterar esta preferência a qualquer momento nas configurações.", "You can change this choice at any time in settings.", "Puedes cambiar esta preferencia en cualquier momento en los ajustes.", "Vous pouvez modifier ce choix à tout moment dans les paramètres."]);
  String get privacyPolicy => _t(["Política de Privacidade", "Privacy Policy", "Política de privacidad", "Politique de confidentialité"]);
  String get adConsentLabel => _t(["Consentimento de Anúncios: ", "Ad Consent: ", "Consentimiento de anuncios: ", "Consentement publicitaire : "]);
  String get consentAccepted => _t(["Aceito", "Accepted", "Aceptado", "Accepté"]);
  String get consentDeclined => _t(["Recusado", "Declined", "Rechazado", "Refusé"]);
  String get consentUnset => _t(["Não definido", "Not set", "Sin definir", "Non défini"]);
  String get purchasesHeader => _t(["COMPRAS", "PURCHASES", "COMPRAS", "ACHATS"]);
  String get adsRemovedDone => _t(["✓ Anúncios removidos", "✓ Ads removed", "✓ Anuncios eliminados", "✓ Annonces supprimées"]);
  String get removeAds => _t(["Remover Anúncios", "Remove Ads", "Eliminar anuncios", "Supprimer les annonces"]);
  String get waiting => _t(["Aguardando...", "Waiting...", "Esperando...", "En attente..."]);
  String get restorePurchase => _t(["Restaurar compra anterior", "Restore previous purchase", "Restaurar compra anterior", "Restaurer un achat précédent"]);
  String get cloudHeader => _t(["SAVE NA NUVEM", "CLOUD SAVE", "GUARDADO EN LA NUBE", "SAUVEGARDE CLOUD"]);
  String get playGamesSignIn => _t(["Entrar no Google Play Games", "Sign in to Google Play Games", "Iniciar sesión en Google Play Juegos", "Se connecter à Google Play Jeux"]);
  String get playGamesConnected => _t(["✓ Conectado ao Google Play Games", "✓ Connected to Google Play Games", "✓ Conectado a Google Play Juegos", "✓ Connecté à Google Play Jeux"]);
  String get cloudSignInOk => _t(["Conectado ao Google Play Games!", "Connected to Google Play Games!", "¡Conectado a Google Play Juegos!", "Connecté à Google Play Jeux !"]);
  String get cloudSignInFailed => _t(["Falha ao conectar. Tente novamente.", "Could not connect. Please try again.", "No se pudo conectar. Inténtalo de nuevo.", "Connexion impossible. Veuillez réessayer."]);
  String get cloudSave => _t(["Salvar na Nuvem", "Save to Cloud", "Guardar en la nube", "Sauvegarder"]);
  String get cloudSaving => _t(["Salvando...", "Saving...", "Guardando...", "Sauvegarde..."]);
  String get cloudSaved => _t(["Progresso salvo na nuvem!", "Progress saved to the cloud!", "¡Progreso guardado en la nube!", "Progression sauvegardée dans le cloud !"]);
  String get cloudSaveFailed => _t(["Erro ao salvar. Tente novamente.", "Could not save. Please try again.", "No se pudo guardar. Inténtalo de nuevo.", "Sauvegarde impossible. Veuillez réessayer."]);
  String get cloudRestore => _t(["Restaurar da Nuvem", "Restore from Cloud", "Restaurar de la nube", "Restaurer"]);
  String get cloudRestoring => _t(["Restaurando...", "Restoring...", "Restaurando...", "Restauration..."]);
  String get cloudRestored => _t(["Progresso restaurado da nuvem!", "Progress restored from the cloud!", "¡Progreso restaurado de la nube!", "Progression restaurée depuis le cloud !"]);
  String get cloudNoSave => _t(["Nenhum save encontrado na nuvem.", "No cloud save found.", "No se encontró ningún guardado en la nube.", "Aucune sauvegarde trouvée dans le cloud."]);
  String get cloudInvalid => _t(["Dados inválidos no save da nuvem.", "Invalid cloud save data.", "Datos no válidos en el guardado en la nube.", "Données de sauvegarde cloud non valides."]);
  String get needHelp => _t(["Precisa de ajuda?", "Need help?", "¿Necesitas ayuda?", "Besoin d'aide ?"]);
  String get helpBodyAccept => _t(["Você está nesta fase há um tempo.\nAceite a ajuda e receba:", "You've been on this stage for a while.\nAccept the help and get:", "Llevas un rato en esta etapa.\nAcepta la ayuda y recibe:", "Vous êtes sur ce niveau depuis un moment.\nAcceptez l'aide et recevez :"]);
  String get helpBodyWatch => _t(["Você está nesta fase há um tempo.\nAssista um anúncio e receba:", "You've been on this stage for a while.\nWatch an ad and get:", "Llevas un rato en esta etapa.\nMira un anuncio y recibe:", "Vous êtes sur ce niveau depuis un moment.\nRegardez une annonce et recevez :"]);
  String get helpBodyNoAd => _t(["Nenhum anúncio disponível no momento.\nTente de novo em instantes para receber:", "No ads available right now.\nTry again shortly to get:", "No hay anuncios disponibles ahora.\nInténtalo de nuevo en un momento para recibir:", "Aucune annonce disponible pour l'instant.\nRéessayez bientôt pour recevoir :"]);
  String get helpDoubleDamage => _t(["Dano dobrado", "Double damage", "Daño doble", "Dégâts doublés"]);
  String get helpCrit => _t(["+50% chance de crítico", "+50% critical chance", "+50% de probabilidad de crítico", "+50% de chance de critique"]);
  String get helpExtraBalls => _t(["+3 bolas extras", "+3 extra balls", "+3 bolas extra", "+3 balles supplémentaires"]);
  String get helpAccept => _t(["Aceitar ajuda", "Accept help", "Aceptar ayuda", "Accepter l'aide"]);
  String get watchAd => _t(["Assistir anúncio", "Watch ad", "Ver anuncio", "Regarder une annonce"]);
  String get noThanks => _t(["Não, obrigado", "No, thanks", "No, gracias", "Non merci"]);
  String get continuePlain => _t(["Continuar", "Continue", "Continuar", "Continuer"]);
  String get continueWatchAd => _t(["Continuar (assistir anúncio)", "Continue (watch ad)", "Continuar (ver anuncio)", "Continuer (regarder une annonce)"]);

  // ── Loja ──────────────────────────────────────────────────────────────────
  String get shopBtn => _t(["🛒 LOJA", "🛒 SHOP", "🛒 TIENDA", "🛒 BOUTIQUE"]);
  String get shopTitle => _t(["LOJA", "SHOP", "TIENDA", "BOUTIQUE"]);
  String get offerBadge => _t(["OFERTA", "OFFER", "OFERTA", "OFFRE"]);
  String get oneTimeOffer => _t(["OFERTA ÚNICA", "ONE-TIME OFFER", "OFERTA ÚNICA", "OFFRE UNIQUE"]);
  String get permanentTag => _t(["PERMANENTE", "PERMANENT", "PERMANENTE", "PERMANENT"]);
  String get starterTitle => _t(["Pacote Iniciante", "Starter Pack", "Paquete de inicio", "Pack de démarrage"]);
  String get starterDesc => _t([
    "+3 bolas no início de toda fase (4 em vez de 1) + skin Prisma exclusiva",
    "+3 balls at the start of every stage (4 instead of 1) + exclusive Prism skin",
    "+3 bolas al inicio de cada etapa (4 en vez de 1) + skin Prisma exclusiva",
    "+3 balles au début de chaque niveau (4 au lieu de 1) + skin Prisme exclusif",
  ]);
  String get buy => _t(["Comprar", "Buy", "Comprar", "Acheter"]);
  String get outcomeSuccess => _t(["✓ Compra concluída!", "✓ Purchase complete!", "✓ ¡Compra completada!", "✓ Achat terminé !"]);
  String get outcomePending => _t([
    "Pagamento pendente. Liberado assim que for aprovado.",
    "Payment pending. Unlocked once it's approved.",
    "Pago pendiente. Se desbloquea al aprobarse.",
    "Paiement en attente. Débloqué dès son approbation.",
  ]);
  String get outcomeCanceled => _t(["Compra cancelada.", "Purchase canceled.", "Compra cancelada.", "Achat annulé."]);
  String get outcomeError => _t([
    "Não foi possível concluir. Verifique a conexão e tente de novo.",
    "Couldn't complete. Check your connection and try again.",
    "No se pudo completar. Revisa la conexión e inténtalo de nuevo.",
    "Impossible de terminer. Vérifiez la connexion et réessayez.",
  ]);
  String get outcomeNotFound => _t([
    "Produto indisponível na loja no momento.",
    "Product not available in the store right now.",
    "Producto no disponible en la tienda por ahora.",
    "Produit indisponible dans la boutique pour le moment.",
  ]);
  String get restoreDone => _t(["Compras restauradas!", "Purchases restored!", "¡Compras restauradas!", "Achats restaurés !"]);
  String get restoreNothing => _t([
    "Nenhuma compra encontrada nesta conta.",
    "No purchases found on this account.",
    "No se encontraron compras en esta cuenta.",
    "Aucun achat trouvé sur ce compte.",
  ]);
  String get restoreFailed => _t([
    "Não foi possível restaurar. Verifique a conexão.",
    "Couldn't restore. Check your connection.",
    "No se pudo restaurar. Revisa la conexión.",
    "Restauration impossible. Vérifiez la connexion.",
  ]);
  String get promoHeader => _t(["CÓDIGO PROMOCIONAL", "PROMO CODE", "CÓDIGO PROMOCIONAL", "CODE PROMO"]);
  String get promoHint => _t(["Digite o código", "Enter the code", "Introduce el código", "Saisissez le code"]);
  String get promoRedeem => _t(["Resgatar no Google Play", "Redeem on Google Play", "Canjear en Google Play", "Utiliser sur Google Play"]);
  String get promoInfo => _t([
    "Confirme o resgate no Google Play e volte ao jogo para receber.",
    "Confirm on Google Play, then come back to the game to receive it.",
    "Confirma el canje en Google Play y vuelve al juego para recibirlo.",
    "Confirmez sur Google Play, puis revenez dans le jeu pour le recevoir.",
  ]);
  String get promoChecking => _t(["Verificando resgate...", "Checking redemption...", "Verificando canje...", "Vérification..."]);
  String get promoOpenFailed => _t([
    "Não foi possível abrir o Google Play.",
    "Couldn't open Google Play.",
    "No se pudo abrir Google Play.",
    "Impossible d'ouvrir Google Play.",
  ]);
  String promoGranted(String items) => _t([
    "✓ Código resgatado: $items",
    "✓ Code redeemed: $items",
    "✓ Código canjeado: $items",
    "✓ Code utilisé : $items",
  ]);
  String get promoNothing => _t([
    "Nenhum item novo encontrado. Se o resgate foi concluído, toque em Restaurar compra anterior em instantes.",
    "No new items found. If you completed the redemption, tap Restore previous purchase in a moment.",
    "No se encontraron artículos nuevos. Si completaste el canje, toca Restaurar compra anterior en un momento.",
    "Aucun nouvel article. Si vous avez terminé, touchez Restaurer un achat précédent dans un instant.",
  ]);
  String get skinTitle => _t(["SKIN DA BOLA", "BALL SKIN", "SKIN DE LA BOLA", "SKIN DE BALLE"]);
  String get skinClassic => _t(["Clássica", "Classic", "Clásica", "Classique"]);
  String get skinPrism => _t(["Prisma", "Prism", "Prisma", "Prisme"]);
  String get starterOfferTitle => _t(["Comece mais forte!", "Start stronger!", "¡Empieza más fuerte!", "Commencez plus fort !"]);
  String get seeOffer => _t(["Ver oferta", "See offer", "Ver oferta", "Voir l'offre"]);
  String get notNow => _t(["Agora não", "Not now", "Ahora no", "Pas maintenant"]);
  String get doublerTitle => _t(["Ouro em Dobro", "Double Gold", "Oro doble", "Or double"]);
  String get doublerDesc => _t([
    "Todo ouro dos blocos vale 2x, para sempre",
    "All gold from blocks is worth 2x, forever",
    "Todo el oro de los bloques vale 2x, para siempre",
    "Tout l'or des blocs vaut 2x, pour toujours",
  ]);
  String get removeAdsDesc => _t([
    "Sem banner nem intersticiais; ajudas sem vídeo",
    "No banner or interstitials; help without videos",
    "Sin banner ni intersticiales; ayudas sin video",
    "Ni bannière ni interstitiels ; aides sans vidéo",
  ]);
  String goldPackName(int i) => switch (i) {
    0 => _t(["Saco de Ouro", "Gold Pouch", "Bolsa de oro", "Bourse d'or"]),
    1 => _t(["Baú de Ouro", "Gold Chest", "Cofre de oro", "Coffre d'or"]),
    _ => _t(["Tesouro Elemental", "Elemental Hoard", "Tesoro elemental", "Trésor élémentaire"]),
  };
  String bonusTag(int pct) => _t(["+$pct% ouro", "+$pct% gold", "+$pct% oro", "+$pct% d'or"]);
  String get popularTag => _t(["POPULAR", "POPULAR", "POPULAR", "POPULAIRE"]);
  String get bestValueTag => _t(["MELHOR VALOR", "BEST VALUE", "MEJOR VALOR", "MEILLEUR PRIX"]);
  String get ownedTag => _t(["✓ Adquirido", "✓ Owned", "✓ Adquirido", "✓ Acquis"]);
  String get storeUnavailable => _t([
    "Loja indisponível no momento.",
    "Store unavailable right now.",
    "Tienda no disponible por ahora.",
    "Boutique indisponible pour le moment.",
  ]);
  String goldAdded(int n) => _t(["+$n ⬤ adicionados!", "+$n ⬤ added!", "¡+$n ⬤ añadidos!", "+$n ⬤ ajoutés !"]);
  String needGoldFor(int n, String upgrade) => _t([
    "Faltam ⬤ $n para $upgrade",
    "You need ⬤ $n more for $upgrade",
    "Te faltan ⬤ $n para $upgrade",
    "Il manque ⬤ $n pour $upgrade",
  ]);
  String stageGoldEarned(int n) => _t(["+$n ⬤ nesta fase", "+$n ⬤ this stage", "+$n ⬤ en esta etapa", "+$n ⬤ ce niveau"]);
  String doublerUpsell(int n) => _t([
    "Com Ouro em Dobro seriam +$n ⬤  →",
    "With Double Gold it'd be +$n ⬤  →",
    "Con Oro doble serían +$n ⬤  →",
    "Avec Or double : +$n ⬤  →",
  ]);
  String get gameOverShop => _t([
    "🛒 Fique mais forte na loja",
    "🛒 Get stronger in the shop",
    "🛒 Hazte más fuerte en la tienda",
    "🛒 Devenez plus fort à la boutique",
  ]);

  // ── Missões diárias ───────────────────────────────────────────────────────
  String get missionsBtn => '📋 ${_t(["Missões diárias", "Daily missions", "Misiones diarias", "Missions du jour"])}';
  String get missionsTitle => _t(["Missões diárias", "Daily missions", "Misiones diarias", "Missions du jour"]);
  String missionsReset(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final time = h > 0 ? '${h}h ${m}m' : '${m}m';
    return _t(["Novas missões em $time", "New missions in $time", "Nuevas misiones en $time", "Nouvelles missions dans $time"]);
  }
  String missionDesc(MissionType t, int n) => switch (t) {
    MissionType.breakBlocks => _t(["Destrua $n blocos", "Break $n blocks", "Destruye $n bloques", "Détruisez $n blocs"]),
    MissionType.earnGold => _t(["Ganhe ⬤ $n quebrando blocos", "Earn ⬤ $n breaking blocks", "Gana ⬤ $n rompiendo bloques", "Gagnez ⬤ $n en cassant des blocs"]),
    MissionType.clearStages => n == 1
        ? _t(["Conclua 1 fase", "Clear 1 stage", "Completa 1 etapa", "Terminez 1 niveau"])
        : _t(["Conclua $n fases", "Clear $n stages", "Completa $n etapas", "Terminez $n niveaux"]),
    MissionType.collectBalls => _t(["Colete $n bolas extras", "Collect $n extra balls", "Recoge $n bolas extra", "Ramassez $n balles bonus"]),
    MissionType.advantageHits => _t(["Acerte $n vezes com vantagem elemental", "Land $n hits with elemental advantage", "Acierta $n golpes con ventaja elemental", "Réussissez $n coups avec avantage élémentaire"]),
    MissionType.critHits => _t(["Acerte $n golpes críticos", "Land $n critical hits", "Acierta $n golpes críticos", "Réussissez $n coups critiques"]),
    MissionType.playRounds => _t(["Jogue $n rodadas", "Play $n rounds", "Juega $n rondas", "Jouez $n manches"]),
    MissionType.useSpecials => n == 1
        ? _t(["Use o poder especial 1 vez", "Use your special power once", "Usa el poder especial 1 vez", "Utilisez votre pouvoir spécial 1 fois"])
        : _t(["Use o poder especial $n vezes", "Use your special power $n times", "Usa el poder especial $n veces", "Utilisez votre pouvoir spécial $n fois"]),
    MissionType.triggerCombos => _t(["Dispare $n combinações elementais", "Trigger $n elemental combos", "Dispara $n combinaciones elementales", "Déclenchez $n combos élémentaires"]),
    MissionType.absorbElements => _t(["Absorva o elemento de $n blocos elementais", "Absorb the element of $n elemental blocks", "Absorbe el elemento de $n bloques elementales", "Absorbez l'élément de $n blocs élémentaires"]),
    MissionType.collectPowerUps => n == 1
        ? _t(["Colete 1 power-up", "Collect 1 power-up", "Recoge 1 power-up", "Ramassez 1 power-up"])
        : _t(["Colete $n power-ups", "Collect $n power-ups", "Recoge $n power-ups", "Ramassez $n power-ups"]),
    MissionType.statusBlocks => _t(["Aplique status em $n blocos (chamas, gelo, ácido...)", "Apply status to $n blocks (burn, freeze, acid...)", "Aplica estados a $n bloques (llamas, hielo, ácido...)", "Appliquez un statut à $n blocs (feu, gel, acide...)"]),
    MissionType.discoverCombos => n == 1
        ? _t(["Descubra 1 combinação nova no Codex", "Discover 1 new combo in the Codex", "Descubre 1 combinación nueva en el Códice", "Découvrez 1 nouveau combo dans le Codex"])
        : _t(["Descubra $n combinações novas no Codex", "Discover $n new combos in the Codex", "Descubre $n combinaciones nuevas en el Códice", "Découvrez $n nouveaux combos dans le Codex"]),
  };
  String missionDifficulty(MissionDifficulty d) => switch (d) {
    MissionDifficulty.easy => _t(["FÁCIL", "EASY", "FÁCIL", "FACILE"]),
    MissionDifficulty.medium => _t(["MÉDIA", "MEDIUM", "MEDIA", "MOYENNE"]),
    MissionDifficulty.hard => _t(["DIFÍCIL", "HARD", "DIFÍCIL", "DIFFICILE"]),
  };
  String get missionClaim => _t(["Resgatar", "Claim", "Reclamar", "Récupérer"]);
  String get missionClaimed => _t(["✓ Resgatado", "✓ Claimed", "✓ Reclamado", "✓ Récupéré"]);
  String get missionBonusTitle => _t(["Baú diário", "Daily chest", "Cofre diario", "Coffre du jour"]);
  String get missionBonusDesc => _t([
    "Resgate as 3 missões para abrir",
    "Claim all 3 missions to open",
    "Reclama las 3 misiones para abrir",
    "Récupérez les 3 missions pour ouvrir",
  ]);
  String get missionBonusOpen => _t(["Abrir", "Open", "Abrir", "Ouvrir"]);
  String get missionCompleted => _t(["✓ Missão concluída!", "✓ Mission complete!", "✓ ¡Misión completada!", "✓ Mission accomplie !"]);
}
