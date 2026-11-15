import 'dart:math';

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/daily_mission.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:ballz_flutter/services/daily_mission_service.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _s = BallzFlameGame.blockSize;

BlockComponent _block(int col, int row,
        {int hp = 100,
        BlockType type = BlockType.normal,
        ElementType el = ElementType.neutral,
        int charges = 0,
        PowerUpKind? power}) =>
    BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: type,
      hp: hp,
      maxHp: hp,
      element: el,
      charges: charges,
      powerUp: power,
    );

BlockComponent _special(int col, int row, ElementType el) =>
    _block(col, row, hp: 0, type: BlockType.special, el: el, charges: 3);

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

/// Força as 3 missões de hoje (determinístico): metas altas para não
/// completarem durante o teste.
Future<DailyMissionService> _missions(
    GameState gs, List<MissionType> types) async {
  SharedPreferences.setMockInitialValues({});
  final s = DailyMissionService.instance;
  await s.load(gs);
  final now = DateTime.now();
  final today = now.year * 10000 + now.month * 100 + now.day;
  final ok = s.applyBackup({
    'day': today,
    'bc': false,
    'br': 10,
    'm': [
      for (var i = 0; i < 3; i++)
        {'t': types[i].index, 'd': i, 'tg': 100, 'r': 10, 'p': 0, 'c': false}
    ],
  });
  expect(ok, isTrue);
  return s;
}

int _progress(DailyMissionService s, MissionType t) =>
    s.missions.firstWhere((m) => m.type == t).progress;

/// Bola nasce dentro do bloco (centro) e o 1º update resolve o contato.
void _ballInside(BallzFlameGame game, int col, int row, ElementType el) {
  game.balls.spawn(col * _s + 20, row * _s + 20 + BallzFlameGame.topOffset, 90,
      -542, el.index, 1);
  game.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('absorver, disparar combo e descobrir contam nas missões', () async {
    final gs = GameState();
    final s = await _missions(gs, [
      MissionType.absorbElements,
      MissionType.triggerCombos,
      MissionType.discoverCombos,
    ]);
    final game = await _game(gs, [_block(0, 0), _special(4, 5, ElementType.water)]);

    _ballInside(game, 4, 5, ElementType.neutral); // absorve
    expect(_progress(s, MissionType.absorbElements), 1);
    expect(_progress(s, MissionType.triggerCombos), 0);

    _ballInside(game, 4, 5, ElementType.fire); // fogo × água = Ácido
    expect(_progress(s, MissionType.triggerCombos), 1);
    expect(_progress(s, MissionType.discoverCombos), 1,
        reason: 'primeira vez que dispara essa combinação');

    // De novo a mesma combinação: conta o combo, mas não é descoberta nova.
    _ballInside(game, 4, 5, ElementType.fire);
    expect(_progress(s, MissionType.triggerCombos), 2);
    expect(_progress(s, MissionType.discoverCombos), 1,
        reason: 'já estava no Codex');
  });

  test('coletar power-up conta', () async {
    final gs = GameState();
    final s = await _missions(gs, [
      MissionType.collectPowerUps,
      MissionType.breakBlocks,
      MissionType.playRounds,
    ]);
    final game = await _game(gs, [
      _block(0, 0),
      _block(4, 5, hp: 0, type: BlockType.powerup, power: PowerUpKind.aim),
    ]);
    _ballInside(game, 4, 5, ElementType.neutral);
    expect(_progress(s, MissionType.collectPowerUps), 1);
  });

  test('usar o especial conta uma vez por uso; Maré em recarga não conta',
      () async {
    final gs = GameState()..specialLevels[ElementType.fire] = 1;
    final s = await _missions(gs, [
      MissionType.useSpecials,
      MissionType.breakBlocks,
      MissionType.playRounds,
    ]);
    final game = await _game(gs, [_block(4, 9, hp: 500)]);
    gs
      ..specialMeter = 1
      ..armedElement = ElementType.fire;
    game.activateSpecial();
    expect(_progress(s, MissionType.useSpecials), 1);

    // Sem medidor: não usa, não conta.
    game.activateSpecial();
    expect(_progress(s, MissionType.useSpecials), 1);

    // Rewarded também conta como uso.
    game.activateSpecialViaAd();
    expect(_progress(s, MissionType.useSpecials), 2);
  });

  test('status em blocos conta por bloco afetado (combo e Linha de Fogo)',
      () async {
    final gs = GameState()..specialLevels[ElementType.fire] = 1;
    final s = await _missions(gs, [
      MissionType.statusBlocks,
      MissionType.breakBlocks,
      MissionType.playRounds,
    ]);
    // Nevasca (vento × água): congela os 3 blocos ao redor do disparo.
    final near = [_block(3, 5), _block(5, 5), _block(4, 4)];
    final far = _block(0, 11);
    final game = await _game(gs, [_special(4, 5, ElementType.water), ...near, far]);
    _ballInside(game, 4, 5, ElementType.wind);
    final frozen = near.where((b) => b.status.frozen).length;
    expect(frozen, 3);
    expect(far.status.frozen, isFalse);
    expect(_progress(s, MissionType.statusBlocks), 3);

    // Linha de Fogo: cada bloco que sobrevive e fica em chamas conta.
    gs
      ..specialMeter = 1
      ..armedElement = ElementType.fire;
    final before = _progress(s, MissionType.statusBlocks);
    game.activateSpecial();
    for (var f = 0; f < 120 && game.fireWaveY != -1; f++) {
      game.update(1 / 60);
    }
    final burning = game.blocks.where((b) => b.status.burning).length;
    expect(burning, greaterThan(0));
    expect(_progress(s, MissionType.statusBlocks), before + burning);
  });
}
