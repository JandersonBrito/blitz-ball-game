import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import '../game/ballz_flame_game.dart';
import '../game/managers/game_state.dart';
import '../services/settings_service.dart';
import '../services/ad_service.dart';
import '../services/consent_service.dart';
import '../services/purchase_service.dart';
import '../services/games_cloud_service.dart';
import 'consent_dialog.dart';
import 'hud_overlay.dart';
import 'special_button.dart';
import 'menu_overlay.dart';
import 'game_over_overlay.dart';
import 'stage_complete_overlay.dart';
import 'settings_screen.dart';
import 'help_offer_overlay.dart';
import 'shop_screen.dart';
import '../services/daily_mission_service.dart';
import '../models/daily_mission.dart';
import '../models/element.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;
  const GameScreen({super.key, required this.gameState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late BallzFlameGame _flameGame;
  late GameState _gameState;
  bool _isPaused = false;
  bool _showPauseSettings = false;
  bool _bannerLoaded = false;
  bool _showShop = false;
  String? _shopHint;

  // Wave toast state
  bool _waveToastVisible = false;
  int _toastStage = 1;
  int _toastWave = 1;
  int _toastTotal = 1;

  // Aviso de missão concluída
  DailyMission? _missionToast;
  int _missionToastSeq = 0;

  // Aviso de combinação nova descoberta (codex)
  String? _comboToast;
  int _comboToastSeq = 0;

  // Aviso do power-up coletado / especial disparado
  String? _announce;
  int _announceSeq = 0;

  @override
  void initState() {
    super.initState();
    _gameState = widget.gameState;
    if (_gameState.gameOver) _gameState.reset();
    _flameGame = _newGame();
    _gameState.addListener(_onGameStateChange);
    AdService.instance.addListener(_onAdsChange);
    PurchaseService.instance.addListener(_onAdsChange);
    DailyMissionService.instance.addListener(_onMissionsChange);
    WidgetsBinding.instance.addObserver(this);
    GamesCloudService.instance.submitStage(_gameState.stage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConsent();
      _claimPurchasedGold();
    });
  }

  BallzFlameGame _newGame() => BallzFlameGame(
      gameState: _gameState, settings: context.read<SettingsService>());

  Future<void> _checkConsent() async {
    if (!ConsentService.instance.hasBeenAsked) {
      if (!mounted) return;
      await showConsentDialog(context);
    } else {
      _loadBanner();
    }
  }

  @override
  void dispose() {
    _gameState.removeListener(_onGameStateChange);
    AdService.instance.removeListener(_onAdsChange);
    PurchaseService.instance.removeListener(_onAdsChange);
    DailyMissionService.instance.removeListener(_onMissionsChange);
    WidgetsBinding.instance.removeObserver(this);
    AdService.instance.disposeBanner();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      DailyMissionService.instance.flush();
      _gameState.flush();
    }
  }

  void _onMissionsChange() {
    final done = DailyMissionService.instance.justCompleted;
    if (done == null || !mounted) return;
    DailyMissionService.instance.clearJustCompleted();
    final seq = ++_missionToastSeq;
    setState(() => _missionToast = done);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && seq == _missionToastSeq) {
        setState(() => _missionToast = null);
      }
    });
  }

  void _onAdsChange() {
    if (mounted) setState(() {});
    _gameState.setStarterBalls(PurchaseService.instance.starterOwned,
        inMenu: _flameGame.phase == GamePhase.menu);
    _claimPurchasedGold();
  }

  bool _claiming = false;

  /// Passa o ouro comprado na loja para o jogo e avisa o jogador.
  Future<void> _claimPurchasedGold() async {
    if (_claiming || PurchaseService.instance.pendingGold == 0) return;
    _claiming = true;
    final amount = await PurchaseService.instance.claimPendingGold();
    _claiming = false;
    if (amount == 0 || !mounted) return;
    _gameState.addGold(amount);
    final l = context.read<SettingsService>().l10n;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.goldAdded(amount),
          style: const TextStyle(
              fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF1D9E75),
    ));
  }

  void _openShop([String? hint]) {
    setState(() {
      _showShop = true;
      _shopHint = hint;
    });
  }

  void _closeShop() => setState(() => _showShop = false);

  void _onGameStateChange() {
    // O serviço ignora fases repetidas ou menores que a melhor já enviada.
    GamesCloudService.instance.submitStage(_gameState.stage);
    final comboId = _gameState.comboToastId;
    if (comboId != null) {
      _gameState.clearComboToast();
      final seq = ++_comboToastSeq;
      setState(() => _comboToast = comboId);
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted && seq == _comboToastSeq) {
          setState(() => _comboToast = null);
        }
      });
    }
    final announce = _gameState.announceKey;
    if (announce != null) {
      _gameState.clearAnnounce();
      final seq = ++_announceSeq;
      setState(() => _announce = announce);
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted && seq == _announceSeq) {
          setState(() => _announce = null);
        }
      });
    }
    if (_gameState.showWaveToast && !_waveToastVisible) {
      setState(() {
        _waveToastVisible = true;
        _toastStage = _gameState.stage;
        _toastWave = _gameState.waveInStage;
        _toastTotal = _gameState.wavesInStage;
      });
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() => _waveToastVisible = false);
          _gameState.clearWaveToast();
        }
      });
    }
  }

  void _loadBanner() {
    AdService.instance.loadBanner(() {
      if (mounted) setState(() => _bannerLoaded = true);
    });
  }

  void _handleStartWave() {
    _flameGame.startWave();
    setState(() {});
  }

  void _handleRestart() {
    AdService.instance.showInterstitial();
    _gameState.reset();
    _flameGame = _newGame();
    setState(() {});
  }

  void _handleContinueAfterAd() {
    AdService.instance.showRewarded(() {
      if (PurchaseService.instance.adsRemoved) _gameState.freeContinueUsed = true;
      _flameGame.continueAfterAd();
      setState(() {});
    });
  }

  /// Quem comprou "Remover Anúncios" continua sem vídeo, uma vez por partida.
  bool get _canContinueAfterAd =>
      AdService.instance.isRewardedReady &&
      !(PurchaseService.instance.adsRemoved && _gameState.freeContinueUsed);

  void _handleSpecialAd() {
    AdService.instance.showRewarded(() {
      _flameGame.activateSpecialViaAd();
      setState(() {});
    });
  }

  void _handleElementAd() {
    AdService.instance.showRewarded(() {
      _flameGame.grantTransmuteViaAd();
      setState(() {});
    });
  }

  void _handleDoubleGold() {
    AdService.instance.showRewarded(() {
      _gameState.runGoldDoubled = true;
      _gameState.addGold(_gameState.runGoldEarned);
      setState(() {});
    });
  }

  void _handleHelpOfferAccepted() {
    AdService.instance.showRewarded(() {
      _gameState.applyHelpAssist();
      setState(() {});
    });
  }

  void _handleHelpOfferDismissed() {
    _gameState.dismissHelpOffer();
    setState(() {});
  }

  void _handleNextStage() {
    _gameState.clearStageComplete();
    _flameGame.continueToNextStage();
    setState(() {});
  }

  void _handleStageCompleteMenu() {
    _gameState.clearStageComplete();
    _flameGame.resumeGame();
    _gameState.reset();
    _flameGame = _newGame();
    setState(() {
      _isPaused = false;
    });
  }

  void _handlePause() {
    _flameGame.pauseGame();
    setState(() {
      _isPaused = true;
      _showPauseSettings = false;
    });
  }

  void _handleResume() {
    _flameGame.resumeGame();
    setState(() {
      _isPaused = false;
      _showPauseSettings = false;
    });
  }

  void _handleQuit() {
    _flameGame.resumeGame();
    _gameState.reset();
    _flameGame = _newGame();
    setState(() {
      _isPaused = false;
      _showPauseSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final bannerWidget = AdService.instance.bannerWidget;

    return ChangeNotifierProvider.value(
      value: _gameState,
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0a14),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
            children: [
              // ── Área de jogo ─────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    // Canvas Flame
                    MouseRegion(
                      onHover: (event) =>
                          _flameGame.handlePointerPosition(event.localPosition),
                      child: Listener(
                        onPointerMove: (event) =>
                            _flameGame.handlePointerPosition(event.localPosition),
                        onPointerUp: (event) =>
                            _flameGame.handleTap(event.localPosition),
                        child: GameWidget(game: _flameGame),
                      ),
                    ),

                    // HUD: camada própria; muda até 10x/s durante a jogada.
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: RepaintBoundary(
                        child: Consumer<GameState>(
                          builder: (ctx, state, _) => HudOverlay(
                            onPause: _handlePause,
                          ),
                        ),
                      ),
                    ),

                    // Botão do especial: canto inferior direito, só durante a
                    // jogada (mira e disparo). Poder do elemento atual.
                    Consumer<GameState>(
                      builder: (ctx, state, _) {
                        final phase = _flameGame.phase;
                        if (phase != GamePhase.aim &&
                            phase != GamePhase.shooting) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          right: 8,
                          bottom: 4,
                          child: SpecialButton(
                            game: _flameGame,
                            adReady: AdService.instance.isRewardedReady,
                            onActivate: () {
                              _flameGame.activateSpecial();
                              setState(() {});
                            },
                            onAdActivate: _handleSpecialAd,
                            onElementAd: _handleElementAd,
                          ),
                        );
                      },
                    ),

                    // Wave toast: o fade anima o alfa das cores, sem Opacity
                    // (que abriria um saveLayer por cima do jogo).
                    IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: _waveToastVisible ? 1.0 : 0.0),
                        duration: const Duration(milliseconds: 350),
                        builder: (_, opacity, __) => opacity == 0
                            ? const SizedBox.shrink()
                            : _WaveToast(
                                opacity: opacity,
                                stage: _toastStage,
                                wave: _toastWave,
                                total: _toastTotal,
                              ),
                      ),
                    ),

                    // Menu overlay
                    Consumer<GameState>(
                      builder: (ctx, state, _) {
                        if (_flameGame.phase != GamePhase.menu || state.gameOver) {
                          return const SizedBox.shrink();
                        }
                        return Positioned.fill(
                          child: MenuOverlay(
                              onStartWave: _handleStartWave,
                              onOpenShop: _openShop),
                        );
                      },
                    ),

                    // Pause overlay
                    if (_isPaused)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xDD0A0A14),
                          child: Center(
                            child: _showPauseSettings
                                ? SettingsScreen(
                                    onBack: () => setState(
                                        () => _showPauseSettings = false),
                                    gameState: _gameState,
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(l.paused,
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                              letterSpacing: 4,
                                              fontFamily: 'monospace')),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        width: 200,
                                        child: Column(
                                          children: [
                                            ElevatedButton(
                                              onPressed: _handleResume,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1D9E75),
                                                foregroundColor: Colors.white,
                                                minimumSize: const Size(
                                                    double.infinity, 48),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                              child: Text(l.continueGame,
                                                  style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            const SizedBox(height: 8),
                                            OutlinedButton(
                                              onPressed: () => setState(() =>
                                                  _showPauseSettings = true),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                    color: Color(0xFF378ADD)),
                                                foregroundColor:
                                                    const Color(0xFF378ADD),
                                                minimumSize: const Size(
                                                    double.infinity, 48),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                              child: Text(l.settingsBtn,
                                                  style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            const SizedBox(height: 8),
                                            OutlinedButton(
                                              onPressed: _handleQuit,
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                    color: Color(0xFFE24B4A)),
                                                foregroundColor:
                                                    const Color(0xFFE24B4A),
                                                minimumSize: const Size(
                                                    double.infinity, 48),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                              child: Text(l.quit,
                                                  style: const TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                    // Stage complete overlay
                    Consumer<GameState>(
                      builder: (ctx, state, _) {
                        if (!state.stageComplete) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: StageCompleteOverlay(
                            stage: state.stage,
                            score: state.score,
                            gold: state.gold,
                            onNextStage: _handleNextStage,
                            onMenu: _handleStageCompleteMenu,
                            onOpenShop: _openShop,
                          ),
                        );
                      },
                    ),

                    // Help offer overlay
                    Consumer<GameState>(
                      builder: (ctx, state, _) {
                        if (!state.showHelpOffer) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: HelpOfferOverlay(
                            fortress: state.isFortressStage,
                            onWatchAd: AdService.instance.isRewardedReady
                                ? _handleHelpOfferAccepted
                                : null,
                            onDismiss: _handleHelpOfferDismissed,
                          ),
                        );
                      },
                    ),

                    // Game over overlay
                    Consumer<GameState>(
                      builder: (ctx, state, _) {
                        if (!state.gameOver) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: GameOverOverlay(
                            onRestart: _handleRestart,
                            onOpenShop: _openShop,
                            onWatchAd: _canContinueAfterAd
                                ? _handleContinueAfterAd
                                : null,
                            onDoubleGold: AdService.instance.isRewardedReady &&
                                    !state.runGoldDoubled &&
                                    state.runGoldEarned > 0
                                ? _handleDoubleGold
                                : null,
                            doubleGoldAmount: state.runGoldEarned,
                          ),
                        );
                      },
                    ),

                    // Aviso de missão concluída: acima dos overlays de fim de fase/game over
                    Positioned(
                      top: 56, left: 0, right: 0,
                      child: IgnorePointer(
                        child: _missionToast == null
                            ? const SizedBox.shrink()
                            : _MissionToast(
                                key: ValueKey(_missionToastSeq),
                                mission: _missionToast!),
                      ),
                    ),

                    // "Nova combinação descoberta!" (codex)
                    Positioned(
                      top: 120, left: 0, right: 0,
                      child: IgnorePointer(
                        child: _comboToast == null
                            ? const SizedBox.shrink()
                            : _ComboToast(
                                key: ValueKey(_comboToastSeq),
                                comboId: _comboToast!),
                      ),
                    ),

                    // Power-up coletado / especial disparado: nome e efeito.
                    Positioned(
                      top: 176, left: 0, right: 0,
                      child: IgnorePointer(
                        child: _announce == null
                            ? const SizedBox.shrink()
                            : _AnnounceToast(
                                key: ValueKey(_announceSeq), keyId: _announce!),
                      ),
                    ),

                    // Loja: fica acima de tudo para abrir de qualquer tela
                    if (_showShop)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xF20A0A14),
                          child: ShopScreen(onBack: _closeShop, hint: _shopHint),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Banner AdMob ──────────────────────────────────────────────
              if (bannerWidget != null)
                SizedBox(
                  width: AdService.instance.bannerWidth,
                  height: AdService.instance.bannerHeight,
                  child: bannerWidget,
                ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Multiplica o alfa de [c] por [opacity]: fade sem saveLayer.
Color _faded(Color c, double opacity) => c.withValues(alpha: c.a * opacity);

class _WaveToast extends StatelessWidget {
  final double opacity;
  final int stage;
  final int wave;
  final int total;

  const _WaveToast({
    required this.opacity,
    required this.stage,
    required this.wave,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final o = opacity;
    const green = Color(0xFF1D9E75);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: _faded(const Color(0xF0121220), o),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _faded(green, o), width: 1.5),
          // Halo nítido em vez de sombra com blur.
          boxShadow: [
            BoxShadow(color: _faded(const Color(0x661D9E75), o), spreadRadius: 2),
            BoxShadow(color: _faded(const Color(0x261D9E75), o), spreadRadius: 6),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${l.hudStage} $stage',
              style: TextStyle(
                color: _faded(Colors.white38, o),
                fontSize: 11,
                letterSpacing: 3,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.nextWave,
              style: TextStyle(
                color: _faded(green, o),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l.waveOf(wave, total),
              style: TextStyle(
                color: _faded(Colors.white, o),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toast "Nova combinação descoberta!", com o nome vindo do codex.
class _ComboToast extends StatelessWidget {
  final String comboId;
  const _ComboToast({super.key, required this.comboId});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    const violet = Color(0xFF9BD1FF);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        builder: (_, t, __) {
          final o = (t * 380 / 300).clamp(0.0, 1.0);
          return Transform.scale(
            scale: 0.7 + 0.3 * Curves.elasticOut.transform(t),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _faded(const Color(0xFF14202e), o),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _faded(violet, o), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: _faded(violet.withValues(alpha: 0.4), o),
                      spreadRadius: 2),
                  BoxShadow(
                      color: _faded(violet.withValues(alpha: 0.12), o),
                      spreadRadius: 6),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.newComboToast,
                      style: TextStyle(
                          color: _faded(violet, o),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  Text('${l.comboName(comboId)} — ${l.comboDesc(comboId)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _faded(Colors.white, o),
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Aviso curto com o nome (e o efeito) do power-up coletado ou do especial
/// disparado. [keyId]: 'pu:<PowerUpKind>', 'sp:<ElementType>' ou
/// 'el:<ElementType>' (elemento das bolas trocado).
class _AnnounceToast extends StatelessWidget {
  final String keyId;
  const _AnnounceToast({super.key, required this.keyId});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final idx = int.tryParse(keyId.substring(3)) ?? -1;
    final isPower = keyId.startsWith('pu:');
    final isShift = keyId.startsWith('el:');
    final String title;
    final String? desc;
    final Color accent;
    if (isPower) {
      title = l.powerUpName(idx);
      desc = l.powerUpDesc(idx);
      accent = const Color(0xFF9BD1FF);
    } else if (isShift) {
      final el = idx >= 0 && idx < ElementType.values.length
          ? ElementType.values[idx]
          : ElementType.neutral;
      title = l.elementShift(el);
      desc = null;
      accent = elementDataMap[el]!.ballColor;
    } else {
      title = l.specialName(idx);
      desc = null;
      accent = idx >= 0 && idx < ElementType.values.length
          ? elementDataMap[ElementType.values[idx]]!.ballColor
          : const Color(0xFFFFFFFF);
    }
    if (title.isEmpty) return const SizedBox.shrink();
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 320),
        builder: (_, t, __) {
          final o = t.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 0.8 + 0.2 * Curves.easeOutBack.transform(t),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: _faded(const Color(0xFF14202e), o * 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _faded(accent, o), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title.toUpperCase(),
                      style: TextStyle(
                          color: _faded(accent, o),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _faded(Colors.white, o),
                            fontSize: 11,
                            fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MissionToast extends StatelessWidget {
  final DailyMission mission;
  const _MissionToast({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    const green = Color(0xFF97C459);
    // Entra com um "pulo" para chamar atenção; o fade é no alfa das cores.
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        builder: (_, t, __) {
          final o = (t * 380 / 300).clamp(0.0, 1.0);
          return Transform.scale(
            scale: 0.7 + 0.3 * Curves.elasticOut.transform(t),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _faded(const Color(0xFF16261A), o),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _faded(green, o), width: 2),
                // Halo nítido em vez de sombra com blur.
                boxShadow: [
                  BoxShadow(
                      color: _faded(green.withValues(alpha: 0.45), o),
                      spreadRadius: 2),
                  BoxShadow(
                      color: _faded(green.withValues(alpha: 0.15), o),
                      spreadRadius: 6),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📋 ${l.missionCompleted}',
                      style: TextStyle(
                          color: _faded(green, o),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text(l.missionDesc(mission.type, mission.target),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _faded(Colors.white, o),
                          fontSize: 12,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  Text('⬤ ${mission.reward}',
                      style: TextStyle(
                          color: _faded(const Color(0xFFEF9F27), o),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
