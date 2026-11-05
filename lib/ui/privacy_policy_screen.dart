import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/privacy_policy_text.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final VoidCallback onBack;
  const PrivacyPolicyScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final l = settings.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.privacyPolicy,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              GestureDetector(
                onTap: onBack,
                child: const Text('✕',
                    style: TextStyle(color: Colors.white54, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _PolicyText(language: settings.language)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onBack,
            child: Text(
              l.back,
              style: const TextStyle(color: Colors.white54, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyText extends StatelessWidget {
  final AppLanguage language;
  const _PolicyText({required this.language});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (title, body) in privacyPolicyText[language]!)
            _Section(title: title, body: body),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1D9E75),
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
