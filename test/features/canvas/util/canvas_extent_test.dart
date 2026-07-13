// canvasStageSize 纯函数单测——内容驱动生长语义。
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';

CanvasNode _node(String id, Offset pos, {Size size = const Size(200, 160)}) =>
    CanvasNode(id: id, label: '', type: CanvasNodeType.image,
        position: pos, size: size);

void main() {
  test('空画布 → 最小舞台', () {
    expect(canvasStageSize(const []),
        const Size(kCanvasMinExtent, kCanvasMinExtent));
  });

  test('内容在最小舞台内 → 仍为最小舞台', () {
    expect(
      canvasStageSize([_node('a', const Offset(100, 100))]),
      const Size(kCanvasMinExtent, kCanvasMinExtent),
    );
  });

  test('内容越界 → 舞台按内容右/下边界 + 余量生长（轴向独立）', () {
    final s = canvasStageSize([
      _node('a', const Offset(5000, 100)), // 右越界
      _node('b', const Offset(100, 6000)), // 下越界
    ]);
    expect(s.width, 5000 + 200 + kCanvasGrowMargin);
    expect(s.height, 6000 + 160 + kCanvasGrowMargin);
  });

  test('多节点取最远者', () {
    final s = canvasStageSize([
      _node('a', const Offset(4500, 0)),
      _node('b', const Offset(9000, 0)),
    ]);
    expect(s.width, 9000 + 200 + kCanvasGrowMargin);
  });
}
