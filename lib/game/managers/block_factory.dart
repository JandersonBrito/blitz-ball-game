import 'dart:math';
import 'package:flame/components.dart';
import '../components/block_component.dart';
import '../../models/element.dart';

final _rng = Random();

const List<ElementType> allElements = ElementType.values;
const List<ElementType> nonNeutralElements = [ElementType.fire, ElementType.water, ElementType.wind];

List<BlockComponent> generateRow(int level, ElementType dominantEl, int rowIndex) {
  final blocks = <BlockComponent>[];
  const cols = 9;
  const blockSize = BlockComponent.blockSize;

  for (int c = 0; c < cols; c++) {
    if (_rng.nextDouble() >= 0.55) continue;

    final r = _rng.nextDouble();
    final bool isBonus   = r < 0.08;
    final bool isGold    = !isBonus && r < 0.18;
    final bool isElemPow = !isBonus && !isGold && r < 0.24;
    final bool isTriple  = !isBonus && !isGold && !isElemPow && r < 0.31;

    ElementType el = ElementType.neutral;
    if (!isBonus && !isGold && !isElemPow && !isTriple) {
      el = _rng.nextDouble() < 0.6
          ? dominantEl
          : allElements[_rng.nextInt(allElements.length)];
    }

    int hp = 0;
    int maxHp = 0;
    if (!isBonus && !isElemPow && !isTriple) {
      hp = (level * (0.5 + _rng.nextDouble())).ceil();
      maxHp = hp;
    }

    BlockType type = BlockType.normal;
    if (isBonus)   type = BlockType.bonus;
    else if (isGold)    type = BlockType.gold;
    else if (isElemPow) type = BlockType.elemPower;
    else if (isTriple)  type = BlockType.triple;

    final elemPowerEl = isElemPow
        ? nonNeutralElements[_rng.nextInt(3)]
        : null;

    final goldValue = isGold ? (1 + level * 0.5).ceil() : 0;

    blocks.add(BlockComponent(
      position: Vector2(c * blockSize + 1, rowIndex * blockSize + 1),
      type: type,
      hp: hp,
      maxHp: maxHp,
      element: el,
      goldValue: goldValue,
      elemPowerEl: elemPowerEl,
    ));
  }

  // ensure at least one block
  if (blocks.isEmpty) {
    blocks.add(BlockComponent(
      position: Vector2(_rng.nextInt(9) * blockSize + 1, rowIndex * blockSize + 1),
      type: BlockType.normal,
      hp: level,
      maxHp: level,
      element: dominantEl,
    ));
  }

  return blocks;
}

List<BlockComponent> initBlocks(int level) {
  final dom = allElements[_rng.nextInt(allElements.length)];
  final blocks = <BlockComponent>[];
  for (int r = 0; r < 3; r++) {
    blocks.addAll(generateRow(level, dom, r));
  }
  return blocks;
}

List<BlockComponent> initBossStage(int level) {
  final el = nonNeutralElements[_rng.nextInt(3)];
  const bossCol = 4; // center of 9 cols (cols 4-5)
  const blockSize = BlockComponent.blockSize;
  final bossHp = level * 18;

  final blocks = <BlockComponent>[
    BlockComponent(
      position: Vector2(bossCol * blockSize + 1, 1),
      type: BlockType.boss,
      hp: bossHp,
      maxHp: bossHp,
      element: el,
      goldValue: (level * 8).ceil(),
      isBoss: true,
    ),
  ];

  // guard blocks on rows 2-3
  for (int c = 0; c < 9; c++) {
    if (c == bossCol || c == bossCol + 1) continue;
    if (_rng.nextDouble() < 0.65) {
      final hp = (level * (0.6 + _rng.nextDouble() * 0.6)).ceil();
      blocks.add(BlockComponent(
        position: Vector2(c * blockSize + 1, 2 * blockSize + 1),
        type: BlockType.normal,
        hp: hp,
        maxHp: hp,
        element: _rng.nextDouble() < 0.5 ? el : ElementType.neutral,
      ));
    }
    if (_rng.nextDouble() < 0.4) {
      final hp = (level * (0.4 + _rng.nextDouble() * 0.4)).ceil();
      blocks.add(BlockComponent(
        position: Vector2(c * blockSize + 1, 3 * blockSize + 1),
        type: BlockType.normal,
        hp: hp,
        maxHp: hp,
        element: ElementType.neutral,
      ));
    }
  }

  return blocks;
}
