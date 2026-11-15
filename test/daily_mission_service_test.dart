import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/app_settings.dart';
import 'package:ballz_flutter/models/daily_mission.dart';
import 'package:ballz_flutter/models/element.dart';
import 'package:ballz_flutter/models/l10n.dart';
import 'package:ballz_flutter/services/daily_mission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gera 3 missões, conta progresso e paga recompensas', () async {
    SharedPreferences.setMockInitialValues({});
    final gs = GameState()..stage = 10;
    final s = DailyMissionService.instance;
    await s.load(gs);

    final ms = s.missions;
    expect(ms.length, 3);
    expect(ms.map((m) => m.type).toSet().length, 3);
    expect(ms.map((m) => m.difficulty).toList(), MissionDifficulty.values);
    // sem upgrade de crítico, a missão de crítico não aparece
    expect(ms.any((m) => m.type == MissionType.critHits), isFalse);

    for (final m in ms) {
      expect(s.claim(m), 0); // ainda não concluída
      s.track(m.type, m.target + 50);
      expect(m.progress, m.target);
      expect(s.justCompleted, m);
    }
    expect(s.claimableCount, 3);

    final before = gs.gold;
    final total = ms.fold<int>(0, (a, m) => a + s.claim(m));
    expect(gs.gold, before + total);
    expect(s.claim(ms.first), 0); // não paga duas vezes

    expect(s.bonusClaimable, isTrue);
    final bonus = s.claimBonus();
    expect(bonus, greaterThan(0));
    expect(s.claimBonus(), 0);
    expect(s.claimableCount, 0);

    // estado salvo é recarregado igual
    s.flush();
    await Future<void>.delayed(Duration.zero);
    await s.load(gs);
    expect(s.missions.every((m) => m.claimed), isTrue);
    expect(s.bonusClaimed, isTrue);
  });

  test('backup do mesmo dia restaura resgates; de outro dia é ignorado', () async {
    SharedPreferences.setMockInitialValues({});
    final gs = GameState()..stage = 5;
    final s = DailyMissionService.instance;
    await s.load(gs);
    final m = s.missions.first;
    expect(m.progress, 0);
    s.track(m.type, m.target);
    expect(s.claim(m), greaterThan(0));
    final code = gs.exportBackupCode();
    final goldAfterClaim = gs.gold;

    // simula reinstalação: estado de missões zerado do dia
    final fresh = Map<String, dynamic>.from(s.exportState())
      ..['m'] = [
        for (final x in s.missions)
          (x.toJson()..['p'] = 0..['c'] = false)
      ];
    expect(s.applyBackup(fresh), isTrue);
    expect(s.missions.first.claimable, isFalse);

    expect(gs.applyBackupCode(code), isTrue);
    expect(gs.gold, goldAfterClaim);
    expect(s.missions.first.claimed, isTrue);
    expect(s.claim(s.missions.first), 0);

    // backup de outro dia não mexe nas missões de hoje
    final old = Map<String, dynamic>.from(s.exportState())
      ..['day'] = 20000101
      ..['m'] = [
        for (final x in s.missions)
          (x.toJson()..['c'] = false)
      ];
    expect(s.applyBackup(old), isFalse);
    expect(s.missions.first.claimed, isTrue);
  });

  group('novas missões (elementos)', () {
    test('sorteio respeita o que o jogador já tem', () {
      // Jogador novo: sem crítico, sem especial; Codex vazio.
      final fresh = GameState();
      var pool = DailyMissionService.poolFor(fresh);
      expect(pool, isNot(contains(MissionType.advantageHits)),
          reason: 'triângulo de vantagem não existe mais');
      expect(pool, isNot(contains(MissionType.critHits)));
      expect(pool, isNot(contains(MissionType.useSpecials)),
          reason: 'sem especial comprado');
      for (final t in [
        MissionType.triggerCombos,
        MissionType.absorbElements,
        MissionType.collectPowerUps,
        MissionType.statusBlocks,
        MissionType.discoverCombos,
      ]) {
        expect(pool, contains(t), reason: '$t disponível para todos');
      }

      // Com especial comprado entra a missão de usar o poder.
      final owner = GameState()..specialLevels[ElementType.fire] = 1;
      expect(DailyMissionService.poolFor(owner), contains(MissionType.useSpecials));

      // Codex quase completo: não sorteia descoberta impossível.
      final almostDone = GameState()
        ..discoveredCombos = (1 << DailyMissionService.comboTotal) - 1 - 0x3;
      expect(almostDone.discoveredComboCount, 23);
      expect(DailyMissionService.poolFor(almostDone),
          isNot(contains(MissionType.discoverCombos)),
          reason: 'só faltam 2 e a meta difícil é 3');
      final complete = GameState()
        ..discoveredCombos = (1 << DailyMissionService.comboTotal) - 1;
      expect(DailyMissionService.poolFor(complete),
          isNot(contains(MissionType.discoverCombos)));

      // Sem GameState (testes/backup): nada que dependa dele.
      pool = DailyMissionService.poolFor(null);
      expect(pool, isNot(contains(MissionType.useSpecials)));
      expect(pool, isNot(contains(MissionType.discoverCombos)));
    });

    test('toda missão tem meta positiva e crescente (fácil ≤ média ≤ difícil)',
        () {
      for (final t in MissionType.values) {
        for (final stage in [1, 10, 50]) {
          final e = DailyMissionService.targetFor(t, MissionDifficulty.easy, stage);
          final m = DailyMissionService.targetFor(t, MissionDifficulty.medium, stage);
          final h = DailyMissionService.targetFor(t, MissionDifficulty.hard, stage);
          expect(e, greaterThan(0), reason: '$t');
          expect(m, greaterThanOrEqualTo(e), reason: '$t');
          expect(h, greaterThanOrEqualTo(m), reason: '$t');
        }
      }
    });

    test('a ordem do enum salvo não mudou: tipos novos só no fim', () {
      expect(MissionType.values.sublist(0, 7), [
        MissionType.breakBlocks,
        MissionType.earnGold,
        MissionType.clearStages,
        MissionType.collectBalls,
        MissionType.advantageHits,
        MissionType.critHits,
        MissionType.playRounds,
      ]);
    });

    test('todas as missões têm descrição nos 4 idiomas, com a meta', () {
      for (final lang in AppLanguage.values) {
        final l = L10n(lang);
        for (final t in MissionType.values) {
          for (final n in [1, 7]) {
            final text = l.missionDesc(t, n);
            expect(text, isNotEmpty, reason: '$t $lang');
            if (n == 7 && t != MissionType.clearStages) {
              expect(text, contains('7'), reason: '$t $lang mostra a meta');
            }
          }
        }
      }
    });

    test('missão salva de antes (tipo antigo) continua carregando', () {
      final old = DailyMission.fromJson(
          {'t': 0, 'd': 0, 'tg': 30, 'r': 50, 'p': 12, 'c': false});
      expect(old?.type, MissionType.breakBlocks);
      expect(old?.progress, 12);
      final future = DailyMission.fromJson(
          {'t': 99, 'd': 0, 'tg': 30, 'r': 50, 'p': 0, 'c': false});
      expect(future, isNull, reason: 'tipo desconhecido é ignorado');
    });
  });
}
