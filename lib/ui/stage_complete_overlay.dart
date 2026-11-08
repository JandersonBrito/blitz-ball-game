import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../services/purchase_service.dart';
import '../services/settings_service.dart';

class StageCompleteOverlay extends StatelessWidget {
  final int stage;
  final int score;
  final int gold;
  final VoidCallback onNextStage;
  final VoidCallback onMenu;
  final VoidCallback onOpenShop;

  const StageCompleteOverlay({
    super.key,
    required this.stage,
    required this.score,
    required this.gold,
    required this.onNextStage,
    required this.onMenu,
    required this.onOpenShop,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final earned = context.watch<GameState>().stageGoldEarned;
    final hasDoubler = context.watch<PurchaseService>().goldDoubler;

    return Container(
      color: const Color(0xE80A0A14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '★',
              style: const TextStyle(
                color: Color(0xFFEF9F27),
                fontSize: 48,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.stageCompleteTitle(stage),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.scoreLabel(score),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.goldLabel(gold),
              style: const TextStyle(
                color: Color(0xFFEF9F27),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            if (earned > 0) ...[
              const SizedBox(height: 4),
              Text(
                hasDoubler ? '${l.stageGoldEarned(earned)}  (×2)' : l.stageGoldEarned(earned),
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
              ),
              // Mostra quanto o jogador deixou de ganhar sem o Ouro em Dobro.
              if (!hasDoubler)
                TextButton(
                  onPressed: onOpenShop,
                  child: Text(
                    l.doublerUpsell(earned * 2),
                    style: const TextStyle(
                        color: Color(0xFF7F77DD),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace'),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: onNextStage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      l.nextStage,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onMenu,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF534AB7)),
                      foregroundColor: const Color(0xFF534AB7),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      l.backToMenu,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
