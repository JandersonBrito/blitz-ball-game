import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/ballz_flame_game.dart';
import '../game/config/element_config.dart';
import '../game/managers/game_state.dart';
import '../models/element.dart';
import '../services/settings_service.dart';

/// Botão do especial, no canto inferior direito. Dispara o poder ESCOLHIDO
/// pelo jogador: à esquerda do botão fica uma fileira com os ícones dos
/// poderes já comprados (aparece com 2 ou mais); tocar num ícone seleciona
/// aquele poder, e o botão passa a mostrar o ícone e a cor dele.
///
/// O anel ao redor é um contador dinâmico: cresce a cada acerto de bola
/// (100 acertos = anel fechado) e, no centro, aparece o número de acertos.
/// Ele ouve [BallzFlameGame.specialMeterProgress], que o jogo atualiza a cada
/// frame — não depende do aviso da UI, limitado a 10 Hz. Fechado, o botão
/// acende. Acima dele, um chip opcional para ativar na hora com anúncio
/// (1× por partida).
class SpecialButton extends StatelessWidget {
  final BallzFlameGame game;
  final VoidCallback onActivate;
  final VoidCallback onAdActivate;
  final bool adReady;

  static const double size = 58;

  const SpecialButton({
    super.key,
    required this.game,
    required this.onActivate,
    required this.onAdActivate,
    required this.adReady,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    final armed = game.specialElement;
    // Poderes comprados, na ordem dos elementos (para a fileira de escolha).
    final owned = <ElementType>[
      for (final el in kCombatElements)
        if (state.specialLevel(el) > 0) el
    ];
    final hasElement = armed != ElementType.neutral;
    final info = elementDataMap[armed]!;
    final cooling =
        hasElement && armed == ElementType.water && state.tideCooldown > 0;
    final showAd = adReady &&
        game.anySpecialOwned &&
        !state.specialAdUsed &&
        ElementConfig.triggerMode == SpecialTriggerMode.meter;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAd) ...[
          GestureDetector(
            onTap: onAdActivate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xCC0A0A14),
                border: Border.all(color: const Color(0xFF1D9E75)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(l.specialAdBtn,
                  style: const TextStyle(
                      color: Color(0xFF1D9E75),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Escolha do poder: um ícone por especial comprado.
            for (final el in kCombatElements)
              if (owned.length > 1 && owned.contains(el)) ...[
                _PowerChip(
                  element: el,
                  selected: el == armed,
                  onTap: () => context.read<GameState>().selectSpecial(el),
                ),
                const SizedBox(width: 6),
              ],
            // Só esta parte reconstrói a cada frame em que o medidor muda.
            ValueListenableBuilder<double>(
              valueListenable: game.specialMeterProgress,
              builder: (context, meter, _) {
                final ready = game.canActivateSpecial;
                final hits = hasElement
                    ? (meter.clamp(0.0, 1.0) * ElementConfig.hitsToFillMeter)
                        .floor()
                    : 0;
                return GestureDetector(
                  onTap: ready ? onActivate : null,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Fundo: acende em cor cheia quando pronto.
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                ready ? info.blockBg : const Color(0xD90A0A14),
                          ),
                        ),
                        // Anel contador: cresce a cada acerto.
                        CustomPaint(
                          size: const Size(size, size),
                          painter: _RingPainter(
                            progress: hasElement ? meter : 0,
                            color: ready ? Colors.white : info.ballColor,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(hasElement ? info.icon : '◇',
                                style: TextStyle(
                                    fontSize: 20,
                                    height: 1.1,
                                    color: hasElement ? null : Colors.white30)),
                            if (hasElement && !cooling)
                              Text(
                                '$hits/${ElementConfig.hitsToFillMeter}',
                                style: TextStyle(
                                    color:
                                        ready ? Colors.white : Colors.white70,
                                    fontSize: 9,
                                    height: 1.0,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace'),
                              ),
                          ],
                        ),
                        if (cooling)
                          Container(
                            width: size - 10,
                            height: size - 10,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xAA000000)),
                            child: Text('${state.tideCooldown}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace')),
                          ),
                        if (!hasElement)
                          const Positioned(
                              right: 5,
                              bottom: 5,
                              child:
                                  Text('🔒', style: TextStyle(fontSize: 11))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Ícone de um poder para escolher; o selecionado fica preenchido.
class _PowerChip extends StatelessWidget {
  final ElementType element;
  final bool selected;
  final VoidCallback onTap;
  const _PowerChip(
      {required this.element, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final info = elementDataMap[element]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? info.blockBg : const Color(0xD90A0A14),
          border: Border.all(
              color: selected
                  ? Colors.white
                  : info.ballColor.withValues(alpha: 0.6),
              width: selected ? 2 : 1),
        ),
        child: Text(info.icon, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  static const double stroke = 5;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white12;
    canvas.drawArc(rect, 0, 2 * pi, false, track);
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = p >= 1 ? StrokeCap.butt : StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawArc(rect, -pi / 2, 2 * pi * p, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
