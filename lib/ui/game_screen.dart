import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import '../game/ballz_flame_game.dart';
import '../game/managers/game_state.dart';
import 'hud_overlay.dart';
import 'menu_overlay.dart';
import 'game_over_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late BallzFlameGame _flameGame;
  late GameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = GameState();
    _flameGame = BallzFlameGame(gameState: _gameState);
  }

  void _handleStartWave() {
    _flameGame.startWave();
    setState(() {});
  }

  void _handleForceReturn() {
    _flameGame.forceReturn();
    setState(() {});
  }

  void _handleRestart() {
    _gameState.reset();
    _flameGame = BallzFlameGame(gameState: _gameState);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gameState,
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0a14),
        body: Stack(
          children: [
            // Flame game canvas
            MouseRegion(
              onHover: (event) => _flameGame.handlePointerPosition(event.localPosition),
              child: GestureDetector(
                onTapUp: (details) => _flameGame.handleTap(details.localPosition),
                child: GameWidget(game: _flameGame),
              ),
            ),

            // HUD — always visible
            Positioned(
              top: 0, left: 0, right: 0,
              child: Consumer<GameState>(
                builder: (ctx, state, _) => HudOverlay(
                  onForceReturn: _handleForceReturn,
                  showReturnButton: _flameGame.phase == GamePhase.shooting,
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

            // Game over overlay
            Consumer<GameState>(
              builder: (ctx, state, _) {
                if (!state.gameOver) return const SizedBox.shrink();
                return Positioned.fill(
                  child: GameOverOverlay(onRestart: _handleRestart),
                );
              },
            ),

            // Legend at bottom
            Positioned(
              bottom: 8, left: 0, right: 0,
              child: Text(
                'Aponte e toque • ● roxo = +1 bola • ⬤ ouro • ⊙ branco = triplicar',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
