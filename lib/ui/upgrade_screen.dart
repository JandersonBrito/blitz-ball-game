import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../models/upgrade.dart';

class UpgradeScreen extends StatelessWidget {
  final VoidCallback onBack;
  const UpgradeScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upgrades',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              Text('⬤ ${state.gold}',
                  style: const TextStyle(color: Color(0xFFEF9F27), fontSize: 13, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 400,
            child: ListView.separated(
              itemCount: upgradeDefs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) => _UpgradeCard(def: upgradeDefs[i]),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onBack,
            child: const Text('← voltar',
                style: TextStyle(color: Colors.white54, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final UpgradeDef def;
  const _UpgradeCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final lvl = state.upgrades[def.id] ?? 0;
    final maxed = lvl >= def.levels.length;
    final next = maxed ? null : def.levels[lvl];
    final canAfford = next != null && state.gold >= next.cost;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: maxed ? Colors.white12 : def.color.withOpacity(0.27),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(def.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(def.label,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    Row(
                      children: List.generate(def.levels.length, (i) => Text(
                        '■',
                        style: TextStyle(
                          color: i < lvl ? def.color : Colors.white24,
                          fontSize: 9,
                        ),
                      )),
                    ),
                  ],
                ),
                Text(
                  maxed ? 'Nível máximo' : next!.desc,
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canAfford ? () => state.buyUpgrade(def.id) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: maxed ? Colors.transparent : canAfford ? def.color : Colors.transparent,
                border: Border.all(
                  color: maxed ? Colors.white12 : canAfford ? def.color : Colors.white24,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                maxed ? 'MAX' : '⬤ ${next!.cost}',
                style: TextStyle(
                  color: maxed ? Colors.white24 : canAfford ? Colors.white : Colors.white38,
                  fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
