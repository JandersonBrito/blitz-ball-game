import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../models/element.dart';
import 'upgrade_screen.dart';

class MenuOverlay extends StatefulWidget {
  final VoidCallback onStartWave;

  const MenuOverlay({super.key, required this.onStartWave});

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  bool _showUpgrades = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    return Container(
      color: const Color(0xEE0A0A14),
      child: Center(
        child: _showUpgrades
            ? UpgradeScreen(onBack: () => setState(() => _showUpgrades = false))
            : _buildMainMenu(state),
      ),
    );
  }

  Widget _buildMainMenu(GameState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage number
          Text(state.isBossStage ? '👹 BOSS' : 'FASE',
              style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text('${state.stage}',
              style: TextStyle(
                color: state.isBossStage ? const Color(0xFFE24B4A) : Colors.white,
                fontSize: 52, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          if (state.isBossStage)
            const Text('derrote o boss para avançar',
                style: TextStyle(color: Color(0xFFE24B4A), fontSize: 11, fontFamily: 'monospace')),

          const SizedBox(height: 16),

          // Wave dots
          _WaveDots(current: state.waveInStage, total: state.wavesInStage),
          const SizedBox(height: 4),
          Text(
            state.wavesInStage == 1
                ? 'limpe todos os blocos para avançar'
                : 'wave ${state.waveInStage} de ${state.wavesInStage}'
                    '${state.waveInStage == state.wavesInStage ? " · limpe tudo para avançar" : ""}',
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
          ),

          const SizedBox(height: 20),

          // Element selector
          _ElementSelector(),

          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('bolas: ${state.ballCount}', style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(width: 16),
              Text('pts: ${state.score}', style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(width: 16),
              Text('⬤ ${state.gold}', style: const TextStyle(color: Color(0xFFEF9F27), fontSize: 11, fontFamily: 'monospace')),
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
                    backgroundColor: state.isBossStage ? const Color(0xFF993C1D) : const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    state.isBossStage ? '👹 Enfrentar Boss' : '▶ Iniciar wave ${state.waveInStage}',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _showUpgrades = true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF9F27)),
                    foregroundColor: const Color(0xFFEF9F27),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('⬤ Upgrades', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
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
            color: done ? const Color(0xFF1D9E75) : active ? Colors.white : Colors.white24,
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
    return Column(
      children: [
        const Text('ELEMENTO DA BOLA',
            style: TextStyle(color: Colors.white30, fontSize: 10, letterSpacing: 1, fontFamily: 'monospace')),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: ElementType.values.map((el) {
            final info = elementDataMap[el]!;
            final selected = state.ballElement == el;
            return GestureDetector(
              onTap: () { state.ballElement = el; state.notifyListeners(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? info.blockBg : Colors.transparent,
                  border: Border.all(color: selected ? info.blockBorder : Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${info.icon} ${info.label}',
                  style: TextStyle(
                    color: selected ? info.textColor : Colors.white38,
                    fontSize: 11, fontFamily: 'monospace',
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (state.ballElement != ElementType.neutral) ...[
          const SizedBox(height: 4),
          Builder(builder: (ctx) {
            final el = state.ballElement;
            final adv = el == ElementType.fire ? 'Vento' : el == ElementType.water ? 'Fogo' : 'Água';
            final dis = el == ElementType.fire ? 'Água' : el == ElementType.water ? 'Vento' : 'Fogo';
            return Text('✦ forte vs $adv · fraco vs $dis',
                style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace'));
          }),
        ],
      ],
    );
  }
}
