import 'dart:math';
import 'package:flame/components.dart' show Vector2;
import '../../models/element.dart';
import '../status/block_status.dart';

enum BlockType { normal, bonus, gold, elemPower, triple, boss, wall }

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
    this.elemPowerEl,
    this.isBoss = false,
  }) : size = isBoss
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
  final ElementType? elemPowerEl;
  final bool isBoss;

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
