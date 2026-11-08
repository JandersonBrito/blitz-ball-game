import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'services/audio_service.dart';
import 'services/haptic_service.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'services/consent_service.dart';
import 'services/games_cloud_service.dart';
import 'game/managers/game_state.dart';
import 'ui/game_screen.dart';
import 'ui/consent_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConsentService.instance.load();
  await PurchaseService.instance.initialize();
  // O login pode abrir UI do Play Games ou demorar; não pode segurar a abertura.
  unawaited(GamesCloudService.instance.initialize());
  // Ads inicializados apenas se consentimento já foi dado.
  // Novo usuário: diálogo será mostrado em GameScreen antes de inicializar.
  if (ConsentService.instance.hasBeenAsked && ConsentService.instance.consented) {
    await AdService.instance.initialize();
  }
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0a0a14),
  ));

  final settings = await SettingsService.load();
  // Carrega em paralelo à abertura; o jogo funciona mudo até ficar pronto.
  unawaited(AudioService.instance.init(settings));
  unawaited(HapticService.instance.init(settings));
  final gameState = await GameState.load();

  runApp(BallzApp(settings: settings, gameState: gameState));
}

class BallzApp extends StatelessWidget {
  final SettingsService settings;
  final GameState gameState;
  const BallzApp({super.key, required this.settings, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: PurchaseService.instance),
        ChangeNotifierProvider.value(value: GamesCloudService.instance),
      ],
      child: MaterialApp(
        title: 'Elemental Breaker: Balls',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0a0a14),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF1D9E75),
            secondary: const Color(0xFFEF9F27),
          ),
        ),
        home: GameScreen(gameState: gameState),
      ),
    );
  }
}
