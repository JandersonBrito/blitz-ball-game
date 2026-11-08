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

  /// O que o upgrade faz, em linguagem de jogador.
  String upgradeDesc(String id) {
    const map = <String, List<String>>{
      'aim':       ['Linha de mira mais longa', 'Longer aiming line', 'Línea de mira más larga', 'Ligne de visée plus longue'],
      'balls':     ['Bolas no início de cada fase', 'Balls at the start of each stage', 'Bolas al inicio de cada etapa', 'Balles au début de chaque niveau'],
      'power':     ['Dano de cada acerto', 'Damage per hit', 'Daño por golpe', 'Dégâts par coup'],
      'crit':      ['Chance de causar dano dobrado', 'Chance to deal double damage', 'Probabilidad de daño doble', 'Chance d\'infliger double dégâts'],
      'upg_fire':  ['Dano do Fogo contra Vento (vantagem)', 'Fire damage vs Wind (advantage)', 'Daño de Fuego contra Viento (ventaja)', 'Dégâts du Feu contre le Vent (avantage)'],
      'upg_water': ['Dano da Água contra Vento (desvantagem)', 'Water damage vs Wind (disadvantage)', 'Daño de Agua contra Viento (desventaja)', 'Dégâts de l\'Eau contre le Vent (désavantage)'],
      'upg_wind':  ['Chance do Vento ignorar desvantagem', 'Chance for Wind to ignore disadvantage', 'Probabilidad de que el Viento ignore la desventaja', 'Chance que le Vent ignore le désavantage'],
      'bounce':    ['Quiques extras mostrados na mira', 'Extra bounces shown on the aim line', 'Rebotes extra mostrados en la mira', 'Rebonds supplémentaires sur la visée'],
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
      case 'upg_fire':
        return pct(value ?? 1.5);
      case 'upg_water':
        return pct(value ?? 0.5);
      case 'upg_wind':
        return pct(value ?? 0);
      case 'bounce':
        return '${(value ?? 0).toInt()}';
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
  String get settingsSfx      => _t(['Efeitos sonoros', 'Sound effects', 'Efectos de sonido', 'Effets sonores']);

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
  String get backupHeader => _t(["BACKUP DE PROGRESSO", "PROGRESS BACKUP", "COPIA DE SEGURIDAD", "SAUVEGARDE DE PROGRESSION"]);
  String get copyCode => _t(["Copiar Código", "Copy Code", "Copiar código", "Copier le code"]);
  String get restore => _t(["Restaurar", "Restore", "Restaurar", "Restaurer"]);
  String get pasteCodeHint => _t(["Cole o código aqui", "Paste the code here", "Pega el código aquí", "Collez le code ici"]);
  String get confirmRestore => _t(["Confirmar Restauração", "Confirm Restore", "Confirmar restauración", "Confirmer la restauration"]);
  String get codeCopied => _t(["Código copiado! Cole em outro aparelho para restaurar.", "Code copied! Paste it on another device to restore.", "¡Código copiado! Pégalo en otro dispositivo para restaurar.", "Code copié ! Collez-le sur un autre appareil pour restaurer."]);
  String get invalidCode => _t(["Código inválido. Verifique e tente novamente.", "Invalid code. Check it and try again.", "Código no válido. Compruébalo e inténtalo de nuevo.", "Code non valide. Vérifiez-le et réessayez."]);
  String get restoreSuccess => _t(["Progresso restaurado com sucesso!", "Progress restored successfully!", "¡Progreso restaurado correctamente!", "Progression restaurée avec succès !"]);
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
}
