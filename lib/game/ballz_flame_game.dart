import 'dart:math';
import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'components/block_component.dart';
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
      aimSteps = (baseAimLength + gameState.aimBonus) / 3;
      aimBounces = gameState.maxBounces;
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
    final el = gameState.ballElement.index;
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

  void _spawnPowerUpRow() {
    const powerUpCount = 3;
    final cols = List.generate(9, (i) => i)..shuffle(_rng);
    final chosen = cols.take(powerUpCount).toList()..sort();
    for (final c in chosen) {
      final isTriple = _rng.nextBool();
      blocks.add(BlockComponent(
        position: Vector2(c * blockSize + 1, topOffset + 1),
        type: isTriple ? BlockType.triple : BlockType.bonus,
        hp: 0,
        maxHp: 0,
        element: ElementType.neutral,
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

    // Status por turno (chamas, ácido...): uma vez por rodada, nunca por frame.
    _processTurnStatuses();

    // descend blocks
    for (final b in blocks) {
      b.position.y += blockSize;
      // Ouro que desce sem ser coletado vale menos: incentiva quebrar logo.
      if (!b.isBoss && b.goldValue > goldDecayFloor) b.goldValue--;
    }

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
      BlockType.elemPower,
      BlockType.wall
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
      AudioService.instance.playWaveClear();
      // Spawn 2 fresh rows for the next wave (field is empty, no overlap check needed)
      final dom = allElements[_rng.nextInt(allElements.length)];
      for (int r = 0; r < 2; r++) {
        final newRow = generateRow(gameState.stage, dom, r);
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
            _queue.outWeight);
        _shotTimer = shotInterval;
      }
    }

    _stepCount++;
    // Bolas criadas neste passo (triplo, divisão) só andam no próximo.
    final n = balls.count;
    for (var i = 0; i < n; i++) {
      if (balls.state[i] != BallPool.flying) continue;
      _stepBall(i, h);
      // boss died: finish loop before touching the balls
      if (_pendingForceReturn) break;
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
    final hs = h / _substeps;
    final w = size.x;
    for (var s = 0; s < _substeps; s++) {
      var x = b.x[i] + b.vx[i] * hs;
      var y = b.y[i] + b.vy[i] * hs;

      // wall bounces
      if (x - ballRadius <= 1) {
        x = ballRadius + 1;
        b.vx[i] = b.vx[i].abs();
        AudioService.instance.playWall();
      }
      if (x + ballRadius >= w - 1) {
        x = w - ballRadius - 1;
        b.vx[i] = -b.vx[i].abs();
        AudioService.instance.playWall();
      }
      if (y - ballRadius <= topOffset) {
        y = topOffset + ballRadius;
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
    final x = balls.x[i], y = balls.y[i];
    final g = _grid;
    final c0 = ((x - ballRadius - g.originX) / blockSize).floor();
    final c1 = ((x + ballRadius - g.originX) / blockSize).floor();
    final r0 = ((y - ballRadius - g.originY) / blockSize).floor();
    final r1 = ((y + ballRadius - g.originY) / blockSize).floor();
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
  }

  /// Colisão círculo × retângulo. Devolve true se a bola deve parar de testar
  /// blocos neste substep (boss morreu).
  bool _hitBlock(int i, BlockComponent block) {
    final x = balls.x[i], y = balls.y[i];
    final left = block.position.x, top = block.position.y;
    final right = left + block.size.x, bottom = top + block.size.y;
    final nearX = x < left ? left : (x > right ? right : x);
    final nearY = y < top ? top : (y > bottom ? bottom : y);
    final dx = x - nearX, dy = y - nearY;
    if (dx * dx + dy * dy >= ballRadius * ballRadius) return false;

    switch (block.type) {
      case BlockType.bonus:
        _removeBlock(block);
        AudioService.instance.playBreak();
        HapticService.instance.blockBreak();
        gameState.incrementBallCount();
        DailyMissionService.instance.track(MissionType.collectBalls);
        _queue.pushFront(
            balls.vx[i], balls.vy[i], ElementType.neutral.index, 1);
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

      case BlockType.elemPower:
        final el = block.elemPowerEl;
        if (el != null) {
          gameState.ballElement = el;
          balls.setAllElements(el.index);
          _queue.setAllElements(el.index);
        }
        _removeBlock(block);
        AudioService.instance.playBreak();
        HapticService.instance.blockBreak();
        _burst(block, elementDataMap[el ?? ElementType.neutral]!.ballColor.toARGB32(),
            0.6);
        return false;

      case BlockType.wall:
        _hitWall(i, block, left, top, right, bottom);
        return false;

      default:
        return _hitDamageable(i, block, left, top, right, bottom);
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
    // Wall element check: only the counter-element destroys it
    // fire←water, water←wind, wind←fire  (mult > 1.0 = effective)
    final canDamage = block.element == ElementType.neutral ||
        _damage.rawMult(balls.element[i], block.element.index) > 1.0;
    if (!canDamage) {
      // Wrong element — reflects like the front face
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
    // A face sai antes do dano: com o bloco removido, os vizinhos mudam.
    final face = _contactFace(i, block, left, top, right, bottom);
    final atk = balls.element[i], def = block.element.index;
    // Um grupo de peso w equivale a w bolas seguidas: cada uma sorteia
    // crítico e bypass do vento, e as que sobram depois de o bloco cair não
    // gastam dano nele (seguem para outros blocos).
    final w = balls.weight[i];
    var hits = 0, crits = 0, advantage = 0;
    while (hits < w) {
      final dmg = _damage.roll(atk, def);
      hits++;
      if (_damage.lastCrit) crits++;
      if (_damage.lastAdvantage) advantage++;
      block.takeDamage(dmg);
      if (!block.isAlive) break;
    }
    balls.idle[i] = 0;
    gameState.addScore(hits);
    final missions = DailyMissionService.instance;
    if (advantage > 0) missions.track(MissionType.advantageHits, advantage);
    if (crits > 0) missions.track(MissionType.critHits, crits);

    if (!block.isAlive) {
      _rewardKill(block);
      final wasBoss = block.isBoss;
      _removeBlock(block);
      if (wasBoss) {
        // Don't call forceReturn() here — we're inside the balls loop.
        // Signal the caller instead.
        _pendingForceReturn = true;
        return true;
      }
      _splitAfterKill(i, hits, face, left, top, right, bottom);
      return false;
    }
    AudioService.instance.playHit();
    HapticService.instance.hit();
    if (crits > 0) block.triggerShake();
    // bounce + push ball out of block to prevent multi-step hits
    _reflectFace(i, face, left, top, right, bottom);
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
          multiplier: PurchaseService.instance.goldMultiplier);
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
    switch (face) {
      case _faceLeft:
        balls.vx[i] = -balls.vx[i].abs();
        balls.x[i] = left - ballRadius - 1;
      case _faceRight:
        balls.vx[i] = balls.vx[i].abs();
        balls.x[i] = right + ballRadius + 1;
      case _faceTop:
        balls.vy[i] = -balls.vy[i].abs();
        balls.y[i] = top - ballRadius - 1;
      default:
        balls.vy[i] = balls.vy[i].abs();
        balls.y[i] = bottom + ballRadius + 1;
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
