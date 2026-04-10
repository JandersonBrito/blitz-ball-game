import 'package:flutter/material.dart';
import '../services/consent_service.dart';
import 'privacy_policy_screen.dart';

/// Mostra o diálogo de consentimento GDPR.
/// Retorna true se o usuário aceitou, false caso contrário.
Future<bool> showConsentDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ConsentDialog(),
  );
  return result ?? false;
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F1523),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anúncios e Privacidade',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Este jogo exibe anúncios para se manter gratuito. '
              'Para oferecer anúncios relevantes, parceiros podem '
              'coletar e usar dados do seu dispositivo conforme a '
              'nossa política de privacidade.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
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
              child: const Text(
                'Ver Política de Privacidade',
                style: TextStyle(
                  color: Color(0xFF1D9E75),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF1D9E75),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Button(
                    label: 'Recusar',
                    color: Colors.white24,
                    textColor: Colors.white54,
                    onTap: () async {
                      await ConsentService.instance.setConsent(false);
                      if (context.mounted) Navigator.of(context).pop(false);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Button(
                    label: 'Aceitar',
                    color: const Color(0xFF1D9E75),
                    textColor: Colors.white,
                    onTap: () async {
                      await ConsentService.instance.setConsent(true);
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Você pode alterar esta preferência a qualquer momento nas configurações.',
              style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _Button({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
