// 新建节点的默认落点。
//
// 债150（Polish Wave 1 PR-8）：旧模型固定世界 (200..600) 随机——全向无限
// 画布（#186）后用户漫游到任意象限,建点必落屏幕外。现改视口中心：视口
// 几何中心经逆变换入世界坐标,叠小随机散布防连建叠点;视口未上报
// （Size.zero,测试/首帧前）回退旧固定区随机。Random 由调用方注入保可测。

import 'dart:math';

import 'package:flutter/widgets.dart';

const double _kMinOffset = 200;
const double _kSpread = 400;

/// 连建散布直径（±60）：肉眼可辨不叠点,又不至于偏离视口中心。
const double _kCenterScatter = 120;

/// 旧固定区随机（视口未知时的回退;历史行为保持既有测试语义）。
Offset pickRandomNodePosition(Random random) => Offset(
      _kMinOffset + random.nextDouble() * _kSpread,
      _kMinOffset + random.nextDouble() * _kSpread,
    );

/// 视口中心落点（债150）。[transform] 为画布 InteractiveViewer 当前矩阵
/// （canvasTransformControllerProvider(canvasId).value）,[viewportSize] 来自
/// canvasViewportSizeProvider;返回值为节点左上角世界坐标（按 [nodeSize] 让
/// 节点几何中心对准视口中心）。
Offset pickViewportCenteredNodePosition({
  required Random random,
  required Matrix4 transform,
  required Size viewportSize,
  Size nodeSize = const Size(200, 160),
}) {
  if (viewportSize == Size.zero) return pickRandomNodePosition(random);
  final viewCenter =
      Offset(viewportSize.width / 2, viewportSize.height / 2);
  final worldCenter =
      MatrixUtils.transformPoint(Matrix4.inverted(transform), viewCenter);
  final scatter = Offset(
    (random.nextDouble() - 0.5) * _kCenterScatter,
    (random.nextDouble() - 0.5) * _kCenterScatter,
  );
  return worldCenter -
      Offset(nodeSize.width / 2, nodeSize.height / 2) +
      scatter;
}
