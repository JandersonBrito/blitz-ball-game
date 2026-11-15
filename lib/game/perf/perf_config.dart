/// Limites de performance do jogo, num lugar só.
abstract final class PerfConfig {
  /// Acima deste número de bolas os tiros saem agrupados: cada bola carrega
  /// um peso (multiplicador) e o dano total da rodada continua o mesmo, com
  /// menos objetos na física e na tela.
  static const int ballGroupThreshold = 100;

  /// Teto de objetos-bola na rodada. Grupos que quebram um bloco podem se
  /// dividir (parte quica, parte passa); acima disto o grupo segue inteiro.
  static const int maxBallObjects = ballGroupThreshold * 2;

  /// Passo fixo da física (s). A 120 Hz a bola anda ~4,6 px por passo.
  static const double fixedDt = 1 / 120;

  /// Deslocamento máximo da bola por substep (px). Com raio 5, nenhuma bola
  /// atravessa bloco nem quina, nem no 2x.
  static const double maxTravelPerSubstep = 2.5;

  /// Teto de passos por frame: abaixo de ~8 FPS o jogo desacelera em vez de
  /// travar tentando recuperar o tempo perdido.
  static const int maxStepsPerFrame = 16;

  /// Maior dt aceito por frame (s). Pausas maiores (GC, app em segundo plano)
  /// não viram um salto na simulação.
  static const double maxFrameDt = 0.1;

  /// Intervalo mínimo entre avisos ao HUD durante a jogada (s).
  static const double uiNotifyInterval = 0.1;

  /// Durante a jogada o progresso é gravado no máximo a cada N segundos; o
  /// fim da rodada e o app indo para segundo plano gravam na hora.
  static const double saveInterval = 2.0;

  /// FPS mínimo antes de o ajuste automático baixar a qualidade.
  static const double minFps = 45;

  /// O mesmo, com o limite de 30 FPS ligado.
  static const double minFpsLocked = 22.5;
}
