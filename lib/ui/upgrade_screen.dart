import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../services/settings_service.dart';
import '../models/upgrade.dart';

class UpgradeScreen extends StatelessWidget {
  final VoidCallback onBack;
  final void Function([String? hint]) onOpenShop;
  const UpgradeScreen({super.key, required this.onBack, required this.onOpenShop});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.upgradesTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              GestureDetector(
                onTap: () => onOpenShop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFEF9F27)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('⬤ ${state.gold}  +',
                      style: const TextStyle(
                          color: Color(0xFFEF9F27),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 400,
            child: ListView.separated(
              itemCount: upgradeDefs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) =>
                  _UpgradeCard(def: upgradeDefs[i], onOpenShop: onOpenShop),
            ),
          ),
          const SizedBox(height: 12),
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

class _UpgradeCard extends StatelessWidget {
  final UpgradeDef def;
  final void Function([String? hint]) onOpenShop;
  const _UpgradeCard({required this.def, required this.onOpenShop});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
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
                    Text(l.upgradeLabel(def.id),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    Row(
                      children: List.generate(
                          def.levels.length,
                          (i) => Text('■',
                              style: TextStyle(
                                color: i < lvl ? def.color : Colors.white24,
                                fontSize: 9,
                              ))),
                    ),
                  ],
                ),
                Text(
                  l.upgradeDesc(def.id),
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontFamily: 'monospace'),
                ),
                Text(
                  maxed
                      ? '${l.upgradeValue(def.id, def.levels.last.value)} · ${l.maxLevel}'
                      : '${l.upgradeValue(def.id, lvl == 0 ? null : def.levels[lvl - 1].value)} → ${l.upgradeValue(def.id, next!.value)}',
                  style: TextStyle(
                      color: maxed ? Colors.white38 : def.color,
                      fontSize: 9,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            // Sem ouro suficiente, o toque leva à loja dizendo quanto falta.
            onTap: canAfford
                ? () => state.buyUpgrade(def.id)
                : next == null
                    ? null
                    : () => onOpenShop(l.needGoldFor(
                        next.cost - state.gold, l.upgradeLabel(def.id))),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: maxed
                    ? Colors.transparent
                    : canAfford
                        ? def.color
                        : Colors.transparent,
                border: Border.all(
                  color: maxed
                      ? Colors.white12
                      : canAfford
                          ? def.color
                          : Colors.white24,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                maxed ? 'MAX' : '⬤ ${next!.cost}',
                style: TextStyle(
                  color: maxed
                      ? Colors.white24
                      : canAfford
                          ? Colors.white
                          : Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
