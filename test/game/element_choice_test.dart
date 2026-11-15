import 'dart:math';
import 'dart:ui';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/config/element_config.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _s = BallzFlameGame.blockSize;

BlockComponent _block(int col, int row, {int hp = 10000}) => BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: BlockType.normal,
      hp: hp,
      maxHp: hp,
      element: ElementType.neutral,
    );

Future<BallzFlameGame> _game(GameState gs) async {
  final game = BallzFlameGame(gameState: gs, random: Random(7));
  game.onGameResize(Vector2(360, 640));
  await game.onLoad();
  game.blocks
    ..clear()
    ..add(_block(0, 1));
  return game;
}

/// Solta [n] bolas e deixa algumas saírem da fila.
Future<BallzFlameGame> _shoot(GameState gs, {int n = 3}) async {
  final game = await _game(gs);
  game.startWave();
  gs.ballCount = n; // depois do startWave: ele reinicia a contagem
  game.handlePointerPosition(Offset(180, game.floorY - 300));
  game.shoot();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Transmutação', () {
    test('sem carga não faz nada', () async {
      final gs = GameState();
      final game = await _shoot(gs);
      expect(game.canTransmute, isFalse);
      expect(game.transmuteBalls(ElementType.fire), isFalse);
    });

    test('na mira: as bolas do próximo tiro saem com o elemento escolhido',
        () async {
      final gs = GameState()..addTransmuteCharge();
      final game = await _game(gs);
      game.startWave();
      gs.ballCount = 3;
      game.handlePointerPosition(Offset(180, game.floorY - 300));
      expect(game.canTransmute, isTrue);
      expect(game.transmuteBalls(ElementType.water), isTrue);
      expect(gs.transmuteCharges, 0, reason: 'gastou a carga');
      game.shoot();
      for (var i = 0; i < 200 && game.balls.count < 3; i++) {
        game.update(1 / 60);
      }
      expect(game.balls.count, 3);
      for (var i = 0; i < 3; i++) {
        expect(game.balls.element[i], ElementType.water.index);
      }
    });

    test('em voo: converte as bolas voando e as da fila', () async {
      final gs = GameState()..addTransmuteCharge();
      final game = await _shoot(gs, n: 4);
      for (var i = 0; i < 40 && game.balls.count < 2; i++) {
        game.update(1 / 60);
      }
      expect(game.balls.count, lessThan(4), reason: 'ainda há bolas na fila');
      expect(game.transmuteBalls(ElementType.lightning), isTrue);
      for (var i = 0; i < 400 && game.balls.count < 4; i++) {
        game.update(1 / 60);
      }
      for (var i = 0; i < game.balls.count; i++) {
        expect(game.balls.element[i], ElementType.lightning.index,
            reason: 'bola $i');
      }
    });

    test('neutro não é uma escolha válida', () async {
      final gs = GameState()..addTransmuteCharge();
      final game = await _shoot(gs);
      expect(game.transmuteBalls(ElementType.neutral), isFalse);
      expect(gs.transmuteCharges, 1);
    });

    test('a escolha some no fim da rodada: o próximo tiro sai neutro',
        () async {
      final gs = GameState()..addTransmuteCharge();
      final game = await _shoot(gs, n: 2);
      game.transmuteBalls(ElementType.fire);
      game.forceReturn();
      for (var i = 0; i < 900 && game.phase != GamePhase.aim; i++) {
        game.update(1 / 60);
      }
      expect(game.phase, GamePhase.aim);
      game.handlePointerPosition(Offset(180, game.floorY - 300));
      game.shoot();
      for (var i = 0; i < 100 && game.balls.count < 1; i++) {
        game.update(1 / 60);
      }
      expect(game.balls.element[0], ElementType.neutral.index);
    });

    test('rewarded: 1 carga por partida; reset libera de novo', () async {
      final gs = GameState();
      final game = await _shoot(gs);
      expect(game.grantTransmuteViaAd(), isTrue);
      expect(gs.transmuteCharges, 1);
      expect(game.grantTransmuteViaAd(), isFalse, reason: 'só uma vez');
      expect(gs.transmuteCharges, 1);
      gs.reset();
      expect(gs.elementAdUsed, isFalse);
      expect(gs.transmuteCharges, 0);
    });

    test('coletar o power-up dá 1 carga e avisa', () async {
      final gs = GameState();
      final game = await _game(gs);
      final pu = BlockComponent(
        position: Vector2(4 * _s + 1, 5 * _s + 1 + BallzFlameGame.topOffset),
        type: BlockType.powerup,
        hp: 0,
        maxHp: 0,
        element: ElementType.neutral,
        powerUp: PowerUpKind.transmute,
      );
      game.blocks.add(pu);
      game.debugBeginRound();
      game.balls.spawn(4 * _s + 20, 5 * _s + 20 + BallzFlameGame.topOffset, 90,
          -542, 0, 1);
      game.update(1 / 60);
      expect(gs.transmuteCharges, 1);
      expect(gs.announceKey, 'pu:${PowerUpKind.transmute.index}');
    });

    test('é raro: ~5% das vagas, e os outros 8 continuam saindo', () {
      final rng = Random(1);
      final counts = <PowerUpKind, int>{};
      const n = 6000;
      for (var i = 0; i < n; i++) {
        final k = BallzFlameGame.pickPowerUp(rng);
        counts[k] = (counts[k] ?? 0) + 1;
      }
      final share = counts[PowerUpKind.transmute]! / n;
      expect(share, closeTo(ElementConfig.transmuteShare, 0.02));
      for (final k in PowerUpKind.values) {
        expect(counts[k] ?? 0, greaterThan(0), reason: '$k');
      }
      // Transmutação é de fato a mais rara.
      for (final k in PowerUpKind.values) {
        if (k == PowerUpKind.transmute) continue;
        expect(counts[k]!, greaterThan(counts[PowerUpKind.transmute]!));
      }
    });

    test('a carga sobrevive ao salvar e carregar', () async {
      final gs = GameState()
        ..addTransmuteCharge()
        ..addTransmuteCharge()
        ..elementAdUsed = true;
      await gs.save();
      final loaded = await GameState.load();
      expect(loaded.transmuteCharges, 2);
      expect(loaded.elementAdUsed, isTrue);
    });
  });

  group('Troca de elemento (1 por turno)', () {
    test('só vale com bola que já tem elemento', () async {
      final gs = GameState();
      final game = await _shoot(gs);
      for (var i = 0; i < 20; i++) {
        game.update(1 / 60);
      }
      expect(game.canSwapElement, isFalse, reason: 'bolas neutras');
      expect(game.swapBallElement(ElementType.fire), isFalse);
    });

    test('troca o elemento das bolas elementais; neutras ficam neutras',
        () async {
      final gs = GameState();
      final game = await _shoot(gs, n: 3);
      for (var i = 0; i < 200 && game.balls.count < 3; i++) {
        game.update(1 / 60);
      }
      game.balls.element[0] = ElementType.fire.index;
      game.balls.element[1] = ElementType.earth.index;
      expect(game.canSwapElement, isTrue);
      expect(game.swapBallElement(ElementType.water), isTrue);
      expect(game.balls.element[0], ElementType.water.index);
      expect(game.balls.element[1], ElementType.water.index);
      expect(game.balls.element[2], ElementType.neutral.index);
    });

    test('uma vez por turno; no turno seguinte vale de novo', () async {
      final gs = GameState();
      final game = await _shoot(gs, n: 2);
      for (var i = 0; i < 100 && game.balls.count < 2; i++) {
        game.update(1 / 60);
      }
      game.balls.element[0] = ElementType.fire.index;
      expect(game.swapBallElement(ElementType.wind), isTrue);
      expect(game.canSwapElement, isFalse, reason: 'já usou neste turno');
      expect(game.swapAvailable.value, isFalse);
      expect(game.swapBallElement(ElementType.earth), isFalse);
      expect(game.balls.element[0], ElementType.wind.index);

      // Novo turno.
      game.forceReturn();
      for (var i = 0; i < 900 && game.phase != GamePhase.aim; i++) {
        game.update(1 / 60);
      }
      game.handlePointerPosition(Offset(180, game.floorY - 300));
      game.shoot();
      for (var i = 0; i < 100 && game.balls.count < 1; i++) {
        game.update(1 / 60);
      }
      game.balls.element[0] = ElementType.fire.index;
      expect(game.canSwapElement, isTrue);
    });

    test('a ordem das combinações continua valendo: a troca não dispara nada',
        () async {
      final gs = GameState();
      final game = await _shoot(gs, n: 1);
      for (var i = 0; i < 40 && game.balls.count < 1; i++) {
        game.update(1 / 60);
      }
      game.balls.element[0] = ElementType.fire.index;
      final hp = game.blocks.first.hp;
      game.swapBallElement(ElementType.water);
      expect(game.blocks.first.hp, hp, reason: 'só muda a cor/elemento');
    });
  });
}
