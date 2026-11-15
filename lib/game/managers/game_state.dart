import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ball_skin.dart';
import '../../models/element.dart';
import '../../models/upgrade.dart';
import '../config/element_config.dart';
import '../../services/daily_mission_service.dart';
import '../perf/perf_config.dart';

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
  bool helpOfferDismissed = false;
  bool freeContinueUsed = false;
  bool showWaveToast = false;
  bool assistActive = false;
  int stageRoundsPlayed = 0;
  int totalRoundsPlayed = 0;
  /// Ouro ganho jogando na fase atual (não inclui compras).
  int stageGoldEarned = 0;
  /// Partidas encerradas em game over, usado para a oferta do Pacote Iniciante.
  int gamesPlayed = 0;
  bool starterOfferSeen = false;
  /// Espelha o Pacote Iniciante do PurchaseService; não é salvo aqui, porque a
  /// fonte da verdade é a compra.
  bool starterBallsActive = false;
  BallSkin ballSkin = BallSkin.classic;
  Map<String, int> upgrades = {for (var u in upgradeDefs) u.id: 0};

  /// Nível do especial de cada elemento (0 = não comprado).
  Map<ElementType, int> specialLevels = {
    for (final e in kCombatElements) e: 0
  };

  /// Codex: bit n = combinação n já descoberta (25 bits).
  int discoveredCombos = 0;

  /// Id da combinação recém-descoberta, para o toast; limpo pela UI.
  String? comboToastId;

  /// Ouro ganho jogando na partida inteira (para o "dobrar moedas" do fim).
  int runGoldEarned = 0;

  /// Rewarded "especial imediato": uma vez por partida.
  bool specialAdUsed = false;

  /// Rewarded "dobrar moedas": uma vez por game over.
  bool runGoldDoubled = false;

  /// Medidor do especial (0..1) e elemento armado (modo meter).
  double specialMeter = 0;
  ElementType armedElement = ElementType.neutral;

  /// Turnos restantes de cooldown da Maré (especial de água).
  int tideCooldown = 0;

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
  static const _kTotalRounds = 'gs_total_rounds';
  static const _kCodex = 'gs_codex';
  static const _kRunGold = 'gs_run_gold';
  static const _kSpecialAdUsed = 'gs_sp_ad_used';
  static const _kRunGoldDoubled = 'gs_run_doubled';
  static const _kMeter = 'gs_sp_meter';
  static const _kArmed = 'gs_sp_armed';
  static const _kTideCd = 'gs_tide_cd';
  static const _kFreeContinueUsed = 'gs_free_continue_used';
  static const _kGamesPlayed = 'gs_games_played';
  static const _kStarterOfferSeen = 'gs_starter_offer_seen';
  static const _kBallSkin = 'gs_ball_skin';

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
    gs.totalRoundsPlayed = prefs.getInt(_kTotalRounds) ?? 0;
    gs.freeContinueUsed = prefs.getBool(_kFreeContinueUsed) ?? false;
    gs.gamesPlayed = prefs.getInt(_kGamesPlayed) ?? 0;
    gs.starterOfferSeen = prefs.getBool(_kStarterOfferSeen) ?? false;
    final skinIdx = prefs.getInt(_kBallSkin) ?? 0;
    gs.ballSkin = BallSkin.values[skinIdx.clamp(0, BallSkin.values.length - 1)];
    for (final u in upgradeDefs) {
      gs.upgrades[u.id] = prefs.getInt('gs_upg_${u.id}') ?? 0;
    }
    for (final e in kCombatElements) {
      gs.specialLevels[e] = prefs.getInt('gs_spec_${e.name}') ?? 0;
    }
    // Conversão dos upgrades elementais antigos (Fogo+/Água+/Vento+): o nível
    // comprado vira nível do especial do mesmo elemento, uma única vez.
    const legacy = {
      'upg_fire': ElementType.fire,
      'upg_water': ElementType.water,
      'upg_wind': ElementType.wind,
    };
    for (final entry in legacy.entries) {
      final key = 'gs_upg_${entry.key}';
      final lvl = prefs.getInt(key) ?? 0;
      if (lvl > 0) {
        final cur = gs.specialLevels[entry.value] ?? 0;
        if (lvl > cur) gs.specialLevels[entry.value] = lvl;
      }
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
    gs.discoveredCombos = prefs.getInt(_kCodex) ?? 0;
    gs.runGoldEarned = prefs.getInt(_kRunGold) ?? 0;
    gs.specialAdUsed = prefs.getBool(_kSpecialAdUsed) ?? false;
    gs.runGoldDoubled = prefs.getBool(_kRunGoldDoubled) ?? false;
    gs.specialMeter = (prefs.getDouble(_kMeter) ?? 0).clamp(0.0, 1.0);
    final armedIdx = prefs.getInt(_kArmed) ?? 0;
    gs.armedElement =
        ElementType.values[armedIdx.clamp(0, ElementType.values.length - 1)];
    gs.tideCooldown = prefs.getInt(_kTideCd) ?? 0;
    return gs;
  }

  /// Grava só as chaves que mudaram: cada `setX` é uma mensagem no platform
  /// channel e, no Android, uma regravação do arquivo de preferências.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final writes = <Future<bool>>[];
    void putInt(String key, int value) {
      if (prefs.getInt(key) != value) writes.add(prefs.setInt(key, value));
    }

    void putBool(String key, bool value) {
      if (prefs.getBool(key) != value) writes.add(prefs.setBool(key, value));
    }

    putInt(_kScore, score);
    putInt(_kGold, gold);
    putInt(_kBallCount, ballCount);
    putInt(_kLevel, level);
    putInt(_kWave, wave);
    putInt(_kStage, stage);
    putInt(_kWaveInStage, waveInStage);
    putInt(_kWavesInStage, wavesInStage);
    putBool(_kGameOver, gameOver);
    putBool(_kStageComplete, stageComplete);
    putInt(_kTotalRounds, totalRoundsPlayed);
    putBool(_kFreeContinueUsed, freeContinueUsed);
    putInt(_kGamesPlayed, gamesPlayed);
    putBool(_kStarterOfferSeen, starterOfferSeen);
    putInt(_kBallSkin, ballSkin.index);
    putInt(_kCodex, discoveredCombos);
    putInt(_kRunGold, runGoldEarned);
    putBool(_kSpecialAdUsed, specialAdUsed);
    putBool(_kRunGoldDoubled, runGoldDoubled);
    putInt(_kArmed, armedElement.index);
    putInt(_kTideCd, tideCooldown);
    if ((prefs.getDouble(_kMeter) ?? 0) != specialMeter) {
      writes.add(prefs.setDouble(_kMeter, specialMeter));
    }
    for (final entry in upgrades.entries) {
      putInt('gs_upg_${entry.key}', entry.value);
    }
    for (final entry in specialLevels.entries) {
      putInt('gs_spec_${entry.key.name}', entry.value);
    }
    await Future.wait(writes);
  }

  // ── Gravação e avisos à UI ───────────────────────────────────────────────
  //
  // Mudanças vindas da UI (compras, upgrades, fim de fase) avisam e gravam na
  // hora. As da jogada (pontos, ouro e bolas a cada acerto) só marcam sujo: o
  // jogo chama [commitGameplay] uma vez por frame, que avisa o HUD no máximo
  // a cada 100 ms e grava no máximo a cada 2 s de jogo; o fim da rodada
  // chama [flush]. Antes, cada acerto gravava 25 chaves.

  bool _uiDirty = false;
  bool _unsaved = false;
  double _lastNotifyAt = double.negativeInfinity;
  double _lastSaveAt = 0;
  Future<void>? _saving;
  bool _saveAgain = false;

  @override
  void notifyListeners() {
    _uiDirty = false;
    super.notifyListeners();
    _unsaved = true;
    _requestSave();
  }

  void _gameplayChanged() {
    _uiDirty = true;
    _unsaved = true;
  }

  /// Chamado pelo jogo a cada frame, com o relógio do jogo em segundos.
  /// Cada partida nova recomeça o relógio: tempo "voltando" conta como
  /// intervalo vencido.
  void commitGameplay(double now) {
    // 1 ms de folga: 6 frames de 1/60 s somam 0,0999… e não 0,1.
    const slack = 0.001;
    final sinceNotify = now - _lastNotifyAt;
    if (_uiDirty &&
        (sinceNotify < 0 || sinceNotify >= PerfConfig.uiNotifyInterval - slack)) {
      _lastNotifyAt = now;
      _uiDirty = false;
      super.notifyListeners(); // só a UI; a gravação tem o próprio ritmo
    }
    final sinceSave = now - _lastSaveAt;
    if (_unsaved &&
        (sinceSave < 0 || sinceSave >= PerfConfig.saveInterval - slack)) {
      _lastSaveAt = now;
      _requestSave();
    }
  }

  /// Avisa a UI e grava agora o que estiver pendente (fim de rodada, app indo
  /// para segundo plano).
  Future<void> flush() {
    if (_uiDirty) {
      _uiDirty = false;
      super.notifyListeners();
    }
    if (_unsaved) _requestSave();
    return _saving ?? Future<void>.value();
  }

  /// No máximo uma gravação em andamento; pedidos no meio viram uma só depois.
  void _requestSave() {
    if (_saving != null) {
      _saveAgain = true;
      return;
    }
    _saving = _runSaves();
  }

  Future<void> _runSaves() async {
    try {
      do {
        _saveAgain = false;
        _unsaved = false;
        await save();
      } while (_saveAgain);
    } catch (e) {
      debugPrint('GameState: falha ao gravar: $e');
    } finally {
      _saving = null;
    }
  }

  bool get isBossStage => stage % 5 == 0;
  bool get isCorridorStage => stage % 3 == 0 && stage % 5 != 0;

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

  /// Bolas no início de cada fase/wave: upgrade + bônus do Pacote Iniciante.
  int get initialBalls => baseInitialBalls + (starterBallsActive ? 3 : 0);

  int get baseInitialBalls {
    final lvl = upgrades['balls'] ?? 0;
    if (lvl == 0) return 1;
    return upgradeDefs.firstWhere((u) => u.id == 'balls').levels[lvl - 1].value.toInt() + 1;
  }

  /// A Prisma só aparece enquanto o Pacote Iniciante estiver ativo.
  BallSkin get activeSkin => starterBallsActive ? ballSkin : BallSkin.classic;

  void selectSkin(BallSkin skin) {
    ballSkin = skin;
    notifyListeners();
  }

  /// Chamado quando a compra muda; no menu, já mostra a nova contagem de bolas.
  void setStarterBalls(bool active, {required bool inMenu}) {
    if (starterBallsActive == active) return;
    final wasInitial = ballCount == initialBalls;
    starterBallsActive = active;
    if (active && ballSkin == BallSkin.classic) ballSkin = BallSkin.prism;
    if (inMenu && wasInitial) ballCount = initialBalls;
    notifyListeners();
  }

  /// A oferta aparece uma única vez, depois da 3ª partida.
  bool get shouldOfferStarter => gamesPlayed >= 3 && !starterOfferSeen;

  void markStarterOfferSeen() {
    starterOfferSeen = true;
    notifyListeners();
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

  // ── Especiais de elemento ────────────────────────────────────────────────

  int specialLevel(ElementType e) => specialLevels[e] ?? 0;

  /// Algum especial de elemento já foi comprado?
  bool get ownsAnySpecial {
    for (var k = 0; k < kCombatElements.length; k++) {
      if ((specialLevels[kCombatElements[k]] ?? 0) > 0) return true;
    }
    return false;
  }

  /// Quantas das 25 combinações já foram descobertas no Codex.
  int get discoveredComboCount {
    var n = 0;
    for (var v = discoveredCombos; v != 0; v &= v - 1) {
      n++;
    }
    return n;
  }

  bool buySpecial(ElementType e) {
    final lvl = specialLevel(e);
    if (lvl >= ElementConfig.specialMaxLevel) return false;
    final cost = ElementConfig.specialCost(lvl + 1);
    if (gold < cost) return false;
    gold -= cost;
    specialLevels[e] = lvl + 1;
    notifyListeners();
    return true;
  }

  /// Conta [hits] acertos no medidor (modo meter): [ElementConfig.hitsToFillMeter]
  /// acertos enchem. Só carrega se algum especial foi comprado. Caminho da
  /// jogada: sem notify imediato (o HUD atualiza no commitGameplay).
  void addSpecialHits(int hits) {
    if (hits <= 0 || specialMeter >= 1) return;
    // Laço indexado: este método roda a cada acerto, sem alocar iterador.
    var owned = false;
    for (var k = 0; k < kCombatElements.length; k++) {
      if ((specialLevels[kCombatElements[k]] ?? 0) > 0) {
        owned = true;
        break;
      }
    }
    if (!owned) return;
    specialMeter =
        (specialMeter + hits / ElementConfig.hitsToFillMeter).clamp(0.0, 1.0);
    _gameplayChanged();
  }

  /// O jogador escolhe qual poder o botão do especial usa. Só vale para
  /// especiais já comprados. Vem da UI: avisa e grava na hora.
  void selectSpecial(ElementType el) {
    if (specialLevel(el) <= 0 || armedElement == el) return;
    armedElement = el;
    notifyListeners();
  }

  void consumeSpecialMeter() {
    specialMeter = 0;
    _gameplayChanged();
  }

  // ── Codex de combinações ─────────────────────────────────────────────────

  bool comboDiscovered(int index) => discoveredCombos & (1 << index) != 0;

  /// Marca a combinação como descoberta; true se é a primeira vez.
  bool discoverCombo(int index, String id) {
    final bit = 1 << index;
    if (discoveredCombos & bit != 0) return false;
    discoveredCombos |= bit;
    comboToastId = id;
    _gameplayChanged();
    return true;
  }

  void clearComboToast() => comboToastId = null;

  /// Aviso curto durante a partida: 'pu:<índice do PowerUpKind>' ao coletar um
  /// power-up, 'sp:<índice do ElementType>' ao disparar um especial. A tela
  /// lê e limpa ([clearAnnounce]).
  String? announceKey;

  void announce(String key) {
    announceKey = key;
    _uiDirty = true; // só a UI; nada para gravar
  }

  void clearAnnounce() => announceKey = null;

  bool get speedUnlocked => (upgrades['speed'] ?? 0) > 0;
  bool fastForward = false;
  bool get fastForwardActive => fastForward && speedUnlocked;
  void toggleFastForward() {
    if (!speedUnlocked) return;
    fastForward = !fastForward;
    notifyListeners();
  }

  void addGold(int amount) { gold += amount; notifyListeners(); }

  /// Ouro vindo dos blocos; [multiplier] vem do "Ouro em Dobro".
  /// Caminho da jogada: a UI fica sabendo no próximo [commitGameplay].
  void earnGold(int base, {int multiplier = 1}) {
    final amount = base * multiplier;
    gold += amount;
    stageGoldEarned += amount;
    runGoldEarned += amount;
    _gameplayChanged();
  }

  /// Caminho da jogada: a UI fica sabendo no próximo [commitGameplay].
  void addScore(int amount) {
    score += amount;
    _gameplayChanged();
  }

  /// Caminho da jogada: a UI fica sabendo no próximo [commitGameplay].
  void incrementBallCount() {
    ballCount++;
    _gameplayChanged();
  }

  void advanceStage() {
    ballCount = initialBalls;
    stage++;
    level++;
    wave++;
    waveInStage = 1;
    wavesInStage = wavesForStage(stage);
    assistActive = false;
    helpOfferDismissed = false;
    stageRoundsPlayed = 0;
    stageGoldEarned = 0;
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

  /// Returns true when an interstitial ad should be shown (every 10 rounds).
  bool incrementTotalRounds() {
    totalRoundsPlayed++;
    return totalRoundsPlayed % 10 == 0;
  }

  /// Sem vídeo disponível a oferta fica para uma próxima rodada da fase.
  void incrementStageRounds({required bool canOfferHelp}) {
    stageRoundsPlayed++;
    final threshold = isBossStage ? 3 : 7;
    if (canOfferHelp && stageRoundsPlayed >= threshold && !assistActive && !helpOfferDismissed) {
      showHelpOffer = true;
      notifyListeners();
    }
  }

  void applyHelpAssist() {
    ballCount += isBossStage ? 5 : 3;
    assistActive = true;
    showHelpOffer = false;
    stageRoundsPlayed = 0;
    notifyListeners();
  }

  void dismissHelpOffer() {
    showHelpOffer = false;
    helpOfferDismissed = true;
    stageRoundsPlayed = 0;
    notifyListeners();
  }

  void setGameOver() {
    gameOver = true;
    gamesPlayed++;
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
    freeContinueUsed = false;
    stageGoldEarned = 0;
    runGoldEarned = 0;
    specialAdUsed = false;
    runGoldDoubled = false;
    specialMeter = 0;
    armedElement = ElementType.neutral;
    tideCooldown = 0;
    ballCount = initialBalls;
    // mantém: gold, upgrades, level, stage, wave, waveInStage, wavesInStage
    notifyListeners();
  }

  /// Exports the current progress as a base64 string the user can copy.
  String exportBackupCode() {
    final data = {
      'score': score,
      'gold': gold,
      'ballCount': ballCount,
      'level': level,
      'wave': wave,
      'stage': stage,
      'waveInStage': waveInStage,
      'wavesInStage': wavesInStage,
      'totalRoundsPlayed': totalRoundsPlayed,
      'upgrades': {for (final e in upgrades.entries) e.key: e.value},
      'specials': {
        for (final e in specialLevels.entries) e.key.name: e.value
      },
      'codex': discoveredCombos,
      // Missões com o dia: restaurar no mesmo dia não libera resgatar de novo.
      'missions': DailyMissionService.instance.exportState(),
    };
    return base64Encode(utf8.encode(jsonEncode(data)));
  }

  /// Applies a backup code exported by [exportBackupCode]. Returns true on success.
  bool applyBackupCode(String code) {
    try {
      final json = jsonDecode(utf8.decode(base64Decode(code))) as Map<String, dynamic>;
      score         = json['score']          as int? ?? score;
      gold          = json['gold']           as int? ?? gold;
      ballCount     = json['ballCount']      as int? ?? ballCount;
      level         = json['level']          as int? ?? level;
      wave          = json['wave']           as int? ?? wave;
      stage         = json['stage']          as int? ?? stage;
      waveInStage   = json['waveInStage']    as int? ?? waveInStage;
      wavesInStage  = json['wavesInStage']   as int? ?? wavesInStage;
      totalRoundsPlayed = json['totalRoundsPlayed'] as int? ?? totalRoundsPlayed;
      final upgs = json['upgrades'] as Map<String, dynamic>?;
      if (upgs != null) {
        for (final e in upgs.entries) {
          if (upgrades.containsKey(e.key)) upgrades[e.key] = e.value as int;
        }
      }
      final specs = json['specials'] as Map<String, dynamic>?;
      if (specs != null) {
        for (final el in kCombatElements) {
          final lvl = specs[el.name] as int?;
          if (lvl != null) {
            specialLevels[el] =
                lvl.clamp(0, ElementConfig.specialMaxLevel);
          }
        }
      }
      discoveredCombos = json['codex'] as int? ?? discoveredCombos;
      DailyMissionService.instance
          .applyBackup(json['missions'] as Map<String, dynamic>?);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
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
    helpOfferDismissed = false;
    freeContinueUsed = false;
    upgrades = {for (var u in upgradeDefs) u.id: 0};
    specialLevels = {for (final e in kCombatElements) e: 0};
    discoveredCombos = 0;
    runGoldEarned = 0;
    specialAdUsed = false;
    runGoldDoubled = false;
    specialMeter = 0;
    armedElement = ElementType.neutral;
    tideCooldown = 0;
    notifyListeners();
  }
}
