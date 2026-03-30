import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../services/settings_service.dart';
import '../models/element.dart';

class HudOverlay extends StatelessWidget {
  final VoidCallback onPause;

  const HudOverlay({
    super.key,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    final elInfo = elementDataMap[state.ballElement]!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // left group: stage + wave
            _HudChip(
                label: l.hudStage,
                value: '${state.stage}${state.isBossStage ? " 👹" : ""}',
                valueColor: state.isBossStage
                    ? const Color(0xFFE24B4A)
                    : Colors.white),
            const SizedBox(width: 8),
            _HudChip(
                label: l.hudWave,
                value: '${state.waveInStage}/${state.wavesInStage}',
                valueColor: Colors.white54),
            const SizedBox(width: 8),

            // score — flexible so it shrinks if needed
            Flexible(
              child: _HudChip(
                label: l.hudPts,
                value: '${state.score}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // balls
            _HudChip(label: '×', value: '${state.ballCount}'),
            const SizedBox(width: 8),

            // gold
            Text('⬤ ',
                style: const TextStyle(color: Color(0xFFEF9F27), fontSize: 11)),
            Text('${state.gold}',
                style: const TextStyle(
                    color: Color(0xFFEF9F27),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'monospace')),
            const SizedBox(width: 8),

            // element — flexible so long names shrink
            Flexible(
              child: Text(
                '${elInfo.icon} ${l.elemName(state.ballElement)}',
                style: TextStyle(color: elInfo.ballColor, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // pause button — always visible, never pushed out
            GestureDetector(
              onTap: onPause,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
  final TextOverflow overflow;

  const _HudChip({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      overflow: overflow,
      text: TextSpan(
        children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontFamily: 'monospace')),
          TextSpan(
              text: value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
