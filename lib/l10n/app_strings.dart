import '../services/settings_service.dart';

/// Simple static translation helper.
/// Usage: AppStrings.get(lang, 'key')
/// Interpolation: AppStrings.fmt(lang, 'key', ['val0', 'val1'])
class AppStrings {
  AppStrings._();

  static String get(AppLanguage lang, String key) {
    return _strings[lang]?[key] ?? _strings[AppLanguage.pt]![key] ?? key;
  }

  /// Replaces {0}, {1}, ... with the values in [args].
  static String fmt(AppLanguage lang, String key, List<String> args) {
    String s = get(lang, key);
    for (var i = 0; i < args.length; i++) {
      s = s.replaceAll('{$i}', args[i]);
    }
    return s;
  }

  static const Map<AppLanguage, Map<String, String>> _strings = {
    AppLanguage.pt: {
      // HUD
      'stage': 'Fase',
      'pts': 'Pts',
      // Pause
      'paused': 'PAUSADO',
      'resume': '▶ Continuar',
      'quit': '✕ Desistir',
      // Menu
      'boss': '👹 BOSS',
      'defeatBoss': 'derrote o boss para avançar',
      'clearAllBlocks': 'limpe todos os blocos para avançar',
      'waveOf': 'wave {0} de {1}',
      'clearToAdvance': ' · limpe tudo para avançar',
      'ballElement': 'ELEMENTO DA BOLA',
      'balls': 'bolas',
      'startWave': '▶ Iniciar wave {0}',
      'faceBoss': '👹 Enfrentar Boss',
      'upgrades': '⬤ Upgrades',
      'strongVs': 'forte vs',
      'weakVs': 'fraco vs',
      // Elements
      'el_fire': 'Fogo',
      'el_water': 'Água',
      'el_wind': 'Vento',
      'el_neutral': 'Neutro',
      // Legend
      'legend': 'Aponte e toque  •  ● roxo = +1 bola  •  ⬤ ouro  •  ⊙ branco = triplicar',
      // Settings
      'settings': 'Configurações',
      'language': 'Idioma',
      'sound': 'Som',
      'volume': 'Volume',
      'soundOn': 'Ligado',
      'soundOff': 'Desligado',
      'back': '← Voltar',
      // Game Over
      'gameOver': 'Fim de Jogo',
      'playAgain': 'Jogar novamente',
      'scoreLabel': 'Pontuação',
      'goldLabel': 'ouro',
      // Upgrades screen
      'upgradesTitle': 'Upgrades',
      'maxLevel': 'Nível máximo',
    },
    AppLanguage.en: {
      // HUD
      'stage': 'Stage',
      'pts': 'Pts',
      // Pause
      'paused': 'PAUSED',
      'resume': '▶ Resume',
      'quit': '✕ Quit',
      // Menu
      'boss': '👹 BOSS',
      'defeatBoss': 'defeat the boss to advance',
      'clearAllBlocks': 'clear all blocks to advance',
      'waveOf': 'wave {0} of {1}',
      'clearToAdvance': ' · clear all to advance',
      'ballElement': 'BALL ELEMENT',
      'balls': 'balls',
      'startWave': '▶ Start wave {0}',
      'faceBoss': '👹 Face Boss',
      'upgrades': '⬤ Upgrades',
      'strongVs': 'strong vs',
      'weakVs': 'weak vs',
      // Elements
      'el_fire': 'Fire',
      'el_water': 'Water',
      'el_wind': 'Wind',
      'el_neutral': 'Neutral',
      // Legend
      'legend': 'Aim and tap  •  ● purple = +1 ball  •  ⬤ gold  •  ⊙ white = triple',
      // Settings
      'settings': 'Settings',
      'language': 'Language',
      'sound': 'Sound',
      'volume': 'Volume',
      'soundOn': 'On',
      'soundOff': 'Off',
      'back': '← Back',
      // Game Over
      'gameOver': 'Game Over',
      'playAgain': 'Play again',
      'scoreLabel': 'Score',
      'goldLabel': 'gold',
      // Upgrades screen
      'upgradesTitle': 'Upgrades',
      'maxLevel': 'Max level',
    },
    AppLanguage.es: {
      // HUD
      'stage': 'Fase',
      'pts': 'Pts',
      // Pause
      'paused': 'PAUSADO',
      'resume': '▶ Continuar',
      'quit': '✕ Abandonar',
      // Menu
      'boss': '👹 JEFE',
      'defeatBoss': 'derrota al jefe para avanzar',
      'clearAllBlocks': 'elimina todos los bloques para avanzar',
      'waveOf': 'ola {0} de {1}',
      'clearToAdvance': ' · elimina todo para avanzar',
      'ballElement': 'ELEMENTO DE BOLA',
      'balls': 'bolas',
      'startWave': '▶ Iniciar ola {0}',
      'faceBoss': '👹 Enfrentar Jefe',
      'upgrades': '⬤ Mejoras',
      'strongVs': 'fuerte vs',
      'weakVs': 'débil vs',
      // Elements
      'el_fire': 'Fuego',
      'el_water': 'Agua',
      'el_wind': 'Viento',
      'el_neutral': 'Neutro',
      // Legend
      'legend': 'Apunta y toca  •  ● morado = +1 bola  •  ⬤ oro  •  ⊙ blanco = triplicar',
      // Settings
      'settings': 'Ajustes',
      'language': 'Idioma',
      'sound': 'Sonido',
      'volume': 'Volumen',
      'soundOn': 'Activado',
      'soundOff': 'Desactivado',
      'back': '← Volver',
      // Game Over
      'gameOver': 'Fin de Juego',
      'playAgain': 'Jugar de nuevo',
      'scoreLabel': 'Puntuación',
      'goldLabel': 'oro',
      // Upgrades screen
      'upgradesTitle': 'Mejoras',
      'maxLevel': 'Nivel máximo',
    },
    AppLanguage.fr: {
      // HUD
      'stage': 'Niveau',
      'pts': 'Pts',
      // Pause
      'paused': 'EN PAUSE',
      'resume': '▶ Reprendre',
      'quit': '✕ Abandonner',
      // Menu
      'boss': '👹 BOSS',
      'defeatBoss': 'vaincre le boss pour avancer',
      'clearAllBlocks': 'éliminez tous les blocs pour avancer',
      'waveOf': 'vague {0} sur {1}',
      'clearToAdvance': ' · éliminez tout pour avancer',
      'ballElement': 'ÉLÉMENT DE BALLE',
      'balls': 'balles',
      'startWave': '▶ Lancer vague {0}',
      'faceBoss': '👹 Affronter le Boss',
      'upgrades': '⬤ Améliorations',
      'strongVs': 'fort vs',
      'weakVs': 'faible vs',
      // Elements
      'el_fire': 'Feu',
      'el_water': 'Eau',
      'el_wind': 'Vent',
      'el_neutral': 'Neutre',
      // Legend
      'legend': 'Viser et toucher  •  ● violet = +1 balle  •  ⬤ or  •  ⊙ blanc = tripler',
      // Settings
      'settings': 'Paramètres',
      'language': 'Langue',
      'sound': 'Son',
      'volume': 'Volume',
      'soundOn': 'Activé',
      'soundOff': 'Désactivé',
      'back': '← Retour',
      // Game Over
      'gameOver': 'Fin de Partie',
      'playAgain': 'Rejouer',
      'scoreLabel': 'Score',
      'goldLabel': 'or',
      // Upgrades screen
      'upgradesTitle': 'Améliorations',
      'maxLevel': 'Niveau max',
    },
  };
}
