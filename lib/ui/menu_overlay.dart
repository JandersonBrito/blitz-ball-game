import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/managers/game_state.dart';
import '../services/purchase_service.dart';
import '../services/settings_service.dart';
import '../services/games_cloud_service.dart';
import '../models/ball_skin.dart';
import '../models/element.dart';
import 'upgrade_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';
import 'daily_missions_screen.dart';
import '../services/daily_mission_service.dart';

class MenuOverlay extends StatefulWidget {
  final VoidCallback onStartWave;
  final void Function([String? hint]) onOpenShop;

  const MenuOverlay({super.key, required this.onStartWave, required this.onOpenShop});

  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  bool _showUpgrades = false;
  bool _showSettings = false;
  bool _showTutorial = false;
  bool _showMissions = false;

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

  bool _openingRanking = false;

  Future<void> _openRanking(GameState state) async {
    if (_openingRanking) return;
    _openingRanking = true;
    final ok = await GamesCloudService.instance.showStageRanking(state.stage);
    _openingRanking = false;
    if (ok || !mounted) return;
    final l = context.read<SettingsService>().l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.rankingFailed)),
    );
  }

  void _closeTutorial() {
    context.read<SettingsService>().markTutorialSeen();
    setState(() => _showTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final purchase = context.watch<PurchaseService>();
    final onMainMenu =
        !_showSettings && !_showUpgrades && !_showTutorial && !_showMissions;
    // Só oferece com o preço já carregado, para nunca mostrar um botão vazio.
    final offerStarter = onMainMenu &&
        state.shouldOfferStarter &&
        purchase.starterAvailable &&
        purchase.product(PurchaseService.starterPackId) != null;
    return Stack(
      children: [
        Positioned.fill(child: _buildContent(state, context)),
        if (offerStarter)
          Positioned.fill(
            child: _StarterOffer(
              price: purchase.product(PurchaseService.starterPackId)!.price,
              onSee: () {
                state.markStarterOfferSeen();
                widget.onOpenShop();
              },
              onClose: state.markStarterOfferSeen,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(GameState state, BuildContext context) {
    return Container(
      color: const Color(0xEE0A0A14),
      child: Center(
        child: _showSettings
            ? SettingsScreen(onBack: () => setState(() => _showSettings = false), gameState: state)
            : _showUpgrades
                ? UpgradeScreen(
                    onBack: () => setState(() => _showUpgrades = false),
                    onOpenShop: widget.onOpenShop)
                : _showTutorial
                    ? TutorialScreen(onBack: _closeTutorial)
                    : _showMissions
                        ? DailyMissionsScreen(
                            onBack: () => setState(() => _showMissions = false))
                        : _buildMainMenu(state, context),
      ),
    );
  }

  Widget _buildMainMenu(GameState state, BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    // Rolável para caber em telas baixas com todos os botões.
    return SingleChildScrollView(
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
          if (state.starterBallsActive) ...[
            const SizedBox(height: 10),
            _SkinSelector(),
          ],

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
                _ShopButton(onTap: () => widget.onOpenShop()),
                const SizedBox(height: 8),
                _MissionsButton(
                    onTap: () => setState(() => _showMissions = true)),
                const SizedBox(height: 8),
                if (GamesCloudService.instance.rankingConfigured) ...[
                  OutlinedButton(
                    onPressed: () => _openRanking(state),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8C547)),
                      foregroundColor: const Color(0xFFE8C547),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(l.rankingBtn,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                ],
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

/// Botão da loja; ganha um selo pulsante enquanto o Pacote Iniciante está à venda.
class _ShopButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ShopButton({required this.onTap});

  @override
  State<_ShopButton> createState() => _ShopButtonState();
}

class _ShopButtonState extends State<_ShopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final offer = context.watch<PurchaseService>().starterAvailable;
    const gold = Color(0xFFEF9F27);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ElevatedButton(
          onPressed: widget.onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: gold.withValues(alpha: 0.18),
            foregroundColor: gold,
            elevation: 0,
            side: const BorderSide(color: gold),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(l.shopBtn,
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ),
        if (offer)
          Positioned(
            top: -8,
            right: -6,
            child: ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.1).animate(_pulse),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE24B4A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l.offerBadge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
              ),
            ),
          ),
      ],
    );
  }
}

class _SkinSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<GameState>();
    final l = context.watch<SettingsService>().l10n;
    Widget chip(BallSkin skin, String label, Color color) {
      final selected = state.ballSkin == skin;
      return GestureDetector(
        onTap: () => state.selectSkin(skin),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(color: selected ? color : Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? color : Colors.white38,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'monospace')),
        ),
      );
    }

    return Column(
      children: [
        Text(l.skinTitle,
            style: const TextStyle(
                color: Colors.white30,
                fontSize: 10,
                letterSpacing: 1,
                fontFamily: 'monospace')),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            chip(BallSkin.classic, '○ ${l.skinClassic}', Colors.white),
            const SizedBox(width: 6),
            chip(BallSkin.prism, '✦ ${l.skinPrism}', const Color(0xFFFFD27A)),
          ],
        ),
      ],
    );
  }
}

/// Oferta do Pacote Iniciante: aparece uma vez e fecha com um toque fora.
class _StarterOffer extends StatelessWidget {
  final String price;
  final VoidCallback onSee;
  final VoidCallback onClose;
  const _StarterOffer(
      {required this.price, required this.onSee, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    const gold = Color(0xFFEF9F27);
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: const Color(0xB30A0A14),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {}, // toque no card não fecha
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF12121E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold, width: 1.5),
              boxShadow: [
                BoxShadow(color: gold.withValues(alpha: 0.3), blurRadius: 18)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: onClose,
                    child: const Text('✕',
                        style: TextStyle(color: Colors.white38, fontSize: 16)),
                  ),
                ),
                const Text('🎁', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 6),
                Text(l.starterOfferTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace')),
                const SizedBox(height: 8),
                Text(l.starterDesc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: gold, fontSize: 12, fontFamily: 'monospace')),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF0A0A14),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('${l.seeOffer} · $price',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(
                  onPressed: onClose,
                  child: Text(l.notNow,
                      style: const TextStyle(
                          color: Colors.white38, fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão das missões; mostra quantas recompensas estão esperando resgate.
class _MissionsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MissionsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<SettingsService>().l10n;
    final pending = context.watch<DailyMissionService>().claimableCount;
    const color = Color(0xFF97C459);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: color),
            foregroundColor: color,
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(l.missionsBtn,
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ),
        if (pending > 0)
          Positioned(
            top: -7,
            right: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE24B4A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$pending',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace')),
            ),
          ),
      ],
    );
  }
}
