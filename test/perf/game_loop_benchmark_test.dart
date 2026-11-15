// Benchmark do loop do jogo (update + render) num cenário pesado e fixo.
//
// Não roda no `flutter test` normal (tag `perf`, pulada em dart_test.yaml).
// Para rodar:
//   flutter test --tags perf --run-skipped test/perf
//
// Mede no host, em modo JIT: serve para comparar versões do código entre si,
// não para prever FPS no aparelho. O número real vem do modo profile no
// aparelho (ver o checklist do DevTools).
//
// Antes x depois: o arquivo só usa a API pública do jogo, então roda igual
// numa versão antiga. Ex.: `git worktree add ../ballz_antes <commit>`, copie
// este arquivo e o dart_test.yaml para lá e rode o mesmo comando nas duas.
//
// Colunas: objetos-bola em voo, acertos por segundo (carga), tempo de
// update/render só nos frames com bolas em voo, gravações e avisos à UI por
// segundo, e chamadas ao Canvas por frame (desenhos e total).
@Tags(['perf'])
library;

import 'dart:math';
import 'dart:ui' as ui;

import 'package:ballz_flutter/game/ballz_flame_game.dart';
import 'package:ballz_flutter/game/components/block_component.dart';
import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingState extends GameState {
  int saves = 0;

  /// Conta as gravações em vez de gravar: o custo real é o platform channel.
  @override
  Future<void> save() async => saves++;
}

class _TimedGame extends BallzFlameGame {
  _TimedGame({required super.gameState});

  final updateUs = <int>[];
  final renderUs = <int>[];
  bool measuring = false;
  int maxFlying = 0;
  final _sw = Stopwatch();

  /// Só frames com bolas em jogo entram na conta.
  bool get _sampling => measuring && phase == GamePhase.shooting;

  @override
  void update(double dt) {
    final sample = _sampling;
    _sw
      ..reset()
      ..start();
    super.update(dt);
    _sw.stop();
    if (!sample) return;
    updateUs.add(_sw.elapsedMicroseconds);
    final f = flyingObjects(this);
    if (f > maxFlying) maxFlying = f;
  }

  @override
  void render(ui.Canvas canvas) {
    final sample = _sampling;
    _sw
      ..reset()
      ..start();
    super.render(canvas);
    _sw.stop();
    if (sample) renderUs.add(_sw.elapsedMicroseconds);
  }

  /// Chamadas ao Canvas num frame: cada desenho vira trabalho na thread de
  /// raster (e, em geral, uma chamada à GPU).
  _CountingCanvas countOps() {
    final c = _CountingCanvas();
    super.render(c);
    return c;
  }
}

class _CountingCanvas implements ui.Canvas {
  int draws = 0;
  int total = 0;

  @override
  int getSaveCount() => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    total++;
    if (invocation.memberName.toString().contains('draw')) draws++;
    return null;
  }
}

/// Tabuleiro fixo de fase avançada: 7 linhas cheias nas colunas 0–7, com a
/// coluna 8 e a faixa de cima livres. As bolas sobem em zigue-zague pelo
/// corredor da direita e ficam presas quicando entre o teto e o topo dos
/// blocos: o pior caso real (a "bolada" no alto). Elementos misturados, blocos
/// de ouro e dois muros. HP alto para o cenário não esvaziar na medição.
List<BlockComponent> _board() {
  final rng = Random(42);
  final blocks = <BlockComponent>[];
  const s = BallzFlameGame.blockSize;
  Vector2 at(int c, int r) =>
      Vector2(c * s + 1, r * s + 1 + BallzFlameGame.topOffset);
  for (var r = 1; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      if (r == 4 && (c == 0 || c == 7)) continue; // muros
      final el = ElementType.values[rng.nextInt(4)];
      final gold = rng.nextDouble() < 0.15;
      final hp = 300 + rng.nextInt(400);
      blocks.add(BlockComponent(
        position: at(c, r),
        type: gold ? BlockType.gold : BlockType.normal,
        hp: hp,
        maxHp: hp + 100,
        element: el,
        goldValue: gold ? 6 : 0,
      ));
    }
  }
  for (final c in const [0, 7]) {
    blocks.add(BlockComponent(
      position: at(c, 4),
      type: BlockType.wall,
      hp: 5,
      maxHp: 5,
      element: ElementType.fire,
    ));
  }
  return blocks;
}

