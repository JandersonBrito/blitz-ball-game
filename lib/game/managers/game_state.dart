import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool stageComplete = false;
  bool showHelpOffer = false;
  bool showWaveToast = false;
  bool assistActive = false;
  int stageRoundsPlayed = 0;
  ElementType ballElement = ElementType.neutral;
  Map<String, int> upgrades = {for (var u in upgradeDefs) u.id: 0};

  static const _kScore = 'gs_score';
  static const _kGold = 'gs_gold';
  static const _kBallCount = 'gs_ball_count';
  static const _kLevel = 'gs_level';
  static const _kWave = 'gs_wave';
  static const _kStage = 'gs_stage';
  static const _kWaveInStage = 'gs_wave_in_stage';
  static const _kWavesInStage = 'gs_waves_in_stage';
  static const _kGameOver = 'gs_game_over';
  static const _kStageComplete = 'gs_stage_complete';
  static const _kBallElement = 'gs_ball_element';

  static Future<GameState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final gs = GameState();
    gs.score = prefs.getInt(_kScore) ?? 0;
    gs.gold = prefs.getInt(_kGold) ?? 0;
    gs.ballCount = prefs.getInt(_kBallCount) ?? 1;
    gs.level = prefs.getInt(_kLevel) ?? 1;
    gs.wave = prefs.getInt(_kWave) ?? 1;
    gs.stage = prefs.getInt(_kStage) ?? 1;
    gs.waveInStage = prefs.getInt(_kWaveInStage) ?? 1;
    gs.wavesInStage = prefs.getInt(_kWavesInStage) ?? 1;
    gs.gameOver = prefs.getBool(_kGameOver) ?? false;
    gs.stageComplete = prefs.getBool(_kStageComplete) ?? false;
    final elIdx = prefs.getInt(_kBallElement) ?? 0;
    gs.ballElement = ElementType.values[elIdx.clamp(0, ElementType.values.length - 1)];
    for (final u in upgradeDefs) {
      gs.upgrades[u.id] = prefs.getInt('gs_upg_${u.id}') ?? 0;
    }
    return gs;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kScore, score);
    await prefs.setInt(_kGold, gold);
    await prefs.setInt(_kBallCount, ballCount);
    await prefs.setInt(_kLevel, level);
    await prefs.setInt(_kWave, wave);
    await prefs.setInt(_kStage, stage);
    await prefs.setInt(_kWaveInStage, waveInStage);
    await prefs.setInt(_kWavesInStage, wavesInStage);
    await prefs.setBool(_kGameOver, gameOver);
    await prefs.setBool(_kStageComplete, stageComplete);
    await prefs.setInt(_kBallElement, ballElement.index);
    for (final entry in upgrades.entries) {
      await prefs.setInt('gs_upg_${entry.key}', entry.value);
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    save();
  }

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
    final base = lvl == 0 ? 1 : upgradeDefs.firstWhere((u) => u.id == 'power').levels[lvl - 1].value.toInt();
    return assistActive ? base * 2 : base;
  }

  double get critChance {
    final lvl = upgrades['crit'] ?? 0;
    final base = lvl == 0 ? 0.0 : upgradeDefs.firstWhere((u) => u.id == 'crit').levels[lvl - 1].value;
    return assistActive ? (base + 0.5).clamp(0.0, 1.0) : base;
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
    assistActive = false;
    stageRoundsPlayed = 0;
    notifyListeners();
  }

  void advanceWave() {
    level++;
    wave++;
    waveInStage++;
    showWaveToast = true;
    notifyListeners();
  }

  void clearWaveToast() {
    showWaveToast = false;
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

  void incrementStageRounds() {
    stageRoundsPlayed++;
    if (stageRoundsPlayed >= 7 && !assistActive) {
      showHelpOffer = true;
      notifyListeners();
    }
  }

  void applyHelpAssist() {
    ballCount += 3;
    assistActive = true;
    showHelpOffer = false;
    stageRoundsPlayed = 0;
    notifyListeners();
  }

  void dismissHelpOffer() {
    showHelpOffer = false;
    stageRoundsPlayed = 0;
    notifyListeners();
  }

  void setGameOver() {
    gameOver = true;
    assistActive = false;
    stageRoundsPlayed = 0;
    notifyListeners();
  }

  void continueAfterAd() {
    gameOver = false;
    notifyListeners();
  }

  void setStageComplete() {
    stageComplete = true;
    notifyListeners();
  }

  void clearStageComplete() {
    stageComplete = false;
    notifyListeners();
  }

  void reset() {
    score = 0;
    gameOver = false;
    stageComplete = false;
    ballElement = ElementType.neutral;
    ballCount = initialBalls;
    // mantém: gold, upgrades, level, stage, wave, waveInStage, wavesInStage
    notifyListeners();
  }

  Future<void> fullReset() async {
    score = 0;
    gold = 0;
    ballCount = 1;
    level = 1;
    wave = 1;
    stage = 1;
    waveInStage = 1;
    wavesInStage = wavesForStage(1);
    gameOver = false;
    stageComplete = false;
    ballElement = ElementType.neutral;
    upgrades = {for (var u in upgradeDefs) u.id: 0};
    notifyListeners();
  }
}
