import 'package:ballz_flutter/models/app_settings.dart';
import 'package:ballz_flutter/models/l10n.dart';
import 'package:ballz_flutter/l10n/privacy_policy_text.dart';
import 'package:ballz_flutter/services/consent_service.dart';
import 'package:ballz_flutter/services/settings_service.dart';
import 'package:ballz_flutter/ui/consent_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('idioma padrão acompanha o aparelho e cai para inglês', () {
    expect(SettingsService.languageForCode('pt'), AppLanguage.pt);
    expect(SettingsService.languageForCode('es'), AppLanguage.es);
    expect(SettingsService.languageForCode('fr'), AppLanguage.fr);
    expect(SettingsService.languageForCode('de'), AppLanguage.en);
  });

  test('política de privacidade tem as mesmas seções em todos os idiomas', () {
    for (final lang in AppLanguage.values) {
      expect(privacyPolicyText[lang], hasLength(9), reason: lang.name);
    }
  });

  testWidgets('recusar no diálogo traduzido grava a escolha', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'language': AppLanguage.fr.index});
    final settings = await SettingsService.load();
    await ConsentService.instance.load();
    final l = L10n(AppLanguage.fr);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showConsentDialog(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text(l.consentTitle), findsOneWidget);
    expect(ConsentService.instance.hasBeenAsked, isFalse);

    await tester.tap(find.text(l.decline));
    await tester.pumpAndSettle();

    expect(find.text(l.consentTitle), findsNothing);
    expect(ConsentService.instance.hasBeenAsked, isTrue);
    expect(ConsentService.instance.consented, isFalse);
  });
}
