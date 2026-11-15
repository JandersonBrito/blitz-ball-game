import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'combos/combo_defs.dart';
import 'combos/zone_system.dart';
import 'components/block_component.dart';
import 'config/element_config.dart';
import 'effects/particle_pool.dart';
import 'managers/block_factory.dart';
import 'managers/game_state.dart';
import 'perf/adaptive_quality.dart';
import 'perf/frame_pacer.dart';
import 'perf/perf_config.dart';
import 'physics/ball_pool.dart';
import 'physics/block_grid.dart';
import 'physics/damage_model.dart';
import 'render/game_renderer.dart';
import 'render/sprite_atlas.dart';
import '../models/daily_mission.dart';
import '../models/element.dart';
import '../models/graphics_quality.dart';
import '../services/ad_service_mobile.dart';
import '../services/audio_service.dart';
import '../services/daily_mission_service.dart';
import '../services/haptic_service.dart';
import '../services/purchase_service.dart';
import '../services/settings_service.dart';

enum GamePhase { menu, aim, shooting, returning, gameOver, stageComplete }

/// Jogo: máquina de fases, física das bolas e regras de dano.
///
/// Performance:
/// - Física própria (círculo × retângulo) com passo fixo de 120 Hz e substeps:
///   o resultado não depende do FPS e nenhuma bola atravessa bloco.
/// - Cada bola só testa as células do grid em volta dela.
/// - Bolas em estrutura de arrays ([BallPool]); acima de
///   [PerfConfig.ballGroupThreshold] elas saem agrupadas, com peso.
/// - Nada é alocado em update/render. O desenho é do [GameRenderer].
/// - Fora da jogada (menu, game over, fim de fase) o motor para: o último
///   frame fica na tela e não se gasta bateria redesenhando o mesmo quadro.
class BallzFlameGame extends FlameGame {
  BallzFlameGame({required this.gameState, this.settings, Random? random})
      : _rng = random ?? Random() {
    _damage = DamageModel(_rng);
  }

  final GameState gameState;

  /// Qualidade, ajuste automático e limite de 30 FPS. Null nos testes.
  final SettingsService? settings;

  // constants
  static const double blockSize = 38.0;
  static const double topOffset = 48.0; // espaço reservado para o HUD
  static const int cols = 9;
  static const int rows = 13;
  static const double ballSpeed = 550.0;
  static const double baseAimLength = 160.0; // px de mira sem upgrade
  static const double ballRadius = 5.0;

  /// Ângulo mínimo (rad) em relação à horizontal e à vertical. Igual ao limite
  /// da mira; impede bolas andando retas de parede a parede para sempre.
  static const double minBallAngle = 0.15;

  /// Tempo sem acertar um bloco quebrável até a bola ser desviada.
  static const double stuckTimeout = 4.0;

  /// Blocos com mais ouro que isto perdem 1 a cada rodada em que descem.
  static const int goldDecayFloor = 5;

  static const double shotInterval = 0.08;

  static final double _minComp = sin(minBallAngle);
  static final double _maxComp = cos(minBallAngle);
  static const double _fixedDt = PerfConfig.fixedDt;
  static final int _substeps =
      (ballSpeed * _fixedDt / PerfConfig.maxTravelPerSubstep).ceil();
  static const List<double> _tripleFallback = [-pi / 3, -pi / 6, pi / 6, pi / 3];

  final Random _rng;
  late final DamageModel _damage;

  late double floorY;
  double originX = 0;
  bool _floorReady = false;

  GamePhase phase = GamePhase.menu;
  double? aimAngle;

  final List<BlockComponent> blocks = [];
  final BallPool balls = BallPool();
  final ShotQueue _queue = ShotQueue();
  final ParticlePool particles = ParticlePool(QualityProfile.high.maxParticles);
  final BlockGrid _grid = BlockGrid(
    cols: cols,
    cellSize: blockSize,
    originX: 1,
    originY: topOffset + 1,
  );

  // Set when boss dies inside ball loop — forceReturn called after loop exits
  bool _pendingForceReturn = false;

  /// A bola testada neste substep ainda está em contato com o especial que ela
  /// lembra ([BallPool.lastSpecial])? Zerado em [_collideBlocks].
  bool _touchingSpecial = false;

  /// Linhas surgidas desde o último bloco especial (cadência da spec:
  /// no máximo 1 a cada [ElementConfig.specialMinRowGap] linhas).
  int _rowsSinceSpecial = ElementConfig.specialMinRowGap;

  /// Zonas persistentes (magma, pântano, campo elétrico, raios, tornado).
  final ZoneSystem zones = ZoneSystem();

  // ── Linha de fogo (especial do Fogo) ──────────────────────────────────────
  /// Posição Y da frente de fogo, subindo do chão ao topo; negativo = inativa.
  /// Lida pelo renderer.
  double fireWaveY = -1;
  int _fireWaveId = 0;
  int _fireWaveDmg = 0;

  // ── Rajada (especial do Vento): lâminas girando que cruzam a tela. ───────
  /// Tempo desde o início; negativo = inativa. Lido pelo renderer.
  double windElapsed = -1;
  int windBladeLanes = 0;
  int _windWaveId = 0;
  int _windDmg = 0;
  static const int _maxWindLanes = 24;

  /// Posição de cada lâmina e direção (+1 → direita, -1 → esquerda,
  /// 0 = ainda não saiu ou já passou). Lidos pelo renderer.
  final Float32List windBladeX = Float32List(_maxWindLanes);
  final Float32List windBladeY = Float32List(_maxWindLanes);
  final Int8List windBladeDir = Int8List(_maxWindLanes);

  // ── Descarga (especial do Raio): raio do céu que salta de bloco em bloco.
  /// Tempo desde o início; negativo = inativa. Lido pelo renderer.
  double boltClock = -1;

  /// Pontos do raio já revelados (0 = céu, depois cada bloco atingido) e o
  /// instante (animTime) em que cada um nasceu, para o clarão do impacto.
  int boltCount = 0;
  static const int _maxBoltPts = 20;
  final Float32List boltX = Float32List(_maxBoltPts);
  final Float32List boltY = Float32List(_maxBoltPts);
  final Float32List boltBorn = Float32List(_maxBoltPts);
  final Int32List _boltVisited = Int32List(16);
  int _boltTargets = 0;
  int _boltJumps = 0;
  int _boltDmg = 0;
  double _boltNextAt = 0;
  double _boltEndClock = -1;

  // ── Impacto (especial da Terra): rocha cai e uma onda de choque abre. ─────
  /// Tempo desde o início; negativo = inativo. Lido pelo renderer.
  double quakeT = -1;
  double quakeX = 0, quakeY = 0;
  bool _quakeLanded = false;
  int _quakeDmg = 0;
  double _quakePct = 0;

  // ── Maré (especial da Água): onda circular a partir do ponto de lançamento.
  /// Raio atual da onda; negativo = inativa. Lido pelo renderer.
  double tideRadius = -1;
  double tideOriginX = 0, tideOriginY = 0;
  double _tideMaxRadius = 0;
  int _tideWaveId = 0;
  int _tideDmg = 0;

  /// Progresso do medidor do especial (0..1), publicado A CADA FRAME para o
  /// anel do botão crescer a cada acerto (o aviso normal da UI é limitado a
  /// 10 Hz). Só notifica quando o valor muda.
  final ValueNotifier<double> specialMeterProgress = ValueNotifier<double>(0);

  /// true quando dá para trocar o elemento das bolas em voo (publicado a
  /// cada frame; o botão do especial ouve).
  final ValueNotifier<bool> swapAvailable = ValueNotifier<bool>(false);

  /// Elemento que a Transmutação deu às bolas da rodada (0 = nenhum). Vale
  /// para o próximo tiro, as bolas já em voo e as bolas bônus; zera no fim
  /// da rodada.
  int _roundEl = 0;

  /// A troca de elemento (1 por turno) já foi usada neste turno?
  bool _swapUsed = false;

  // ── Combos: fila do passo, resolvida fora do loop das bolas ──────────────
  static const int _maxQueuedCombos = 32;
  final Uint8List _comboBallEl = Uint8List(_maxQueuedCombos);
  final Uint8List _comboBlockEl = Uint8List(_maxQueuedCombos);
  final Int16List _comboBallIdx = Int16List(_maxQueuedCombos);
  final Float32List _comboX = Float32List(_maxQueuedCombos);
  final Float32List _comboY = Float32List(_maxQueuedCombos);
  int _comboCount = 0;

  // Deslocamentos pendentes: aplicados no fim da rodada, antes da descida
  // (nunca com bolas em voo — decisão de design).
  final Float64List _pushRowsY = Float64List(8);
  int _pushRowCount = 0;
  bool _pushAllRows = false;
  bool _gatherCenter = false;

  // Magnetismo (combo raio×terra): puxa as bolas à linha mais baixa.
  double _magnetTime = 0;
  double _magnetY = 0;

  // ── Power-ups não elementais (estado da partida) ──────────────────────────
  /// Muralha: descidas seguradas.
  int wallCharges = 0;

  /// Mira estendida: turnos restantes.
  int _aimBoostTurns = 0;

  /// Ouro em dobro: rodadas restantes (a atual conta).
  int _goldBoostRounds = 0;

  /// Bola gigante: vale para as bolas desta rodada.
  bool _giantRound = false;

  /// Buraco negro: puxa as bolas para ([_bhX], [_bhY]) por alguns segundos.
  double _blackholeTime = 0;
  double _bhX = 0, _bhY = 0;

  /// Portais: par ativo por turnos (lido pelo renderer).
  int portalTurns = 0;
  double portalAx = 0, portalAy = 0, portalBx = 0, portalBy = 0;
  static const double _portalRadius = 15;

  // Lidos pelo renderer.
  bool get blackholeActive => _blackholeTime > 0;
  double get bhX => _bhX;
  double get bhY => _bhY;

  // Contador do modo de disparo everyNBalls.
  int _elemHitCounter = 0;

  // Especiais disparados por batida (passiveChance/everyNBalls): também
  // resolvidos fora do loop das bolas.
  final Uint8List _pendSpEl = Uint8List(8);
  final Float32List _pendSpX = Float32List(8);
  final Float32List _pendSpY = Float32List(8);
  int _pendSpCount = 0;

  // Scratch dos efeitos (top-HP, raios em 8 direções), sem alocação.
  final List<BlockComponent?> _topB = List<BlockComponent?>.filled(8, null);
  final Float64List _rayD = Float64List(8);
  final Int32List _visited = Int32List(16);

  double _shotTimer = 0;
  double _accumulator = 0;
  int _stepCount = 0;
  int landed = 0;
  double? firstLandX;
  double? returnTargetX;

  /// Elemento da última bola que chegou ao chão (cor do marcador no chão).
  int lastLandedElement = 0;

  /// Relógio das animações visuais (pulso do boss, anel da Prisma).
  double animTime = 0;

  /// Fração do passo fixo já decorrida, para interpolar o desenho.
  double renderAlpha = 1;

  /// Mira em passos de 3 px e ricochetes: guardados ao entrar na mira, para
  /// não consultar upgrades a cada frame.
  double aimSteps = baseAimLength / 3;
  int aimBounces = 0;

  QualityProfile profile = QualityProfile.high;
  GameRenderer? _renderer;

  // Escolha mais próxima para as bolas do bloco triplo (sem alocar lista).
  final Float64List _nearD = Float64List(4);
  final List<BlockComponent?> _nearB = List<BlockComponent?>.filled(4, null);

  // ── Motor: pausa, ociosidade e limite de 30 FPS ──────────────────────────
  late final FramePacer _pacer = FramePacer(_pacedFrame);
  bool _userPaused = false;
  bool _fpsLock = false;

  // ── Qualidade adaptativa ─────────────────────────────────────────────────
  final AdaptiveQuality _adaptive = AdaptiveQuality();
  bool _adaptiveArmed = false;

  /// Em debug o FPS não representa o aparelho; o ajuste só registra no log.
  @visibleForTesting
  bool adaptiveInDebug = false;

