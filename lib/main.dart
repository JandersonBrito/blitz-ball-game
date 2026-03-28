import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'ui/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0a0a14),
  ));

  final settings = await SettingsService.load();

  runApp(BallzApp(settings: settings));
}

class BallzApp extends StatelessWidget {
  final SettingsService settings;
  const BallzApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        title: 'Ballz',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0a0a14),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF1D9E75),
            secondary: const Color(0xFFEF9F27),
          ),
        ),
        home: const GameScreen(),
      ),
    );
  }
}
