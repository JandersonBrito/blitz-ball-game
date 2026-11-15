import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:ballz_flutter/services/purchase_service.dart';
import 'package:ballz_flutter/services/settings_service.dart';
import 'package:ballz_flutter/models/app_settings.dart';
import 'package:ballz_flutter/models/l10n.dart';
import 'package:ballz_flutter/ui/codex_screen.dart';
import 'package:ballz_flutter/ui/special_button.dart';
import 'package:ballz_flutter/ui/tutorial_screen.dart';
import 'package:ballz_flutter/ui/upgrade_screen.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests: as telas novas (HUD com medidor, Especiais, Codex) montam e
/// mostram o que importa, sem depender de ouro ou de anúncio reais.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameState gs;
  late SettingsService settings;

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: gs),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<PurchaseService>.value(
              value: PurchaseService.instance),
        ],
        child: MaterialApp(
          home: Scaffold(
              backgroundColor: const Color(0xFF0a0a14),
              body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    gs = GameState()
      ..gold = 500
      ..specialLevels[ElementType.fire] = 2
      ..specialMeter = 1
      ..armedElement = ElementType.fire
      ..discoveredCombos = 0x3; // 2 combos reveladas
  });

  Future<BallzFlameGame> startedGame() async {
    final game = BallzFlameGame(gameState: gs, settings: settings);
    game.onGameResize(Vector2(360, 640));
    await game.onLoad();
    game.startWave(); // fase aim: o botão pode ser usado
    return game;
  }

  testWidgets('botão do especial: pronto, mostra o elemento atual e dispara',
      (tester) async {
    final game = await startedGame();
    var fired = 0;
    await pump(
        tester,
        SpecialButton(
          game: game,
          adReady: false,
          onActivate: () => fired++,
          onAdActivate: () {},
        ));
    final fire = elementDataMap[ElementType.fire]!;
    expect(find.text(fire.icon), findsOneWidget, reason: 'ícone do elemento');
    expect(find.text('🔒'), findsNothing, reason: 'especial comprado');
    await tester.tap(find.text(fire.icon));
    expect(fired, 1);
  });

  testWidgets('botão do especial: medidor incompleto não dispara',
      (tester) async {
    gs.specialMeter = 0.4;
    final game = await startedGame();
    var fired = 0;
    await pump(
        tester,
        SpecialButton(
          game: game,
          adReady: false,
          onActivate: () => fired++,
          onAdActivate: () {},
        ));
    await tester.tap(find.text(elementDataMap[ElementType.fire]!.icon));
    expect(fired, 0);
  });

  testWidgets('contador do anel acompanha os acertos em tempo real',
      (tester) async {
    gs.specialMeter = 0;
    final game = await startedGame();
    await pump(
        tester,
        SpecialButton(
          game: game,
          adReady: false,
          onActivate: () {},
          onAdActivate: () {},
        ));
    expect(find.text('0/100'), findsOneWidget);
    // Acertos chegam: só o anel/contador reconstroem (sem aviso do GameState).
    gs.addSpecialHits(37);
    game.specialMeterProgress.value = gs.specialMeter;
    await tester.pump();
    expect(find.text('37/100'), findsOneWidget);
    gs.addSpecialHits(63);
    game.specialMeterProgress.value = gs.specialMeter;
    await tester.pump();
    expect(find.text('100/100'), findsOneWidget);
  });

  testWidgets('botão do especial: sem nenhum especial comprado mostra cadeado',
      (tester) async {
    gs.specialLevels[ElementType.fire] = 0;
    final game = await startedGame();
    await pump(
        tester,
        SpecialButton(
          game: game,
          adReady: false,
          onActivate: () {},
          onAdActivate: () {},
        ));
    expect(find.text('🔒'), findsOneWidget);
  });

  testWidgets('escolha do poder: ícones dos comprados; tocar seleciona',
      (tester) async {
    gs
      ..specialLevels[ElementType.water] = 1
      ..specialLevels[ElementType.earth] = 3
      ..armedElement = ElementType.fire;
    final game = await startedGame();
    var fired = 0;
    await pump(
        tester,
        SpecialButton(
          game: game,
          adReady: false,
          onActivate: () => fired++,
          onAdActivate: () {},
        ));
    final fire = elementDataMap[ElementType.fire]!.icon;
    final water = elementDataMap[ElementType.water]!.icon;
    final earth = elementDataMap[ElementType.earth]!.icon;
    final wind = elementDataMap[ElementType.wind]!.icon;
    // Fogo, água e terra comprados: 3 ícones na fileira + o do botão (fogo).
    expect(find.text(water), findsOneWidget);
    expect(find.text(earth), findsOneWidget);
    expect(find.text(wind), findsNothing, reason: 'vento não comprado');
    expect(find.text(fire), findsNWidgets(2),
        reason: 'ícone na fileira e no botão');
    expect(game.specialElement, ElementType.fire);

    // Toca em Terra: o botão passa a ser de Terra.
    await tester.tap(find.text(earth));
    await tester.pump();
    expect(gs.armedElement, ElementType.earth);
    expect(game.specialElement, ElementType.earth);
    expect(find.text(earth), findsNWidgets(2),
        reason: 'agora o botão também mostra terra');

    // E o botão pronto dispara aquele poder.
    await tester.tap(find.text(earth).last);
    expect(fired, 1);
  });

  testWidgets('com um só poder comprado não há fileira de escolha',
      (tester) async {
    final game = await startedGame(); // só fogo comprado (setUp)
    await pump(
        tester,
        SpecialButton(
          game: game,
          adReady: false,
          onActivate: () {},
          onAdActivate: () {},
        ));
    final fire = elementDataMap[ElementType.fire]!.icon;
    expect(find.text(fire), findsOneWidget, reason: 'só o ícone do botão');
  });

  testWidgets('chip do anúncio só aparece com rewarded pronto e uso livre',
      (tester) async {
    final game = await startedGame();
    Widget btn(bool adReady) => SpecialButton(
          game: game,
          adReady: adReady,
          onActivate: () {},
          onAdActivate: () {},
        );
    final l = settings.l10n;
    await pump(tester, btn(true));
    expect(find.text(l.specialAdBtn), findsOneWidget);
    await pump(tester, btn(false));
    expect(find.text(l.specialAdBtn), findsNothing);
    gs.specialAdUsed = true;
    await pump(tester, btn(true));
    expect(find.text(l.specialAdBtn), findsNothing, reason: 'já usado');
  });

  testWidgets('tela de upgrades lista os 5 especiais com preço', (tester) async {
    await pump(tester, UpgradeScreen(onBack: () {}, onOpenShop: ([h]) {}));
    final l = settings.l10n;
    expect(find.text(l.specialsTitle), findsOneWidget);
    for (final el in kCombatElements) {
      expect(find.textContaining(l.elemName(el)), findsWidgets);
    }
  });

  testWidgets('codex mostra reveladas e "???" nas demais', (tester) async {
    await pump(tester, CodexScreen(onBack: () {}));
    expect(find.text('???'), findsWidgets);
    final l = settings.l10n;
    expect(find.textContaining(l.comboName('explosion')), findsOneWidget);
    expect(find.textContaining(l.codexProgress(2, 25)), findsOneWidget);
  });

  testWidgets('tutorial tem os 7 slides, com os novos de combos/status/especiais',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GameState>.value(value: gs),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: MaterialApp(home: TutorialScreen(onBack: () {})),
      ),
    );
    await tester.pump();
    final l = settings.l10n;
    expect(find.text('1/7'), findsOneWidget, reason: '7 slides no total');

    final expectedTitles = [
      l.tutSlide1Title,
      l.tutSlide2Title,
      l.tutSlide3Title,
      l.tutSlideStatusTitle,
      l.tutSlideSpecialsTitle,
      l.tutSlide4Title,
      l.tutSlide5Title,
    ];
    for (var i = 0; i < expectedTitles.length; i++) {
      expect(find.text(expectedTitles[i]), findsOneWidget,
          reason: 'slide ${i + 1}');
      if (i < expectedTitles.length - 1) {
        await tester.tap(find.text(l.tutorialNext));
        await tester.pumpAndSettle();
      }
    }
    // Último slide: botão "Jogar".
    expect(find.text(l.tutorialPlay), findsOneWidget);
  });

  test('slides do tutorial têm textos nos 4 idiomas', () {
    for (final lang in AppLanguage.values) {
      final l = L10n(lang);
      final slides = [
        l.tutSlide1Items,
        l.tutSlide2Items,
        l.tutSlide3Items,
        l.tutSlideStatusItems,
        l.tutSlideSpecialsItems,
        l.tutSlide4Items,
        l.tutSlide5Items,
      ];
      // Um idioma faltando numa lista _t lançaria RangeError aqui.
      for (final items in slides) {
        for (final item in items) {
          expect(item[1], isNotEmpty, reason: '$lang');
          expect(item[2], isNotEmpty, reason: '$lang');
        }
      }
      expect(l.tutSlideStatusSub, isNotEmpty);
      expect(l.tutSlideSpecialsSub, isNotEmpty);
    }
  });
}
