import 'dart:ui' as ui;

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/game/render/sprite_atlas.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conta chamadas ao Canvas para provar o desenho em lote.
class _CountingCanvas implements ui.Canvas {
  final calls = <String>[];

  @override
  int getSaveCount() => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    calls.add(name.substring(8, name.length - 2)); // Symbol("x") -> x
    return null;
  }
}

BlockComponent _b(int c, int r, BlockType type,
        {int hp = 120,
        ElementType el = ElementType.fire,
        int gold = 0,
        ElementType? power,
        bool boss = false}) =>
    BlockComponent(
      position: Vector2(c * 38.0 + 1, r * 38.0 + 49),
      type: type,
      hp: hp,
      maxHp: hp + 40,
      element: el,
      goldValue: gold,
      elemPowerEl: power,
      isBoss: boss,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('atlas tem todos os sprites dentro da imagem', () {
    final atlas = SpriteAtlas.build(2.75);
    expect(atlas.image.width, 1024);
    for (var id = 0; id < Spr.count; id++) {
      final r = atlas.rects;
      expect(r[id * 4 + 2], greaterThan(r[id * 4]), reason: 'sprite $id');
      expect(r[id * 4 + 3], lessThanOrEqualTo(atlas.image.height));
    }
    expect(atlas.glyphHeight, greaterThan(0));
    // ~1–2 MB de textura, mesmo em tela 3x.
    final big = SpriteAtlas.build(3);
    expect(big.image.width * big.image.height * 4, lessThan(4 << 20));
  });

  test('frame com todos os tipos de bloco e bolas sai em poucos desenhos',
      () async {
    SharedPreferences.setMockInitialValues({});
    final gs = GameState()..starterBallsActive = true; // Prisma: anel e brilho
    final game = BallzFlameGame(gameState: gs);
    game.onGameResize(Vector2(360, 640));
    await game.onLoad();
    final burning = _b(0, 0, BlockType.normal)
      ..status.applyBurn(turns: 2, damage: 3);
    game.blocks
      ..clear()
      ..addAll([
        burning,
        _b(1, 0, BlockType.normal, el: ElementType.neutral, hp: 7),
        _b(2, 0, BlockType.gold, el: ElementType.neutral, gold: 6),
        _b(3, 0, BlockType.normal, el: ElementType.water, gold: 4, hp: 1234),
        _b(4, 0, BlockType.bonus, hp: 0),
        _b(5, 0, BlockType.triple, hp: 0),
        _b(6, 0, BlockType.elemPower, el: ElementType.neutral, power: ElementType.wind),
        _b(7, 0, BlockType.wall, hp: 3),
        _b(8, 0, BlockType.wall, hp: 1, el: ElementType.neutral),
        _b(3, 2, BlockType.boss, hp: 54321, boss: true),
      ]);
    game.debugBeginRound();
    for (var i = 0; i < 40; i++) {
      game.balls.spawn(20.0 + i * 8, 400, 120, -500, i % 4, 1);
    }
    game.particles
      ..limit = 50
      ..burst(100, 100, 0xFFFF0000, 20);
    game.update(1 / 60);

    final canvas = _CountingCanvas();
    game.render(canvas);
    final draws = canvas.calls.where((c) => c.startsWith('draw')).toList();
    expect(draws, ['drawPicture', 'drawRawAtlas', 'drawRawAtlas']);

    // E desenha de verdade, sem erro, num canvas real.
    final recorder = ui.PictureRecorder();
    game.render(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(360, 640);
    expect(image.width, 360);
    image.dispose();
    picture.dispose();
  });

  test('mira usa um path só e o contador de bolas vem do atlas', () async {
    SharedPreferences.setMockInitialValues({});
    final gs = GameState()..upgrades['bounce'] = 3;
    final game = BallzFlameGame(gameState: gs);
    game.onGameResize(Vector2(360, 640));
    await game.onLoad();
    game.startWave();
    gs.ballCount = 123;
    game.handlePointerPosition(Offset(30, game.floorY - 100));
    final canvas = _CountingCanvas();
    game.render(canvas);
    final draws = canvas.calls.where((c) => c.startsWith('draw')).toList();
    expect(draws, ['drawPicture', 'drawRawAtlas', 'drawPath', 'drawRawAtlas']);
  });
}
