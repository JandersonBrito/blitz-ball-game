import 'dart:math';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/managers/block_factory.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<BallzFlameGame> _game(GameState gs, List<BlockComponent> blocks) async {
  final game = BallzFlameGame(gameState: gs, random: Random(7));
  game.onGameResize(Vector2(360, 640));
  await game.onLoad();
  game.blocks
    ..clear()
    ..addAll(blocks);
  return game;
}

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

  test('fortaleza a cada 10 fases, nunca junto de boss nem de corredor', () {
    expect([for (var s = 1; s <= 60; s++) if (GameState.isFortress(s)) s],
        [17, 27, 37, 47, 57]);
    final gs = GameState();
    for (var s = 1; s <= 500; s++) {
      gs.stage = s;
      if (gs.isFortressStage) {
        expect(gs.isBossStage, isFalse, reason: 'fase $s');
        expect(gs.isCorridorStage, isFalse, reason: 'fase $s');
        expect(gs.wavesForStage(s), 1);
      }
    }
  });

  test('HP do núcleo: 5.000 na primeira, cresce e tem teto', () {
    expect(fortressCoreHp(17), 5000);
    expect(fortressCoreHp(27), 5750);
    expect(fortressCoreHp(1000), 12000);
  });

  test('layout: núcleo gigante, tudo ancorado e dentro das 9 colunas', () {
    final blocks = initFortressStage(17);
    final core = blocks.reduce((a, b) => a.maxHp >= b.maxHp ? a : b);
    expect(core.maxHp, 5000);
    expect(core.goldValue, greaterThan(0));
    expect(blocks.every((b) => b.anchored), isTrue);
    for (final b in blocks) {
      final c = ((b.position.x - 1) / BlockComponent.blockSize).round();
      expect(c, inInclusiveRange(0, 8));
    }
    // Sem dois blocos na mesma célula.
    final cells = blocks
        .map((b) =>
            '${b.position.x.round()}:${b.position.y.round()}')
        .toSet();
    expect(cells.length, blocks.length);
    expect(blocks.where((b) => b.maxHp >= 1000).length, 3);
  });

  test('ajuda na fortaleza: 3x de dano, +8 bolas e oferta cedo', () {
    final gs = GameState()
      ..stage = 17
      ..upgrades['power'] = 2; // 3 de dano
    expect(gs.baseDamage, 3);
    gs.ballCount = 4;
    gs.applyHelpAssist();
    expect(gs.baseDamage, 9);
    expect(gs.ballCount, 12);

    final normal = GameState()..stage = 12;
    normal.applyHelpAssist();
    expect(normal.baseDamage, 2);

    final f = GameState()..stage = 17;
    f.incrementStageRounds(canOfferHelp: true);
    expect(f.showHelpOffer, isFalse);
    f.incrementStageRounds(canOfferHelp: true);
    expect(f.showHelpOffer, isTrue);
  });

  test('continuar depois do game over na fortaleza já vem com a ajuda', () {
    final gs = GameState()..stage = 17;
    gs.setGameOver();
    gs.continueAfterAd();
    expect(gs.assistActive, isTrue);
    final n = GameState()..stage = 12;
    n.setGameOver();
    n.continueAfterAd();
    expect(n.assistActive, isFalse);
  });

  test('a estrutura ancorada desce 1 linha a cada 3 rodadas', () async {
    final gs = GameState()..stage = 17;
    final b = initFortressStage(17).first;
    final game = await _game(gs, [b]);
    final y0 = b.position.y;
    _playRound(game);
    expect(b.position.y, y0);
    _playRound(game);
    expect(b.position.y, y0);
    _playRound(game);
    expect(b.position.y, y0 + BlockComponent.blockSize);
  });
}
