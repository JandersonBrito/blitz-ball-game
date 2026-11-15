import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/effects/particle_pool.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/game/perf/adaptive_quality.dart';
import 'package:ballz_flutter/game/status/block_status.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:ballz_flutter/models/graphics_quality.dart';
import 'package:ballz_flutter/services/settings_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingGame extends BallzFlameGame {
  _CountingGame({required super.gameState, super.settings});
  int updates = 0;

  @override
  void update(double dt) {
    updates++;
    super.update(dt);
  }
}

const _frame = Duration(microseconds: 16667); // 60 Hz

Future<_CountingGame> _pumpGame(WidgetTester tester, SettingsService settings) async {
  final game = _CountingGame(gameState: GameState(), settings: settings);
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: GameWidget(game: game)));
  await tester.pump();
  return game;
}

Future<int> _updatesIn(WidgetTester tester, _CountingGame game, int frames) async {
  final before = game.updates;
  for (var i = 0; i < frames; i++) {
    await tester.pump(_frame);
  }
  return game.updates - before;
}

void main() {
  group('motor', () {
    testWidgets('parado no menu; roda na mira; trava em 30 FPS quando pedido',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      final game = await _pumpGame(tester, settings);

      expect(game.phase, GamePhase.menu);
      expect(await _updatesIn(tester, game, 30), 0, reason: 'menu não redesenha');

      game.startWave();
      expect(await _updatesIn(tester, game, 60), inInclusiveRange(59, 61));

      settings.setFpsLock30(true);
      await tester.pump(_frame);
      expect(await _updatesIn(tester, game, 60), inInclusiveRange(29, 31));

      game.pauseGame();
      expect(await _updatesIn(tester, game, 30), 0, reason: 'pausado');
      game.resumeGame();
      expect(await _updatesIn(tester, game, 60), inInclusiveRange(29, 31));

      settings.setFpsLock30(false);
      await tester.pump(_frame);
      expect(await _updatesIn(tester, game, 60), inInclusiveRange(59, 61));
    });
  });

  group('qualidade adaptativa', () {
    test('mede depois do aquecimento e ignora pausas longas', () {
      final a = AdaptiveQuality(warmup: 0.5, window: 3);
      // Aquecimento a 10 FPS não conta.
      for (var i = 0; i < 5; i++) {
        expect(a.addFrame(0.1, 45), isFalse);
      }
      // Um anúncio de 2 s no meio é ignorado.
      expect(a.addFrame(2.0, 45), isFalse);
      var low = false;
      for (var i = 0; i < 200 && !a.done; i++) {
        low = a.addFrame(1 / 60, 45);
      }
      expect(a.done, isTrue);
      expect(low, isFalse);
      expect(a.lastFps, closeTo(60, 0.5));

      a.restart();
      for (var i = 0; i < 200 && !a.done; i++) {
        low = a.addFrame(1 / 30, 45);
      }
      expect(low, isTrue);
    });

    test('a 30 FPS a partida baixa de Alto para Médio e depois para Baixo',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      expect(settings.graphicsQuality, GraphicsQuality.high);
      final gs = GameState();
      final game = BallzFlameGame(gameState: gs, settings: settings)
        ..adaptiveInDebug = true;
      game.onGameResize(Vector2(360, 640));
      await game.onLoad();
      game.blocks
        ..clear()
        ..add(BlockComponent(
          position: Vector2(1, 49),
          type: BlockType.normal,
          hp: 1 << 30,
          maxHp: 1 << 30,
          element: ElementType.neutral,
        ));
      game.startWave();
      gs.ballCount = 400; // rodada longa
      game.handlePointerPosition(Offset(game.originX + 50, game.floorY - 300));
      game.shoot();
      for (var i = 0; i < 150; i++) {
        game.update(1 / 30); // 5 s a 30 FPS
      }
      expect(settings.graphicsQuality, GraphicsQuality.medium);
      for (var i = 0; i < 150; i++) {
        game.update(1 / 30);
      }
      expect(settings.graphicsQuality, GraphicsQuality.low);
      expect(game.profile.maxParticles, QualityProfile.low.maxParticles);
    });

    test('sem o ajuste automático a qualidade não muda', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'graphics_auto': false});
      final settings = await SettingsService.load();
      final gs = GameState();
      final game = BallzFlameGame(gameState: gs, settings: settings)
        ..adaptiveInDebug = true;
      game.onGameResize(Vector2(360, 640));
      await game.onLoad();
      game.startWave();
      gs.ballCount = 400;
      game.handlePointerPosition(Offset(game.originX + 50, game.floorY - 300));
      game.shoot();
      for (var i = 0; i < 150; i++) {
        game.update(1 / 30);
      }
      expect(settings.graphicsQuality, GraphicsQuality.high);
    });
  });

  group('partículas', () {
    test('respeitam o limite global e encolhem com a tela cheia', () {
      final p = ParticlePool(240)..limit = 40;
      p.burst(0, 0, 0xFFFFFFFF, 10);
      expect(p.count, 10);
      p.burst(0, 0, 0xFFFFFFFF, 10);
      expect(p.count, 20);
      // Metade do limite: estouros pela metade.
      p.burst(0, 0, 0xFFFFFFFF, 10);
      expect(p.count, 25);
      for (var i = 0; i < 20; i++) {
        p.burst(0, 0, 0xFFFFFFFF, 10);
      }
      expect(p.count, lessThanOrEqualTo(40));
      // Baixar a qualidade não corta as vivas; elas morrem sozinhas.
      p.limit = 10;
      expect(p.budget(10), 0);
      for (var i = 0; i < 60; i++) {
        p.update(1 / 60);
      }
      expect(p.count, 0);
    });

    test('qualidade sem partículas não solta nada', () {
      final p = ParticlePool(240)..limit = 0;
      p.burst(0, 0, 0xFFFFFFFF, 10);
      expect(p.count, 0);
    });
  });

  group('status por turno', () {
    test('tick aplica dano e conta os turnos', () {
      final s = BlockStatus()
        ..applyBurn(turns: 2, damage: 5)
        ..applyAcid(turns: 1, damage: 3)
        ..applyFreeze(turns: 2);
      expect(s.tick(), 8);
      expect(s.acid, isFalse);
      expect(s.tick(), 5);
      expect(s.burning, isFalse);
      expect(s.frozen, isFalse);
      expect(s.isEmpty, isTrue);
      expect(s.tick(), 0);
    });

    test('reaplicar fica com a maior duração e o maior dano', () {
      final s = BlockStatus()
        ..applyBurn(turns: 3, damage: 2)
        ..applyBurn(turns: 1, damage: 7);
      expect(s.burnTurns, 3);
      expect(s.burnDamage, 7);
    });
  });
}
