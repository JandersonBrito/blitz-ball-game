import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';

class GameOverOverlay extends StatelessWidget {
  final VoidCallback onRestart;
  const GameOverOverlay({super.key, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Container(
      color: const Color(0xE80A0A14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Game Over',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Text('Fase ${state.stage} · Wave ${state.waveInStage}/${state.wavesInStage}',
                style: const TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text('Pontuação: ${state.score}',
                style: const TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text('⬤ ${state.gold} ouro',
                style: const TextStyle(color: Color(0xFFEF9F27), fontSize: 13, fontFamily: 'monospace')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRestart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF534AB7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Jogar novamente',
                  style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
