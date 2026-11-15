import 'dart:math';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/config/element_config.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/game/status/block_status.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _s = BallzFlameGame.blockSize;

BlockComponent _block(int col, int row,
        {int hp = 10000,
        BlockType type = BlockType.normal,
        bool boss = false}) =>
    BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: type,
      hp: hp,
      maxHp: hp,
      element: ElementType.neutral,
      isBoss: boss,
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

/// Joga uma rodada "vazia" (1 bola pra cima) até voltar ao aim/menu:
/// o que interessa é o _finishRound (descida, zonas, status).
void _playRound(BallzFlameGame game) {
  game.debugBeginRound();
  game.balls.spawn(180, game.floorY - 10, 90, -542, 0, 1);
  for (var i = 0; i < 4000; i++) {
    game.update(1 / 60);
    if (game.phase != GamePhase.shooting && game.phase != GamePhase.returning) {
      return;
    }
  }
  fail('a rodada não terminou');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bloco congelado não desce e segura a coluna; os outros descem', () async {
    final frozen = _block(4, 5)..status.applyFreeze(turns: 2);
    final adjacent = _block(4, 4); // encostado em cima do congelado
    final gap = _block(4, 2); // mesma coluna, com 1 célula de vão
    final other = _block(7, 5); // coluna livre
    final game = await _game(GameState(), [frozen, adjacent, gap, other]);
    final frozenY = frozen.position.y;
    final adjacentY = adjacent.position.y;
    final gapY = gap.position.y;
    final otherY = other.position.y;

    _playRound(game);
    expect(frozen.position.y, frozenY, reason: 'congelado não desce');
    expect(adjacent.position.y, adjacentY,
        reason: 'encostado no congelado fica segurado');
    expect(gap.position.y, gapY + _s, reason: 'com vão livre, desce');
    expect(other.position.y, otherY + _s, reason: 'coluna livre desce');
  });

  test('preso (lama) segura só o próximo turno', () async {
    final stuck = _block(2, 5)..status.applyStick(turns: 1);
    final game = await _game(GameState(), [stuck]);
    final y0 = stuck.position.y;

    _playRound(game);
    expect(stuck.position.y, y0, reason: '1º turno: preso');
    _playRound(game);
    expect(stuck.position.y, y0 + _s, reason: '2º turno: solto');
  });

  test('boss só desce com as DUAS colunas livres', () async {
    final boss = _block(4, 2, boss: true); // ocupa colunas 4–5
    final frozenBelow = _block(5, 6)..status.applyFreeze(turns: 9);
    // Empilha blocos até encostar no boss (linhas 4 e 5 na coluna 5).
    final mid1 = _block(5, 4);
    final mid2 = _block(5, 5);
    final game = await _game(GameState(), [boss, frozenBelow, mid1, mid2]);
    final bossY = boss.position.y;

    _playRound(game);
    expect(mid2.position.y, 5 * _s + 1 + BallzFlameGame.topOffset,
        reason: 'encostado no congelado');
    expect(mid1.position.y, 4 * _s + 1 + BallzFlameGame.topOffset);
    expect(boss.position.y, bossY, reason: 'coluna 5 travada segura o boss');
  });

  test('amolecido dobra o dano e congelado multiplica por 1.5', () {
    final s = BlockStatus()..applySoften(turns: 1);
    expect(s.damageMult(2.0, 1.5), 2.0);
    s.applyFreeze(turns: 1);
    expect(s.damageMult(2.0, 1.5), 3.0);
    expect(s.holdsDescent, isTrue);
    s.tick();
    expect(s.softened, isFalse);
    expect(s.frozen, isFalse);
    expect(s.damageMult(2.0, 1.5), 1.0);
  });

  test('o multiplicador de status vale no acerto da bola', () async {
    final soft = _block(4, 5, hp: 100)..status.applySoften(turns: 3);
    final game = await _game(GameState(), [_block(0, 0), soft]);
    game.debugBeginRound();
    // Bola batendo por baixo do bloco amolecido: dano 1 × 2 = 2.
    game.balls.spawn(172, 350, 90, -542, 0, 1);
    for (var i = 0; i < 60 && soft.hp == 100; i++) {
      game.update(1 / 60);
    }
    expect(soft.hp, 100 - ElementConfig.softenedDamageMult.round());
  });

  test('muralha (power-up) segura uma descida inteira', () async {
    final b = _block(3, 5);
    final game = await _game(GameState(), [b]);
    game.wallCharges = 1;
    final y0 = b.position.y;
    _playRound(game);
    expect(b.position.y, y0, reason: 'muralha usada');
    expect(game.wallCharges, 0);
    _playRound(game);
    expect(b.position.y, y0 + _s, reason: 'sem muralha, desce');
  });
}
