import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../game/ballz_flame_game.dart';
import '../game/managers/game_state.dart';
import '../services/settings_service.dart';
import '../services/ad_service.dart';
import 'hud_overlay.dart';
import 'menu_overlay.dart';
import 'game_over_overlay.dart';
import 'stage_complete_overlay.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;
  const GameScreen({super.key, required this.gameState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late BallzFlameGame _flameGame;
  late GameState _gameState;
  bool _isPaused = false;
  bool _showPauseSettings = false;
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _gameState = widget.gameState;
    if (_gameState.gameOver) _gameState.reset();
    _flameGame = BallzFlameGame(gameState: _gameState);
    _loadBanner();
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: AdService.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );
    _bannerAd = banner;
    banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _handleStartWave() {
    _flameGame.startWave();
    setState(() {});
  }

  void _handleRestart() {
    AdService.instance.showInterstitial();
    _gameState.reset();
    _flameGame = BallzFlameGame(gameState: _gameState);
    setState(() {});
  }

  void _handleContinueAfterAd() {
    AdService.instance.showRewarded(() {
      _flameGame.continueAfterAd();
      setState(() {});
    });
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
    _flameGame = BallzFlameGame(gameState: _gameState);
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
    _flameGame = BallzFlameGame(gameState: _gameState);
    setState(() {
      _isPaused = false;
      _showPauseSettings = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final bannerLoaded = _bannerAd != null;

    return ChangeNotifierProvider.value(
      value: _gameState,
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0a14),
        body: SafeArea(
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

                    // HUD
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Consumer<GameState>(
                        builder: (ctx, state, _) => HudOverlay(
                          onPause: _handlePause,
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
                          child: MenuOverlay(onStartWave: _handleStartWave),
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
                            onWatchAd: AdService.instance.isRewardedReady
                                ? _handleContinueAfterAd
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Banner AdMob ──────────────────────────────────────────────
              if (bannerLoaded)
                SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
