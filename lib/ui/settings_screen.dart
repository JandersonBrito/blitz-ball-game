import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/l10n.dart';
import '../services/settings_service.dart';
import '../services/purchase_service.dart';
import '../services/consent_service.dart';
import '../services/games_cloud_service.dart';
import '../game/managers/game_state.dart';
import 'privacy_policy_screen.dart';
import 'consent_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  final GameState gameState;
  const SettingsScreen({super.key, required this.onBack, required this.gameState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _restoreController = TextEditingController();
  String? _restoreError;
  bool _showRestoreField = false;

  final _promoController = TextEditingController();
  bool _promoOpenFailed = false;

  bool _cloudSaving = false;
  bool _cloudRestoring = false;
  String? _cloudFeedback;
  bool _cloudFeedbackIsError = false;

  @override
  void dispose() {
    _restoreController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _handleCloudSignIn() async {
    final ok = await GamesCloudService.instance.signIn();
    if (!mounted) return;
    final l = context.read<SettingsService>().l10n;
    _showCloudFeedback(
      ok ? l.cloudSignInOk : l.cloudSignInFailed,
      isError: !ok,
    );
  }

  Future<void> _handleCloudSave() async {
    if (!GamesCloudService.instance.signedIn) return;
    setState(() => _cloudSaving = true);
    final code = widget.gameState.exportBackupCode();
    final ok = await GamesCloudService.instance.saveToCloud(code);
    if (!mounted) return;
    setState(() => _cloudSaving = false);
    final l = context.read<SettingsService>().l10n;
    _showCloudFeedback(
      ok ? l.cloudSaved : l.cloudSaveFailed,
      isError: !ok,
    );
  }

  Future<void> _handleCloudRestore() async {
    if (!GamesCloudService.instance.signedIn) return;
    setState(() => _cloudRestoring = true);
    final code = await GamesCloudService.instance.loadFromCloud();
    if (!mounted) return;
    setState(() => _cloudRestoring = false);
    final l = context.read<SettingsService>().l10n;
    if (code == null) {
      _showCloudFeedback(l.cloudNoSave, isError: true);
      return;
    }
    final applied = widget.gameState.applyBackupCode(code);
    _showCloudFeedback(
      applied ? l.cloudRestored : l.cloudInvalid,
      isError: !applied,
    );
  }

  void _showCloudFeedback(String message, {required bool isError}) {
    setState(() {
      _cloudFeedback = message;
      _cloudFeedbackIsError = isError;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _cloudFeedback = null);
    });
  }

  void _copyBackup() {
    final code = widget.gameState.exportBackupCode();
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.read<SettingsService>().l10n.codeCopied),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _redeemPromo() async {
    FocusScope.of(context).unfocus();
    final ok = await PurchaseService.instance.redeemCode(_promoController.text);
    if (!mounted) return;
    setState(() => _promoOpenFailed = !ok);
    if (ok) _promoController.clear();
  }

  String _productName(L10n l, String id) {
    final packIndex =
        PurchaseService.goldPacks.indexWhere((p) => p.id == id);
    if (packIndex >= 0) {
      return '${l.goldPackName(packIndex)} '
          '(+${PurchaseService.goldPacks[packIndex].gold} ⬤)';
    }
    return switch (id) {
      PurchaseService.removeAdsId => l.removeAds,
      PurchaseService.goldDoublerId => l.doublerTitle,
      PurchaseService.starterPackId => l.starterTitle,
      _ => id,
    };
  }

  Widget _promoSection(L10n l, PurchaseService purchase) {
    final result = purchase.redeemResult;
    String? feedback;
    var feedbackIsError = false;
    if (purchase.checkingRedeem) {
      feedback = l.promoChecking;
    } else if (_promoOpenFailed) {
      feedback = l.promoOpenFailed;
      feedbackIsError = true;
    } else if (result != null) {
      feedback = result.found
          ? l.promoGranted(
              result.grantedIds.map((id) => _productName(l, id)).join(', '))
          : l.promoNothing;
      feedbackIsError = !result.found;
    } else if (purchase.redeemPending) {
      feedback = l.promoInfo;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.promoHeader,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 1,
                fontFamily: 'monospace')),
        const SizedBox(height: 8),
        TextField(
          controller: _promoController,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _redeemPromo(),
          onChanged: (_) {
            if (_promoOpenFailed || purchase.redeemResult != null) {
              setState(() => _promoOpenFailed = false);
              purchase.clearRedeemResult();
            }
          },
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 2,
              fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: l.promoHint,
            hintStyle: const TextStyle(
                color: Colors.white24, fontSize: 11, letterSpacing: 0),
            isDense: true,
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: purchase.available && !purchase.checkingRedeem
              ? _redeemPromo
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF1D9E75)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              purchase.available ? l.promoRedeem : l.storeUnavailable,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF1D9E75),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (feedback != null) ...[
          const SizedBox(height: 6),
          Text(
            feedback,
            style: TextStyle(
                color: feedbackIsError
                    ? Colors.redAccent
                    : (result?.found ?? false)
                        ? const Color(0xFF1D9E75)
                        : Colors.white54,
                fontSize: 10,
                fontFamily: 'monospace'),
          ),
        ],
      ],
    );
  }

  void _applyRestore() {
    final code = _restoreController.text.trim();
    final ok = widget.gameState.applyBackupCode(code);
    final l = context.read<SettingsService>().l10n;
    setState(() {
      _restoreError = ok ? null : l.invalidCode;
      if (ok) {
        _showRestoreField = false;
        _restoreController.clear();
      }
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.restoreSuccess)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final purchase = context.watch<PurchaseService>();
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
                onTap: widget.onBack,
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

          // Vibration toggle
          Text(l.settingsVibration,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => settings.setVibrationEnabled(!settings.vibrationEnabled),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: settings.vibrationEnabled
                    ? const Color(0xFF1D9E75)
                    : Colors.transparent,
                border: Border.all(
                    color: settings.vibrationEnabled
                        ? const Color(0xFF1D9E75)
                        : Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                settings.vibrationEnabled ? '📳 On' : '📴 Off',
                style: TextStyle(
                  color: settings.vibrationEnabled
                      ? Colors.white
                      : Colors.white38,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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

          // Volumes separados: música e efeitos
          if (settings.soundEnabled) ...[
            const SizedBox(height: 16),
            _VolumeSlider(
              label: l.settingsMusic,
              value: settings.musicVolume,
              onChanged: settings.setMusicVolume,
            ),
            const SizedBox(height: 8),
            _VolumeSlider(
              label: l.settingsSfx,
              value: settings.sfxVolume,
              onChanged: settings.setSfxVolume,
            ),
          ],

          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: const Color(0xFF0a0a14),
                  body: SafeArea(
                    child: PrivacyPolicyScreen(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                l.privacyPolicy,
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Consentimento de anúncios
          GestureDetector(
            onTap: () async {
              await showConsentDialog(context);
              setState(() {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    l.adConsentLabel,
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    ConsentService.instance.hasBeenAsked
                        ? (ConsentService.instance.consented ? l.consentAccepted : l.consentDeclined)
                        : l.consentUnset,
                    style: TextStyle(
                      color: ConsentService.instance.consented
                          ? const Color(0xFF1D9E75)
                          : Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Remover Anúncios ──────────────────────────────────────────
          Text(l.purchasesHeader,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          if (purchase.adsRemoved)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                l.adsRemovedDone,
                style: const TextStyle(
                    color: Color(0xFF1D9E75),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            GestureDetector(
              onTap: purchase.purchasing ? null : () => purchase.buyRemoveAds(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF9F27).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFEF9F27)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  purchase.purchasing ? l.waiting : l.removeAds,
                  style: const TextStyle(
                      color: Color(0xFFEF9F27),
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => purchase.restorePurchases(),
              child: Text(
                l.restorePurchase,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white38),
              ),
            ),
          ],

          // ── Código promocional (Google Play) ─────────────────────────
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 20),
            _promoSection(l, purchase),
          ],

          const SizedBox(height: 20),

          // ── Save na Nuvem ─────────────────────────────────────────────
          Text(l.cloudHeader,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final cloud = context.watch<GamesCloudService>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!cloud.signedIn)
                  GestureDetector(
                    onTap: _handleCloudSignIn,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l.playGamesSignIn,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                if (cloud.signedIn) ...[
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _cloudSaving ? null : _handleCloudSave,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _cloudSaving ? l.cloudSaving : l.cloudSave,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _cloudRestoring ? null : _handleCloudRestore,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _cloudRestoring ? l.cloudRestoring : l.cloudRestore,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.playGamesConnected,
                    style: const TextStyle(
                        color: Color(0xFF1D9E75),
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ],
                if (_cloudFeedback != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _cloudFeedback!,
                    style: TextStyle(
                        color: _cloudFeedbackIsError
                            ? Colors.redAccent
                            : const Color(0xFF1D9E75),
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ],
              ],
            );
          }),

          const SizedBox(height: 20),

          // ── Backup / Restore ──────────────────────────────────────────
          Text(l.backupHeader,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _copyBackup,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.copyCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showRestoreField = !_showRestoreField),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.restore,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showRestoreField) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _restoreController,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: l.pasteCodeHint,
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                errorText: _restoreError,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _applyRestore,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9E75).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFF1D9E75)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l.confirmRestore,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF1D9E75),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onBack,
            child: Text(l.back,
                style: const TextStyle(
                    color: Colors.white54, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _VolumeSlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
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
          child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
        ),
      ],
    );
  }
}
