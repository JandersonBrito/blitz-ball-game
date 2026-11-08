import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ouro dos blocos aplica o multiplicador e conta por fase', () {
    final gs = GameState();
    gs.earnGold(5);
    gs.earnGold(5, multiplier: 2);
    expect(gs.gold, 15);
    expect(gs.stageGoldEarned, 15);

    gs.addGold(1000); // compra na loja não conta como ouro da fase
    expect(gs.gold, 1015);
    expect(gs.stageGoldEarned, 15);

    gs.advanceStage();
    expect(gs.stageGoldEarned, 0);
    expect(gs.gold, 1015);
  });
}
