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
class SpecialButton extends StatefulWidget {
  final BallzFlameGame game;
  final VoidCallback onActivate;
  final VoidCallback onAdActivate;

  /// Pede o anúncio que dá 1 carga de Transmutação (1× por partida).
  final VoidCallback onElementAd;
  final bool adReady;

  static const double size = 58;

  const SpecialButton({
    super.key,
    required this.game,
    required this.onActivate,
    required this.onAdActivate,
    required this.onElementAd,
    required this.adReady,
  });

  @override
  State<SpecialButton> createState() => _SpecialButtonState();
}

/// Como o seletor de elemento da bola está aberto.
enum _PickMode { transmute, swap }

class _SpecialButtonState extends State<SpecialButton> {
  static const double size = SpecialButton.size;
  BallzFlameGame get game => widget.game;
  VoidCallback get onActivate => widget.onActivate;
  VoidCallback get onAdActivate => widget.onAdActivate;
  bool get adReady => widget.adReady;

  _PickMode? _mode;
  int _prevCharges = 0;

  @override
  void initState() {
    super.initState();
    // Cargas que já existiam ao montar não abrem a escolha sozinhas.
    _prevCharges = context.read<GameState>().transmuteCharges;
  }

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
        // Escolha do elemento da bola + ações (ouve a troca disponível).
        ValueListenableBuilder<bool>(
          valueListenable: game.swapAvailable,
          builder: (context, swapOk, _) {
            final canTransmute = game.canTransmute;
            final inPlay =
                game.phase == GamePhase.aim || game.phase == GamePhase.shooting;
            // Carga nova (power-up ou anúncio): abre a escolha sozinho.
            if (state.transmuteCharges > _prevCharges && canTransmute) {
              _mode = _PickMode.transmute;
            }
            _prevCharges = state.transmuteCharges;
            if (_mode == _PickMode.transmute && !canTransmute) _mode = null;
            if (_mode == _PickMode.swap && !swapOk) _mode = null;
            final showElementAd = adReady && inPlay && !state.elementAdUsed;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_mode != null) ...[
                  Text(
                      _mode == _PickMode.transmute
                          ? l.transmutePick
                          : l.swapPick,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontFamily: 'monospace')),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final el in kCombatElements) ...[
                        _PowerChip(
                          element: el,
                          selected: false,
                          onTap: () {
                            final ok = _mode == _PickMode.transmute
                                ? game.transmuteBalls(el)
                                : game.swapBallElement(el);
                            if (ok) setState(() => _mode = null);
                          },
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (canTransmute)
                      _ActionChip(
                        label: l.transmuteChip(state.transmuteCharges),
                        color: const Color(0xFF9BD1FF),
                        active: _mode == _PickMode.transmute,
                        onTap: () => setState(() => _mode =
                            _mode == _PickMode.transmute
                                ? null
                                : _PickMode.transmute),
                      ),
                    if (swapOk)
                      _ActionChip(
                        label: l.swapChip,
                        color: const Color(0xFFFFC857),
                        active: _mode == _PickMode.swap,
                        onTap: () => setState(() => _mode =
                            _mode == _PickMode.swap ? null : _PickMode.swap),
                      ),
                    if (showElementAd)
                      _ActionChip(
                        label: l.elementAdBtn,
                        color: const Color(0xFF1D9E75),
                        onTap: widget.onElementAd,
                      ),
                    if (showAd)
                      _ActionChip(
                        label: l.specialAdBtn,
                        color: const Color(0xFF1D9E75),
                        onTap: onAdActivate,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            );
          },
        ),
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

/// Chip de texto (ação rápida acima do botão do especial).
class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.label,
      required this.color,
      required this.onTap,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color:
              active ? color.withValues(alpha: 0.35) : const Color(0xCC0A0A14),
          border: Border.all(color: color, width: active ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ),
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
