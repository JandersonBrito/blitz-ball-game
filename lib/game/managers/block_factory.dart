import 'dart:math';
import 'package:flame/components.dart';
import '../components/block_component.dart';
import '../../models/element.dart';

final _rng = Random();

const List<ElementType> allElements = ElementType.values;
const List<ElementType> nonNeutralElements = [ElementType.fire, ElementType.water, ElementType.wind];

// Layout patterns: lists of columns that WILL have blocks.
// Each pattern leaves 1-2 intentional corridor gaps for ball navigation.
const _layoutPatterns = [
  [0, 1, 2, 3, 4, 5, 6],   // open right edge — ball goes around right
  [2, 3, 4, 5, 6, 7, 8],   // open left edge  — ball goes around left
  [0, 1, 3, 4, 5, 7, 8],   // two gaps (cols 2 & 6) — two shooting lanes
  [1, 2, 3, 5, 6, 7, 8],   // center corridor at col 4
  [0, 1, 2, 4, 5, 6, 8],   // gaps at cols 3 & 7
  [1, 2, 4, 5, 6, 7],      // two clusters with edge + center gap
];

List<BlockComponent> generateRow(int level, ElementType dominantEl, int rowIndex) {
  final blocks = <BlockComponent>[];
  const blockSize = BlockComponent.blockSize;

  // Pick a layout pattern — creates predictable corridors for ball chaining
  final activeCols = _layoutPatterns[_rng.nextInt(_layoutPatterns.length)];

  for (final c in activeCols) {
    // 80% fill density within chosen columns (up from ~45% random)
    if (_rng.nextDouble() >= 0.80) continue;

    final r = _rng.nextDouble();
    final bool isBonus   = r < 0.08;
    final bool isGold    = !isBonus && r < 0.28;
    final bool isElemPow = !isBonus && !isGold && r < 0.34;
    final bool isTriple  = !isBonus && !isGold && !isElemPow && r < 0.48;

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
    if (isBonus)        type = BlockType.bonus;
    else if (isGold)    type = BlockType.gold;
    else if (isElemPow) type = BlockType.elemPower;
    else if (isTriple)  type = BlockType.triple;

    final elemPowerEl = isElemPow ? nonNeutralElements[_rng.nextInt(3)] : null;
    final goldValue   = isGold ? (1 + level * 0.5).ceil() : 0;

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
    final c = activeCols[_rng.nextInt(activeCols.length)];
    blocks.add(BlockComponent(
      position: Vector2(c * blockSize + 1, rowIndex * blockSize + 1),
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

  // Boss at row 1 (shifted down one row to allow guard blocks above)
  final blocks = <BlockComponent>[
    BlockComponent(
      position: Vector2(bossCol * blockSize + 1, blockSize + 1),
      type: BlockType.boss,
      hp: bossHp,
      maxHp: bossHp,
      element: el,
      goldValue: (level * 8).ceil(),
      isBoss: true,
    ),
  ];

  // Surround boss on all 4 sides
  // Boss occupies cols 4-5, rows 1-2 (2x2 blocks)
  BlockComponent guard(int col, int row) {
    final hp = (level * (0.5 + _rng.nextDouble() * 0.5)).ceil();
    return BlockComponent(
      position: Vector2(col * blockSize + 1, row * blockSize + 1),
      type: BlockType.normal,
      hp: hp,
      maxHp: hp,
      element: _rng.nextDouble() < 0.5 ? el : ElementType.neutral,
    );
  }

  // Top row (row 0): cols 3–6
  for (int c = 3; c <= 6; c++) blocks.add(guard(c, 0));
  // Left side (col 3): rows 1–2
  for (int r = 1; r <= 2; r++) blocks.add(guard(3, r));
  // Right side (col 6): rows 1–2
  for (int r = 1; r <= 2; r++) blocks.add(guard(6, r));
  // Bottom row (row 3): cols 3–6
  for (int c = 3; c <= 6; c++) blocks.add(guard(c, 3));

  return blocks;
}
