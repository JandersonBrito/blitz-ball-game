import 'dart:math';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/game/perf/perf_config.dart';
import 'package:ballz_flutter/game/physics/ball_pool.dart';
import 'package:ballz_flutter/game/physics/damage_model.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _s = BallzFlameGame.blockSize;

BlockComponent _block(int col, int row,
        {int hp = 10000,
        BlockType type = BlockType.normal,
        ElementType el = ElementType.neutral}) =>
    BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: type,
      hp: hp,
      maxHp: hp,
      element: el,
    );

Future<BallzFlameGame> _game(GameState gs, List<BlockComponent> blocks) async {
  final game = BallzFlameGame(gameState: gs, random: Random(7));
  game.onGameResize(Vector2(360, 640));
  await game.onLoad();
  game.blocks
    ..clear()
    ..addAll(blocks);
  return game;
}

/// Roda a rodada até as bolas voltarem (ou estourar o limite de frames).
void _playRound(BallzFlameGame game, {double dt = 1 / 60, int maxFrames = 4000}) {
  for (var i = 0; i < maxFrames; i++) {
    game.update(dt);
    if (game.phase != GamePhase.shooting && game.phase != GamePhase.returning) {
      return;
    }
  }
  fail('a rodada não terminou');
}

int _hpLost(List<BlockComponent> blocks) =>
    blocks.fold(0, (sum, b) => sum + (b.maxHp - b.hp));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('frame longo (100 ms) não faz a bola atravessar o bloco', () async {
    final target = _block(4, 5, hp: 50);
    final game = await _game(GameState(), [target]);
    game.debugBeginRound();
    // 550 px/s: 55 px por frame, mais que a janela de 48 px do bloco.
    game.balls.spawn(172, 400, 0, -550, 0, 1);
    for (var i = 0; i < 3; i++) {
      game.update(0.1);
    }
    expect(target.hp, 49);
    expect(game.balls.vy[0], greaterThan(0), reason: 'quicou para baixo');
  });

  test('o resultado da física não depende do FPS', () async {
    // Cenário caótico (bolas presas na faixa de cima): com passo variável o
    // resultado divergiria logo; com passo fixo tem que ser idêntico.
    Future<(int, int)> run(double dt) async {
      final board = [
        for (var r = 1; r < 8; r++)
          for (var c = 0; c < 8; c++) _block(c, r, hp: 600),
      ];
      final gs = GameState();
      final game = await _game(gs, board);
      game.startWave();
      gs.ballCount = 30;
      game.handlePointerPosition(Offset(game.originX + 100, game.floorY - 173));
      game.shoot();
      _playRound(game, dt: dt);
      return (_hpLost(board), gs.score);
    }

    final at60 = await run(1 / 60);
    expect(at60.$1, greaterThan(300), reason: 'cenário com muitos acertos');
    expect(await run(1 / 30), at60);
    expect(await run(1 / 144), at60);
  });

  test('acima do limite as bolas saem agrupadas e o dano total é o mesmo',
      () async {
    final row = [for (var c = 0; c < 9; c++) _block(c, 2)];
    final gs = GameState();
    final game = await _game(gs, row);
    game.startWave();
    gs.ballCount = 250;
    game.handlePointerPosition(Offset(game.originX, game.floorY - 300));
    game.shoot();
    expect(game.queuedWeight, 250, reason: 'soma dos pesos = bolas');

    var maxObjects = 0;
    for (var i = 0; i < 4000; i++) {
      game.update(1 / 60);
      maxObjects = max(maxObjects, game.balls.count);
      if (game.phase != GamePhase.shooting) break;
    }
    // Cada bola bate uma vez na fileira e cai: dano 1 por bola.
    expect(_hpLost(row), 250);
    expect(maxObjects, lessThanOrEqualTo(PerfConfig.ballGroupThreshold));
  });

  test('grupo que quebra um bloco se divide: parte quica, parte passa',
      () async {
    final weak = _block(6, 8, hp: 2);
    final game = await _game(GameState(), [weak]);
    game.debugBeginRound();
    // Peso 3 subindo em direção à base do bloco de HP 2.
    game.balls.spawn(248, 450, 82, -544, 0, 3);
    for (var i = 0; i < 30 && game.blocks.isNotEmpty; i++) {
      game.update(1 / 60);
    }
    expect(game.blocks, isEmpty);
    final b = game.balls;
    expect(b.count, 2);
    expect(b.weight[0] + b.weight[1], 3);
    // A 1ª bola do grupo quicou; a 2ª quebrou e passou junto com a 3ª.
    final up = b.vy[0] < 0 ? 0 : 1;
    expect(b.weight[up], 2);
    expect(b.vy[1 - up], greaterThan(0));
    expect(b.weight[1 - up], 1);
  });

  test('junção entre blocos vizinhos quica como superfície lisa', () async {
    final left = _block(3, 1), right = _block(4, 1);
    final game = await _game(GameState(), [left, right]);
    game.debugBeginRound();
    // Descendo para a esquerda bem em cima da junção (x = 153).
    game.balls.spawn(158, 70, -275, 476, 0, 1);
    for (var i = 0; i < 10 && _hpLost([left, right]) == 0; i++) {
      game.update(1 / 60);
    }
    expect(_hpLost([left, right]), 1, reason: 'um acerto só');
    expect(game.balls.vy[0], lessThan(0), reason: 'quicou para cima');
    expect(game.balls.vx[0], lessThan(0), reason: 'seguiu para a esquerda');
  });

  test('bola subindo perto da borda do bloco quica na base, não na lateral',
      () async {
    final target = _block(4, 5, hp: 50); // x de 153 a 191
    final game = await _game(GameState(), [target]);
    game.debugBeginRound();
    // Centro a 1,4 px da borda direita, dentro da largura do bloco.
    game.balls.spawn(189.6, 285, 0.1, -550, 0, 1);
    for (var i = 0; i < 10 && target.hp == 50; i++) {
      game.update(1 / 60);
    }
    expect(target.hp, 49);
    expect(game.balls.vy[0], greaterThan(0));
  });

  test('status são processados por turno, nunca por frame', () async {
    final burning = _block(0, 0, hp: 100)..status.applyBurn(turns: 3, damage: 10);
    final dying = _block(8, 0, hp: 5)..status.applyBurn(turns: 2, damage: 10);
    final gs = GameState();
    final game = await _game(gs, [burning, dying]);
    game.startWave();
    game.handlePointerPosition(Offset(game.originX - 40, game.floorY - 300));
    game.shoot();
    for (var i = 0; i < 20; i++) {
      game.update(1 / 60);
    }
    expect(game.phase, GamePhase.shooting);
    expect(burning.hp, 100, reason: 'nada de dano por frame');

    _playRound(game);
    expect(game.phase, GamePhase.aim);
    expect(burning.hp, 90);
    expect(burning.status.burnTurns, 2);
    expect(game.blocks.contains(dying), isFalse, reason: 'morreu no fim do turno');
  });

  test('bolas na fila são todas disparadas antes do retorno', () async {
    final gs = GameState();
    final game = await _game(gs, [_block(0, 0)]);
    game.startWave();
    gs.ballCount = 40;
    game.handlePointerPosition(Offset(game.originX + 50, game.floorY - 300));
    game.shoot();
    var fired = 0;
    for (var i = 0; i < 4000 && game.phase == GamePhase.shooting; i++) {
      game.update(1 / 60);
      fired = max(fired, game.balls.count);
    }
    expect(fired, 40);
    expect(game.balls.state[0], BallPool.returning);
  });

  group('DamageModel', () {
    test('segue as regras de GameState.calcElemMult', () {
      final gs = GameState()
        ..upgrades['power'] = 5
        ..upgrades['upg_fire'] = 3
        ..upgrades['upg_water'] = 2;
      final model = DamageModel(Random(1))..refresh(gs);
      expect(model.base, 8);
      for (final atk in ElementType.values) {
        for (final def in ElementType.values) {
          expect(model.roll(atk.index, def.index),
              (8 * gs.calcElemMult(atk, def)).ceil(),
              reason: '$atk x $def');
        }
      }
    });

    test('vento ignora a desvantagem na proporção do upgrade', () {
      // Base 8: 4 de dano sem o bypass (x0.5), 8 com ele (x1.0).
      final gs = GameState()
        ..upgrades['upg_wind'] = 5 // 75%
        ..upgrades['power'] = 5;
      final model = DamageModel(Random(3))..refresh(gs);
      var bypassed = 0;
      for (var i = 0; i < 4000; i++) {
        if (model.roll(ElementType.wind.index, ElementType.fire.index) == 8) {
          bypassed++;
        }
      }
      expect(bypassed / 4000, closeTo(0.75, 0.03));
    });
  });
}
