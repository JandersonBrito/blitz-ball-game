import 'package:ballz_flutter/services/ad_load_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('não carrega durante a jogada; carrega quando ela acaba',
      (tester) async {
    var loads = 0;
    var playing = true;
    final gate = AdLoadGate(() => loads++, isBlocked: () => playing);

    gate.request();
    expect(loads, 0);
    expect(gate.pending, isTrue);

    playing = false;
    gate.flush();
    expect(loads, 1);
    expect(gate.pending, isFalse);
    gate.flush();
    expect(loads, 1, reason: 'nada pendente');
  });

  testWidgets('falha tenta de novo com espera crescente, fora da jogada',
      (tester) async {
    var loads = 0;
    var playing = false;
    final gate = AdLoadGate(() => loads++, isBlocked: () => playing);

    gate.request();
    expect(loads, 1);
    gate.failed();
    await tester.pump(const Duration(seconds: 29));
    expect(loads, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(loads, 2, reason: 'nova tentativa em 30 s');

    gate.failed();
    playing = true;
    await tester.pump(const Duration(seconds: 61));
    expect(loads, 2, reason: 'a nova tentativa espera a jogada');
    expect(gate.pending, isTrue);
    playing = false;
    gate.flush();
    expect(loads, 3);

    gate.loaded();
    expect(gate.failures, 0);
    expect(AdLoadGate.backoff(1), const Duration(seconds: 30));
    expect(AdLoadGate.backoff(3), const Duration(seconds: 120));
    expect(AdLoadGate.backoff(9), const Duration(minutes: 5));
  });
}
