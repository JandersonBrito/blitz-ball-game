import 'dart:typed_data';
import '../components/block_component.dart';

/// Grid uniforme do tabuleiro: cada bola só testa as células em volta dela,
/// em vez de todos os blocos.
///
/// Blocos 1×1 ficam numa lista ligada por célula (`nextInCell` do bloco), então
/// a sobreposição rara (ex.: depois do "continuar" com anúncio) funciona sem
/// alocar nada. Blocos maiores (boss 2×2) ficam em [big] e são testados
/// direto: há no máximo um por fase.
///
/// O grid também sabe quais células têm bloco sólido (que reflete a bola),
/// para a colisão ignorar faces internas: numa fileira de blocos lado a lado
/// a junção entre dois deles não é uma quina.
class BlockGrid {
  BlockGrid({
    required this.cols,
    required this.cellSize,
    required this.originX,
    required this.originY,
  });

  final int cols;
  final double cellSize;

  /// Canto superior esquerdo da célula (0, 0).
  final double originX;
  final double originY;

  int _rows = 0;
  int get rows => _rows;
  List<BlockComponent?> _heads = const [];
  Uint8List _solid = Uint8List(0);

  /// Blocos que ocupam mais de uma célula.
  final List<BlockComponent> big = [];

  /// Faces de um bloco, para [exposedFaces].
  static const int faceLeft = 1, faceRight = 2, faceTop = 4, faceBottom = 8;

  /// Power-ups são atravessados; o resto devolve a bola.
  static bool reflects(BlockComponent b) =>
      b.type != BlockType.bonus &&
      b.type != BlockType.triple &&
      b.type != BlockType.elemPower;

  /// Só aloca quando o número de linhas muda (troca de tamanho da tela).
  void resize(int rows) {
    if (rows == _rows) return;
    _rows = rows;
    _heads = List<BlockComponent?>.filled(cols * rows, null);
    _solid = Uint8List(cols * rows);
  }

  void rebuild(List<BlockComponent> blocks) {
    _heads.fillRange(0, _heads.length, null);
    _solid.fillRange(0, _solid.length, 0);
    big.clear();
    for (var i = 0; i < blocks.length; i++) {
      insert(blocks[i]);
    }
  }

  void insert(BlockComponent b) {
    b.nextInCell = null;
    b.gridCell = -1;
    if (b.size.x > cellSize + 0.5 || b.size.y > cellSize + 0.5) {
      big.add(b);
      if (reflects(b)) _markBig(b, 1);
      return;
    }
    final c = ((b.position.x - originX) / cellSize).round();
    final r = ((b.position.y - originY) / cellSize).round();
    // Fora da área jogável (ex.: acima do teto): nenhuma bola chega lá.
    if (c < 0 || c >= cols || r < 0 || r >= _rows) return;
    final cell = r * cols + c;
    b.gridCell = cell;
    b.nextInCell = _heads[cell];
    _heads[cell] = b;
    if (reflects(b)) _solid[cell] = 1;
  }

  void remove(BlockComponent b) {
    final cell = b.gridCell;
    if (cell < 0) {
      if (big.remove(b) && reflects(b)) _markBig(b, 0);
      return;
    }
    BlockComponent? prev;
    var cur = _heads[cell];
    while (cur != null) {
      if (identical(cur, b)) {
        if (prev == null) {
          _heads[cell] = cur.nextInCell;
        } else {
          prev.nextInCell = cur.nextInCell;
        }
        break;
      }
      prev = cur;
      cur = cur.nextInCell;
    }
    b.gridCell = -1;
    b.nextInCell = null;
    _refreshSolid(cell);
  }

  void _refreshSolid(int cell) {
    var solid = 0;
    for (var b = _heads[cell]; b != null; b = b.nextInCell) {
      if (reflects(b)) {
        solid = 1;
        break;
      }
    }
    _solid[cell] = solid;
  }

  /// Marca (ou desmarca, recalculando) as células cobertas por um bloco grande.
  void _markBig(BlockComponent b, int value) {
    final c0 = ((b.position.x - originX) / cellSize).round();
    final r0 = ((b.position.y - originY) / cellSize).round();
    final c1 = c0 + (b.size.x / cellSize).round() - 1;
    final r1 = r0 + (b.size.y / cellSize).round() - 1;
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        if (c < 0 || c >= cols || r < 0 || r >= _rows) continue;
        final cell = r * cols + c;
        if (value == 1) {
          _solid[cell] = 1;
        } else {
          _refreshSolid(cell);
        }
      }
    }
  }

  /// Primeiro bloco da célula ([col], [row]); null fora do grid.
  BlockComponent? head(int col, int row) {
    if (col < 0 || col >= cols || row < 0 || row >= _rows) return null;
    return _heads[row * cols + col];
  }

  bool solidAt(int col, int row) {
    if (col < 0 || col >= cols || row < 0 || row >= _rows) return false;
    return _solid[row * cols + col] == 1;
  }

  /// Faces do bloco sem vizinho sólido ([faceLeft] | [faceRight] | ...).
  /// Blocos grandes e fora do grid contam com todas as faces expostas.
  int exposedFaces(BlockComponent b) {
    final cell = b.gridCell;
    if (cell < 0) return faceLeft | faceRight | faceTop | faceBottom;
    final c = cell % cols, r = cell ~/ cols;
    var mask = 0;
    if (!solidAt(c - 1, r)) mask |= faceLeft;
    if (!solidAt(c + 1, r)) mask |= faceRight;
    if (!solidAt(c, r - 1)) mask |= faceTop;
    if (!solidAt(c, r + 1)) mask |= faceBottom;
    return mask;
  }
}
