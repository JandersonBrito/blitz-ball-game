import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/element.dart';
import '../../models/upgrade.dart';

class GameState extends ChangeNotifier {
  int score = 0;
  int gold = 0;
  int ballCount = 1;
  int level = 1;
  int wave = 1;
  int stage = 1;
  int waveInStage = 1;
  int wavesInStage = 1;
  bool gameOver = false;
  ElementType ballElement = ElementType.neutral;
  Map<String, int> upgrades = {for (var u in upgradeDefs) u.id: 0};

  bool get isBossStage => stage % 5 == 0;

  int wavesForStage(int s) => ((s - 1) ~/ 10) + 1;

  double getUpgradeValue(String id) {
    final lvl = upgrades[id] ?? 0;
    if (lvl == 0) return 0;
    final def = upgradeDefs.firstWhere((u) => u.id == id);
    return def.levels[lvl - 1].value;
  }

  int get baseDamage {
    final lvl = upgrades['power'] ?? 0;
    if (lvl == 0) return 1;
    return upgradeDefs.firstWhere((u) => u.id == 'power').levels[lvl - 1].value.toInt();
  }

  double get critChance {
    final lvl = upgrades['crit'] ?? 0;
    if (lvl == 0) return 0;
    return upgradeDefs.firstWhere((u) => u.id == 'crit').levels[lvl - 1].value;
  }

  double get aimBonus {
    final lvl = upgrades['aim'] ?? 0;
    if (lvl == 0) return 0;
    return upgradeDefs.firstWhere((u) => u.id == 'aim').levels[lvl - 1].value;
  }

  int get maxBounces {
    final lvl = upgrades['bounce'] ?? 0;
    if (lvl == 0) return 0;
    return upgradeDefs.firstWhere((u) => u.id == 'bounce').levels[lvl - 1].value.toInt();
  }

  int get initialBalls {
    final lvl = upgrades['balls'] ?? 0;
    if (lvl == 0) return 1;
    return upgradeDefs.firstWhere((u) => u.id == 'balls').levels[lvl - 1].value.toInt() + 1;
  }

  double calcElemMult(ElementType atk, ElementType def) {
    // wind bypass
    final windLvl = upgrades['upg_wind'] ?? 0;
    if (atk == ElementType.wind && windLvl > 0) {
      final bypass = upgradeDefs.firstWhere((u) => u.id == 'upg_wind').levels[windLvl - 1].value;
      if (Random().nextDouble() < bypass) return 1.0;
    }
    double m = getElementMult(atk, def);
    final fireLvl = upgrades['upg_fire'] ?? 0;
    if (atk == ElementType.fire && m > 1 && fireLvl > 0) {
      m = upgradeDefs.firstWhere((u) => u.id == 'upg_fire').levels[fireLvl - 1].value;
    }
    final waterLvl = upgrades['upg_water'] ?? 0;
    if (atk == ElementType.water && m < 1 && waterLvl > 0) {
      m = upgradeDefs.firstWhere((u) => u.id == 'upg_water').levels[waterLvl - 1].value;
    }
    return m;
  }

  bool buyUpgrade(String id) {
    final def = upgradeDefs.firstWhere((u) => u.id == id, orElse: () => throw Exception('Unknown upgrade $id'));
    final lvl = upgrades[id] ?? 0;
    if (lvl >= def.levels.length) return false;
    final cost = def.levels[lvl].cost;
    if (gold < cost) return false;
    gold -= cost;
    upgrades[id] = lvl + 1;
    notifyListeners();
    return true;
  }

  void addGold(int amount) { gold += amount; notifyListeners(); }
  void addScore(int amount) { score += amount; notifyListeners(); }
  void incrementBallCount() { ballCount++; notifyListeners(); }

  void advanceStage() {
    ballCount = initialBalls;
    stage++;
    level++;
    wave++;
    waveInStage = 1;
    wavesInStage = wavesForStage(stage);
    notifyListeners();
  }

  void advanceWave() {
    level++;
    wave++;
    waveInStage++;
    notifyListeners();
  }

  void repeatWave() {
    level++;
    wave++;
    notifyListeners();
  }

  void startWave() {
    ballCount = initialBalls;
    notifyListeners();
  }

  void setGameOver() {
    gameOver = true;
    notifyListeners();
  }

  void reset() {
    score = 0;
    gold = 0;
    ballCount = 1;
    level = 1;
    wave = 1;
    stage = 1;
    waveInStage = 1;
    wavesInStage = wavesForStage(1);
    gameOver = false;
    ballElement = ElementType.neutral;
    upgrades = {for (var u in upgradeDefs) u.id: 0};
    notifyListeners();
  }
}
