import 'package:ballz_flutter/game/combos/combo_defs.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:ballz_flutter/models/l10n.dart';
import 'package:ballz_flutter/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('codex', () {
    test('descoberta marca o bit uma única vez e arma o toast', () {
      final gs = GameState();
      expect(gs.comboDiscovered(3), isFalse);
      expect(gs.discoverCombo(3, 'plasma'), isTrue);
      expect(gs.comboDiscovered(3), isTrue);
      expect(gs.comboToastId, 'plasma');
      gs.clearComboToast();
      expect(gs.discoverCombo(3, 'plasma'), isFalse, reason: 'já descoberta');
      expect(gs.comboToastId, isNull, reason: 'sem toast repetido');
    });

    test('codex e especiais sobrevivem ao save/load', () async {
      final gs = GameState()
        ..discoveredCombos = 0x155
        ..gold = 10
        ..specialLevels[ElementType.earth] = 4;
      await gs.save();
      final loaded = await GameState.load();
      expect(loaded.discoveredCombos, 0x155);
      expect(loaded.specialLevel(ElementType.earth), 4);
    });

    test('todas as combinações têm nome e descrição nos 4 idiomas', () {
      for (final lang in AppLanguage.values) {
        final l = L10n(lang);
        for (final def in comboDefs) {
          expect(l.comboName(def.id), isNot(def.id),
              reason: 'nome de ${def.id} em $lang');
          expect(l.comboDesc(def.id), isNotEmpty,
              reason: 'descrição de ${def.id} em $lang');
        }
      }
    });
  });

  group('upgrades legados', () {
    test('Fogo+/Água+/Vento+ viram níveis dos especiais e as chaves somem',
        () async {
      SharedPreferences.setMockInitialValues({
        'gs_upg_upg_fire': 3,
        'gs_upg_upg_wind': 5,
      });
      final gs = await GameState.load();
      expect(gs.specialLevel(ElementType.fire), 3);
      expect(gs.specialLevel(ElementType.wind), 5);
      expect(gs.specialLevel(ElementType.water), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('gs_upg_upg_fire'), isFalse);
      expect(prefs.containsKey('gs_upg_upg_wind'), isFalse);
    });
  });

  group('rewarded: dobrar moedas', () {
    test('runGoldEarned acumula a partida inteira e zera no reset', () {
      final gs = GameState();
      gs.earnGold(10);
      gs.earnGold(5, multiplier: 2);
      expect(gs.runGoldEarned, 20);
      gs.reset();
      expect(gs.runGoldEarned, 0);
      expect(gs.runGoldDoubled, isFalse);
    });
  });
}
