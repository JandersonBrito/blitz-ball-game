import 'dart:math';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/combos/combo_defs.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/game/physics/ball_pool.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _s = BallzFlameGame.blockSize;

BlockComponent _block(int col, int row, {int hp = 100}) => BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: BlockType.normal,
      hp: hp,
      maxHp: hp,
      element: ElementType.neutral,
    );

BlockComponent _special(int col, int row, ElementType el) => BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: BlockType.special,
      hp: 0,
      maxHp: 0,
      element: el,
      charges: 3,
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

/// Dispara a combinação [ballEl] × especial em (4,5) de forma determinística:
/// a bola nasce DENTRO do bloco especial e o 1º update resolve o combo.
Future<BallzFlameGame> _trigger(ElementType ballEl, ElementType blockEl,
    List<BlockComponent> board, GameState gs) async {
  final game = await _game(gs, [_special(4, 5, blockEl), ...board]);
  game.debugBeginRound();
  game.balls.spawn(4 * _s + 20, 5 * _s + 20 + BallzFlameGame.topOffset, 90,
      -542, ballEl.index, 1);
  game.update(1 / 60);
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tabela de combinações', () {
    test('tem as 25 combinações, uma por par, e a ordem importa', () {
      expect(comboDefs.length, 25);
      final seen = <int>{};
      for (final def in comboDefs) {
        expect(def.ball, isNot(ElementType.neutral));
        expect(def.block, isNot(ElementType.neutral));
        expect(seen.add(comboIndex(def.ball, def.block)), isTrue,
            reason: 'par duplicado: ${def.id}');
        expect(comboFor(def.ball, def.block).id, def.id);
      }
      // Assimetria da spec: fogo×água = Ácido; água×fogo = Vapor.
      expect(comboFor(ElementType.fire, ElementType.water).id, 'acid_pool');
      expect(comboFor(ElementType.water, ElementType.fire).id, 'vapor');
    });

    test('dano cresce com o nível do especial e o tamanho também', () {
      final def = comboFor(ElementType.fire, ElementType.fire);
      expect(def.effDmg(5), greaterThan(def.effDmg(1)));
      expect(def.effSize(9), greaterThan(def.effSize(1)));
    });
  });

  group('efeitos', () {
    test('Explosão (fogo×fogo): dano em área 3×3', () async {
      final near = _block(3, 5);
      final far = _block(0, 10);
      final game = await _trigger(
          ElementType.fire, ElementType.fire, [near, far], GameState());
      expect(near.hp, lessThan(100), reason: 'vizinho atingido');
      expect(far.hp, 100, reason: 'fora da área');
      expect(game.gameState.comboDiscovered(
          comboIndex(ElementType.fire, ElementType.fire)), isTrue);
    });

    test('Plasma (fogo×raio): linha inteira', () async {
      final sameRow = _block(0, 5);
      final otherRow = _block(0, 9);
      await _trigger(
          ElementType.fire, ElementType.lightning, [sameRow, otherRow],
          GameState());
      expect(sameRow.hp, lessThan(100));
      expect(otherRow.hp, 100);
    });

    test('Fissura (terra×terra): corta 50% do HP da coluna', () async {
      final sameCol = _block(4, 9, hp: 100);
      final otherCol = _block(0, 9, hp: 100);
      await _trigger(
          ElementType.earth, ElementType.earth, [sameCol, otherCol],
          GameState());
      expect(sameCol.hp, 50);
      expect(otherCol.hp, 100);
    });

    test('Trovão (raio×raio): os 5 blocos com mais HP', () async {
      final tough = [for (var c = 0; c < 5; c++) _block(c, 9, hp: 900)];
      final weak = _block(7, 9, hp: 10);
      await _trigger(ElementType.lightning, ElementType.lightning,
          [...tough, weak], GameState());
      for (final b in tough) {
        expect(b.hp, lessThan(900));
      }
      expect(weak.hp, 10, reason: 'fraco não está no top 5');
    });

    test('Nevasca (vento×água): congela a área', () async {
      final near = _block(4, 4);
      await _trigger(
          ElementType.wind, ElementType.water, [near], GameState());
      expect(near.status.frozen, isTrue);
    });

    test('Furacão (vento×vento): a bola se divide em 3', () async {
      final game = await _trigger(
          ElementType.wind, ElementType.wind, [_block(0, 10)], GameState());
      expect(game.balls.count, 3);
    });

    test('Relâmpago (raio×vento): a bola perfura por 2 s e não ricocheteia',
        () async {
      final wallBlock = _block(4, 3, hp: 1000);
      final game = await _trigger(
          ElementType.lightning, ElementType.wind, [wallBlock], GameState());
      expect(game.balls.pierceTime[0], greaterThan(0));
      // Sobe perfurando o bloco: dano sem inverter vy.
      for (var i = 0; i < 30 && wallBlock.hp == 1000; i++) {
        game.update(1 / 60);
      }
      expect(wallBlock.hp, lessThan(1000));
      expect(game.balls.vy[0], lessThan(0), reason: 'não quicou');
    });

    test('Magma (terra×fogo): zona fixa queima quem desce sobre ela', () async {
      // Fora do caminho da bola (que sai para cima/direita); desce PARA a lava.
      final under = _block(3, 4, hp: 1000);
      final game = await _trigger(
          ElementType.earth, ElementType.fire, [under], GameState());
      expect(game.zones.count, 1);
      expect(ZoneKind.values[game.zones.kind[0] - 1], ZoneKind.magma);
      final turns0 = game.zones.turns[0];
      final hp0 = under.hp; // a bola pode ter batido nele antes do retorno
      // Fim da rodada: desce sobre a lava, é queimado e a zona perde 1 turno.
      game.forceReturn();
      for (var i = 0; i < 600 && game.phase == GamePhase.returning; i++) {
        game.update(1 / 60);
      }
      expect(game.zones.count, 1);
      expect(game.zones.turns[0], turns0 - 1);
      expect(under.hp, lessThan(hp0), reason: 'queimado pela lava');
      expect(under.status.burning, isTrue,
          reason: 'em chamas para o próximo turno');
    });

    test('Onda (água×água): empurra a linha 1 casa para trás no fim da rodada',
        () async {
      final rowBlock = _block(1, 5, hp: 1000);
      final game = await _trigger(
          ElementType.water, ElementType.water, [rowBlock], GameState());
      final y0 = rowBlock.position.y;
      game.forceReturn();
      for (var i = 0; i < 600 && game.phase == GamePhase.returning; i++) {
        game.update(1 / 60);
      }
      // Empurrada 1 para cima e depois a descida normal: efeito líquido = y0.
      expect(rowBlock.position.y, y0, reason: 'subiu 1 e desceu 1');
    });

    test('Pedregulho (terra×vento): bola extra pesada', () async {
      final game = await _trigger(
          ElementType.earth, ElementType.wind, [_block(0, 10)], GameState());
      expect(game.balls.count, 2);
      expect(game.balls.weight[1], greaterThanOrEqualTo(6));
    });

    test('a bola volta a ser neutra e o grupo gasta só 1 carga', () async {
      final game = await _trigger(
          ElementType.fire, ElementType.fire, [_block(0, 10)], GameState());
      expect(game.balls.element[0], ElementType.neutral.index);
      expect(game.blocks.whereType<BlockComponent>()
          .where((b) => b.type == BlockType.special)
          .first.charges, 2);
      expect(game.balls.state[0], BallPool.flying);
    });
  });
}
