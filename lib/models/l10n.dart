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

  // ── Legend ────────────────────────────────────────────────────────────────
  String get legend => _t([
    'Aponte e toque  ●=+1 bola  ⬤=ouro  ⊙=triplicar',
    'Aim and tap  ●=+1 ball  ⬤=gold  ⊙=triple',
    'Apunta y toca  ●=+1 bola  ⬤=oro  ⊙=triplicar',
    'Vise et touche  ●=+1 balle  ⬤=or  ⊙=tripler',
  ]);
}
