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

BlockComponent _block(int col, int row, {int hp = 100}) => BlockComponent(
      position: Vector2(col * _s + 1, row * _s + 1 + BallzFlameGame.topOffset),
      type: BlockType.normal,
      hp: hp,
      maxHp: hp,
      element: ElementType.neutral,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('fórmulas (config central)', () {
    test('dano cresce de forma linear', () {
      final d1 = ElementConfig.specialDamage(4, 1);
      final d2 = ElementConfig.specialDamage(4, 2);
      final d9 = ElementConfig.specialDamage(4, 9);
      final d10 = ElementConfig.specialDamage(4, 10);
      expect(d2 - d1, d10 - d9, reason: 'incremento constante');
    });

    test('custo cresce de forma exponencial', () {
      final r1 = ElementConfig.specialCost(10) / ElementConfig.specialCost(9);
      final r2 = ElementConfig.specialCost(20) / ElementConfig.specialCost(19);
      expect(r1, closeTo(ElementConfig.specialCostR, 0.02));
      expect(r2, closeTo(ElementConfig.specialCostR, 0.02));
    });

    test('a curva de dano acompanha a curva de HP dos blocos', () {
      // Modelo de renda: ouro por fase ≈ nº de blocos de ouro × valor médio
      // (block_factory: valor 1 + 0.25·fase; ~3 blocos de ouro por wave).
      // O jogador gasta metade no especial principal. O HP médio de um bloco
      // na fase s é ~s (factory: s × U(0.5, 1.5)).
      var gold = 0.0;
      var level = 0;
      var spent = 0.0;
      int? firstLevelStage;
      const ballDamage = 4; // Força no meio da tabela
      for (var s = 1; s <= 100; s++) {
        gold += 3 * (1 + 0.25 * s) * 2; // ~2 waves por fase
        while (level < ElementConfig.specialMaxLevel &&
            spent + ElementConfig.specialCost(level + 1) <= gold / 2) {
          spent += ElementConfig.specialCost(level + 1);
          level++;
          firstLevelStage ??= s;
        }
        if (level == 0) continue; // ainda juntando para o 1º nível
        final dmg = ElementConfig.specialDamage(ballDamage, level);
        final ratio = dmg / s; // HP médio ≈ s
        expect(ratio, inInclusiveRange(0.15, 30),
            reason: 'fase $s: nível $level, dano $dmg');
      }
      expect(firstLevelStage, isNotNull);
      expect(firstLevelStage!, lessThanOrEqualTo(20),
          reason: 'o 1º nível sai cedo o bastante');
      expect(level, greaterThanOrEqualTo(8),
          reason: 'até a fase 100 dá para evoluir bastante');
      expect(level, lessThan(ElementConfig.specialMaxLevel),
          reason: 'mas não chega no teto de graça');
    });
  });

  group('compra e medidor', () {
    test('buySpecial cobra o custo exponencial e sobe o nível', () {
      final gs = GameState()..gold = 10000;
      expect(gs.buySpecial(ElementType.fire), isTrue);
      expect(gs.specialLevel(ElementType.fire), 1);
      expect(gs.gold, 10000 - ElementConfig.specialCost(1));
      final before = gs.gold;
      expect(gs.buySpecial(ElementType.fire), isTrue);
      expect(gs.gold, before - ElementConfig.specialCost(2));
    });

    test('sem ouro não compra', () {
      final gs = GameState()..gold = 0;
      expect(gs.buySpecial(ElementType.fire), isFalse);
      expect(gs.specialLevel(ElementType.fire), 0);
    });

    test('100 acertos enchem o medidor; só carrega com especial comprado', () {
      final gs = GameState();
      gs.addSpecialHits(100);
      expect(gs.specialMeter, 0, reason: 'sem especial comprado: não carrega');
      gs.specialLevels[ElementType.fire] = 1;
      gs.addSpecialHits(40);
      expect(gs.specialMeter, closeTo(0.4, 1e-9));
      gs.addSpecialHits(59);
      expect(gs.specialMeter, closeTo(0.99, 1e-9));
      gs.addSpecialHits(1);
      expect(gs.specialMeter, 1.0);
      gs.addSpecialHits(500);
      expect(gs.specialMeter, 1.0, reason: 'satura em 1');
    });

    test('o poder do botão: o escolhido pelo jogador ou o de maior nível',
        () async {
      final gs = GameState()
        ..specialLevels[ElementType.fire] = 2
        ..specialLevels[ElementType.earth] = 5;
      final game = await _game(gs, [_block(0, 0)]);
      expect(game.specialElement, ElementType.earth,
          reason: 'sem elemento absorvido: o de maior nível');
      gs.selectSpecial(ElementType.fire);
      expect(game.specialElement, ElementType.fire, reason: 'o escolhido');
      gs.selectSpecial(ElementType.water); // não comprado: ignora
      expect(game.specialElement, ElementType.fire);
      gs.selectSpecial(ElementType.earth);
      expect(game.specialElement, ElementType.earth, reason: 'troca livre');
      expect(GameState().specialLevels.values.every((l) => l == 0), isTrue);
    });

    test('o anel recebe o progresso no mesmo frame do acerto, sem esperar o HUD',
        () async {
      final gs = GameState()..specialLevels[ElementType.fire] = 1;
      final wall = _block(4, 5, hp: 1000000);
      final game = await _game(gs, [wall]);
      var uiNotifies = 0;
      gs.addListener(() => uiNotifies++);
      final seen = <double>[];
      game.specialMeterProgress.addListener(
          () => seen.add(game.specialMeterProgress.value));

      game.balls.spawn(172, 330, 0.1, -550, 0, 10);
      for (var i = 0; i < 40 && wall.hp == 1000000; i++) {
        game.update(1 / 60);
      }
      expect(gs.specialMeter, closeTo(0.10, 1e-9));
      expect(game.specialMeterProgress.value, closeTo(0.10, 1e-9),
          reason: 'publicado no próprio frame do acerto');
      expect(seen, isNotEmpty);
      expect(seen.last, closeTo(0.10, 1e-9));
      // O aviso geral da UI continua limitado (10 Hz): o anel não depende dele.
      expect(uiNotifies, lessThanOrEqualTo(1));
    });

    test('uma rodada real: 100 acertos enchem o medidor e liberam o botão',
        () async {
      final gs = GameState()..specialLevels[ElementType.fire] = 1;
      final wall = _block(4, 5, hp: 1000000);
      final game = await _game(gs, [wall]);
      expect(game.canActivateSpecial, isFalse);
      // 99 bolas acertando: ainda não.
      game.balls.spawn(172, 330, 0.1, -550, 0, 99);
      for (var i = 0; i < 40 && wall.hp == 1000000; i++) {
        game.update(1 / 60);
      }
      expect(wall.maxHp - wall.hp, greaterThan(0));
      expect(gs.specialMeter, closeTo(0.99, 1e-9));
      expect(game.canActivateSpecial, isFalse);
      // A 100ª bola completa o medidor, sem nenhum elemento absorvido:
      // o botão usa o especial que o jogador tem (fogo).
      game.balls.spawn(172, 330, 0.1, -550, 0, 1);
      for (var i = 0; i < 40 && gs.specialMeter < 1; i++) {
        game.update(1 / 60);
      }
      expect(gs.specialMeter, 1.0);
      expect(game.specialElement, ElementType.fire);
      expect(game.canActivateSpecial, isTrue);
      game.activateSpecial();
      expect(gs.specialMeter, 0, reason: 'consumido ao usar');
    });
  });

  group('efeitos dos especiais', () {
    test('Linha de fogo: sobe de baixo para cima e atinge TODOS os blocos',
        () async {
      final gs = GameState()..specialLevels[ElementType.fire] = 3;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.fire;
      final low = _block(0, 10);
      final midL = _block(4, 6);
      final midR = _block(8, 6);
      final high = _block(2, 1);
      // Uma linha cheia, para provar que nenhuma coluna escapa.
      final fullRow = [for (var c = 0; c < 9; c++) _block(c, 8)];
      final all = [low, midL, midR, high, ...fullRow];
      final game = await _game(gs, all);

      expect(game.canActivateSpecial, isTrue);
      game.activateSpecial();
      expect(gs.specialMeter, 0, reason: 'medidor consumido');
      expect(game.fireWaveY, closeTo(game.floorY, 1),
          reason: 'a linha nasce no chão');
      for (final b in all) {
        expect(b.hp, 100, reason: 'nada acontece instantaneamente');
      }

      // Anota o frame em que cada bloco leva o dano.
      final hitFrame = <BlockComponent, int>{};
      var prevY = game.fireWaveY;
      for (var f = 1; f <= 120 && game.fireWaveY >= 0; f++) {
        game.update(1 / 60);
        if (game.fireWaveY >= 0) {
          expect(game.fireWaveY, lessThan(prevY), reason: 'só sobe');
          prevY = game.fireWaveY;
        }
        for (final b in all) {
          if (b.hp < 100) hitFrame.putIfAbsent(b, () => f);
        }
      }
      expect(game.fireWaveY, -1, reason: 'a linha termina no topo');
      expect(hitFrame.length, all.length, reason: 'todos os blocos atingidos');
      // Ordem visível: de baixo (linha 10) para cima (linha 1).
      expect(hitFrame[low]!, lessThan(hitFrame[fullRow[0]]!));
      expect(hitFrame[fullRow[0]]!, lessThan(hitFrame[midL]!));
      expect(hitFrame[midL], hitFrame[midR], reason: 'mesma linha, mesmo frame');
      expect(hitFrame[midL]!, lessThan(hitFrame[high]!));
      // Dano = dano da bola × nível, uma vez só por bloco, e todos em chamas.
      final dmg = ElementConfig.specialDamage(gs.baseDamage, 3);
      for (final b in all) {
        expect(b.hp, 100 - dmg, reason: 'dano único por bloco');
        expect(b.status.burning, isTrue, reason: 'ficam em chamas');
      }
    });

    test('Linha de fogo: o dano cresce com o nível e mata o que não aguenta',
        () async {
      Future<int> lostAtLevel(int level) async {
        final gs = GameState()..specialLevels[ElementType.fire] = level;
        gs
          ..specialMeter = 1
          ..armedElement = ElementType.fire;
        final tough = _block(4, 6, hp: 1000);
        final game = await _game(gs, [tough, _block(0, 6, hp: 1)]);
        game.activateSpecial();
        for (var f = 0; f < 120 && game.fireWaveY != -1; f++) {
          game.update(1 / 60);
        }
        expect(game.blocks.where((b) => b.maxHp == 1), isEmpty,
            reason: 'bloco fraco morreu e foi removido');
        return 1000 - tough.hp;
      }

      final l1 = await lostAtLevel(1);
      final l5 = await lostAtLevel(5);
      expect(l5, greaterThan(l1));
      expect(l5, 5 * l1, reason: 'linear no nível');
    });

    test('Rajada: lâminas cortam TODOS os blocos, uma vez cada', () async {
      final gs = GameState()..specialLevels[ElementType.wind] = 4;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.wind;
      // Tabuleiro cheio: 14 linhas × 9 colunas. Nenhum pode escapar.
      final all = [
        for (var r = 0; r < 14; r++)
          for (var c = 0; c < 9; c++) _block(c, r)
      ];
      final game = await _game(gs, all);
      expect(game.canActivateSpecial, isTrue);
      game.activateSpecial();
      expect(game.windElapsed, 0);
      for (final b in all) {
        expect(b.hp, 100, reason: 'nada acontece instantaneamente');
      }

      final hitFrame = <BlockComponent, int>{};
      for (var f = 1; f <= 240 && game.windElapsed >= 0; f++) {
        game.update(1 / 60);
        for (final b in all) {
          if (b.hp < 100) hitFrame.putIfAbsent(b, () => f);
        }
      }
      expect(game.windElapsed, -1, reason: 'as lâminas terminam');
      expect(hitFrame.length, all.length, reason: 'nenhum bloco escapou');

      final dmg = (ElementConfig.specialDamage(gs.baseDamage, 4) *
              ElementConfig.windGustDmg)
          .ceil();
      for (final b in all) {
        expect(b.hp, 100 - dmg, reason: 'dano único por bloco');
      }
      // De cima para baixo: a faixa de cima começa antes.
      expect(hitFrame[all.first]!, lessThan(hitFrame[all.last]!));
    });

    test('Rajada: as lâminas alternam a direção por faixa', () async {
      final gs = GameState()..specialLevels[ElementType.wind] = 4;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.wind;
      // Linha 0 (faixa 0, vai →) e linha 2 (faixa 1, vai ←): colunas 0 e 8.
      final r0l = _block(0, 0), r0r = _block(8, 0);
      final r2l = _block(0, 2), r2r = _block(8, 2);
      final all = [r0l, r0r, r2l, r2r];
      final game = await _game(gs, all);
      game.activateSpecial();
      final hitFrame = <BlockComponent, int>{};
      for (var f = 1; f <= 240 && game.windElapsed >= 0; f++) {
        game.update(1 / 60);
        for (final b in all) {
          if (b.hp < 100) hitFrame.putIfAbsent(b, () => f);
        }
      }
      expect(hitFrame[r0l]!, lessThan(hitFrame[r0r]!),
          reason: 'faixa 0 vai da esquerda para a direita');
      expect(hitFrame[r2r]!, lessThan(hitFrame[r2l]!),
          reason: 'faixa 1 vai da direita para a esquerda');
    });

    test('Rajada: o empurrão para o centro continua no fim da rodada',
        () async {
      final gs = GameState()..specialLevels[ElementType.wind] = 1;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.wind;
      final edge = _block(0, 8, hp: 1000000);
      final game = await _game(gs, [edge]);
      final x0 = edge.position.x;
      game.activateSpecial();
      game.forceReturn();
      for (var i = 0; i < 600 && game.phase == GamePhase.returning; i++) {
        game.update(1 / 60);
      }
      expect(edge.position.x, x0 + _s, reason: 'juntou 1 coluna ao centro');
    });

    test('Maré: onda circular a partir do lançamento, atinge todos os blocos',
        () async {
      final gs = GameState()..specialLevels[ElementType.water] = 2;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.water;
      // Mesma linha (6): centro mais perto do lançamento que as pontas.
      final center = _block(4, 6);
      final left = _block(0, 6);
      final right = _block(8, 6);
      final near = _block(4, 9); // quase em cima do ponto de lançamento
      final far = _block(1, 1); // canto de cima
      final all = [center, left, right, near, far];
      final game = await _game(gs, all);
      final originX = game.originX, originY = game.floorY;

      game.activateSpecial();
      expect(game.tideRadius, 0, reason: 'a onda nasce no ponto de lançamento');
      expect(game.tideOriginX, originX);
      expect(game.tideOriginY, originY);
      for (final b in all) {
        expect(b.hp, 100, reason: 'nada acontece instantaneamente');
      }

      final hitFrame = <BlockComponent, int>{};
      var prevR = game.tideRadius;
      for (var f = 1; f <= 120 && game.tideRadius >= 0; f++) {
        game.update(1 / 60);
        if (game.tideRadius >= 0) {
          expect(game.tideRadius, greaterThan(prevR), reason: 'só se expande');
          prevR = game.tideRadius;
        }
        for (final b in all) {
          if (b.hp < 100) hitFrame.putIfAbsent(b, () => f);
        }
      }
      expect(game.tideRadius, -1, reason: 'termina ao cobrir o tabuleiro');
      expect(hitFrame.length, all.length, reason: 'todos atingidos');

      // Radial, NÃO uma linha: na mesma linha, o do centro (mais perto do
      // ponto de lançamento) leva o dano antes das pontas.
      expect(hitFrame[center]!, lessThan(hitFrame[left]!));
      expect(hitFrame[center]!, lessThan(hitFrame[right]!));
      // E os mais próximos primeiro, sem importar a linha.
      expect(hitFrame[near]!, lessThan(hitFrame[center]!));
      expect(hitFrame[center]!, lessThan(hitFrame[far]!));

      // Dano único por bloco = fração do dano do especial.
      final dmg = (ElementConfig.specialDamage(gs.baseDamage, 2) *
              ElementConfig.tideDmgMult)
          .ceil();
      for (final b in all) {
        expect(b.hp, 100 - dmg, reason: 'dano único por bloco');
      }
      // O empurrão e o cooldown continuam valendo.
      expect(gs.tideCooldown, ElementConfig.tideCooldown(2));
    });

    test('Maré: empurra tudo 1 linha para trás e entra em cooldown', () async {
      final gs = GameState()..specialLevels[ElementType.water] = 1;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.water;
      final b = _block(2, 8, hp: 1000);
      final game = await _game(gs, [b]);
      final y0 = b.position.y;

      game.activateSpecial();
      expect(gs.tideCooldown, ElementConfig.tideCooldown(1));

      // Fim da rodada: sobe 1 (maré) e desce 1 (descida normal) → y0.
      game.forceReturn();
      for (var i = 0; i < 600 && game.phase == GamePhase.returning; i++) {
        game.update(1 / 60);
      }
      expect(b.position.y, y0);
      expect(gs.tideCooldown, ElementConfig.tideCooldown(1) - 1,
          reason: 'cooldown desconta por turno');

      // Com cooldown, o botão não ativa de novo.
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.water;
      expect(game.canActivateSpecial, isFalse);
    });

    test('Impacto da terra: a rocha cai e dá dano % do HP atual', () async {
      final gs = GameState()..specialLevels[ElementType.earth] = 5;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.earth;
      final big = _block(4, 9, hp: 10000);
      final game = await _game(gs, [big]);
      game.activateSpecial();
      expect(game.quakeT, greaterThanOrEqualTo(0), reason: 'animação em curso');
      expect(big.hp, 10000, reason: 'a rocha ainda está caindo');
      final pct = ElementConfig.earthPct(5);
      for (var f = 0; f < 120 && game.quakeT >= 0; f++) {
        game.update(1 / 60);
      }
      expect(game.quakeT, -1, reason: 'a animação termina');
      expect(big.hp, 10000 - (10000 * pct).ceil(), reason: 'dano único');
    });

    test('Impacto da terra: só atinge a área 3×3 do alvo', () async {
      final gs = GameState()..specialLevels[ElementType.earth] = 5;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.earth;
      final anchor = _block(4, 9, hp: 10000);
      final near = _block(5, 9, hp: 1000);
      final far = _block(0, 2, hp: 1000);
      final game = await _game(gs, [anchor, near, far]);
      game.activateSpecial();
      for (var f = 0; f < 120 && game.quakeT >= 0; f++) {
        game.update(1 / 60);
      }
      expect(near.hp, lessThan(1000));
      expect(far.hp, 1000);
    });

    test('Descarga: o raio salta de bloco em bloco, um por passo', () async {
      final gs = GameState()..specialLevels[ElementType.lightning] = 4;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.lightning;
      final jumps = ElementConfig.lightningJumps(4); // 4
      // Uma fileira de blocos; o de mais HP é o alvo inicial.
      final row = [
        for (var c = 0; c < 6; c++) _block(c, 6, hp: c == 0 ? 500 : 400)
      ];
      final game = await _game(gs, row);
      game.activateSpecial();
      expect(game.boltClock, greaterThanOrEqualTo(0));
      expect(row.where((b) => b.hp < b.maxHp).length, 1,
          reason: 'só o primeiro golpe é imediato');
      expect(game.boltCount, 2, reason: 'céu + primeiro alvo');

      var maxHitSoFar = 1;
      for (var f = 0; f < 240 && game.boltClock >= 0; f++) {
        game.update(1 / 60);
        final hit = row.where((b) => b.hp < b.maxHp).length;
        expect(hit - maxHitSoFar, lessThanOrEqualTo(1),
            reason: 'no máximo 1 salto por passo de 0,07 s');
        maxHitSoFar = hit;
      }
      expect(game.boltClock, -1, reason: 'o raio esmaece e some');
      expect(row.where((b) => b.hp < b.maxHp).length, jumps,
          reason: 'um bloco por salto, sem repetir');
      final dmg = ElementConfig.specialDamage(1, 4);
      for (final b in row.where((b) => b.hp < b.maxHp)) {
        expect(b.maxHp - b.hp, greaterThanOrEqualTo(1));
        expect(b.maxHp - b.hp, lessThanOrEqualTo(dmg * 4), reason: 'dano único');
      }
    });

    test('avisa o nome do especial ao disparar', () async {
      final gs = GameState()..specialLevels[ElementType.fire] = 1;
      gs
        ..specialMeter = 1
        ..armedElement = ElementType.fire;
      final game = await _game(gs, [_block(4, 9, hp: 100)]);
      game.activateSpecial();
      expect(gs.announceKey, 'sp:${ElementType.fire.index}');
    });

    test('rewarded ativa na hora, uma vez por partida', () async {
      final gs = GameState()..specialLevels[ElementType.fire] = 2;
      final b = _block(4, 9, hp: 500);
      final game = await _game(gs, [b]);
      expect(gs.specialMeter, 0);
      game.activateSpecialViaAd();
      expect(gs.specialAdUsed, isTrue);
      expect(game.fireWaveY, greaterThanOrEqualTo(0),
          reason: 'disparou sem medidor');
      for (var f = 0; f < 120 && game.fireWaveY != -1; f++) {
        game.update(1 / 60);
      }
      expect(b.hp, lessThan(500), reason: 'a linha atingiu o bloco');
      final hpAfter = b.hp;
      game.activateSpecialViaAd();
      expect(game.fireWaveY, -1, reason: 'segunda vez não roda');
      expect(b.hp, hpAfter);
      gs.reset();
      expect(gs.specialAdUsed, isFalse, reason: 'nova partida libera de novo');
    });
  });
}
