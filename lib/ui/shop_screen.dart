import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../models/l10n.dart';
import '../services/purchase_service.dart';
import '../services/settings_service.dart';

const _gold = Color(0xFFEF9F27);
const _green = Color(0xFF1D9E75);
const _purple = Color(0xFF7F77DD);
const _blue = Color(0xFF378ADD);

class ShopScreen extends StatelessWidget {
  final VoidCallback onBack;

  /// Motivo de ter aberto a loja, ex.: "Faltam ⬤ 120 para Força".
  final String? hint;

  const ShopScreen({super.key, required this.onBack, this.hint});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final purchase = context.watch<PurchaseService>();
    final l = context.watch<SettingsService>().l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.shopTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              Text('⬤ ${state.gold}',
                  style: const TextStyle(
                      color: _gold, fontSize: 13, fontFamily: 'monospace')),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _gold, fontSize: 11, fontFamily: 'monospace')),
            ),
          ],
          if (!purchase.available) ...[
            const SizedBox(height: 10),
            Text(l.storeUnavailable,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (purchase.starterAvailable)
                  _OfferCard(
                    id: PurchaseService.starterPackId,
                    icon: '🎁',
                    title: l.starterTitle,
                    desc: l.starterDesc(PurchaseService.starterPackGold),
                    color: _gold,
                    tag: l.oneTimeOffer,
                    highlight: true,
                  ),
                for (var i = 0; i < PurchaseService.goldPacks.length; i++)
                  _goldPackCard(purchase, l, i),
                _OfferCard(
                  id: PurchaseService.goldDoublerId,
                  icon: '⬤×2',
                  title: l.doublerTitle,
                  desc: l.doublerDesc,
                  color: _purple,
                  tag: l.permanentTag,
                ),
                _OfferCard(
                  id: PurchaseService.removeAdsId,
                  icon: '🚫',
                  title: l.removeAds,
                  desc: l.removeAdsDesc,
                  color: _blue,
                  tag: l.permanentTag,
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: purchase.available
                        ? () => purchase.restorePurchases()
                        : null,
                    child: Text(l.restorePurchase,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white38)),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _goldPackCard(PurchaseService purchase, L10n l, int i) {
    final pack = PurchaseService.goldPacks[i];
    final bonus = purchase.bonusVsSmallest(pack);
    final pct = bonus == null ? 0 : (bonus * 100).round();
    final isLast = i == PurchaseService.goldPacks.length - 1;
    return _OfferCard(
      id: pack.id,
      icon: ['💰', '🧰', '👑'][i.clamp(0, 2)],
      title: l.goldPackName(i),
      desc: '⬤ ${pack.gold}${pct >= 5 ? '  ·  ${l.bonusTag(pct)}' : ''}',
      color: _gold,
      tag: isLast ? l.bestValueTag : (i == 1 ? l.popularTag : null),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String id;
  final String icon;
  final String title;
  final String desc;
  final Color color;
  final String? tag;
  final bool highlight;

  const _OfferCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    this.tag,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseService>();
    final l = context.watch<SettingsService>().l10n;
    final owned = purchase.isOwned(id);
    final busy = purchase.purchasingId == id;
    final price = purchase.product(id)?.price;
    final enabled = !owned && purchase.available && !purchase.purchasing;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.14 : 0.05),
        border: Border.all(
          color: owned ? Colors.white12 : color.withValues(alpha: highlight ? 1 : 0.4),
          width: highlight ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: highlight
            ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 14)]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(icon,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: icon.length > 2 ? 12 : 22,
                    color: color,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag != null && !owned)
                  Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(tag!,
                        style: const TextStyle(
                            color: Color(0xFF0A0A14),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace')),
                  ),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        color: owned ? Colors.white38 : color,
                        fontSize: 10,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: enabled ? () => purchase.buy(id) : null,
            child: Container(
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: owned
                    ? Colors.transparent
                    : enabled
                        ? (highlight ? color : _green)
                        : Colors.white10,
                border: Border.all(color: owned ? Colors.white12 : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                owned
                    ? l.ownedTag
                    : busy
                        ? '...'
                        : price ?? '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: owned ? Colors.white38 : Colors.white,
                  fontSize: 11,
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
