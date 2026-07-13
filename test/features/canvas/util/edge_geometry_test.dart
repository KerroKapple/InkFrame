// edge_geometry 纯函数单测——锚点 / 贝塞尔路径 / 采样距离。

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/edge_geometry.dart';

void main() {
  const node = CanvasNode(
    id: 'n',
    label: '',
    type: CanvasNodeType.image,
    position: Offset(100, 200),
    size: Size(200, 100),
  );

  test('源出点 = 右边中点，靶入点 = 左边中点', () {
    expect(edgeSourceAnchor(node), const Offset(300, 250));
    expect(edgeTargetAnchor(node), const Offset(100, 250));
  });

  test('edgePath 起止于两锚点', () {
    const a = Offset(0, 0);
    const b = Offset(200, 100);
    final path = edgePath(a, b);
    final m = path.computeMetrics().single;
    expect(m.getTangentForOffset(0)!.position, a);
    final end = m.getTangentForOffset(m.length)!.position;
    expect(end.dx, closeTo(b.dx, 0.5));
    expect(end.dy, closeTo(b.dy, 0.5));
  });

  test('末端切线为 +x 方向（箭头恒水平入端口）', () {
    // 靶点在源点左侧（回连）也保持左入。
    final m =
        edgePath(const Offset(200, 0), const Offset(0, 100)).computeMetrics().single;
    final tangent = m.getTangentForOffset(m.length)!.vector;
    expect(tangent.dx, greaterThan(0));
  });

  test('distanceToEdgePath：锚点上为 0，远点为正', () {
    const a = Offset(0, 0);
    const b = Offset(200, 100);
    expect(distanceToEdgePath(a, a, b), 0);
    expect(distanceToEdgePath(const Offset(100, -200), a, b),
        greaterThan(100));
  });

  test('edgeBoundsMayHit：曲线附近为真，远点为假（O(1) 预筛语义）', () {
    const a = Offset(0, 0);
    const b = Offset(200, 100);
    // 曲线中点必在包围盒内。
    expect(edgeBoundsMayHit(edgePathMidpoint(a, b), a, b, 10), isTrue);
    // 锚点本身命中。
    expect(edgeBoundsMayHit(a, a, b, 10), isTrue);
    // 远点被拒。
    expect(edgeBoundsMayHit(const Offset(-99999, -99999), a, b, 10), isFalse);
    // y 向只按锚点扩 threshold：越过阈值即拒。
    expect(edgeBoundsMayHit(const Offset(100, 130), a, b, 10), isFalse);
  });

  test('edgePathMidpoint：对称手柄下等于锚点几何中点', () {
    const a = Offset(0, 0);
    const b = Offset(200, 200);
    final mid = edgePathMidpoint(a, b);
    expect(mid.dx, closeTo(100, 1));
    expect(mid.dy, closeTo(100, 1));
  });
}
