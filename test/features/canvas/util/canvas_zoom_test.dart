// canvas_zoom 纯函数单测（PL-2）：钳制上下限、复位、步进方向、围绕视口中心。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';

Matrix4 _scaled(double s) => Matrix4.identity()..scaleByDouble(s, s, 1.0, 1.0);

void main() {
  const viewport = Size(800, 600);

  test('放大：目标缩放 = 当前 × step', () {
    final result = zoomedTransform(
      current: Matrix4.identity(),
      factor: kCanvasZoomStep,
      viewportSize: viewport,
    );
    expect(scaleOf(result), closeTo(kCanvasZoomStep, 1e-9));
  });

  test('缩小：目标缩放 = 当前 ÷ step（步进方向）', () {
    final result = zoomedTransform(
      current: Matrix4.identity(),
      factor: 1 / kCanvasZoomStep,
      viewportSize: viewport,
    );
    expect(scaleOf(result), lessThan(1.0));
    expect(scaleOf(result), closeTo(1 / kCanvasZoomStep, 1e-9));
  });

  test('钳制上限：超过 maxScale 被夹到 maxScale', () {
    // 当前已接近上限，再放大应夹住。
    final result = zoomedTransform(
      current: _scaled(kCanvasMaxScale - 0.05),
      factor: kCanvasZoomStep,
      viewportSize: viewport,
    );
    expect(scaleOf(result), closeTo(kCanvasMaxScale, 1e-9));
  });

  test('钳制下限：低于 minScale 被夹到 minScale', () {
    final result = zoomedTransform(
      current: _scaled(kCanvasMinScale + 0.01),
      factor: 1 / kCanvasZoomStep,
      viewportSize: viewport,
    );
    expect(scaleOf(result), closeTo(kCanvasMinScale, 1e-9));
  });

  test('复位 → 单位矩阵', () {
    expect(resetTransform(), Matrix4.identity());
  });

  test('围绕视口中心：中心处的场景点缩放后仍落在视口中心', () {
    final center = Offset(viewport.width / 2, viewport.height / 2);
    // 先施加一个带平移的变换（模拟已平移/缩放过的画布）。
    final current = Matrix4.identity()
      ..translateByDouble(120.0, -80.0, 0.0, 1.0)
      ..scaleByDouble(1.5, 1.5, 1.0, 1.0);
    // 当前视口中心对应的场景点。
    final sceneAtCenter = MatrixUtils.transformPoint(
      Matrix4.inverted(current),
      center,
    );
    final zoomed = zoomedTransform(
      current: current,
      factor: kCanvasZoomStep,
      viewportSize: viewport,
    );
    // 缩放后，同一场景点应重新映射回视口中心。
    final mapped = MatrixUtils.transformPoint(zoomed, sceneAtCenter);
    expect(mapped.dx, closeTo(center.dx, 1e-6));
    expect(mapped.dy, closeTo(center.dy, 1e-6));
  });
}
