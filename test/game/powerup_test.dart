import 'dart:math';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/config/element_config.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _s = BallzFlameGame.blockSize;

BlockComponent _block(int col, int row,
        {int hp = 100, BlockType type = BlockType.normal, int gold = 0}) =>
    BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: type,
      hp: hp,
      maxHp: hp,
      element: ElementType.neutral,
      goldValue: gold,
    );

BlockComponent _pickup(int col, int row, PowerUpKind kind) => BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: BlockType.powerup,
      hp: 0,
      maxHp: 0,
      element: ElementType.neutral,
      powerUp: kind,
    );

Future<BallzFlameGame> _game(GameState gs, List<BlockComponent> blocks) async {
  final game = BallzFlameGame(gameState: gs, random: Random(7));
  game.onGameResize(Vector2(360, 640));
  await game.onLoad();
  game.blocks
    ..clear()
    ..addAll(blocks);
  game.debugBeginRound();
  return game;
}

/// Bola nasce dentro do coletável: o 1º update coleta.
void _collect(BallzFlameGame game, {int col = 4, int row = 5}) {
  game.balls.spawn(col * _s + 20, row * _s + 20 + BallzFlameGame.topOffset,
      90, -542, 0, 1);
  game.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('perfurante: a bola atravessa N blocos sem ricochetear', () async {
    final above = _block(4, 3, hp: 1000);
    final game = await _game(
        GameState(), [_pickup(4, 5, PowerUpKind.pierce), above]);
    _collect(game);
    expect(game.blocks.any((b) => b.type == BlockType.powerup), isFalse,
        reason: 'coletado');
    expect(game.balls.pierceLeft[0], ElementConfig.pierceBlocks);
    for (var i = 0; i < 40 && above.hp == 1000; i++) {
      game.update(1 / 60);
    }
    expect(above.hp, lessThan(1000));
    expect(game.balls.vy[0], lessThan(0), reason: 'atravessou sem quicar');
    expect(game.balls.pierceLeft[0], ElementConfig.pierceBlocks - 1);
  });

  test('coletar um power-up avisa o nome (toast)', () async {
    final gs = GameState();
    final game = await _game(
        gs, [_pickup(4, 5, PowerUpKind.magnet), _block(0, 10)]);
    expect(gs.announceKey, isNull);
    _collect(game);
    expect(gs.announceKey, 'pu:${PowerUpKind.magnet.index}');
  });

  test('bola gigante: raio dobrado nas bolas da rodada', () async {
    final game = await _game(
        GameState(), [_pickup(4, 5, PowerUpKind.giant), _block(0, 10)]);
    _collect(game);
    expect(game.balls.radius[0], ElementConfig.giantRadius);
  });

  test('ímã: coleta o ouro e as bolas extras do tabuleiro', () async {
    final gs = GameState();
    final goldBlock = _block(1, 8, type: BlockType.gold, hp: 50, gold: 7);
    final bonus = _block(7, 8, type: BlockType.bonus, hp: 0);
    final normal = _block(2, 9);
    final game = await _game(
        gs, [_pickup(4, 5, PowerUpKind.magnet), goldBlock, bonus, normal]);
    final balls0 = gs.ballCount;
    _collect(game);
    expect(gs.gold, 7);
    expect(gs.ballCount, balls0 + 1);
    expect(game.blocks.contains(goldBlock), isFalse);
    expect(game.blocks.contains(bonus), isFalse);
    expect(game.blocks.contains(normal), isTrue, reason: 'normais ficam');
  });

  test('multiplicador de moedas: ouro em dobro na rodada', () async {
    final gs = GameState();
    final goldBlock = _block(4, 3, type: BlockType.gold, hp: 1, gold: 5);
    final game = await _game(
        gs, [_pickup(4, 5, PowerUpKind.gold2x), goldBlock, _block(0, 10)]);
    _collect(game); // coleta o 2x; a bola segue e quebra o bloco de ouro
    for (var i = 0; i < 60 && game.blocks.contains(goldBlock); i++) {
      game.update(1 / 60);
    }
    expect(game.blocks.contains(goldBlock), isFalse);
    expect(gs.gold, 10, reason: '5 × 2');
  });

  test('bomba-relógio: explode sozinha depois de N turnos', () async {
    final bomb = _block(4, 5, type: BlockType.bomb, hp: 0)
      ..charges = 1; // explode no fim desta rodada
    final near = _block(3, 5, hp: 1000);
    final far = _block(0, 10, hp: 1000);
    final game = await _game(GameState(), [bomb, near, far]);
    game.balls.spawn(180, game.floorY - 10, 90, -542, 0, 1);
    for (var i = 0; i < 4000 && game.phase == GamePhase.shooting ||
            game.phase == GamePhase.returning; i++) {
      game.update(1 / 60);
    }
    expect(game.blocks.contains(bomb), isFalse, reason: 'explodiu');
    expect(near.hp, lessThan(1000), reason: 'área 3×3');
    expect(far.hp, 1000);
  });

  test('portais teletransportam a bola preservando a velocidade', () async {
    final game = await _game(GameState(),
        [_pickup(4, 5, PowerUpKind.portal), _block(0, 12, hp: 1000)]);
    _collect(game);
    expect(game.portalTurns, ElementConfig.portalTurns);
    // Põe a bola em cima do portal A: deve sair no B.
    game.balls.x[0] = game.portalAx;
    game.balls.y[0] = game.portalAy;
    final vy = game.balls.vy[0];
    game.update(1 / 60);
    final dxB = (game.balls.x[0] - game.portalBx).abs();
    expect(dxB, lessThan(30), reason: 'saiu perto do portal B');
    expect(game.balls.vy[0], vy, reason: 'velocidade preservada');
  });

  test('mira estendida: mais quiques por alguns turnos', () async {
    final game = await _game(
        GameState(), [_pickup(4, 5, PowerUpKind.aim), _block(0, 12, hp: 9000)]);
    _collect(game);
    final base = game.gameState.maxBounces;
    game.forceReturn();
    for (var i = 0; i < 600 && game.phase == GamePhase.returning; i++) {
      game.update(1 / 60);
    }
    expect(game.phase, GamePhase.aim);
    expect(game.aimBounces, base + ElementConfig.aimBoostBounces);
  });
}
