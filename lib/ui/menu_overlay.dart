import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../services/settings_service.dart';
import '../models/element.dart';
import 'upgrade_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';

class MenuOverlay extends StatefulWidget {
  final VoidCallback onStartWave;

  const MenuOverlay({super.key, required this.onStartWave});

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  bool _showUpgrades = false;
  bool _showSettings = false;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsService>();
      if (!settings.tutorialSeen) {
        setState(() => _showTutorial = true);
      }
    });
  }

  void _closeTutorial() {
    context.read<SettingsService>().markTutorialSeen();
    setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Container(
      color: const Color(0xEE0A0A14),
      child: Center(
        child: _showSettings
            ? SettingsScreen(onBack: () => setState(() => _showSettings = false), gameState: state)
            : _showUpgrades
                ? UpgradeScreen(onBack: () => setState(() => _showUpgrades = false))
                : _showTutorial
                    ? TutorialScreen(onBack: _closeTutorial)
                    : _buildMainMenu(state, context),
      ),
    );
  }

  Widget _buildMainMenu(GameState state, BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage number
          Text(state.isBossStage ? '👹 ${l.boss}' : l.stage,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text('${state.stage}',
              style: TextStyle(
                  color: state.isBossStage
                      ? const Color(0xFFE24B4A)
                      : Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
          if (state.isBossStage)
            Text(l.bossTip,
                style: const TextStyle(
                    color: Color(0xFFE24B4A),
                    fontSize: 11,
                    fontFamily: 'monospace')),

          const SizedBox(height: 16),

          // Wave dots
          _WaveDots(current: state.waveInStage, total: state.wavesInStage),
          const SizedBox(height: 4),
          Text(
            state.wavesInStage == 1
                ? l.clearAll
                : '${l.waveOf(state.waveInStage, state.wavesInStage)}'
                    '${state.waveInStage == state.wavesInStage ? ' · ${l.clearLast}' : ''}',
            style: const TextStyle(
                color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
          ),

          const SizedBox(height: 20),

          // Element selector
          _ElementSelector(),

          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l.balls(state.ballCount),
                  style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 11,
                      fontFamily: 'monospace')),
              const SizedBox(width: 16),
              Text(l.pts(state.score),
                  style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 11,
                      fontFamily: 'monospace')),
              const SizedBox(width: 16),
              Text('⬤ ${state.gold}',
                  style: const TextStyle(
                      color: Color(0xFFEF9F27),
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ],
          ),

          const SizedBox(height: 20),

          // Buttons
          SizedBox(
            width: 200,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: widget.onStartWave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isBossStage
                        ? const Color(0xFF993C1D)
                        : const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    state.isBossStage
                        ? l.fightBoss
                        : l.startWave(state.waveInStage),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _showUpgrades = true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF9F27)),
                    foregroundColor: const Color(0xFFEF9F27),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(l.upgradesBtn,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _showSettings = true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF378ADD)),
                    foregroundColor: const Color(0xFF378ADD),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(l.settingsBtn,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _showTutorial = true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6B6B8A)),
                    foregroundColor: const Color(0xFF9E9EBF),
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(l.tutorialBtn,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.normal,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveDots extends StatelessWidget {
  final int current, total;
  const _WaveDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final done = i < current - 1;
        final active = i == current - 1;
        return Container(
          width: 10, height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? const Color(0xFF1D9E75)
                : active
                    ? Colors.white
                    : Colors.white24,
            border: active ? Border.all(color: Colors.white, width: 2) : null,
          ),
        );
      }),
    );
  }
}

class _ElementSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    return Column(
      children: [
        Text(l.elementTitle,
            style: const TextStyle(
                color: Colors.white30,
                fontSize: 10,
                letterSpacing: 1,
                fontFamily: 'monospace')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: ElementType.values.map((el) {
            final info = elementDataMap[el]!;
            final selected = state.ballElement == el;
            final name = l.elemName(el);
            return GestureDetector(
              onTap: () {
                state.ballElement = el;
                state.notifyListeners();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? info.blockBg : Colors.transparent,
                  border: Border.all(
                      color: selected ? info.blockBorder : Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${info.icon} $name',
                  style: TextStyle(
                    color: selected ? info.textColor : Colors.white38,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (state.ballElement != ElementType.neutral) ...[
          const SizedBox(height: 4),
          Text(l.elemAdvantage(state.ballElement),
              style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 9,
                  fontFamily: 'monospace')),
        ],
      ],
    );
  }
}
