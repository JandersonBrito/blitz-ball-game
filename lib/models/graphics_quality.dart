/// Qualidade gráfica escolhida nas configurações (ou reduzida sozinha pelo
/// ajuste automático).
enum GraphicsQuality { low, medium, high }

/// O que cada nível de qualidade liga. Só muda o visual: dano, física e
/// recompensas são iguais em qualquer nível.
class QualityProfile {
  const QualityProfile({
    required this.maxParticles,
    required this.particlesPerBurst,
    required this.trailLength,
    required this.maxTrailBalls,
    required this.glow,
  });

  /// Limite global de partículas vivas ao mesmo tempo.
  final int maxParticles;

  /// Partículas por bloco quebrado, antes do corte por carga.
  final int particlesPerBurst;

  /// Cópias esmaecidas atrás de cada bola (0 = sem rastro).
  final int trailLength;

  /// Com mais bolas em voo que isto, o rastro some: tela cheia já basta.
  final int maxTrailBalls;

  /// Halo das bolas e pulso do boss (já desenhados no atlas, sem blur).
  final bool glow;

  static const low = QualityProfile(
    maxParticles: 24,
    particlesPerBurst: 3,
    trailLength: 0,
    maxTrailBalls: 0,
    glow: false,
  );

  static const medium = QualityProfile(
    maxParticles: 96,
    particlesPerBurst: 6,
    trailLength: 0,
    maxTrailBalls: 0,
    glow: true,
  );

  static const high = QualityProfile(
    maxParticles: 240,
    particlesPerBurst: 10,
    trailLength: 4,
    maxTrailBalls: 80,
    glow: true,
  );

  static QualityProfile of(GraphicsQuality q) => switch (q) {
        GraphicsQuality.low => low,
        GraphicsQuality.medium => medium,
        GraphicsQuality.high => high,
      };
}