/// Objetos-bola em voo. Acesso dinâmico para o mesmo arquivo rodar na versão
/// antiga (lista de BallComponent) e na nova (BallPool).
int flyingObjects(BallzFlameGame g) {
  final d = g as dynamic;
  try {
    return d.balls.flyingCount as int;
  } catch (_) {}
  try {
    return (d.activeBalls as List).where((b) => (b as dynamic).active == true).length;
  } catch (_) {}
  return -1;
}

class _Scenario {
  final String name;
  final int balls;
  final bool prism;
  final bool fast;
  const _Scenario(this.name, this.balls, {this.prism = false, this.fast = false});
}

double _mean(List<int> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

int _p95(List<int> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  return s[(s.length * 0.95).floor().clamp(0, s.length - 1)];
}

void main() {
  const frames = 600; // 10 s a 60 FPS
  const warmup = 120;
  const frameDt = Duration(microseconds: 16667);
  const scenarios = [
    _Scenario('100 bolas', 100),
    _Scenario('300 bolas', 300),
    _Scenario('300 bolas, Prisma, 2x', 300, prism: true, fast: true),
  ];
  final report = StringBuffer()
    ..writeln()
    ..writeln('cenário | objetos em voo (máx) | acertos/s | '
        'update ms (média/p95) | render ms (média/p95) | saves/s | notify/s | '
        'draws/frame (chamadas ao canvas)');

  for (final sc in scenarios) {
    testWidgets(sc.name, (tester) async {
      SharedPreferences.setMockInitialValues({});
      final gs = _CountingState()..stage = 22;
      if (sc.prism) gs.starterBallsActive = true;
      if (sc.fast) {
        gs.upgrades['speed'] = 1;
        gs.fastForward = true;
      }
      var notifies = 0;
      gs.addListener(() => notifies++);

      final game = _TimedGame(gameState: gs);
      tester.view.physicalSize = const ui.Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: game),
      ));
      await tester.pump();

      game.blocks
        ..clear()
        ..addAll(_board());
      game.startWave();
      gs.ballCount = sc.balls;
      // 60° para a direita: entra no corredor da coluna 8.
      game.handlePointerPosition(Offset(game.originX + 100, game.floorY - 173));
      game.shoot();
      expect(game.phase, GamePhase.shooting);

      for (var i = 0; i < warmup; i++) {
        await tester.pump(frameDt);
      }
      final savesBefore = gs.saves;
      final notifiesBefore = notifies;
      final scoreBefore = gs.score;
      game.measuring = true;
      _CountingCanvas? ops;
      for (var i = 0; i < frames; i++) {
        await tester.pump(frameDt);
        if (i == frames ~/ 4) ops = game.countOps();
      }
      game.measuring = false;
      // Taxas por segundo real com bolas em voo (o que o jogador vê).
      final seconds = game.updateUs.length * frameDt.inMicroseconds / 1e6;

      // Deixa timers de gravação (missões etc.) dispararem antes do fim.
      await tester.pump(const Duration(seconds: 5));

      report.writeln('${sc.name} | ${game.maxFlying} | '
          '${((gs.score - scoreBefore) / seconds).toStringAsFixed(0)} | '
          '${(_mean(game.updateUs) / 1000).toStringAsFixed(2)} / '
          '${(_p95(game.updateUs) / 1000).toStringAsFixed(2)} | '
          '${(_mean(game.renderUs) / 1000).toStringAsFixed(2)} / '
          '${(_p95(game.renderUs) / 1000).toStringAsFixed(2)} | '
          '${((gs.saves - savesBefore) / seconds).toStringAsFixed(0)} | '
          '${((notifies - notifiesBefore) / seconds).toStringAsFixed(0)} | '
          '${ops!.draws} (${ops.total})');
      // ignore: avoid_print
      if (sc == scenarios.last) print(report);
    });
  }
}
