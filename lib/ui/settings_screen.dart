import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
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

  bool _cloudSaving = false;
  bool _cloudRestoring = false;
  String? _cloudFeedback;
  bool _cloudFeedbackIsError = false;

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
  }

  Future<void> _handleCloudSignIn() async {
    final ok = await GamesCloudService.instance.signIn();
    if (!mounted) return;
    _showCloudFeedback(
      ok ? 'Conectado ao Google Play Games!' : 'Falha ao conectar. Tente novamente.',
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
    _showCloudFeedback(
      ok ? 'Progresso salvo na nuvem!' : 'Erro ao salvar: ${GamesCloudService.instance.lastError}',
      isError: !ok,
    );
  }

  Future<void> _handleCloudRestore() async {
    if (!GamesCloudService.instance.signedIn) return;
    setState(() => _cloudRestoring = true);
    final code = await GamesCloudService.instance.loadFromCloud();
    if (!mounted) return;
    setState(() => _cloudRestoring = false);
    if (code == null) {
      _showCloudFeedback(
        GamesCloudService.instance.lastError ?? 'Nenhum save encontrado na nuvem.',
        isError: true,
      );
      return;
    }
    final applied = widget.gameState.applyBackupCode(code);
    _showCloudFeedback(
      applied ? 'Progresso restaurado da nuvem!' : 'Dados inválidos no save da nuvem.',
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
      const SnackBar(
        content: Text('Código copiado! Cole em outro aparelho para restaurar.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _applyRestore() {
    final code = _restoreController.text.trim();
    final ok = widget.gameState.applyBackupCode(code);
    setState(() {
      _restoreError = ok ? null : 'Código inválido. Verifique e tente novamente.';
      if (ok) {
        _showRestoreField = false;
        _restoreController.clear();
      }
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progresso restaurado com sucesso!')),
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
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Política de Privacidade',
                style: TextStyle(
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
                  const Text(
                    'Consentimento de Anúncios: ',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    ConsentService.instance.hasBeenAsked
                        ? (ConsentService.instance.consented ? 'Aceito' : 'Recusado')
                        : 'Não definido',
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
          Text('COMPRAS',
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontFamily: 'monospace')),
          const SizedBox(height: 8),
          if (purchase.adsRemoved)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '✓ Anúncios removidos',
                style: TextStyle(
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
                  purchase.purchasing ? 'Aguardando...' : 'Remover Anúncios',
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
              child: const Text(
                'Restaurar compra anterior',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white38),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Save na Nuvem ─────────────────────────────────────────────
          Text('SAVE NA NUVEM',
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
                      child: const Text(
                        'Entrar no Google Play Games',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                              _cloudSaving ? 'Salvando...' : 'Salvar na Nuvem',
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
                              _cloudRestoring ? 'Restaurando...' : 'Restaurar da Nuvem',
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
                  const Text(
                    '✓ Conectado ao Google Play Games',
                    style: TextStyle(
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
          Text('BACKUP DE PROGRESSO',
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
                    child: const Text(
                      'Copiar Código',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                    child: const Text(
                      'Restaurar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                hintText: 'Cole o código aqui',
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
                child: const Text(
                  'Confirmar Restauração',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
