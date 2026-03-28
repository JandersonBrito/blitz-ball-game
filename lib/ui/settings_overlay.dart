import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../l10n/app_strings.dart';

class SettingsOverlay extends StatelessWidget {
  final VoidCallback onBack;
  const SettingsOverlay({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final lang = settings.language;
    final s = AppStrings.get;

    return Container(
      color: const Color(0xEE0A0A14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Center(
                  child: Text(
                    '⚙  ${s(lang, 'settings').toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Language section
                _SectionLabel(s(lang, 'language')),
                const SizedBox(height: 8),
                _LanguageSelector(current: lang),
                const SizedBox(height: 24),

                // Sound section
                _SectionLabel(s(lang, 'sound')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ToggleButton(
                      label: s(lang, 'soundOn'),
                      selected: settings.soundEnabled,
                      onTap: () => context.read<SettingsService>().soundEnabled = true,
                    ),
                    const SizedBox(width: 8),
                    _ToggleButton(
                      label: s(lang, 'soundOff'),
                      selected: !settings.soundEnabled,
                      onTap: () => context.read<SettingsService>().soundEnabled = false,
                    ),
                  ],
                ),

                // Volume section (always visible, but dimmed when sound off)
                const SizedBox(height: 20),
                _SectionLabel(s(lang, 'volume')),
                const SizedBox(height: 4),
                Opacity(
                  opacity: settings.soundEnabled ? 1.0 : 0.35,
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF1D9E75),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: const Color(0xFF1D9E75),
                          overlayColor: const Color(0x221D9E75),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: settings.volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: settings.soundEnabled
                              ? (v) => context.read<SettingsService>().volume = v
                              : null,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('0%',
                              style: TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace')),
                          Text('${(settings.volume * 100).round()}%',
                              style: const TextStyle(
                                  color: Color(0xFF1D9E75), fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                          const Text('100%',
                              style: TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Back button
                Center(
                  child: TextButton(
                    onPressed: onBack,
                    child: Text(
                      s(lang, 'back'),
                      style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white30,
        fontSize: 10,
        letterSpacing: 1.5,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final AppLanguage current;
  const _LanguageSelector({required this.current});

  static const _langs = [
    (lang: AppLanguage.pt, label: 'PT', name: 'Português'),
    (lang: AppLanguage.en, label: 'EN', name: 'English'),
    (lang: AppLanguage.es, label: 'ES', name: 'Español'),
    (lang: AppLanguage.fr, label: 'FR', name: 'Français'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _langs.map((item) {
        final selected = current == item.lang;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => context.read<SettingsService>().language = item.lang,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1D9E75) : Colors.transparent,
                  border: Border.all(
                    color: selected ? const Color(0xFF1D9E75) : Colors.white24,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      item.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white70 : Colors.white24,
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D9E75) : Colors.transparent,
          border: Border.all(
            color: selected ? const Color(0xFF1D9E75) : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white38,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
