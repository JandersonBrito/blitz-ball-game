import 'dart:math';
import 'package:flame/components.dart' show Vector2;
import '../../models/element.dart';
import '../status/block_status.dart';

enum BlockType { normal, bonus, gold, special, triple, boss, wall, powerup, bomb }

/// Power-ups não elementais coletáveis no tabuleiro.
enum PowerUpKind {
  /// Bolas atravessam N blocos antes de ricochetear.
  pierce,

  /// Bolas maiores: acertam mais blocos.
  giant,

  /// Par de portais que teletransporta as bolas.
  portal,

  /// Puxa as bolas para um ponto por alguns segundos.
  blackhole,

  /// Muralha no fundo: segura uma descida.
  wall,

  /// Mira estendida: mostra mais ricochetes por alguns turnos.
  aim,

  /// Dobra as moedas da rodada atual e da próxima.
  gold2x,

  /// Ímã: coleta todas as moedas e bolas extras do tabuleiro.
  magnet,
}

/// Bloco do tabuleiro. Só dados: quem desenha é o GameRenderer (atlas em lote)
/// e quem colide é a física do jogo, pelo grid. Não é um componente do Flame:
/// Transform2D, hitbox e ciclo de vida custavam memória e CPU sem uso.
class BlockComponent {
  BlockComponent({
    required this.position,
    required this.type,
    required this.hp,
    required this.maxHp,
    required this.element,
    this.goldValue = 0,
    this.charges = 0,
    this.powerUp,
    this.isBoss = false,
  }) : serial = ++_lastSerial,
       size = isBoss
            ? Vector2(blockSize * 2, blockSize * 2)
            : Vector2(blockSize, blockSize);

  static const double blockSize = 38.0;

  /// Canto superior esquerdo, em pixels lógicos.
  final Vector2 position;
  final Vector2 size;
  final BlockType type;
  int hp;
  int maxHp;
  final ElementType element;
  int goldValue;

  /// Passagens restantes de um bloco especial ([BlockType.special]) ou
  /// turnos até a bomba ([BlockType.bomb]) explodir.
  int charges;

  /// Id da última onda de fogo que atingiu este bloco (0 = nenhuma): cada
  /// bloco leva dano uma vez por onda, sem lista auxiliar.
  int fireWaveId = 0;

  /// O mesmo para a onda da Maré (separado: as duas podem coexistir).
  int tideWaveId = 0;

  /// E para as lâminas do Vento.
  int windWaveId = 0;

  /// Qual power-up este coletável dá ([BlockType.powerup]).
  final PowerUpKind? powerUp;
  final bool isBoss;

  /// Identificador único do bloco na partida. As bolas guardam o serial do
  /// último especial tocado ([BallPool.lastSpecial]) para gastar exatamente
  /// 1 carga por passagem, e não 1 por substep.
  final int serial;
  static int _lastSerial = 0;

  /// Status por turno (chamas, ácido, congelado), processados no fim da rodada.
  final BlockStatus status = BlockStatus();

  /// Próximo bloco na mesma célula do grid: lista ligada, sem alocação.
  BlockComponent? nextInCell;

  /// Célula no grid (-1 = fora do grid ou bloco grande).
  int gridCell = -1;

  bool get isAlive => hp > 0;
  double get hpRatio => maxHp > 0 ? hp / maxHp : 1.0;

  // shake state
  static const double _shakeDuration = 0.22;
  double _shakeTimer = 0;
  double shakeOffsetX = 0;
  double shakeOffsetY = 0;

  void triggerShake() {
    _shakeTimer = _shakeDuration;
  }

  void updateShake(double dt) {
    if (_shakeTimer <= 0) return;
    _shakeTimer = max(0, _shakeTimer - dt);
    final fade = _shakeTimer / _shakeDuration;
    final t = _shakeTimer * 90;
    shakeOffsetX = sin(t) * 3.5 * fade;
    shakeOffsetY = sin(t * 1.3) * 2.0 * fade;
  }

  void takeDamage(int dmg) {
    hp = max(0, hp - dmg);
  }
}
