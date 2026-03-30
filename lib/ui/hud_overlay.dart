import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../services/settings_service.dart';
import '../models/element.dart';

class HudOverlay extends StatelessWidget {
  final VoidCallback onForceReturn;
  final VoidCallback onPause;
  final bool showReturnButton;

  const HudOverlay({
    super.key,
    required this.onForceReturn,
    required this.onPause,
    required this.showReturnButton,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    final elInfo = elementDataMap[state.ballElement]!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HudChip(
                label: l.hudStage,
                value: '${state.stage}${state.isBossStage ? " 👹" : ""}',
                valueColor: state.isBossStage
                    ? const Color(0xFFE24B4A)
                    : Colors.white),
            const SizedBox(width: 12),
            _HudChip(
                label: l.hudWave,
                value: '${state.waveInStage}/${state.wavesInStage}',
                valueColor: Colors.white54),
            const SizedBox(width: 12),
            _HudChip(label: l.hudPts, value: '${state.score}'),
            const SizedBox(width: 12),
            _HudChip(label: '×', value: '${state.ballCount}'),
            const SizedBox(width: 12),
            Text('⬤ ',
                style: TextStyle(color: const Color(0xFFEF9F27), fontSize: 12)),
            Text('${state.gold}',
                style: const TextStyle(
                    color: Color(0xFFEF9F27),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(width: 12),
            Text('${elInfo.icon} ${l.elemName(state.ballElement)}',
                style: TextStyle(color: elInfo.ballColor, fontSize: 12)),
            if (showReturnButton) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onForceReturn,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFE24B4A)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('↩',
                      style:
                          TextStyle(color: Color(0xFFE24B4A), fontSize: 12)),
                ),
              ),
            ],
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onPause,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('⏸',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _HudChip(
      {required this.label,
      required this.value,
      this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'monospace')),
          TextSpan(
              text: value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
