import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onBack;
  const SettingsScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final l = settings.l10n;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.settingsTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
              GestureDetector(
                onTap: onBack,
                child: const Text('✕',
                    style: TextStyle(color: Colors.white54, fontSize: 18)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Language
          Text(l.settingsLanguage,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppLanguage.values.map((lang) {
              final selected = settings.language == lang;
              const labels = {
                AppLanguage.pt: 'PT — Português',
                AppLanguage.en: 'EN — English',
                AppLanguage.es: 'ES — Español',
                AppLanguage.fr: 'FR — Français',
              };
              return GestureDetector(
                onTap: () => settings.setLanguage(lang),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1D9E75)
                        : Colors.transparent,
                    border: Border.all(
                        color: selected
                            ? const Color(0xFF1D9E75)
                            : Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    labels[lang]!,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Sound toggle
          Text(l.settingsSound,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => settings.setSoundEnabled(!settings.soundEnabled),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: settings.soundEnabled
                    ? const Color(0xFF1D9E75)
                    : Colors.transparent,
                border: Border.all(
                    color: settings.soundEnabled
                        ? const Color(0xFF1D9E75)
                        : Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                settings.soundEnabled ? '🔊 On' : '🔇 Off',
                style: TextStyle(
                  color:
                      settings.soundEnabled ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Volume slider
          if (settings.soundEnabled) ...[
            const SizedBox(height: 16),
            Text(l.settingsVolume,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontFamily: 'monospace')),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF1D9E75),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFF1D9E75),
                overlayColor: const Color(0x221D9E75),
              ),
              child: Slider(
                value: settings.volume,
                min: 0,
                max: 1,
                onChanged: settings.setVolume,
              ),
            ),
          ],

          const SizedBox(height: 16),
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
