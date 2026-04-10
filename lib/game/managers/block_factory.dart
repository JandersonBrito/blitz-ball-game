import 'dart:math';
import 'package:flame/components.dart';
import '../components/block_component.dart';
import '../../models/element.dart';

final _rng = Random();

const List<ElementType> allElements = ElementType.values;
const List<ElementType> nonNeutralElements = [ElementType.fire, ElementType.water, ElementType.wind];

// Wall barrier patterns: columns that WILL have wall blocks.
// Each pattern leaves 2 gaps (single-column) spread across the 9-column grid.
const _wallBarrierPatterns = [
  [0, 1, 2, 4, 5, 6, 8],   // gaps at cols 3 and 7
  [0, 1, 3, 4, 5, 7, 8],   // gaps at cols 2 and 6
  [0, 2, 3, 4, 6, 7, 8],   // gaps at cols 1 and 5
  [1, 2, 3, 5, 6, 7, 8],   // gaps at cols 0 and 4
  [0, 1, 2, 3, 5, 6, 7, 8], // single gap at col 4 (center)
  [0, 1, 3, 4, 6, 7, 8],   // gaps at cols 2 and 5
];

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

List<BlockComponent> generateRow(int level, ElementType dominantEl, int rowIndex, {bool isPreBoss = false}) {
  final blocks = <BlockComponent>[];
  const blockSize = BlockComponent.blockSize;

  // Pick a layout pattern — creates predictable corridors for ball chaining
  final activeCols = _layoutPatterns[_rng.nextInt(_layoutPatterns.length)];

  for (final c in activeCols) {
    // 80% fill density within chosen columns (up from ~45% random)
    if (_rng.nextDouble() >= 0.80) continue;

    final r = _rng.nextDouble();
    // Pre-boss stage: higher chance of bonus ball (12%) and gold (50%)
    final double bonusThreshold = isPreBoss ? 0.12 : 0.08;
    final double goldThreshold  = isPreBoss ? 0.50 : 0.28;
    final bool isBonus   = r < bonusThreshold;
    final bool isGold    = !isBonus && r < goldThreshold;
    final bool isElemPow = !isBonus && !isGold && r < (isPreBoss ? 0.56 : 0.34);
    final bool isTriple  = !isBonus && !isGold && !isElemPow && r < (isPreBoss ? 0.70 : 0.48);

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
    final goldValue   = isGold ? (1 + level * 0.25).ceil() : 0;

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

List<BlockComponent> generateWallBarrier(int rowIndex, int level) {
  const blockSize = BlockComponent.blockSize;
  final pattern = _wallBarrierPatterns[_rng.nextInt(_wallBarrierPatterns.length)];
  final hp = 1 + (level ~/ 5);
  // Each barrier row shares the same element
  final el = nonNeutralElements[_rng.nextInt(nonNeutralElements.length)];
  return pattern.map((c) => BlockComponent(
    position: Vector2(c * blockSize + 1, rowIndex * blockSize + 1),
    type: BlockType.wall,
    hp: hp,
    maxHp: hp,
    element: el,
  )).toList();
}

List<BlockComponent> initBlocks(int level) {
  final dom = allElements[_rng.nextInt(allElements.length)];
  final bool isPreBoss = level % 5 == 4;
  final blocks = <BlockComponent>[];
  for (int r = 0; r < 3; r++) {
    blocks.addAll(generateRow(level, dom, r, isPreBoss: isPreBoss));
  }
  // Guarantee at least one bonus ball block on pre-boss stage
  if (isPreBoss && !blocks.any((b) => b.type == BlockType.bonus)) {
    const blockSize = BlockComponent.blockSize;
    final col = _rng.nextInt(9);
    blocks.add(BlockComponent(
      position: Vector2(col * blockSize + 1, 1),
      type: BlockType.bonus,
      hp: 0,
      maxHp: 0,
      element: dom,
    ));
  }
  // Spawn wall barrier below normal rows from level 3 onwards (40% chance)
  if (level >= 3 && !isPreBoss && _rng.nextDouble() < 0.40) {
    blocks.addAll(generateWallBarrier(3, level));
  }
  return blocks;
}

// Maze grid patterns. Each is a 7×9 grid (rows × cols).
// 0 = empty, 1 = high-HP block, 2 = triple power-up reward
// Row 0 = top of screen, row 6 = bottom (ball entry). Row 6 must have
// at least 3 consecutive open cells so the ball can enter.
const _mazePatternsGrid = [
  // Pattern A — two side towers, wide center corridor
  [
    [1,1,1,0,0,0,1,1,1],  // top: center exit
    [1,2,1,0,1,0,1,2,1],  // triples at 1,7
    [1,1,1,0,1,0,1,1,1],
    [1,1,0,0,1,0,0,1,1],  // corridor widens
    [1,1,0,1,2,1,0,1,1],  // triple at center 4
    [1,2,0,0,0,0,0,2,1],  // triples at 1,7; wide open
    [1,1,0,0,0,0,0,1,1],  // entry: cols 2-6 (5 wide)
  ],
  // Pattern B — zigzag left→right
  [
    [1,1,0,0,1,1,1,1,1],  // top: exit left
    [1,0,0,1,1,1,2,1,1],  // triple at 6
    [1,0,1,1,1,0,0,1,1],
    [1,1,1,1,0,0,1,1,1],
    [1,1,1,0,0,1,1,2,1],  // triple at 7
    [1,2,1,0,0,1,1,1,1],  // triple at 1
    [1,1,0,0,0,1,1,1,1],  // entry: cols 2-4 (3 wide)
  ],
  // Pattern C — right tower + left open corridor
  [
    [0,0,1,1,1,1,1,1,1],  // top: exit cols 0-1
    [0,0,1,2,1,1,2,1,1],  // triples at 3,6
    [0,1,1,1,1,0,0,1,1],
    [0,0,1,1,0,0,1,1,1],
    [0,0,1,0,0,1,1,2,1],  // triple at 7
    [0,1,1,0,1,1,1,1,1],
    [0,0,0,0,1,1,1,1,1],  // entry: cols 0-3 (4 wide)
  ],
  // Pattern D — symmetric cross, open center base
  [
    [1,1,0,0,1,0,0,1,1],  // top: two exits
    [1,1,0,1,1,1,0,1,1],
    [0,0,0,1,2,1,0,0,0],  // triple at center
    [1,1,0,1,1,1,0,1,1],
    [1,2,0,0,1,0,0,2,1],  // triples at 1,7
    [1,1,1,0,0,0,1,1,1],
    [1,1,0,0,0,0,0,1,1],  // entry: cols 2-6 (5 wide)
  ],
];

List<BlockComponent> initCorridorStage(int level) {
  const blockSize = BlockComponent.blockSize;
  final el = nonNeutralElements[_rng.nextInt(nonNeutralElements.length)];
  final grid = _mazePatternsGrid[_rng.nextInt(_mazePatternsGrid.length)];
  // HP scales more gently at low levels: level 3 → 14, level 6 → 23, level 9 → 32
  final hp = 5 + level * 3;
  final blocks = <BlockComponent>[];

  for (int r = 0; r < grid.length; r++) {
    for (int c = 0; c < grid[r].length; c++) {
      final cell = grid[r][c];
      if (cell == 0) continue;
      final isTriple = cell == 2;
      blocks.add(BlockComponent(
        position: Vector2(c * blockSize + 1, r * blockSize + 1),
        type: isTriple ? BlockType.triple : BlockType.normal,
        hp: isTriple ? 0 : hp,
        maxHp: isTriple ? 0 : hp,
        element: isTriple ? ElementType.neutral : el,
      ));
    }
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
      goldValue: (level * 4).ceil(),
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
      goldValue: (level * 1).ceil(),
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
