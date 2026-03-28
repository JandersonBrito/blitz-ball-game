import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force landscape or portrait — keep portrait for this game
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Color(0xFF0a0a14),
  ));
  runApp(const BallzApp());
}

class BallzApp extends StatelessWidget {
  const BallzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