  @override
  Color backgroundColor() => const Color(0xFF0a0a14);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _layoutFloor(size);
    _loadBlocks();
    final ratio = PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2;
    _renderer = GameRenderer(SpriteAtlas.shared(ratio));
    specialMeterProgress.value = gameState.specialMeter;
    _applySettings();
  }

  @override
  void onAttach() {
    super.onAttach();
    settings?.removeListener(_applySettings);
    settings?.addListener(_applySettings);
    _applySettings();
    _syncEngine();
  }

  @override
  void onDetach() {
    _pacer.stop();
    settings?.removeListener(_applySettings);
    AdService.instance.setGameplayActive(false);
    super.onDetach();
  }

  @override
  void onRemove() {
    _renderer?.dispose();
    super.onRemove();
  }

  /// A área do jogo muda de tamanho quando o banner aparece ou some; o chão
  /// precisa acompanhar para não ficar escondido atrás do anúncio.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layoutFloor(size);
  }

  void _layoutFloor(Vector2 size) {
    if (size.x <= 0 || size.y <= 0) return;
    final oldFloor = _floorReady ? floorY : null;
    floorY = size.y - 50;
    _floorReady = true;
    originX = originX == 0
        ? size.x / 2
        : originX.clamp(ballRadius + 1, size.x - ballRadius - 1);
    _grid.resize(((floorY - _grid.originY) / blockSize).ceil() + 1);
    _grid.rebuild(blocks);
    if (oldFloor == null || oldFloor == floorY) return;
    // Bolas já paradas no chão acompanham o novo chão.
    if (firstLandX != null) {
      for (var i = 0; i < balls.count; i++) {
        if (balls.state[i] == BallPool.landed) balls.land(i, firstLandX!, floorY);
      }
    }
  }

  void _applySettings() {
    final s = settings;
    profile = QualityProfile.of(s?.graphicsQuality ?? GraphicsQuality.high);
    particles.limit = profile.maxParticles;
    final lock = s?.fpsLock30 ?? false;
    if (lock != _fpsLock) {
      _fpsLock = lock;
      _syncEngine();
    }
  }

  /// Liga ou para o motor conforme pausa, fase e limite de FPS.
  void _syncEngine() {
    final idle = phase == GamePhase.menu ||
        phase == GamePhase.gameOver ||
        phase == GamePhase.stageComplete;
    final run = isAttached && !_userPaused && !idle;
    if (_fpsLock) {
      if (!paused) pauseEngine();
      run ? _pacer.start() : _pacer.stop();
      return;
    }
    _pacer.stop();
    if (run && paused) resumeEngine();
    if (!run && !paused) pauseEngine();
  }

  void _pacedFrame(double dt) {
    if (isAttached) stepEngine(stepTime: dt);
  }

  /// Com o motor parado, desenha um frame (ex.: tabuleiro novo atrás do menu).
  void _requestRepaint() {
    if (isAttached && paused) stepEngine(stepTime: 0);
  }

  void _setPhase(GamePhase p) {
    phase = p;
    if (p == GamePhase.aim) {
      final boost = _aimBoostTurns > 0;
      aimSteps = (baseAimLength +
              gameState.aimBonus +
              (boost ? ElementConfig.aimBoostLength : 0)) /
          3;
      aimBounces =
          gameState.maxBounces + (boost ? ElementConfig.aimBoostBounces : 0);
    }
    // Fora da jogada (menu, game over, fase concluída) não sobra linha de
    // fogo congelada na tela.
    if (p == GamePhase.menu ||
        p == GamePhase.gameOver ||
        p == GamePhase.stageComplete) {
      fireWaveY = -1;
      tideRadius = -1;
      windElapsed = -1;
      boltClock = -1;
      quakeT = -1;
      _roundEl = 0;
    }
    AdService.instance
        .setGameplayActive(p == GamePhase.shooting || p == GamePhase.returning);
    _syncEngine();
  }

  void _loadBlocks() {
    blocks.clear();
    final isBoss = gameState.isBossStage &&
        gameState.waveInStage == gameState.wavesInStage;
    final isCorridor = gameState.isCorridorStage && gameState.waveInStage == 1;
    final newBlocks = isBoss
        ? initBossStage(gameState.stage)
        : isCorridor
            ? initCorridorStage(gameState.stage)
            : initBlocks(gameState.stage);
    for (final b in newBlocks) {
      b.position.y += topOffset;
    }
    blocks.addAll(newBlocks);
    _rowsSinceSpecial = blocks.any((b) => b.type == BlockType.special)
        ? 0
        : ElementConfig.specialMinRowGap;
    // Tabuleiro novo: nada pendente do anterior.
    zones.clear();
    _pushRowCount = 0;
    _pushAllRows = false;
    _gatherCenter = false;
    _magnetTime = 0;
    _blackholeTime = 0;
    _magnetPending = false;
    _comboCount = 0;
    _pendSpCount = 0;
    portalTurns = 0;
    fireWaveY = -1;
    tideRadius = -1;
    windElapsed = -1;
    boltClock = -1;
    quakeT = -1;
    _grid.rebuild(blocks);
  }

  void startWave() {
    if (phase != GamePhase.menu) return;
    gameState.startWave();
    _setPhase(GamePhase.aim);
  }

  void shoot() {
    if (phase != GamePhase.aim || aimAngle == null) return;
    final dx = cos(aimAngle!) * ballSpeed;
    final dy = sin(aimAngle!) * ballSpeed;
    _damage.refresh(gameState);
    _grid.rebuild(blocks);
    balls.clear();
    _queue.clear();
    // Acima do limite cada tiro leva várias bolas: soma dos pesos = total.
    final n = gameState.ballCount;
    final objects = n > PerfConfig.ballGroupThreshold
        ? PerfConfig.ballGroupThreshold
        : n;
    // As bolas saem neutras (elemento se absorve dos blocos especiais), salvo
    // se o jogador usou Transmutação antes do tiro.
    final el = _roundEl;
    _swapUsed = false;
    for (var k = 0; k < objects; k++) {
      _queue.pushBack(dx, dy, el, (k + 1) * n ~/ objects - k * n ~/ objects);
    }
    _shotTimer = 0;
    _accumulator = 0;
    _setPhase(GamePhase.shooting);
    if (!_adaptive.done) _adaptiveArmed = true;
  }

  void forceReturn() {
    if (phase != GamePhase.shooting) return;
    _queue.clear();
    _startReturnPhase();
  }

  void _startReturnPhase() {
    final targetX = firstLandX ?? originX;
    for (var i = 0; i < balls.count; i++) {
      balls.beginReturn(
          i, targetX, floorY, min(balls.y[i], floorY) - 120 - (i % 4) * 35);
    }
    returnTargetX = targetX;
    _setPhase(GamePhase.returning);
  }

  /// Sorteia o power-up de uma vaga: Transmutação é rara
  /// ([ElementConfig.transmuteShare]); os demais saem uniformes.
  @visibleForTesting
  static PowerUpKind pickPowerUp(Random rng) {
    if (rng.nextDouble() < ElementConfig.transmuteShare) {
      return PowerUpKind.transmute;
    }
    return PowerUpKind.values[rng.nextInt(PowerUpKind.values.length - 1)];
  }

  void _spawnPowerUpRow() {
    const powerUpCount = 3;
    final cols = List.generate(9, (i) => i)..shuffle(_rng);
    final chosen = cols.take(powerUpCount).toList()..sort();
    for (final c in chosen) {
      // Vaga vira power-up não elemental de vez em quando.
      if (_rng.nextDouble() < ElementConfig.powerupChance) {
        final kind = pickPowerUp(_rng);
        blocks.add(BlockComponent(
          position: Vector2(c * blockSize + 1, topOffset + 1),
          type: BlockType.powerup,
          hp: 0,
          maxHp: 0,
          element: ElementType.neutral,
          powerUp: kind,
        ));
        continue;
      }
      final isTriple = _rng.nextBool();
      blocks.add(BlockComponent(
        position: Vector2(c * blockSize + 1, topOffset + 1),
        type: isTriple ? BlockType.triple : BlockType.bonus,
        hp: 0,
        maxHp: 0,
        element: ElementType.neutral,
      ));
    }
    // Bloco especial com a cadência da spec, numa coluna livre.
    _rowsSinceSpecial++;
    if (_rowsSinceSpecial > ElementConfig.specialMinRowGap &&
        _rng.nextDouble() < ElementConfig.specialChance) {
      _rowsSinceSpecial = 0;
      blocks.add(makeSpecialBlock(cols[powerUpCount], 0)
        ..position.y += topOffset);
    }
    // Bomba-relógio: rara, explode sozinha em N turnos.
    if (_rng.nextDouble() < ElementConfig.bombChance) {
      blocks.add(BlockComponent(
        position: Vector2(cols[powerUpCount + 1] * blockSize + 1, topOffset + 1),
        type: BlockType.bomb,
        hp: 0,
        maxHp: 0,
        element: ElementType.neutral,
        charges: ElementConfig.bombTurns,
      ));
    }
  }

  void _finishRound() {
    originX = returnTargetX ?? size.x / 2;
    balls.clear();
    landed = 0;
    firstLandX = null;
    returnTargetX = null;

    DailyMissionService.instance.track(MissionType.playRounds);

    // interstitial ad every 10 rounds, if AdService's time limits allow it
    if (gameState.incrementTotalRounds()) {
      AdService.instance.showInterstitial();
    }

    // Ordem do turno: deslocamentos pendentes (onda/maré/rajada — nunca com
    // bolas em voo), descida (lê congelado/preso ANTES do tick), zonas
    // (magma, raios, tornado) e então os status (dano e duração). Nunca por
    // frame.
    if (gameState.tideCooldown > 0) {
      gameState.tideCooldown--;
      gameState.notifyListeners();
    }
    _applyPendingPushes();
    if (_gatherCenter) {
      _gatherCenter = false;
      _applyGather();
    }
    _descendBlocks();
    _processTurnStatuses();
    // Zonas depois dos status: a queimadura que a lava aplica vale para o
    // PRÓXIMO turno (senão o tick do mesmo turno a consumiria).
    _tickZones();
    _tickBombs();

    // Power-ups por turnos.
    if (_aimBoostTurns > 0) _aimBoostTurns--;
    if (_goldBoostRounds > 0) _goldBoostRounds--;
    if (portalTurns > 0) portalTurns--;
    _giantRound = false;
    _roundEl = 0;

    // game over check
    if (blocks.any((b) => b.position.y + b.size.y >= floorY)) {
      _setPhase(GamePhase.gameOver);
      gameState.setGameOver();
      _endRoundSync();
      return;
    }

    const clearableTypes = {
      BlockType.bonus,
      BlockType.triple,
      BlockType.special,
      BlockType.wall,
      BlockType.powerup,
      BlockType.bomb,
    };
    if (blocks.isNotEmpty &&
        blocks.every((b) => clearableTypes.contains(b.type))) {
      blocks.clear();
    }

    if (blocks.isEmpty) {
      // Wave cleared — advance or finish stage
      final lastWave = gameState.waveInStage >= gameState.wavesInStage;
      if (lastWave) {
        _setPhase(GamePhase.stageComplete);
        DailyMissionService.instance.track(MissionType.clearStages);
        gameState.setStageComplete();
        AudioService.instance.playStageComplete();
        _endRoundSync();
        return;
      }
      gameState.advanceWave();
      zones.clear(); // tabuleiro novo: zonas não sobrevivem à wave
      AudioService.instance.playWaveClear();
      // Spawn 2 fresh rows for the next wave (field is empty, no overlap check needed)
      final dom = allElements[_rng.nextInt(allElements.length)];
      for (int r = 0; r < 2; r++) {
        _rowsSinceSpecial++;
        final allowSpecial = _rowsSinceSpecial > ElementConfig.specialMinRowGap &&
            _rng.nextDouble() < ElementConfig.specialChance;
        final newRow =
            generateRow(gameState.stage, dom, r, allowSpecial: allowSpecial);
        if (newRow.any((b) => b.type == BlockType.special)) {
          _rowsSinceSpecial = 0;
        }
        for (final b in newRow) {
          b.position.y += topOffset;
        }
        blocks.addAll(newRow);
      }
      // Wall barrier — same 40% chance as the first wave (skip on last wave since it's boss)
      final isLastWave = gameState.waveInStage >= gameState.wavesInStage;
      if (gameState.stage >= 3 && !isLastWave && _rng.nextDouble() < 0.40) {
        final wallRow = generateWallBarrier(3, gameState.stage);
        for (final b in wallRow) {
          b.position.y += topOffset;
        }
        blocks.addAll(wallRow);
      }
      _setPhase(GamePhase.menu);
    } else {
      // Blocks remain — wave continues, spawn only power-up blocks at top
      gameState.incrementStageRounds(
          canOfferHelp: AdService.instance.isRewardedReady);
      _spawnPowerUpRow();
      _setPhase(GamePhase.aim);
    }
    _endRoundSync();
  }

  /// Fim de rodada: tabuleiro novo no grid, HUD atualizado e progresso gravado.
  void _endRoundSync() {
    _grid.rebuild(blocks);
    gameState.flush();
  }

  // Scratch da descida por coluna: só cresce, nunca aloca por rodada.
  Int32List _descOrder = Int32List(0);
  final Float64List _colCeil = Float64List(cols);

  /// Aplica os empurrões pendentes (Onda: uma linha; Maré: todas), movendo
  /// blocos 1 linha PARA CIMA onde houver espaço — no fim da rodada, antes da
  /// descida, nunca com bolas em voo.
  void _applyPendingPushes() {
    if (_pushAllRows) {
      _pushAllRows = false;
      _pushBlocksUp(null);
    }
    for (var k = 0; k < _pushRowCount; k++) {
      _pushBlocksUp(_pushRowsY[k]);
    }
    _pushRowCount = 0;
  }

  /// Move 1 linha para cima os blocos da linha [onlyRowY] (ou todos, com
  /// null), de cima para baixo, sem sobrepor nem passar do teto.
  void _pushBlocksUp(double? onlyRowY) {
    final n = blocks.length;
    if (n == 0) return;
    if (_descOrder.length < n) _descOrder = Int32List(n * 2);
    final order = _descOrder;
    for (var i = 0; i < n; i++) {
      order[i] = i;
    }
    // Insertion sort por y CRESCENTE (de cima para baixo).
    for (var i = 1; i < n; i++) {
      final idx = order[i];
      final y = blocks[idx].position.y;
      var j = i - 1;
      while (j >= 0 && blocks[order[j]].position.y > y) {
        order[j + 1] = order[j];
        j--;
      }
      order[j + 1] = idx;
    }
    // _colCeil aqui guarda, por coluna, o fundo da área já ocupada acima.
    for (var c = 0; c < cols; c++) {
      _colCeil[c] = topOffset + 1;
    }
    for (var k = 0; k < n; k++) {
      final b = blocks[order[k]];
      final c0 = ((b.position.x - 1) / blockSize).round();
      final span = (b.size.x / blockSize).round();
      final wants = onlyRowY == null ||
          (b.position.y - onlyRowY).abs() < blockSize / 2;
      if (wants) {
        final newY = b.position.y - blockSize;
        var blocked = false;
        for (var c = c0; c < c0 + span; c++) {
          if (c < 0 || c >= cols) continue;
          if (newY < _colCeil[c] - 0.5) {
            blocked = true;
            break;
          }
        }
        if (!blocked) b.position.y = newY;
      }
      final bottom = b.position.y + b.size.y;
      for (var c = c0; c < c0 + span; c++) {
        if (c >= 0 && c < cols && bottom > _colCeil[c]) _colCeil[c] = bottom;
      }
    }
  }

  /// Rajada de vento: junta os blocos 1 coluna em direção ao centro, abrindo
  /// corredores nas laterais. Processa do centro para fora.
  void _applyGather() {
    const center = (cols - 1) / 2; // 4.0
    final n = blocks.length;
    if (n == 0) return;
    if (_descOrder.length < n) _descOrder = Int32List(n * 2);
    final order = _descOrder;
    for (var i = 0; i < n; i++) {
      order[i] = i;
    }
    // Ordena por distância ao centro (mais perto primeiro).
    double dist(BlockComponent b) =>
        ((b.position.x - 1) / blockSize - center).abs();
    for (var i = 1; i < n; i++) {
      final idx = order[i];
      final d = dist(blocks[idx]);
      var j = i - 1;
      while (j >= 0 && dist(blocks[order[j]]) > d) {
        order[j + 1] = order[j];
        j--;
      }
      order[j + 1] = idx;
    }
    for (var k = 0; k < n; k++) {
      final b = blocks[order[k]];
      if (b.isBoss) continue; // boss não é arrastado
      final c = ((b.position.x - 1) / blockSize).round();
      if ((c - center).abs() < 0.6) continue; // já no centro
      final target = c + (c < center ? 1 : -1);
      final tx = target * blockSize + 1;
      // Célula ocupada (mesma linha)?
      var free = true;
      for (var i = 0; i < n; i++) {
        final o = blocks[i];
        if (identical(o, b)) continue;
        if ((o.position.y - b.position.y).abs() < blockSize / 2 &&
            (o.position.x - tx).abs() < blockSize / 2) {
          free = false;
          break;
        }
      }
      if (free) b.position.x = tx;
    }
  }

  /// Efeitos das zonas, uma vez por rodada (depois da descida: magma queima
  /// quem desceu sobre ela).
  void _tickZones() {
    final z = zones;
    for (var i = 0; i < z.count; i++) {
      final kind = ZoneKind.values[z.kind[i] - 1];
      switch (kind) {
        case ZoneKind.magma:
          _zoneAreaDamage(z.x[i], z.y[i], z.halfW[i], z.halfH[i], z.dmg[i],
              burn: true);
        case ZoneKind.swamp:
          _zoneAreaDamage(z.x[i], z.y[i], z.halfW[i], z.halfH[i], z.dmg[i]);
        case ZoneKind.electric:
          break; // efeito é no acerto das bolas (ballDamageMultAt)
        case ZoneKind.bolts:
          _randomDamage(z.size[i], z.dmg[i]);
        case ZoneKind.fireTornado:
          // Anda 1 coluna por turno, quicando nas bordas (direção em size).
          final dir = z.size[i] == 0 ? 1.0 : -1.0;
          var nx = z.x[i] + dir * blockSize;
          if (nx < blockSize || nx > size.x - blockSize) {
            z.size[i] = z.size[i] == 0 ? 1 : 0;
            nx = z.x[i] - dir * blockSize;
          }
          z.x[i] = nx;
          _zoneAreaDamage(z.x[i], z.y[i], z.halfW[i] + blockSize / 2,
              z.halfH[i] + blockSize / 2, z.dmg[i],
              burn: true);
      }
    }
    z.tickTurns();
  }

  void _zoneAreaDamage(double cx, double cy, double hw, double hh, int dmg,
      {bool burn = false}) {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      final bx = b.position.x + b.size.x / 2;
      final by = b.position.y + b.size.y / 2;
      if ((bx - cx).abs() >= hw + b.size.x / 2 - 1 ||
          (by - cy).abs() >= hh + b.size.y / 2 - 1) {
        continue;
      }
      final died = _effectDamage(b, dmg);
      if (burn && !died && b.isAlive) {
        b.status.applyBurn(turns: 1, damage: max(1, dmg ~/ 2));
      }
    }
  }

  /// Desce os blocos 1 linha, por coluna e de baixo para cima: bloco
  /// congelado/preso não desce e segura os de cima na mesma coluna (o boss,
  /// com 2 colunas, só desce se as duas estiverem livres). A Muralha
  /// (power-up) segura uma descida inteira.
  void _descendBlocks() {
    if (wallCharges > 0) {
      wallCharges--;
      return;
    }
    final n = blocks.length;
    if (n == 0) return;
    if (_descOrder.length < n) _descOrder = Int32List(n * 2);
    final order = _descOrder;
    for (var i = 0; i < n; i++) {
      order[i] = i;
    }
    // Insertion sort por y decrescente: ~130 blocos, uma vez por rodada.
    for (var i = 1; i < n; i++) {
      final idx = order[i];
      final y = blocks[idx].position.y;
      var j = i - 1;
      while (j >= 0 && blocks[order[j]].position.y < y) {
        order[j + 1] = order[j];
        j--;
      }
      order[j + 1] = idx;
    }
    for (var c = 0; c < cols; c++) {
      _colCeil[c] = double.infinity;
    }
    for (var k = 0; k < n; k++) {
      final b = blocks[order[k]];
      final c0 = ((b.position.x - 1) / blockSize).round();
      final span = (b.size.x / blockSize).round();
      final newY = b.position.y + blockSize;
      var blocked = b.status.holdsDescent;
      if (!blocked) {
        for (var c = c0; c < c0 + span; c++) {
          if (c < 0 || c >= cols) continue;
          if (newY + b.size.y > _colCeil[c] + 0.5) {
            blocked = true;
            break;
          }
        }
      }
      if (!blocked) {
        b.position.y = newY;
        // Ouro que desce sem ser coletado vale menos: incentiva quebrar logo.
        if (!b.isBoss && b.goldValue > goldDecayFloor) b.goldValue--;
      }
      final top = b.position.y;
      for (var c = c0; c < c0 + span; c++) {
        if (c >= 0 && c < cols && top < _colCeil[c]) _colCeil[c] = top;
      }
    }
  }

  /// Bombas-relógio: contagem por turno; no zero, explosão em área.
  void _tickBombs() {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (b.type != BlockType.bomb) continue;
      if (--b.charges > 0) {
        b.triggerShake();
        continue;
      }
      final cx = b.position.x + b.size.x / 2;
      final cy = b.position.y + b.size.y / 2;
      _removeBlock(b);
      AudioService.instance.playBreak();
      HapticService.instance.blockBreak();
      particles.burst(cx, cy, 0xFFFF7043, profile.particlesPerBurst * 2,
          speed: 220);
      _areaDamage(
          cx, cy, 3, max(1, (_damage.base * ElementConfig.bombDmgMult).ceil()));
    }
  }

  void _processTurnStatuses() {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (b.status.isEmpty) continue;
      final dmg = b.status.tick();
      if (dmg <= 0 || !b.isAlive) continue;
      b.takeDamage(dmg);
      if (!b.isAlive) {
        _rewardKill(b);
        _removeBlock(b);
      } else {
        b.triggerShake();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final frameDt = dt > PerfConfig.maxFrameDt ? PerfConfig.maxFrameDt : dt;
    final speed = gameState.fastForwardActive ? 2.0 : 1.0;
    animTime += frameDt;
    _sampleFps(dt);

    for (var i = 0; i < blocks.length; i++) {
      blocks[i].updateShake(frameDt);
    }
    particles.update(frameDt);
    if (fireWaveY >= 0) _advanceFireWave(frameDt);
    if (tideRadius >= 0) _advanceTide(frameDt);
    if (windElapsed >= 0) _advanceWind(frameDt);
    if (boltClock >= 0) _advanceLightning(frameDt);
    if (quakeT >= 0) _advanceQuake(frameDt);

    renderAlpha = 1;
    if (phase == GamePhase.shooting) {
      // 2x: simula o dobro do tempo em passos fixos, para as colisões
      // continuarem precisas.
      _accumulator += frameDt * speed;
      var steps = 0;
      while (_accumulator >= _fixedDt) {
        _accumulator -= _fixedDt;
        _stepShooting(_fixedDt);
        if (phase != GamePhase.shooting ||
            ++steps >= PerfConfig.maxStepsPerFrame) {
          _accumulator = 0;
          break;
        }
      }
      if (phase == GamePhase.shooting) renderAlpha = _accumulator / _fixedDt;
    }
    if (phase == GamePhase.returning) _updateReturning(frameDt * speed);
    specialMeterProgress.value = gameState.specialMeter;
    swapAvailable.value = canSwapElement;
    gameState.commitGameplay(animTime);
  }

  void _sampleFps(double dt) {
    if (!_adaptiveArmed || _adaptive.done) return;
    if (phase != GamePhase.shooting && phase != GamePhase.returning) return;
    final s = settings;
    if (s == null || !s.autoQuality) {
      _adaptive.finish();
      return;
    }
    final minFps = _fpsLock ? PerfConfig.minFpsLocked : PerfConfig.minFps;
    if (!_adaptive.addFrame(dt, minFps)) {
      if (_adaptive.done) {
        debugPrint('Qualidade: ${_adaptive.lastFps?.toStringAsFixed(1)} FPS, '
            'mantém ${s.graphicsQuality.name}');
      }
      return;
    }
    final q = s.graphicsQuality;
    debugPrint('Qualidade: ${_adaptive.lastFps?.toStringAsFixed(1)} FPS '
        '(mínimo $minFps) em ${q.name}');
    if (q == GraphicsQuality.low || (kDebugMode && !adaptiveInDebug)) return;
    final lower = GraphicsQuality.values[q.index - 1];
    s.setGraphicsQuality(lower);
    _applySettings(); // já vale neste frame, sem esperar o listener
    // Mede de novo no nível novo; no Baixo não há para onde descer.
    if (lower != GraphicsQuality.low) _adaptive.restart();
  }

  void _stepShooting(double h) {
    // fire from queue
    if (_queue.length > 0) {
      _shotTimer -= h;
      if (_shotTimer <= 0 && _queue.popFront()) {
        balls.spawn(originX, floorY, _queue.outDx, _queue.outDy, _queue.outEl,
            _queue.outWeight,
            r: _giantRound ? ElementConfig.giantRadius : ballRadius);
        _shotTimer = shotInterval;
      }
    }

    _stepCount++;
    if (_magnetTime > 0) _magnetTime -= h;
    if (_blackholeTime > 0) _blackholeTime -= h;
    // Bolas criadas neste passo (triplo, divisão) só andam no próximo.
    final n = balls.count;
    for (var i = 0; i < n; i++) {
      if (balls.state[i] != BallPool.flying) continue;
      _stepBall(i, h);
      // boss died: finish loop before touching the balls
      if (_pendingForceReturn) break;
    }

    // Combos, especiais por batida e ímã: resolvidos FORA do loop das bolas.
    if (_comboCount > 0) _resolveCombos();
    if (_pendSpCount > 0) {
      final n = _pendSpCount;
      _pendSpCount = 0;
      for (var k = 0; k < n; k++) {
        _fireSpecial(
            ElementType.values[_pendSpEl[k]], _pendSpX[k], _pendSpY[k]);
      }
    }
    if (_magnetPending) {
      _magnetPending = false;
      _magnetCollect();
    }

    if (_pendingForceReturn) {
      _pendingForceReturn = false;
      forceReturn();
      return;
    }
    if (blocks.isEmpty) {
      forceReturn();
      return;
    }
    if (balls.flyingCount == 0 && _queue.length == 0 && balls.count > 0) {
      _startReturnPhase();
    }
  }

  void _stepBall(int i, double h) {
    final b = balls;
    b.px[i] = b.x[i];
    b.py[i] = b.y[i];
    if (b.pierceTime[i] > 0) b.pierceTime[i] -= h;
    if (b.portalCd[i] > 0) b.portalCd[i] -= h;
    if (_magnetTime > 0) {
      // Magnetismo: curva a velocidade na vertical em direção à linha alvo,
      // mantendo o módulo.
      final dir = _magnetY > b.y[i] ? 1.0 : -1.0;
      final vx = b.vx[i], vy = b.vy[i] + dir * 900 * h;
      final sp = sqrt(vx * vx + vy * vy);
      if (sp > 0) {
        final k = ballSpeed / sp;
        b.vx[i] = vx * k;
        b.vy[i] = vy * k;
      }
    }
    if (_blackholeTime > 0) {
      // Buraco negro: acelera em direção ao ponto, mantendo o módulo.
      final dx = _bhX - b.x[i], dy = _bhY - b.y[i];
      final d = sqrt(dx * dx + dy * dy);
      if (d > 4) {
        final vx = b.vx[i] + dx / d * 1400 * h;
        final vy = b.vy[i] + dy / d * 1400 * h;
        final sp = sqrt(vx * vx + vy * vy);
        final k = ballSpeed / sp;
        b.vx[i] = vx * k;
        b.vy[i] = vy * k;
      }
    }
    final r = b.radius[i];
    final hs = h / _substeps;
    final w = size.x;
    for (var s = 0; s < _substeps; s++) {
      var x = b.x[i] + b.vx[i] * hs;
      var y = b.y[i] + b.vy[i] * hs;

      // wall bounces
      if (x - r <= 1) {
        x = r + 1;
        b.vx[i] = b.vx[i].abs();
        AudioService.instance.playWall();
      }
      if (x + r >= w - 1) {
        x = w - r - 1;
        b.vx[i] = -b.vx[i].abs();
        AudioService.instance.playWall();
      }
      if (y - r <= topOffset) {
        y = topOffset + r;
        b.vy[i] = b.vy[i].abs();
        AudioService.instance.playWall();
      }

      // floor
      if (y >= floorY) {
        landed++;
        final landX = firstLandX ??= x;
        lastLandedElement = b.element[i];
        b.land(i, landX, floorY);
        return;
      }
      b.x[i] = x;
      b.y[i] = y;

      // Portais: teletransporta preservando a velocidade.
      if (portalTurns > 0 && b.portalCd[i] <= 0) {
        const pr2 = _portalRadius * _portalRadius;
        final dax = x - portalAx, day = y - portalAy;
        final dbx = x - portalBx, dby = y - portalBy;
        if (dax * dax + day * day < pr2) {
          b.x[i] = b.px[i] = portalBx;
          b.y[i] = b.py[i] = portalBy;
          b.portalCd[i] = 0.3;
        } else if (dbx * dbx + dby * dby < pr2) {
          b.x[i] = b.px[i] = portalAx;
          b.y[i] = b.py[i] = portalAy;
          b.portalCd[i] = 0.3;
        }
      }

      // block collisions — may set _pendingForceReturn if boss dies
      _collideBlocks(i);
      if (_pendingForceReturn) return;
    }

    // Anti-loop: nenhum quique deixa a bola quase reta, e uma bola que
    // passa muito tempo sem acertar nada quebrável é desviada.
    final idle = b.idle[i] + h;
    if (idle >= stuckTimeout) {
      b.idle[i] = 0;
      _nudge(i);
    } else {
      b.idle[i] = idle;
    }
    _enforceMinAngle(i);
    if (profile.trailLength > 0 && _stepCount.isEven) b.pushTrail(i);
  }

  /// Testa só as células do grid que a bola toca (no máximo 2×2) e o boss.
  void _collideBlocks(int i) {
    _touchingSpecial = false;
    final x = balls.x[i], y = balls.y[i];
    final r = balls.radius[i];
    final g = _grid;
    final c0 = ((x - r - g.originX) / blockSize).floor();
    final c1 = ((x + r - g.originX) / blockSize).floor();
    final r0 = ((y - r - g.originY) / blockSize).floor();
    final r1 = ((y + r - g.originY) / blockSize).floor();
    for (var row = r0; row <= r1; row++) {
      for (var col = c0; col <= c1; col++) {
        var block = g.head(col, row);
        while (block != null) {
          final next = block.nextInCell;
          if (_hitBlock(i, block)) return;
          block = next;
        }
      }
    }
    final big = g.big;
    for (var k = big.length - 1; k >= 0; k--) {
      if (_hitBlock(i, big[k])) return;
    }
    // Saiu do bloco especial: a próxima entrada conta como nova passagem.
    if (!_touchingSpecial && balls.lastSpecial[i] != 0) balls.lastSpecial[i] = 0;
  }

  /// Colisão círculo × retângulo. Devolve true se a bola deve parar de testar
  /// blocos neste substep (boss morreu).
  bool _hitBlock(int i, BlockComponent block) {
    final x = balls.x[i], y = balls.y[i];
    final r = balls.radius[i];
    final left = block.position.x, top = block.position.y;
    final right = left + block.size.x, bottom = top + block.size.y;
    final nearX = x < left ? left : (x > right ? right : x);
    final nearY = y < top ? top : (y > bottom ? bottom : y);
    final dx = x - nearX, dy = y - nearY;
    if (dx * dx + dy * dy >= r * r) return false;

    switch (block.type) {
      case BlockType.bonus:
        _removeBlock(block);
        AudioService.instance.playBreak();
        HapticService.instance.blockBreak();
        gameState.incrementBallCount();
        DailyMissionService.instance.track(MissionType.collectBalls);
        _queue.pushFront(balls.vx[i], balls.vy[i], _roundEl, 1);
        _burst(block, 0xFF7F77DD, 0.6);
        return false;

      case BlockType.triple:
        _removeBlock(block);
        AudioService.instance.playBreak();
        HapticService.instance.blockBreak();
        _spawnTriple(i);
        gameState.addScore(8);
        _burst(block, 0xFFFFFFFF, 0.6);
        return false;

      case BlockType.special:
        _hitSpecial(i, block);
        return false;

      case BlockType.powerup:
        _collectPowerUp(i, block);
        return false;

      case BlockType.bomb:
        return false; // a bola atravessa; a bomba é por turnos

      case BlockType.wall:
        _hitWall(i, block, left, top, right, bottom);
        return false;

      default:
        return _hitDamageable(i, block, left, top, right, bottom);
    }
  }

  /// Bloco especial: a bola atravessa (não reflete) e cada passagem gasta
  /// 1 carga. Bola neutra absorve o elemento do bloco; bola com elemento
  /// dispara a combinação ([_onCombo]).
  void _hitSpecial(int i, BlockComponent block) {
    _touchingSpecial = true;
    if (balls.lastSpecial[i] == block.serial) return; // mesma passagem
    balls.lastSpecial[i] = block.serial;
    balls.idle[i] = 0;
    final el = block.element;
    final atk = balls.element[i];
    if (atk == ElementType.neutral.index) {
      // Absorção: só esta bola muda de elemento (o poder do botão de especial
      // é escolhido pelo jogador, não pela absorção).
      balls.element[i] = el.index;
      DailyMissionService.instance.track(MissionType.absorbElements);
      AudioService.instance.playHit();
      _burst(block, elementDataMap[el]!.ballColor.toARGB32(), 0.6);
    } else {
      _onCombo(i, ElementType.values[atk], el, balls.x[i], balls.y[i]);
      if (!ElementConfig.keepElementAfterCombo) {
        balls.element[i] = ElementType.neutral.index;
      }
    }
    block.triggerShake();
    if (--block.charges <= 0) {
      _removeBlock(block);
      AudioService.instance.playBreak();
      HapticService.instance.blockBreak();
      _burst(block, elementDataMap[el]!.blockBg.toARGB32(), 1);
    }
  }

  /// Coleta um power-up do tabuleiro e aplica o efeito na hora.
  void _collectPowerUp(int i, BlockComponent block) {
    final kind = block.powerUp;
    _removeBlock(block);
    AudioService.instance.playPickup();
    HapticService.instance.blockBreak();
    _burst(block, 0xFFFFFFFF, 0.8);
    DailyMissionService.instance.track(MissionType.collectPowerUps);
    if (kind == null) return;
    gameState.announce('pu:${kind.index}');
    switch (kind) {
      case PowerUpKind.pierce:
        for (var k = 0; k < balls.count; k++) {
          if (balls.state[k] == BallPool.flying) {
            balls.pierceLeft[k] += ElementConfig.pierceBlocks;
          }
        }
      case PowerUpKind.giant:
        _giantRound = true;
        for (var k = 0; k < balls.count; k++) {
          if (balls.state[k] == BallPool.flying) {
            balls.radius[k] = ElementConfig.giantRadius;
          }
        }
      case PowerUpKind.portal:
        portalTurns = ElementConfig.portalTurns;
        portalAx = (1 + _rng.nextInt(3)) * blockSize + blockSize / 2;
        portalBx = (5 + _rng.nextInt(3)) * blockSize + blockSize / 2;
        portalAy = topOffset + (2 + _rng.nextInt(3)) * blockSize;
        portalBy = topOffset + (6 + _rng.nextInt(3)) * blockSize;
      case PowerUpKind.blackhole:
        _blackholeTime = ElementConfig.blackholeSeconds;
        _bhX = balls.x[i];
        _bhY = balls.y[i];
      case PowerUpKind.wall:
        wallCharges++;
      case PowerUpKind.aim:
        _aimBoostTurns = ElementConfig.aimBoostTurns;
      case PowerUpKind.gold2x:
        _goldBoostRounds = ElementConfig.goldBoostRounds;
      case PowerUpKind.magnet:
        _magnetPending = true; // coleta fora do loop de colisão
      case PowerUpKind.transmute:
        gameState.addTransmuteCharge(); // o jogador escolhe o elemento na UI
    }
  }

  bool _magnetPending = false;

  /// Ímã: coleta todas as moedas e bolas extras do tabuleiro. Roda depois do
  /// loop das bolas (remove vários blocos de uma vez).
  void _magnetCollect() {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (b.type == BlockType.gold) {
        if (b.goldValue > 0) {
          gameState.earnGold(b.goldValue,
              multiplier: PurchaseService.instance.goldMultiplier *
                  (_goldBoostRounds > 0 ? 2 : 1));
        }
        _burst(b, 0xFFEF9F27, 0.8);
        _removeBlock(b);
      } else if (b.type == BlockType.bonus) {
        gameState.incrementBallCount();
        DailyMissionService.instance.track(MissionType.collectBalls);
        _burst(b, 0xFF7F77DD, 0.8);
        _removeBlock(b);
      }
    }
  }

  /// Combinação disparada (bola [ball] × bloco [blockEl]) em ([x], [y]).
  /// A ordem importa: fogo×água ≠ água×fogo. O efeito entra numa fila e é
  /// resolvido DEPOIS do loop das bolas do passo ([_resolveCombos]): nenhum
  /// bloco é removido no meio da iteração de colisão.
  void _onCombo(int ballIdx, ElementType ball, ElementType blockEl, double x,
      double y) {
    final n = profile.particlesPerBurst;
    if (n > 0) {
      particles.burst(x, y, elementDataMap[ball]!.ballColor.toARGB32(), n,
          speed: 170);
      particles.burst(x, y, elementDataMap[blockEl]!.ballColor.toARGB32(), n,
          speed: 170);
    }
    AudioService.instance.playCombo();
    HapticService.instance.hit();
    if (_comboCount < _maxQueuedCombos) {
      _comboBallEl[_comboCount] = ball.index;
      _comboBlockEl[_comboCount] = blockEl.index;
      _comboBallIdx[_comboCount] = ballIdx;
      _comboX[_comboCount] = x;
      _comboY[_comboCount] = y;
      _comboCount++;
    }
    final missions = DailyMissionService.instance;
    missions.track(MissionType.triggerCombos);
    // Codex: revela na primeira ativação.
    if (gameState.discoverCombo(
        comboIndex(ball, blockEl), comboFor(ball, blockEl).id)) {
      missions.track(MissionType.discoverCombos);
    }
  }

  void _resolveCombos() {
    final n = _comboCount;
    _comboCount = 0;
    for (var k = 0; k < n; k++) {
      final ball = ElementType.values[_comboBallEl[k]];
      final block = ElementType.values[_comboBlockEl[k]];
      _executeCombo(comboFor(ball, block), ball, _comboBallIdx[k],
          _comboX[k], _comboY[k]);
    }
  }

  void _executeCombo(
      ComboDef def, ElementType ball, int ballIdx, double x, double y) {
    // Força do combo = nível do especial do elemento da bola (mínimo 1).
    final level = max(1, gameState.specialLevel(ball));
    final dmg = max(1, (_damage.base * def.effDmg(level)).ceil());
    final size = def.effSize(level);
    switch (def.kind) {
      case ComboKind.area:
        _areaDamage(x, y, size, dmg);
      case ComboKind.row:
        _rowDamage(y, dmg);
      case ComboKind.column:
        _columnDamage(x, dmg);
      case ComboKind.cross:
        _rowDamage(y, dmg);
        _columnDamage(x, dmg);
      case ComboKind.lowestRow:
        _lowestRowDamage(dmg);
      case ComboKind.columnPercent:
        _columnPercent(x, def.effDmg(level).clamp(0.05, 0.9));
      case ComboKind.chain:
        _chainDamage(x, y, size, dmg);
      case ComboKind.topHp:
        _topHpDamage(size, dmg);
      case ComboKind.randomBlocks:
        _randomDamage(size, dmg);
      case ComboKind.rays8:
        _rays8Damage(x, y, dmg);
      case ComboKind.status:
        _applyStatusArea(def.status!, x, y, size, def.turns, dmg);
      case ComboKind.zone:
        zones.add(def.zone!, x, y, size * blockSize / 2, size * blockSize / 2,
            durTurns: def.turns, lvl: level, damage: dmg, n: size);
      case ComboKind.pushRow:
        _rowDamage(y, dmg);
        if (_pushRowCount < _pushRowsY.length) {
          _pushRowsY[_pushRowCount++] = y;
        }
      case ComboKind.split:
        _splitBallCombo(x, y, size);
      case ComboKind.heavyBall:
        _spawnHeavy(x, y, size + (level - 1));
      case ComboKind.pierce:
        if (ballIdx >= 0 && ballIdx < balls.count &&
            def.seconds > balls.pierceTime[ballIdx]) {
          balls.pierceTime[ballIdx] = def.seconds;
        }
      case ComboKind.magnet:
        _activateMagnet(def.seconds);
    }
  }

  // ── Primitivas de efeito (combos, especiais e zonas) ──────────────────────

  /// Alvo válido para dano de efeito (power-ups e especiais têm hp 0).
  static bool _effectTarget(BlockComponent b) =>
      b.hp > 0 && b.type != BlockType.special;

  /// Dano "de efeito": aplica multiplicador de status, recompensa e remove.
  /// Devolve true se o bloco morreu. Nunca chamar dentro do loop de colisão.
  bool _effectDamage(BlockComponent b, int dmg) {
    if (dmg <= 0 || !b.isAlive || !_effectTarget(b)) return false;
    var d = dmg;
    final st = b.status;
    if (!st.isEmpty) {
      final m = st.damageMult(
          ElementConfig.softenedDamageMult, ElementConfig.frozenDamageMult);
      if (m != 1.0) d = (d * m).ceil();
    }
    b.takeDamage(d);
    if (!b.isAlive) {
      _rewardKill(b);
      final wasBoss = b.isBoss;
      _removeBlock(b);
      if (wasBoss) _pendingForceReturn = true;
      return true;
    }
    b.triggerShake();
    return false;
  }

  void _areaDamage(double cx, double cy, int sizeCells, int dmg) {
    final h = sizeCells * blockSize / 2;
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      final bx = b.position.x + b.size.x / 2;
      final by = b.position.y + b.size.y / 2;
      if ((bx - cx).abs() < h + b.size.x / 2 - 1 &&
          (by - cy).abs() < h + b.size.y / 2 - 1) {
        _effectDamage(b, dmg);
      }
    }
  }

  void _rowDamage(double cy, int dmg) {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (cy >= b.position.y - 1 && cy <= b.position.y + b.size.y + 1) {
        _effectDamage(b, dmg);
      }
    }
  }

  void _columnDamage(double cx, int dmg) {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (cx >= b.position.x - 1 && cx <= b.position.x + b.size.x + 1) {
        _effectDamage(b, dmg);
      }
    }
  }

  void _lowestRowDamage(int dmg) {
    var maxY = -1.0;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (_effectTarget(b) && b.position.y > maxY) maxY = b.position.y;
    }
    if (maxY < 0) return;
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if ((b.position.y - maxY).abs() < blockSize / 2) _effectDamage(b, dmg);
    }
  }

  void _columnPercent(double cx, double frac) {
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      if (cx >= b.position.x - 1 && cx <= b.position.x + b.size.x + 1) {
        _effectDamage(b, (b.hp * frac).ceil());
      }
    }
  }

  void _chainDamage(double x, double y, int jumps, int dmg) {
    var cx = x, cy = y;
    var visited = 0;
    final maxJumps = min(jumps, _visited.length);
    for (var j = 0; j < maxJumps; j++) {
      BlockComponent? best;
      var bestD = double.infinity;
      for (var i = blocks.length - 1; i >= 0; i--) {
        final b = blocks[i];
        if (!_effectTarget(b)) continue;
        var seen = false;
        for (var v = 0; v < visited; v++) {
          if (_visited[v] == b.serial) {
            seen = true;
            break;
          }
        }
        if (seen) continue;
        final dx = b.position.x + b.size.x / 2 - cx;
        final dy = b.position.y + b.size.y / 2 - cy;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = b;
        }
      }
      if (best == null) break;
      _visited[visited++] = best.serial;
      cx = best.position.x + best.size.x / 2;
      cy = best.position.y + best.size.y / 2;
      particles.burst(cx, cy, 0xFFCE93D8, profile.particlesPerBurst ~/ 2,
          speed: 140);
      _effectDamage(best, dmg);
    }
  }

  void _topHpDamage(int n, int dmg) {
    final cap = min(n, _topB.length);
    var found = 0;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      if (found == cap && b.hp <= _topB[cap - 1]!.hp) continue;
      var pos = found < cap ? found++ : cap - 1;
      while (pos > 0 && _topB[pos - 1]!.hp < b.hp) {
        _topB[pos] = _topB[pos - 1];
        pos--;
      }
      _topB[pos] = b;
    }
    for (var k = 0; k < found; k++) {
      final b = _topB[k]!;
      particles.burst(b.position.x + b.size.x / 2,
          b.position.y + b.size.y / 2, 0xFFCE93D8,
          profile.particlesPerBurst ~/ 2, speed: 140);
      _effectDamage(b, dmg);
    }
    _topB.fillRange(0, _topB.length, null);
  }

  void _randomDamage(int n, int dmg) {
    for (var k = 0; k < n; k++) {
      if (blocks.isEmpty) return;
      BlockComponent? pick;
      for (var tries = 0; tries < 6; tries++) {
        final b = blocks[_rng.nextInt(blocks.length)];
        if (_effectTarget(b)) {
          pick = b;
          break;
        }
      }
      if (pick == null) continue;
      particles.burst(pick.position.x + pick.size.x / 2,
          pick.position.y + pick.size.y / 2,
          elementDataMap[pick.element]!.ballColor.toARGB32(),
          profile.particlesPerBurst ~/ 2, speed: 150);
      _effectDamage(pick, dmg);
    }
  }

  /// Estilhaços em 8 direções: o bloco mais próximo em cada setor de 45°.
  void _rays8Damage(double x, double y, int dmg) {
    for (var s = 0; s < 8; s++) {
      _rayD[s] = double.infinity;
      _topB[s] = null;
    }
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      final dx = b.position.x + b.size.x / 2 - x;
      final dy = b.position.y + b.size.y / 2 - y;
      final d = dx * dx + dy * dy;
      if (d < 1) continue;
      final sector = (((atan2(dy, dx) + pi) / (pi / 4)).floor()) & 7;
      if (d < _rayD[sector]) {
        _rayD[sector] = d;
        _topB[sector] = b;
      }
    }
    for (var s = 0; s < 8; s++) {
      final b = _topB[s];
      if (b != null) _effectDamage(b, dmg);
      _topB[s] = null;
    }
  }

  void _applyStatusArea(ComboStatus st, double cx, double cy, int sizeCells,
      int turns, int dmg) {
    final h = sizeCells * blockSize / 2;
    var affected = 0;
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      final bx = b.position.x + b.size.x / 2;
      final by = b.position.y + b.size.y / 2;
      if ((bx - cx).abs() >= h + b.size.x / 2 - 1 ||
          (by - cy).abs() >= h + b.size.y / 2 - 1) {
        continue;
      }
      affected++;
      switch (st) {
        case ComboStatus.burn:
          b.status.applyBurn(turns: turns, damage: max(1, dmg));
        case ComboStatus.acid:
          b.status.applyAcid(turns: turns, damage: max(1, dmg));
        case ComboStatus.freeze:
          b.status.applyFreeze(turns: turns);
          if (dmg > 0) _effectDamage(b, dmg);
        case ComboStatus.soften:
          b.status.applySoften(turns: turns);
          if (dmg > 0) _effectDamage(b, dmg);
        case ComboStatus.stick:
          b.status.applyStick(turns: turns);
          if (dmg > 0) _effectDamage(b, dmg);
      }
    }
    if (affected > 0) {
      DailyMissionService.instance.track(MissionType.statusBlocks, affected);
    }
  }

  void _splitBallCombo(double x, double y, int n) {
    for (var k = 1; k < n; k++) {
      if (balls.count >= PerfConfig.maxBallObjects) break;
      final side = k.isOdd ? 1.0 : -1.0;
      final ang = -pi / 2 + side * (0.4 + 0.25 * ((k - 1) ~/ 2));
      final j = balls.spawn(x, y, cos(ang) * ballSpeed, sin(ang) * ballSpeed,
          ElementType.neutral.index, 1);
      _enforceMinAngle(j);
    }
  }

  void _spawnHeavy(double x, double y, int weight) {
    if (balls.count >= PerfConfig.maxBallObjects) return;
    final j = balls.spawn(
        x, y, 0.1, -ballSpeed, ElementType.neutral.index, weight,
        r: 7);
    _enforceMinAngle(j);
  }

  void _activateMagnet(double seconds) {
    if (seconds > _magnetTime) _magnetTime = seconds;
    var maxY = topOffset + blockSize;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      final by = b.position.y + b.size.y / 2;
      if (by > maxY) maxY = by;
    }
    _magnetY = maxY;
  }

  // ── Especiais de elemento (upgrades por nível) ─────────────────────────────

  /// Batida de bola elemental: alimenta o modo de disparo configurado.
  /// passiveChance/everyNBalls só ENFILEIRAM ([_pendSp*]): o efeito roda fora
  /// do loop de colisão, junto com os combos.
  void _onElementalHit(ElementType el, BlockComponent block) {
    if (gameState.specialLevel(el) <= 0) return;
    switch (ElementConfig.triggerMode) {
      case SpecialTriggerMode.passiveChance:
        if (_rng.nextDouble() < ElementConfig.passiveTriggerChance) {
          _queueSpecial(el, block);
        }
      case SpecialTriggerMode.everyNBalls:
        if (++_elemHitCounter >= ElementConfig.triggerEveryNBalls) {
          _elemHitCounter = 0;
          _queueSpecial(el, block);
        }
      case SpecialTriggerMode.meter:
        break; // o medidor conta acertos em _applyBallDamage
    }
  }

  void _queueSpecial(ElementType el, BlockComponent block) {
    if (_pendSpCount >= _pendSpEl.length) return;
    _pendSpEl[_pendSpCount] = el.index;
    _pendSpX[_pendSpCount] = block.position.x + block.size.x / 2;
    _pendSpY[_pendSpCount] = block.position.y + block.size.y / 2;
    _pendSpCount++;
  }

  /// O botão do medidor pode ser usado agora?
  bool get canActivateSpecial {
    final el = specialElement;
    return ElementConfig.triggerMode == SpecialTriggerMode.meter &&
        gameState.specialMeter >= 1 &&
        el != ElementType.neutral &&
        (phase == GamePhase.aim || phase == GamePhase.shooting) &&
        (el != ElementType.water || gameState.tideCooldown == 0);
  }

  /// Poder do botão de especial: o que o jogador escolheu (se ainda for um
  /// especial comprado) ou, sem escolha, o de maior nível. Neutro só quando
  /// nenhum especial foi comprado.
  ElementType get specialElement {
    final armed = gameState.armedElement;
    if (armed != ElementType.neutral && gameState.specialLevel(armed) > 0) {
      return armed;
    }
    var best = ElementType.neutral;
    var bestLevel = 0;
    for (final e in kCombatElements) {
      final lvl = gameState.specialLevel(e);
      if (lvl > bestLevel) {
        best = e;
        bestLevel = lvl;
      }
    }
    return best;
  }

  /// Dispara o especial do elemento atual (modo meter), consumindo o medidor.
  void activateSpecial() {
    if (!canActivateSpecial) return;
    final el = specialElement;
    gameState.consumeSpecialMeter();
    specialMeterProgress.value = 0;
    _fireSpecialAtAnchor(el);
    if (phase != GamePhase.shooting) _pendingForceReturn = false;
  }

  /// Rewarded: ativa um especial imediatamente, ignorando medidor e cooldown.
  /// Uma vez por partida; o anúncio já foi assistido quando isto roda.
  void activateSpecialViaAd() {
    if (gameState.specialAdUsed) return;
    final el = specialElement;
    if (el == ElementType.neutral) return;
    gameState.specialAdUsed = true;
    gameState.tideCooldown = 0;
    gameState.notifyListeners();
    _fireSpecialAtAnchor(el);
    if (phase != GamePhase.shooting) _pendingForceReturn = false;
    _requestRepaint();
  }

  // ── Escolha do elemento da bola ───────────────────────────────────────────

  /// Transmutação: dá para usar se há carga e a rodada está na mira ou em voo.
  bool get canTransmute =>
      gameState.transmuteCharges > 0 &&
      (phase == GamePhase.aim || phase == GamePhase.shooting);

  /// Troca: só em voo, 1× por turno, e só se alguma bola já tem elemento.
  bool get canSwapElement =>
      phase == GamePhase.shooting && !_swapUsed && _hasElementalBall();

  bool _hasElementalBall() {
    for (var i = 0; i < balls.count; i++) {
      if (balls.state[i] == BallPool.flying &&
          balls.element[i] != ElementType.neutral.index) {
        return true;
      }
    }
    return false;
  }

  /// Transmutação: gasta 1 carga e TODAS as bolas da rodada (já em voo, na
  /// fila e as que o próximo tiro lançar) passam a ter [el].
  bool transmuteBalls(ElementType el) {
    if (el == ElementType.neutral || !canTransmute) return false;
    if (!gameState.useTransmuteCharge()) return false;
    _roundEl = el.index;
    _queue.setAllElements(_roundEl);
    for (var i = 0; i < balls.count; i++) {
      if (balls.state[i] == BallPool.flying) balls.element[i] = _roundEl;
    }
    _elementShiftFx(el);
    return true;
  }

  /// Troca: as bolas em voo que JÁ têm elemento passam a ter [el]. Uma vez
  /// por turno; mantém a graça das combinações (a ordem continua importando).
  bool swapBallElement(ElementType el) {
    if (el == ElementType.neutral || !canSwapElement) return false;
    _swapUsed = true;
    for (var i = 0; i < balls.count; i++) {
      if (balls.state[i] == BallPool.flying &&
          balls.element[i] != ElementType.neutral.index) {
        balls.element[i] = el.index;
      }
    }
    swapAvailable.value = false;
    _elementShiftFx(el);
    return true;
  }

  /// Rewarded: ganha uma carga de Transmutação. Uma vez por partida; o
  /// anúncio já foi assistido quando isto roda.
  bool grantTransmuteViaAd() {
    if (gameState.elementAdUsed) return false;
    gameState.elementAdUsed = true;
    gameState.addTransmuteCharge();
    gameState.notifyListeners();
    return true;
  }

  void _elementShiftFx(ElementType el) {
    final color = elementDataMap[el]!.ballColor.toARGB32();
    particles.burst(originX, floorY, color, profile.particlesPerBurst * 2,
        speed: 160);
    var shown = 0;
    for (var i = 0; i < balls.count && shown < 12; i++) {
      if (balls.state[i] != BallPool.flying) continue;
      particles.burst(balls.x[i], balls.y[i], color, 3, speed: 70);
      shown++;
    }
    gameState.announce('el:${el.index}');
    AudioService.instance.playPickup();
    HapticService.instance.hit();
    _requestRepaint();
  }

  /// true se algum especial foi comprado (HUD mostra o medidor).
  bool get anySpecialOwned {
    for (final e in kCombatElements) {
      if (gameState.specialLevel(e) > 0) return true;
    }
    return false;
  }

  void _fireSpecialAtAnchor(ElementType el) {
    // Âncora: o bloco com mais HP (alvo que mais rende).
    BlockComponent? anchor;
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      if (anchor == null || b.hp > anchor.hp) anchor = b;
    }
    if (anchor == null) return;
    _fireSpecial(el, anchor.position.x + anchor.size.x / 2,
        anchor.position.y + anchor.size.y / 2);
  }

  /// Efeito do especial de [el], no ponto ([x], [y]).
  void _fireSpecial(ElementType el, double x, double y) {
    final level = gameState.specialLevel(el);
    if (level <= 0) return;
    // Maré em recarga não dispara (modos passivos): não conta como uso.
    if (el == ElementType.water && gameState.tideCooldown > 0) return;
    final dmg = ElementConfig.specialDamage(_damage.base, level);
    DailyMissionService.instance.track(MissionType.useSpecials);
    gameState.announce('sp:${el.index}');
    AudioService.instance.playSpecial();
    HapticService.instance.blockBreak();
    particles.burst(x, y, elementDataMap[el]!.ballColor.toARGB32(),
        profile.particlesPerBurst * 2, speed: 200);
    switch (el) {
      case ElementType.fire:
        // Linha de fogo: sobe do chão ao topo atingindo todos os blocos.
        _startFireWave(dmg);
      case ElementType.water:
        // Maré: uma onda circular atinge todos os blocos e TODOS são
        // empurrados 1 linha para trás no fim da rodada. Cooldown em turnos (a distância é sempre 1).
        if (gameState.tideCooldown > 0) return;
        _startTide(max(1, (dmg * ElementConfig.tideDmgMult).ceil()));
        _pushAllRows = true;
        gameState.tideCooldown = ElementConfig.tideCooldown(level);
      case ElementType.wind:
        // Rajada: lâminas de vento cruzam a tela cortando tudo; no fim da
        // rodada os blocos são juntados ao centro (abre corredores nas
        // laterais; sinergia com a Linha de Fogo).
        _startWind(max(1, (dmg * ElementConfig.windGustDmg).ceil()));
        _gatherCenter = true;
      case ElementType.lightning:
        // Descarga: um raio cai do céu e salta de bloco em bloco.
        _startLightning(x, y, ElementConfig.lightningJumps(level), dmg);
      case ElementType.earth:
        // Impacto: uma rocha cai e o dano % do HP atual atinge a área —
        // continua útil no late game.
        _startQuake(x, y, ElementConfig.earthPct(level), dmg);
      case ElementType.neutral:
        break;
    }
  }

  /// Inicia a linha de fogo: a frente nasce no chão e sobe até o topo
  /// ([_advanceFireWave]). Ativar de novo recomeça a onda do chão.
  void _startFireWave(int dmg) {
    _fireWaveId++;
    _fireWaveDmg = dmg;
    fireWaveY = floorY;
  }

  /// Sobe a frente de fogo. Cada bloco leva o dano UMA vez, no momento em que
  /// a frente passa pelo centro dele (de baixo para cima, como se vê), e
  /// fica em chamas. Roda no update, fora do loop de colisão das bolas.
  void _advanceFireWave(double dt) {
    fireWaveY -= ElementConfig.fireWaveSpeed * dt;
    final front = fireWaveY;
    final burn = max(1, (_fireWaveDmg * ElementConfig.fireWaveBurnFrac).ceil());
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (b.fireWaveId == _fireWaveId) continue;
      // Já passou pelo bloco: o centro dele está abaixo da frente.
      if (b.position.y + b.size.y / 2 < front) continue;
      b.fireWaveId = _fireWaveId;
      if (!_effectTarget(b)) continue;
      particles.burst(b.position.x + b.size.x / 2, b.position.y + b.size.y / 2,
          0xFFFF9A3C, profile.particlesPerBurst ~/ 2, speed: 120);
      final died = _effectDamage(b, _fireWaveDmg);
      if (!died && b.isAlive) {
        b.status.applyBurn(turns: ElementConfig.fireWaveBurnTurns, damage: burn);
        DailyMissionService.instance.track(MissionType.statusBlocks);
      }
    }
    // Faíscas ao longo da frente (limitadas pela qualidade gráfica).
    particles.burst(_rng.nextDouble() * size.x, front, 0xFFFFC857, 2,
        speed: 70);
    if (front < topOffset - 12) fireWaveY = -1;
    // Boss morto fora da jogada: a rodada não está em curso, então não há o
    // que forçar a voltar (a flag ficaria pendente para o próximo tiro).
    if (phase != GamePhase.shooting) _pendingForceReturn = false;
  }

  /// Inicia a Rajada: uma lâmina por faixa horizontal, de cima para baixo.
  void _startWind(int dmg) {
    _windWaveId++;
    _windDmg = dmg;
    windElapsed = 0;
    windBladeLanes = min(_maxWindLanes,
        ((floorY - topOffset) / ElementConfig.windBladeLane).ceil());
    windBladeDir.fillRange(0, _maxWindLanes, 0);
  }

  /// Move as lâminas. Cada uma cruza a tela em [ElementConfig.windBladeTravel]
  /// s com uma leve oscilação vertical, alternando a direção por faixa, e
  /// corta (dano único por bloco) tudo que fica ao alcance dela. As faixas
  /// se sobrepõem: nenhum bloco escapa. Roda no update, fora do loop de
  /// colisão das bolas.
  void _advanceWind(double dt) {
    windElapsed += dt;
    const margin = 40.0;
    final w = size.x;
    final travel = ElementConfig.windBladeTravel;
    final stagger = ElementConfig.windBladeStagger;
    final lane = ElementConfig.windBladeLane;
    final r2 = ElementConfig.windBladeRadius * ElementConfig.windBladeRadius;
    for (var i = 0; i < windBladeLanes; i++) {
      final ti = windElapsed - i * stagger;
      if (ti < 0 || ti > travel) {
        windBladeDir[i] = 0;
        continue;
      }
      final p = ti / travel;
      final dir = i.isEven ? 1 : -1;
      final bx = dir > 0
          ? -margin + p * (w + 2 * margin)
          : w + margin - p * (w + 2 * margin);
      final by = topOffset + lane / 2 + i * lane + 8 * sin(ti * 14 + i * 2);
      windBladeX[i] = bx;
      windBladeY[i] = by;
      windBladeDir[i] = dir;
      for (var k = blocks.length - 1; k >= 0; k--) {
        final b = blocks[k];
        if (b.windWaveId == _windWaveId) continue;
        final dx = b.position.x + b.size.x / 2 - bx;
        final dy = b.position.y + b.size.y / 2 - by;
        if (dx * dx + dy * dy > r2) continue;
        b.windWaveId = _windWaveId;
        if (!_effectTarget(b)) continue;
        particles.burst(b.position.x + b.size.x / 2,
            b.position.y + b.size.y / 2, 0xFFD6F5A0,
            profile.particlesPerBurst ~/ 2, speed: 130);
        _effectDamage(b, _windDmg);
      }
    }
    if (windElapsed > (windBladeLanes - 1) * stagger + travel) {
      windElapsed = -1;
      windBladeDir.fillRange(0, _maxWindLanes, 0);
    }
    if (phase != GamePhase.shooting) _pendingForceReturn = false;
  }

  /// Inicia a Maré: um anel de água nasce no ponto de lançamento e se expande
  /// até cobrir o tabuleiro inteiro ([_advanceTide]).
  void _startTide(int dmg) {
    _tideWaveId++;
    _tideDmg = dmg;
    tideOriginX = originX;
    tideOriginY = floorY;
    tideRadius = 0;
    // Alcance: até o canto mais distante da área de jogo.
    final dx = max(originX, size.x - originX);
    final dy = floorY - topOffset;
    _tideMaxRadius = sqrt(dx * dx + dy * dy) + 24;
  }

  /// Expande o anel. Cada bloco leva o dano UMA vez, quando a frente chega ao
  /// centro dele (os mais próximos primeiro — dá para ver a onda passando).
  /// Roda no update, fora do loop de colisão das bolas.
  void _advanceTide(double dt) {
    tideRadius += ElementConfig.tideSpeed * dt;
    final r = tideRadius;
    final r2 = r * r;
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (b.tideWaveId == _tideWaveId) continue;
      final dx = b.position.x + b.size.x / 2 - tideOriginX;
      final dy = b.position.y + b.size.y / 2 - tideOriginY;
      if (dx * dx + dy * dy > r2) continue; // a frente ainda não chegou
      b.tideWaveId = _tideWaveId;
      if (!_effectTarget(b)) continue;
      particles.burst(b.position.x + b.size.x / 2, b.position.y + b.size.y / 2,
          0xFF8FD8FF, profile.particlesPerBurst ~/ 2, speed: 110);
      _effectDamage(b, _tideDmg);
    }
    // Respingos ao longo da crista (limitados pela qualidade gráfica).
    final a = pi + _rng.nextDouble() * pi; // semicírculo de cima
    particles.burst(tideOriginX + cos(a) * r, tideOriginY + sin(a) * r,
        0xFFBEE6FF, 2, speed: 60);
    if (r > _tideMaxRadius) tideRadius = -1;
    if (phase != GamePhase.shooting) _pendingForceReturn = false;
  }

  /// Inicia a Descarga: o raio cai do céu sobre ([x], [y]) e salta, a cada
  /// [ElementConfig.boltStep] s, para o bloco mais próximo ainda não atingido
  /// ([_advanceLightning]). O primeiro golpe é imediato.
  void _startLightning(double x, double y, int jumps, int dmg) {
    boltClock = 0;
    _boltEndClock = -1;
    _boltTargets = 0;
    _boltJumps = min(jumps, _boltVisited.length);
    _boltDmg = dmg;
    _boltNextAt = ElementConfig.boltStep;
    boltX[0] = x;
    boltY[0] = topOffset - 14;
    boltBorn[0] = animTime;
    boltCount = 1;
    _boltCx = x;
    _boltCy = y;
    _boltStrike();
  }

  double _boltCx = 0, _boltCy = 0;

  /// Um salto: acha o bloco mais próximo ainda não atingido, revela o ponto e
  /// dá o dano. Sem alvo, a descarga termina.
  void _boltStrike() {
    BlockComponent? best;
    var bestD = double.infinity;
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      var seen = false;
      for (var v = 0; v < _boltTargets; v++) {
        if (_boltVisited[v] == b.serial) {
          seen = true;
          break;
        }
      }
      if (seen) continue;
      final dx = b.position.x + b.size.x / 2 - _boltCx;
      final dy = b.position.y + b.size.y / 2 - _boltCy;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    if (best == null || boltCount >= _maxBoltPts) {
      _boltTargets = _boltJumps; // acabou
      _boltEndClock = boltClock;
      return;
    }
    _boltVisited[_boltTargets++] = best.serial;
    _boltCx = best.position.x + best.size.x / 2;
    _boltCy = best.position.y + best.size.y / 2;
    boltX[boltCount] = _boltCx;
    boltY[boltCount] = _boltCy;
    boltBorn[boltCount] = animTime;
    boltCount++;
    particles.burst(_boltCx, _boltCy, 0xFFE1BEE7, profile.particlesPerBurst,
        speed: 170);
    _effectDamage(best, _boltDmg);
    if (_boltTargets >= _boltJumps) _boltEndClock = boltClock;
  }

  /// Avança a Descarga: um salto por passo e, no fim, o raio esmaece. Roda no
  /// update, fora do loop de colisão das bolas.
  void _advanceLightning(double dt) {
    boltClock += dt;
    if (_boltEndClock < 0) {
      _boltNextAt -= dt;
      while (_boltNextAt <= 0 && _boltEndClock < 0) {
        _boltStrike();
        _boltNextAt += ElementConfig.boltStep;
      }
    } else if (boltClock - _boltEndClock > ElementConfig.boltFade) {
      boltClock = -1;
      boltCount = 0;
    }
    if (phase != GamePhase.shooting) _pendingForceReturn = false;
  }

  /// Opacidade (0–1) do raio: cheio durante os saltos, esmaece no fim.
  double get boltAlpha {
    if (_boltEndClock < 0) return 1;
    return (1 - (boltClock - _boltEndClock) / ElementConfig.boltFade)
        .clamp(0.0, 1.0);
  }

  /// Inicia o Impacto: uma rocha cai sobre ([x], [y]) e, ao tocar o chão,
  /// dá o dano em área e abre a onda de choque ([_advanceQuake]).
  void _startQuake(double x, double y, double pct, int dmg) {
    quakeT = 0;
    quakeX = x;
    quakeY = y;
    _quakeLanded = false;
    _quakeDmg = dmg;
    _quakePct = pct;
  }

  void _advanceQuake(double dt) {
    quakeT += dt;
    if (!_quakeLanded && quakeT >= ElementConfig.earthFall) {
      _quakeLanded = true;
      _earthImpact(
          quakeX, quakeY, ElementConfig.earthCells, _quakePct, _quakeDmg);
      // Poeira e pedras, e o tabuleiro inteiro treme.
      particles.burst(quakeX, quakeY, 0xFF8D6E63,
          profile.particlesPerBurst * 3, speed: 230);
      particles.burst(quakeX, quakeY, 0xFFD7CCC8, profile.particlesPerBurst,
          speed: 120);
      for (var i = 0; i < blocks.length; i++) {
        blocks[i].triggerShake();
      }
      HapticService.instance.blockBreak();
    }
    if (quakeT >= ElementConfig.earthFall + ElementConfig.earthShock) {
      quakeT = -1;
    }
    if (phase != GamePhase.shooting) _pendingForceReturn = false;
  }

  void _earthImpact(double cx, double cy, int sizeCells, double pct, int dmg) {
    final h = sizeCells * blockSize / 2;
    for (var i = blocks.length - 1; i >= 0; i--) {
      final b = blocks[i];
      if (!_effectTarget(b)) continue;
      final bx = b.position.x + b.size.x / 2;
      final by = b.position.y + b.size.y / 2;
      if ((bx - cx).abs() < h + b.size.x / 2 - 1 &&
          (by - cy).abs() < h + b.size.y / 2 - 1) {
        _effectDamage(b, max(dmg, (b.hp * pct).ceil()));
      }
    }
  }

  void _hitWall(int i, BlockComponent block, double left, double top,
      double right, double bottom) {
    // Determine which face was hit
    final face = _contactFace(i, block, left, top, right, bottom);
    if (face != _faceTop) {
      // Front or sides — reflect without damage
      AudioService.instance.playWall();
      _reflectFace(i, face, left, top, right, bottom);
      return;
    }
    // Hit from the back (top face).
    // Muro elemental só cai para bola com elemento (absorvido de um bloco
    // especial); muro neutro cai para qualquer bola.
    final canDamage = block.element == ElementType.neutral ||
        balls.element[i] != ElementType.neutral.index;
    if (!canDamage) {
      // Bola neutra — reflects like the front face
      AudioService.instance.playWall();
      _reflectFace(i, _faceTop, left, top, right, bottom);
      return;
    }
    // Cada bola do grupo tira 1 de durabilidade até o muro cair.
    final w = balls.weight[i];
    var hits = 0;
    while (hits < w && block.isAlive) {
      block.takeDamage(1);
      hits++;
    }
    balls.idle[i] = 0;
    block.triggerShake();
    if (!block.isAlive) {
      _removeBlock(block);
      gameState.addScore(10);
      AudioService.instance.playBreak();
      HapticService.instance.blockBreak();
      _burst(block, 0xFF7799CC, 1);
      _splitAfterKill(i, hits, _faceTop, left, top, right, bottom);
      return;
    }
    AudioService.instance.playHit();
    HapticService.instance.hit();
    _reflectFace(i, _faceTop, left, top, right, bottom);
  }

  bool _hitDamageable(int i, BlockComponent block, double left, double top,
      double right, double bottom) {
    // Bola perfurante (combo Relâmpago ou power-up): dano sem ricochete, uma
    // vez por passagem — usa a mesma memória de contato dos blocos especiais.
    final piercing = balls.pierceTime[i] > 0 || balls.pierceLeft[i] > 0;
    if (piercing) {
      _touchingSpecial = true;
      if (balls.lastSpecial[i] == block.serial) return false;
      balls.lastSpecial[i] = block.serial;
      final died = _applyBallDamage(i, block);
      if (balls.pierceLeft[i] > 0) balls.pierceLeft[i]--;
      if (died && !block.isBoss) return false;
      return _pendingForceReturn;
    }

    // A face sai antes do dano: com o bloco removido, os vizinhos mudam.
    final face = _contactFace(i, block, left, top, right, bottom);
    _applyBallDamage(i, block);

    if (!block.isAlive) {
      if (block.isBoss) {
        // Don't call forceReturn() here — we're inside the balls loop.
        // Signal the caller instead.
        return true;
      }
      _splitAfterKill(i, _lastHits, face, left, top, right, bottom);
      return false;
    }
    AudioService.instance.playHit();
    HapticService.instance.hit();
    // bounce + push ball out of block to prevent multi-step hits
    _reflectFace(i, face, left, top, right, bottom);
    return false;
  }

  /// Nº de bolas do grupo que bateram no último [_applyBallDamage].
  int _lastHits = 0;

  /// Aplica o dano da bola [i] no [block] (grupo de peso w = w bolas em
  /// sequência), com multiplicadores de status e de zona elétrica, gatilho de
  /// especial e recompensas. Devolve true se o bloco morreu (boss marca
  /// [_pendingForceReturn]).
  bool _applyBallDamage(int i, BlockComponent block) {
    final w = balls.weight[i];
    // Status no bloco (amolecido, congelado) multiplicam o dano recebido;
    // campo eletrificado multiplica o dano das bolas dentro dele.
    var mult = block.status.isEmpty
        ? 1.0
        : block.status.damageMult(
            ElementConfig.softenedDamageMult, ElementConfig.frozenDamageMult);
    if (zones.count > 0) {
      mult *= zones.ballDamageMultAt(balls.x[i], balls.y[i]);
    }
    var hits = 0, crits = 0;
    while (hits < w) {
      var dmg = _damage.roll();
      if (mult != 1.0) dmg = (dmg * mult).ceil();
      hits++;
      if (_damage.lastCrit) crits++;
      block.takeDamage(dmg);
      if (!block.isAlive) break;
    }
    _lastHits = hits;
    balls.idle[i] = 0;
    gameState.addScore(hits);
    if (crits > 0) {
      DailyMissionService.instance.track(MissionType.critHits, crits);
      if (block.isAlive) block.triggerShake();
    }
    // Gatilho do especial: o medidor conta acertos (100 = cheio); os modos
    // passivos usam só batidas de bola com elemento.
    final el = balls.element[i];
    if (ElementConfig.triggerMode == SpecialTriggerMode.meter &&
        (el != 0 || !ElementConfig.meterCountsOnlyElementalHits)) {
      gameState.addSpecialHits(hits);
    }
    if (el != 0) _onElementalHit(ElementType.values[el], block);

    if (!block.isAlive) {
      _rewardKill(block);
      final wasBoss = block.isBoss;
      _removeBlock(block);
      if (wasBoss) _pendingForceReturn = true;
      return true;
    }
    return false;
  }

  /// Recompensas de um bloco destruído (por bola ou por status de turno).
  void _rewardKill(BlockComponent block) {
    AudioService.instance.playBreak();
    HapticService.instance.blockBreak();
    final missions = DailyMissionService.instance;
    missions.track(MissionType.breakBlocks);
    if (block.goldValue > 0) {
      final goldBefore = gameState.gold;
      gameState.earnGold(
          block.isBoss ? block.goldValue * 2 : block.goldValue,
          multiplier: PurchaseService.instance.goldMultiplier *
              (_goldBoostRounds > 0 ? 2 : 1));
      missions.track(MissionType.earnGold, gameState.gold - goldBefore);
    }
    gameState.addScore(block.isBoss ? 20 : 3);
    final color = elementDataMap[block.element]!.blockBg.toARGB32();
    _burst(block, color, block.isBoss ? 3 : 1);
  }

  /// Grupo que quebrou um bloco: as bolas que bateram antes da última quicam,
  /// a que quebrou e as seguintes passam. Vira dois objetos enquanto houver
  /// espaço; senão o grupo segue inteiro pelo caminho da maioria.
  void _splitAfterKill(int i, int killedAt, int face, double left, double top,
      double right, double bottom) {
    final bounced = killedAt - 1;
    if (bounced <= 0) return;
    final passing = balls.weight[i] - bounced;
    var j = i;
    if (balls.count < PerfConfig.maxBallObjects) {
      j = balls.spawn(balls.x[i], balls.y[i], balls.vx[i], balls.vy[i],
          balls.element[i], bounced);
      balls.weight[i] = passing;
    } else if (bounced <= passing) {
      return;
    }
    _reflectFace(j, face, left, top, right, bottom);
  }

  static const int _faceLeft = 0, _faceRight = 1, _faceTop = 2, _faceBottom = 3;

  /// Face do bloco que a bola tocou, pelo ponto do bloco mais próximo do
  /// centro da bola: com o centro dentro da largura do bloco, foi a face de
  /// cima ou de baixo; dentro da altura, uma lateral. Na quina vale a face
  /// exposta (sem bloco sólido colado): numa fileira lado a lado, a junção
  /// entre dois blocos não é quina e a bola quica como numa superfície lisa.
  /// Com as duas expostas, decide o eixo dominante (empate: vertical).
  int _contactFace(int i, BlockComponent block, double left, double top,
      double right, double bottom) {
    final x = balls.x[i], y = balls.y[i];
    final inX = x >= left && x <= right, inY = y >= top && y <= bottom;
    final hFace = x < (left + right) / 2 ? _faceLeft : _faceRight;
    final vFace = y < (top + bottom) / 2 ? _faceTop : _faceBottom;
    if (inX && !inY) return vFace;
    if (inY && !inX) return hFace;
    var exposed = _grid.exposedFaces(block);
    if (exposed == 0) exposed = 15; // cercado: vale qualquer face
    if (!inX && !inY) {
      final hOk = (exposed &
              (hFace == _faceLeft ? BlockGrid.faceLeft : BlockGrid.faceRight)) !=
          0;
      final vOk = (exposed &
              (vFace == _faceTop ? BlockGrid.faceTop : BlockGrid.faceBottom)) !=
          0;
      if (hOk != vOk) return hOk ? hFace : vFace;
      final dx = x < left ? left - x : x - right;
      final dy = y < top ? top - y : y - bottom;
      return dx > dy ? hFace : vFace;
    }
    // Centro dentro do bloco (raro com substeps): a face exposta mais próxima.
    const inf = double.infinity;
    final dl = (exposed & BlockGrid.faceLeft) != 0 ? (x - left).abs() : inf;
    final dr = (exposed & BlockGrid.faceRight) != 0 ? (x - right).abs() : inf;
    final dt = (exposed & BlockGrid.faceTop) != 0 ? (y - top).abs() : inf;
    final db = (exposed & BlockGrid.faceBottom) != 0 ? (y - bottom).abs() : inf;
    final ox = dl < dr ? dl : dr, oy = dt < db ? dt : db;
    if (ox < oy) return dl <= dr ? _faceLeft : _faceRight;
    return dt <= db ? _faceTop : _faceBottom;
  }

  /// Reflete pela [face] e empurra a bola para fora do bloco. A velocidade
  /// passa a apontar para fora da face (nunca de volta para dentro, mesmo
  /// tocando dois blocos no mesmo passo).
  void _reflectFace(int i, int face, double left, double top, double right,
      double bottom) {
    final r = balls.radius[i];
    switch (face) {
      case _faceLeft:
        balls.vx[i] = -balls.vx[i].abs();
        balls.x[i] = left - r - 1;
      case _faceRight:
        balls.vx[i] = balls.vx[i].abs();
        balls.x[i] = right + r + 1;
      case _faceTop:
        balls.vy[i] = -balls.vy[i].abs();
        balls.y[i] = top - r - 1;
      default:
        balls.vy[i] = balls.vy[i].abs();
        balls.y[i] = bottom + r + 1;
    }
  }

  void _removeBlock(BlockComponent block) {
    _grid.remove(block);
    blocks.remove(block);
  }

  void _burst(BlockComponent block, int argb, double scale) {
    final n = (profile.particlesPerBurst * scale).round();
    if (n <= 0) return;
    particles.burst(block.position.x + block.size.x / 2,
        block.position.y + block.size.y / 2, argb, n);
  }

  /// Quatro bolas novas, cada uma mirando um dos blocos mais próximos.
  void _spawnTriple(int i) {
    final bx = balls.x[i], by = balls.y[i];
    var found = 0;
    for (var k = 0; k < blocks.length; k++) {
      final c = blocks[k];
      final ddx = c.position.x + c.size.x / 2 - bx;
      final ddy = c.position.y + c.size.y / 2 - by;
      final d = ddx * ddx + ddy * ddy;
      if (found == 4 && d >= _nearD[3]) continue;
      var pos = found < 4 ? found++ : 3;
      while (pos > 0 && _nearD[pos - 1] > d) {
        _nearD[pos] = _nearD[pos - 1];
        _nearB[pos] = _nearB[pos - 1];
        pos--;
      }
      _nearD[pos] = d;
      _nearB[pos] = c;
    }
    final baseAng = atan2(balls.vy[i], balls.vx[i]);
    for (var k = 0; k < 4; k++) {
      double targetAng;
      final target = k < found ? _nearB[k] : null;
      if (target != null) {
        targetAng = atan2(target.position.y + target.size.y / 2 - by,
            target.position.x + target.size.x / 2 - bx);
      } else {
        targetAng = baseAng + _tripleFallback[k];
      }
      final j = balls.spawn(bx, by, cos(targetAng) * ballSpeed,
          sin(targetAng) * ballSpeed, ElementType.neutral.index, 1);
      _enforceMinAngle(j);
    }
    _nearB.fillRange(0, 4, null);
  }

  /// Garante que a velocidade forme pelo menos [minBallAngle] com os dois
  /// eixos, mantendo a velocidade e o sentido em cada eixo.
  void _enforceMinAngle(int i) {
    final vx = balls.vx[i], vy = balls.vy[i];
    final speed = sqrt(vx * vx + vy * vy);
    if (speed == 0) return;
    final minComp = _minComp * speed;
    final maxComp = _maxComp * speed;
    if (vy.abs() < minComp) {
      final sy = vy < 0 ? -1.0 : 1.0;
      balls.vx[i] = (vx < 0 ? -1 : 1) * maxComp;
      balls.vy[i] = sy * minComp;
    } else if (vx.abs() < minComp) {
      final sx = vx == 0 ? (_rng.nextBool() ? 1.0 : -1.0) : vx.sign;
      balls.vx[i] = sx * minComp;
      balls.vy[i] = (vy < 0 ? -1 : 1) * maxComp;
    }
  }

  /// Gira a velocidade entre 20° e 40° para um lado aleatório, quebrando o loop.
  void _nudge(int i) {
    final delta =
        (20 + _rng.nextDouble() * 20) * pi / 180 * (_rng.nextBool() ? 1 : -1);
    final vx = balls.vx[i], vy = balls.vy[i];
    final ang = atan2(vy, vx) + delta;
    final speed = sqrt(vx * vx + vy * vy);
    balls.vx[i] = cos(ang) * speed;
    balls.vy[i] = sin(ang) * speed;
  }

  void _updateReturning(double dt) {
    const speed = 1 / 0.6; // complete in 0.6 seconds
    var allArrived = true;
    final ex = returnTargetX ?? originX, ey = floorY;
    for (var i = 0; i < balls.count; i++) {
      final t = min(1.0, balls.t[i] + dt * speed), mt = 1 - t;
      balls.t[i] = t;
      balls.x[i] =
          mt * mt * balls.sx[i] + 2 * mt * t * balls.cx[i] + t * t * ex;
      balls.y[i] =
          mt * mt * balls.sy[i] + 2 * mt * t * balls.cy[i] + t * t * ey;
      if (t < 1) allArrived = false;
    }
    if (allArrived) _finishRound();
  }

  void handlePointerPosition(Offset pos) {
    if (phase != GamePhase.aim) return;
    double ang = atan2(pos.dy - floorY, pos.dx - originX);
    ang = ang.clamp(-pi + 0.15, -0.15);
    aimAngle = ang;
  }

  void handleTap(Offset pos) {
    if (phase == GamePhase.shooting) {
      forceReturn();
      return;
    }
    if (phase != GamePhase.aim) return;
    handlePointerPosition(pos);
    shoot();
  }

  /// Chamado após o jogador assistir ao anúncio premiado no game over.
  /// Move todos os blocos uma linha para cima e retoma o jogo.
  void continueAfterAd() {
    for (final b in blocks) {
      b.position.y -= blockSize;
    }
    _grid.rebuild(blocks);
    gameState.continueAfterAd();
    _setPhase(GamePhase.aim);
  }

  void continueToNextStage() {
    gameState.advanceStage();
    _loadBlocks();
    _setPhase(GamePhase.menu);
    _requestRepaint();
  }

  void pauseGame() {
    _userPaused = true;
    _syncEngine();
  }

  void resumeGame() {
    _userPaused = false;
    _syncEngine();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderer?.render(canvas, this);
  }

  // ── Ganchos de teste ─────────────────────────────────────────────────────

  /// Começa uma rodada sem fila de tiros, para os testes soltarem bolas
  /// direto em [balls].
  @visibleForTesting
  void debugBeginRound() {
    _damage.refresh(gameState);
    _grid.rebuild(blocks);
    balls.clear();
    _queue.clear();
    _accumulator = 0;
    _setPhase(GamePhase.shooting);
  }

  @visibleForTesting
  int get queuedWeight => _queue.totalWeight;
}
