import 'package:ballz_flutter/game/managers/game_state.dart';
import 'package:ballz_flutter/models/ball_skin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('bolas iniciais', () {
    test('sem o pacote começa com 1 bola', () {
      final gs = GameState();
      expect(gs.initialBalls, 1);
      gs.startWave();
      expect(gs.ballCount, 1);
    });

    test('com o pacote começa com 4 bolas', () {
      final gs = GameState()..starterBallsActive = true;
      expect(gs.initialBalls, 4);
      gs.startWave();
      expect(gs.ballCount, 4);
    });

    test('o bônus soma com o upgrade de bolas iniciais', () {
      final gs = GameState()..upgrades['balls'] = 5; // máximo: 13 bolas
      expect(gs.initialBalls, 13);
      gs.starterBallsActive = true;
      expect(gs.initialBalls, 16);
    });

    test('vale ao avançar de fase e ao recomeçar a partida', () {
      final gs = GameState()..starterBallsActive = true;
      gs.advanceStage();
      expect(gs.ballCount, 4);
      gs.ballCount = 20;
      gs.reset();
      expect(gs.ballCount, 4);
    });

    test('o crescimento por rodada não muda com o pacote', () {
      final gs = GameState()..starterBallsActive = true;
      gs.startWave();
      gs.incrementBallCount();
      gs.incrementBallCount();
      expect(gs.ballCount, 6); // 4 iniciais + 2 de blocos bônus
    });

    test('comprar no menu atualiza a contagem mostrada', () {
      final gs = GameState()..startWave();
      gs.setStarterBalls(true, inMenu: true);
      expect(gs.ballCount, 4);
    });

    test('comprar no meio da fase não mexe nas bolas em jogo', () {
      final gs = GameState()..startWave();
      gs.incrementBallCount(); // 2 bolas
      gs.setStarterBalls(true, inMenu: false);
      expect(gs.ballCount, 2);
      gs.startWave();
      expect(gs.ballCount, 4);
    });
  });

  group('skin Prisma', () {
    test('liberada e selecionada ao comprar; some se o pacote for revogado', () {
      final gs = GameState();
      expect(gs.activeSkin, BallSkin.classic);
      gs.setStarterBalls(true, inMenu: true);
      expect(gs.activeSkin, BallSkin.prism);
      gs.setStarterBalls(false, inMenu: true);
      expect(gs.activeSkin, BallSkin.classic);
      expect(gs.initialBalls, 1);
    });
  });

  test('oferta aparece só depois da 3ª partida e uma única vez', () {
    final gs = GameState();
    gs.setGameOver();
    gs.setGameOver();
    expect(gs.shouldOfferStarter, isFalse);
    gs.setGameOver();
    expect(gs.shouldOfferStarter, isTrue);
    gs.markStarterOfferSeen();
    expect(gs.shouldOfferStarter, isFalse);
  });
}
