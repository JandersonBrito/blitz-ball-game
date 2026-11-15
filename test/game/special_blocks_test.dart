import 'dart:math';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/config/element_config.dart';
import 'package:ballz_flutter/game/managers/block_factory.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _s = BallzFlameGame.blockSize;

BlockComponent _block(int col, int row,
        {int hp = 10000,
        BlockType type = BlockType.normal,
        ElementType el = ElementType.neutral,
        int charges = 0}) =>
    BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: type,
      hp: hp,
      maxHp: hp,
      element: el,
      charges: charges,
    );

BlockComponent _special(int col, int row, ElementType el, {int charges = 3}) =>
    _block(col, row, hp: 0, type: BlockType.special, el: el, charges: charges);

Future<BallzFlameGame> _game(GameState gs, List<BlockComponent> blocks) async {
  final game = BallzFlameGame(gameState: gs, random: Random(7));
  game.onGameResize(Vector2(360, 640));
  await game.onLoad();
  game.blocks
    ..clear()
    ..addAll(blocks);
  return game;
}

/// Roda frames até [done] (ou estourar o limite).
void _until(BallzFlameGame game, bool Function() done, {int maxFrames = 600}) {
  for (var i = 0; i < maxFrames; i++) {
    if (done()) return;
    game.update(1 / 60);
  }
  fail('condição não aconteceu em $maxFrames frames');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bola neutra atravessa o especial, absorve o elemento e gasta 1 carga',
      () async {
    final special = _special(4, 5, ElementType.fire); // x 153–191, y 239–277
    final game = await _game(GameState(), [_block(0, 0), special]);
    game.debugBeginRound();
    // Sobe atravessando o bloco: entra por baixo e sai por cima.
    game.balls.spawn(160, 350, 90, -542, ElementType.neutral.index, 1);

    _until(game, () => game.balls.y[0] < 230); // já saiu por cima
    expect(game.balls.element[0], ElementType.fire.index, reason: 'absorveu');
    expect(game.balls.vy[0], lessThan(0), reason: 'atravessou sem quicar');
    expect(special.charges, 2, reason: '1 carga por passagem, não por substep');
    expect(game.blocks.contains(special), isTrue);
  });

  test('absorver NÃO troca o poder escolhido no botão de especial', () async {
    final gs = GameState()
      ..specialLevels[ElementType.water] = 1
      ..specialLevels[ElementType.fire] = 1;
    gs.selectSpecial(ElementType.fire);
    final water = _special(2, 5, ElementType.water);
    final game = await _game(gs, [_block(0, 0), water]);
    game.debugBeginRound();
    game.balls.spawn(2 * _s + 20, 5 * _s + 20 + BallzFlameGame.topOffset, 90,
        -542, ElementType.neutral.index, 1);
    game.update(1 / 60);
    expect(game.balls.element[0], ElementType.water.index, reason: 'absorveu');
    expect(gs.armedElement, ElementType.fire,
        reason: 'o poder do botão continua o que o jogador escolheu');
    expect(game.specialElement, ElementType.fire);
  });

  test('bola com elemento dispara a combinação e volta a ser neutra', () async {
    final special = _special(4, 5, ElementType.water);
    final game = await _game(GameState(), [_block(0, 0), special]);
    game.debugBeginRound();
    game.balls.spawn(160, 350, 90, -542, ElementType.fire.index, 1);

    _until(game, () => game.balls.y[0] < 230);
    // keepElementAfterCombo = false: a bola gastou o elemento no combo.
    expect(ElementConfig.keepElementAfterCombo, isFalse);
    expect(game.balls.element[0], ElementType.neutral.index);
    expect(game.balls.vy[0], lessThan(0), reason: 'atravessou sem quicar');
    expect(special.charges, 2);
  });

  test('bloco especial some quando as cargas acabam', () async {
    final special = _special(4, 5, ElementType.earth, charges: 1);
    final game = await _game(GameState(), [_block(0, 0), special]);
    game.debugBeginRound();
    game.balls.spawn(160, 350, 90, -542, ElementType.neutral.index, 1);

    _until(game, () => !game.blocks.contains(special));
    expect(game.balls.element[0], ElementType.earth.index);
  });

  test('absorção muda só a bola que passou pelo bloco', () async {
    final special = _special(4, 5, ElementType.lightning);
    final game = await _game(GameState(), [_block(0, 0), special]);
    game.debugBeginRound();
    game.balls.spawn(160, 350, 90, -542, ElementType.neutral.index, 1);
    game.balls.spawn(330, 400, 90, -542, ElementType.neutral.index, 1);

    _until(game, () => game.balls.element[0] == ElementType.lightning.index);
    expect(game.balls.element[1], ElementType.neutral.index);
  });

  test('sair e entrar de novo no mesmo bloco conta outra passagem', () async {
    final special = _special(4, 5, ElementType.fire); // centro ≈ (172, 258)
    final game = await _game(GameState(), [_block(0, 0), special]);
    game.debugBeginRound();
    // Nasce dentro do especial: o 1º frame consome a 1ª passagem (absorve).
    game.balls.spawn(172, 258, 90, -542, ElementType.neutral.index, 1);
    game.update(1 / 60);
    expect(special.charges, 2);
    expect(game.balls.element[0], ElementType.fire.index);

    // Enquanto está em contato, mais frames não gastam outra carga.
    game.update(1 / 60);
    expect(special.charges, 2);

    // Sai do bloco (contato zerado)...
    game.balls.x[0] = 60;
    game.balls.y[0] = 450;
    game.update(1 / 60);
    expect(special.charges, 2);

    // ...e volta: 2ª passagem. Fogo × fogo dispara combo e a bola fica neutra.
    game.balls.x[0] = 172;
    game.balls.y[0] = 258;
    game.update(1 / 60);
    expect(special.charges, 1);
    expect(game.balls.element[0], ElementType.neutral.index,
        reason: 'combo consumiu o elemento');
  });

  group('spawn de blocos especiais', () {
    test('no máximo 1 por geração inicial, com cargas e elemento válidos', () {
      for (var level = 1; level <= 30; level++) {
        for (var run = 0; run < 10; run++) {
          final blocks = initBlocks(level);
          final specials =
              blocks.where((b) => b.type == BlockType.special).toList();
          expect(specials.length, lessThanOrEqualTo(1), reason: 'level $level');
          for (final s in specials) {
            expect(s.charges, ElementConfig.specialCharges);
            expect(s.element, isNot(ElementType.neutral));
            expect(kCombatElements, contains(s.element));
          }
        }
      }
    });

    test('o especial nasce numa coluna vazia da linha', () {
      for (var run = 0; run < 200; run++) {
        final row = generateRow(5, ElementType.fire, 0, allowSpecial: true);
        final positions = row.map((b) => b.position.x).toList();
        expect(positions.toSet().length, positions.length,
            reason: 'sem dois blocos na mesma coluna');
        expect(row.where((b) => b.type == BlockType.special).length,
            lessThanOrEqualTo(1));
      }
    });
  });
}
