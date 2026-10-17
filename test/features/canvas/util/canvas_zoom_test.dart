// canvas_zoom 纯函数单测（PL-2）：钳制上下限、初始相机、步进方向、围绕视口中心、缩放到 100%。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/theme/tokens.dart';

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

  // 变异对照：initialCanvasTransform 的 y 平移去掉 `+ InkToolbarSize.stageTopInset` ⇒ 原点断言红。
  test('初始相机：scale=1、世界原点对准视口左上再往下让出工具条', () {
    final m = initialCanvasTransform();
    expect(scaleOf(m), 1.0);
    // 舞台中央的世界原点（kStageOrigin）映射到屏幕 (0, stageTopInset)：顶上那一条留给浮动工具条。
    expect(
      MatrixUtils.transformPoint(m, kStageOrigin),
      const Offset(0, InkToolbarSize.stageTopInset),
    );
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

  // ===== 缩放到 100%（⌘0 / Ctrl+0）=====
  group('actualSizeTransform', () {
    // 任意缩放 + 平移下：scale 精确变成 1，变换前落在视口中心的场景点，变换后仍在视口中心。
    // 变异对照：目标 scale 写成 scaleOf(current) ⇒ scale 断言红；支点按 (0,0) 算 ⇒ 中心点断言红。
    for (final double s in <double>[2.5, kCanvasMinScale, kCanvasMaxScale]) {
      test('100%：scale $s 下 scale 变成 1，视口中心的场景点不动', () {
        final center = Offset(viewport.width / 2, viewport.height / 2);
        final current = Matrix4.identity()
          ..translateByDouble(120.0, -80.0, 0.0, 1.0)
          ..scaleByDouble(s, s, 1.0, 1.0);
        final sceneAtCenter = MatrixUtils.transformPoint(
          Matrix4.inverted(current),
          center,
        );

        final result = actualSizeTransform(current, viewport);

        expect(scaleOf(result), 1.0);
        final mapped = MatrixUtils.transformPoint(result, sceneAtCenter);
        expect(mapped.dx, closeTo(center.dx, 1e-6));
        expect(mapped.dy, closeTo(center.dy, 1e-6));
      });
    }

    // 平移取二进制下不精确的小数：走通用支点路径时新平移是 cx - (cx - tx)，800×600 视口下
    // -37.3 → -37.300000000000011、52.7 → 52.699999999999989，Matrix4 逐元素比较就不等了。
    // 整数平移守不住这一点（cx - (cx - tx) 一点误差都没有）。
    // 变异对照：删掉 actualSizeTransform 里 `if (s == target) return current.clone();` ⇒ 本条红。
    test('已是 100%：原样返回（不抖动、不重置平移）', () {
      final current = Matrix4.identity()
        ..translateByDouble(-37.3, 52.7, 0.0, 1.0);

      final result = actualSizeTransform(current, viewport);

      expect(result, current);
    });

    // 首帧前视口尺寸还没上报：支点退化为 (0,0)，与 zoomedTransform 一致；不抛错、不跳回初始相机。
    // 变异对照：Size.zero 时提前 return initialCanvasTransform() ⇒ 原点断言红。
    test('视口尺寸为零：以原点为锚、不抛错', () {
      final current = Matrix4.identity()
        ..translateByDouble(120.0, -80.0, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
      final sceneAtOrigin = MatrixUtils.transformPoint(
        Matrix4.inverted(current),
        Offset.zero,
      );

      final result = actualSizeTransform(current, Size.zero);

      expect(scaleOf(result), 1.0);
      final mapped = MatrixUtils.transformPoint(result, sceneAtOrigin);
      expect(mapped.dx, closeTo(0, 1e-6));
      expect(mapped.dy, closeTo(0, 1e-6));
    });
  });
}
