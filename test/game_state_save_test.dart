import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/graphics_quality.dart';
import 'package:ballz_flutter/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingState extends GameState {
  int saves = 0;

  @override
  Future<void> save() async {
    saves++;
    await super.save();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('acertos não gravam nem avisam a UI um a um', () async {
    final gs = _CountingState();
    var notifies = 0;
    gs.addListener(() => notifies++);
    for (var i = 0; i < 500; i++) {
      gs.addScore(1);
      gs.earnGold(1);
    }
    gs.incrementBallCount();
    expect(gs.score, 500);
    expect(gs.gold, 500);
    expect(notifies, 0);
    expect(gs.saves, 0);

    // 3 s de jogo a 60 FPS: HUD a ~10 Hz, gravação a cada 2 s.
    var t = 0.0;
    for (var f = 0; f < 180; f++) {
      gs.addScore(1);
      gs.commitGameplay(t += 1 / 60);
    }
    expect(notifies, inInclusiveRange(28, 31));
    expect(gs.saves, inInclusiveRange(1, 2));

    gs.addScore(1);
    await gs.flush();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('gs_score'), gs.score);
    expect(prefs.getInt('gs_gold'), 500);
  });

  test('partida nova (relógio do jogo recomeça) continua avisando', () {
    final gs = GameState();
    var notifies = 0;
    gs.addListener(() => notifies++);
    gs.addScore(1);
    gs.commitGameplay(100);
    gs.addScore(1);
    gs.commitGameplay(0.5); // jogo novo: relógio voltou
    expect(notifies, 2);
  });

  test('mudanças da UI gravam na hora, agrupando pedidos seguidos', () async {
    final gs = _CountingState();
    gs.addGold(10);
    gs.addGold(10);
    gs.addGold(10);
    await gs.flush();
    expect(gs.saves, lessThanOrEqualTo(2));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('gs_gold'), 30);
  });

  test('qualidade, ajuste automático e 30 FPS ficam salvos', () async {
    final s = await SettingsService.load();
    expect(s.graphicsQuality, GraphicsQuality.high);
    expect(s.autoQuality, isTrue);
    expect(s.fpsLock30, isFalse);
    s.setGraphicsQuality(GraphicsQuality.low);
    s.setAutoQuality(false);
    s.setFpsLock30(true);
    await Future<void>.delayed(Duration.zero);
    final again = await SettingsService.load();
    expect(again.graphicsQuality, GraphicsQuality.low);
    expect(again.autoQuality, isFalse);
    expect(again.fpsLock30, isTrue);
  });
}
