import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../services/settings_service.dart';

class GameOverOverlay extends StatelessWidget {
  final VoidCallback onRestart;
  final VoidCallback? onWatchAd; // null quando o ad não está disponível

  const GameOverOverlay({
    super.key,
    required this.onRestart,
    this.onWatchAd,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    return Container(
      color: const Color(0xE80A0A14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.gameOver,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Text(l.stageWave(state.stage, state.waveInStage, state.wavesInStage),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text(l.scoreLabel(state.score),
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Text(l.goldLabel(state.gold),
                style: const TextStyle(
                    color: Color(0xFFEF9F27),
                    fontSize: 13,
                    fontFamily: 'monospace')),
            const SizedBox(height: 24),

            // Botão rewarded — só aparece quando o ad está carregado
            if (onWatchAd != null) ...[
              ElevatedButton.icon(
                onPressed: onWatchAd,
                icon: const Text('▶', style: TextStyle(fontSize: 14)),
                label: const Text('Continuar (assistir anúncio)',
                    style: TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
            ],

            ElevatedButton(
              onPressed: onRestart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF534AB7),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(l.playAgain,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
