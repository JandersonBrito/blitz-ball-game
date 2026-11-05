import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/purchase_service.dart';
import '../services/settings_service.dart';

class HelpOfferOverlay extends StatelessWidget {
  final VoidCallback? onWatchAd; // null quando ad não está disponível
  final VoidCallback onDismiss;

  const HelpOfferOverlay({
    super.key,
    required this.onWatchAd,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final adsRemoved = context.watch<PurchaseService>().adsRemoved;
    final l = context.watch<SettingsService>().l10n;
    return Container(
      color: const Color(0xE80A0A14),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF12121E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF9F27), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.needHelp,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                adsRemoved
                    ? l.helpBodyAccept
                    : onWatchAd != null
                        ? l.helpBodyWatch
                        : l.helpBodyNoAd,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 20),
              _rewardRow('⚔️', l.helpDoubleDamage),
              const SizedBox(height: 8),
              _rewardRow('💥', l.helpCrit),
              const SizedBox(height: 8),
              _rewardRow('🔮', l.helpExtraBalls),
              const SizedBox(height: 24),
              if (onWatchAd != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onWatchAd,
                    icon: const Text('▶', style: TextStyle(fontSize: 14)),
                    label: Text(
                      adsRemoved ? l.helpAccept : l.watchAd,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    l.noThanks,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _rewardRow(String icon, String label) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFEF9F27),
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
