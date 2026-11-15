import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/combos/combo_defs.dart';
import '../game/managers/game_state.dart';
import '../models/element.dart';
import '../services/settings_service.dart';

/// Codex: as 25 combinações (bola × bloco). Começam como "???" e são
/// reveladas na primeira ativação de cada uma.
class CodexScreen extends StatelessWidget {
  final VoidCallback onBack;
  const CodexScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    var found = 0;
    for (var i = 0; i < comboDefs.length; i++) {
      if (state.comboDiscovered(i)) found++;
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.codexTitle,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text('${l.codexProgress(found, comboDefs.length)} · ${l.codexHint}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
          const SizedBox(height: 10),
          SizedBox(
            height: 420,
            child: ListView.separated(
              itemCount: comboDefs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (ctx, i) => _ComboCard(
                def: comboDefs[i],
                discovered: state.comboDiscovered(i),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onBack,
            child: Text(l.back,
                style: const TextStyle(
                    color: Colors.white54, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  final ComboDef def;
  final bool discovered;
  const _ComboCard({required this.def, required this.discovered});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final ball = elementDataMap[def.ball]!;
    final block = elementDataMap[def.block]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: discovered ? 0.06 : 0.025),
        border: Border.all(
            color: discovered
                ? ball.blockBorder.withValues(alpha: 0.6)
                : Colors.white12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              discovered ? '${ball.icon}×${block.icon}' : '?×?',
              style: TextStyle(
                  fontSize: 13,
                  color: discovered ? Colors.white : Colors.white24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discovered ? l.comboName(def.id) : '???',
                  style: TextStyle(
                      color: discovered ? ball.ballColor : Colors.white30,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace'),
                ),
                if (discovered)
                  Text(l.comboDesc(def.id),
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
