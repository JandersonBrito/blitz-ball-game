import 'app_settings.dart';
import 'element.dart';

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
  String get elementTitle => _t(['ELEMENTO DA BOLA', 'BALL ELEMENT', 'ELEMENTO DE LA BOLA', 'ÉLÉMENT DE BALLE']);
  String get elemNeutral =>  _t(['Neutro', 'Neutral', 'Neutro', 'Neutre']);
  String get elemFire =>     _t(['Fogo', 'Fire', 'Fuego', 'Feu']);
  String get elemWater =>    _t(['Água', 'Water', 'Agua', 'Eau']);
  String get elemWind =>     _t(['Vento', 'Wind', 'Viento', 'Vent']);

  String elemName(ElementType el) => switch (el) {
    ElementType.neutral => elemNeutral,
    ElementType.fire    => elemFire,
    ElementType.water   => elemWater,
    ElementType.wind    => elemWind,
  };

  String elemAdvantage(ElementType el) {
    final strong = _t(['forte vs', 'strong vs', 'fuerte vs', 'fort vs']);
    final weak =   _t(['fraco vs', 'weak vs', 'débil vs', 'faible vs']);
    final adv = el == ElementType.fire  ? elemWind
              : el == ElementType.water ? elemFire
              : elemWater;
    final dis = el == ElementType.fire  ? elemWater
              : el == ElementType.water ? elemWind
              : elemFire;
    return '✦ $strong $adv · $weak $dis';
  }

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
      'upg_fire':  ['Fogo+',         'Fire+',          'Fuego+',         'Feu+'],
      'upg_water': ['Água+',         'Water+',         'Agua+',          'Eau+'],
      'upg_wind':  ['Vento+',        'Wind+',          'Viento+',        'Vent+'],
      'bounce':    ['Ricochete',     'Bounce',         'Rebote',         'Rebond'],
    };
    final t = map[id];
    return t != null ? _t(t) : id;
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

  // ── Tutorial ──────────────────────────────────────────────────────────────
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
          _t(['Aumenta permanentemente sua contagem de bolas',
              'Permanently increases your ball count',
              'Aumenta permanentemente tu conteo de bolas',
              'Augmente définitivement votre nombre de balles'])],
    ['🟠', _t(['Ouro', 'Gold', 'Oro', 'Or']),
          _t(['Recompensa moedas para comprar upgrades',
              'Rewards coins to buy upgrades',
              'Recompensa monedas para comprar mejoras',
              'Récompense des pièces pour acheter des améliorations'])],
    ['⬜', _t(['Triplicar', 'Triple', 'Triplicar', 'Triple']),
          _t(['Divide a bola em 4 ao ser atingida',
              'Splits the ball into 4 when hit',
              'Divide la bola en 4 al ser golpeada',
              'Divise la balle en 4 quand elle est touchée'])],
    ['🌀', _t(['Elemento', 'Element', 'Elemento', 'Élément']),
          _t(['Muda o elemento de todas as bolas',
              'Changes the element of all balls',
              'Cambia el elemento de todas las bolas',
              'Change l\'élément de toutes les balles'])],
  ];

  // Slide 3 – Elementos
  String get tutSlide3Title => _t(['Sistema de Elementos', 'Element System', 'Sistema de Elementos', 'Système d\'Éléments']);
  String get tutSlide3Sub => _t([
    'Escolha o elemento certo para causar\nmais dano e vencer mais rápido!',
    'Choose the right element to deal\nmore damage and win faster!',
    '¡Elige el elemento correcto para causar\nmás daño y ganar más rápido!',
    'Choisissez le bon élément pour infliger\nplus de dégâts et gagner plus vite!',
  ]);
  List<List<String>> get tutSlide3Items => [
    ['🔥', _t(['Fogo → Vento', 'Fire → Wind', 'Fuego → Viento', 'Feu → Vent']),
          _t(['Fogo é forte vs Vento e fraco vs Água',
              'Fire is strong vs Wind and weak vs Water',
              'Fuego es fuerte vs Viento y débil vs Agua',
              'Le Feu est fort vs Vent et faible vs Eau'])],
    ['💧', _t(['Água → Fogo', 'Water → Fire', 'Agua → Fuego', 'Eau → Feu']),
          _t(['Água é forte vs Fogo e fraca vs Vento',
              'Water is strong vs Fire and weak vs Wind',
              'Agua es fuerte vs Fuego y débil vs Viento',
              'L\'Eau est forte vs Feu et faible vs Vent'])],
    ['🌪', _t(['Vento → Água', 'Wind → Water', 'Viento → Agua', 'Vent → Eau']),
          _t(['Vento é forte vs Água e fraco vs Fogo',
              'Wind is strong vs Water and weak vs Fire',
              'Viento es fuerte vs Agua y débil vs Fuego',
              'Le Vent est fort vs Eau et faible vs Feu'])],
    ['⚪', _t(['Neutro', 'Neutral', 'Neutro', 'Neutre']),
          _t(['Sem bônus ou penalidade — útil em qualquer fase',
              'No bonus or penalty — useful in any stage',
              'Sin bono ni penalización — útil en cualquier fase',
              'Aucun bonus ni pénalité — utile à tout niveau'])],
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
          _t(['Use upgrades de elemento para maximizar o dano',
              'Use element upgrades to maximize damage',
              'Usa mejoras de elemento para maximizar el daño',
              'Utilisez les améliorations d\'élément pour maximiser les dégâts'])],
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
    ['🔥', _t(['Bônus Elemental', 'Elemental Bonus', 'Bono Elemental', 'Bonus Élémentaire']),
          _t(['Amplifica vantagens dos elementos (Fogo+, Água+, Vento+)',
              'Amplifies element advantages (Fire+, Water+, Wind+)',
              'Amplifica las ventajas de elementos (Fuego+, Agua+, Viento+)',
              'Amplifie les avantages des éléments (Feu+, Eau+, Vent+)'])],
  ];

  // ── Legend ────────────────────────────────────────────────────────────────
  String get legend => _t([
    'Aponte e toque  ●=+1 bola  ⬤=ouro  ⊙=triplicar',
    'Aim and tap  ●=+1 ball  ⬤=gold  ⊙=triple',
    'Apunta y toca  ●=+1 bola  ⬤=oro  ⊙=triplicar',
    'Vise et touche  ●=+1 balle  ⬤=or  ⊙=tripler',
  ]);
}
