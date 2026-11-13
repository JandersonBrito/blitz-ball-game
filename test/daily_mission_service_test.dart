import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/daily_mission.dart';
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
}
