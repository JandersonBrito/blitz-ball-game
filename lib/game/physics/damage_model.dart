import 'dart:math';
import 'dart:typed_data';
import '../../models/element.dart';
import '../managers/game_state.dart';

/// Tabelas de dano calculadas uma vez por rodada (upgrades e ajuda não mudam
/// no meio dela). Cada acerto só faz contas e sorteios: nada de procurar
/// upgrade em lista, criar `Random` ou consultar mapas.
///
/// Segue as mesmas regras de [GameState.calcElemMult]: o teste
/// damage_model_test garante que as duas não se separem.
class DamageModel {
  DamageModel([Random? rng]) : _rng = rng ?? Random();

  final Random _rng;
  int base = 1;
  double critChance = 0;

  /// Multiplicador elemental já com os upgrades, por [atacante * 4 + defensor].
  final Float64List _mult = Float64List(16);

  /// Multiplicador elemental puro (sem upgrades), usado pelos muros.
  final Float64List _raw = Float64List(16);

  /// Chance do vento ignorar a desvantagem.
  final Float64List _bypass = Float64List(16);

  // Resultado do último [roll], em campos para não alocar uma tupla por acerto.
  bool lastCrit = false;
  bool lastAdvantage = false;

  void refresh(GameState gs) {
    base = gs.baseDamage;
    critChance = gs.critChance;
    final fire = gs.getUpgradeValue('upg_fire');
    final water = gs.getUpgradeValue('upg_water');
    final wind = gs.getUpgradeValue('upg_wind');
    for (final atk in ElementType.values) {
      for (final def in ElementType.values) {
        final k = atk.index * 4 + def.index;
        final raw = getElementMult(atk, def);
        var m = raw;
        var bypass = 0.0;
        if (atk == ElementType.wind && raw < 1 && wind > 0) bypass = wind;
        if (atk == ElementType.fire && raw > 1 && fire > 0) m = fire;
        if (atk == ElementType.water && raw < 1 && water > 0) m = water;
        _raw[k] = raw;
        _mult[k] = m;
        _bypass[k] = bypass;
      }
    }
  }

  double rawMult(int atk, int def) => _raw[atk * 4 + def];

  /// Dano de uma bola (peso 1) do elemento [atk] num bloco do elemento [def].
  int roll(int atk, int def) {
    final k = atk * 4 + def;
    var m = _mult[k];
    final bypass = _bypass[k];
    if (bypass > 0 && _rng.nextDouble() < bypass) m = 1.0;
    final crit = critChance > 0 && _rng.nextDouble() < critChance;
    lastCrit = crit;
    lastAdvantage = m > 1;
    return (base * m * (crit ? 2 : 1)).ceil();
  }
}
