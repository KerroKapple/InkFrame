// 画布缩放数学（PL-2）：纯函数 + 钳制常量，可脱离 widget 单测。
//
// 缩放边界/步进是行为而非样式，故以常量沉淀于此（非 design token），
// 并作为 InteractiveViewer.minScale/maxScale 与快捷键缩放的单一真相源。

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 缩放下限（与 InteractiveViewer.minScale 共用）。
const double kCanvasMinScale = 0.1;

/// 缩放上限（与 InteractiveViewer.maxScale 共用）。
const double kCanvasMaxScale = 3.0;

/// 每次快捷键缩放的倍率：放大 ×step，缩小 ÷step。
const double kCanvasZoomStep = 1.2;

/// 从变换矩阵读取当前 2D 缩放值（x 基向量长度）。
///
/// InteractiveViewer 的矩阵 z 轴恒为 1，故不能用 getMaxScaleOnAxis——缩小到 <1
/// 时它会误取 z 轴的 1.0。此处取首列 (x,y) 的模长，对无旋转/无斜切的画布即为缩放。
double scaleOf(Matrix4 m) {
  final double a = m.storage[0];
  final double b = m.storage[1];
  return math.sqrt(a * a + b * b);
}

/// 围绕视口中心，把当前变换按 [factor] 缩放后返回新矩阵；目标缩放钳制在
/// [kCanvasMinScale, kCanvasMaxScale]。纯函数，无副作用。
///
/// InteractiveViewer 的矩阵把子(场景)坐标映射到视口坐标：screen = scale*scene + t。
/// 保持视口中心处的场景点不动，即为围绕视口中心缩放。
Matrix4 zoomedTransform({
  required Matrix4 current,
  required double factor,
  required Size viewportSize,
}) {
  final double s = scaleOf(current);
  final double target = (s * factor)
      .clamp(kCanvasMinScale, kCanvasMaxScale)
      .toDouble();
  final double tx = current.storage[12];
  final double ty = current.storage[13];
  final double cx = viewportSize.width / 2;
  final double cy = viewportSize.height / 2;
  // 视口中心对应的场景点（矩阵恒含正缩放，s 不为 0）。
  final double sceneX = (cx - tx) / s;
  final double sceneY = (cy - ty) / s;
  // 新平移：让同一场景点仍落在视口中心。
  final double ntx = cx - target * sceneX;
  final double nty = cy - target * sceneY;
  return Matrix4.identity()
    ..translateByDouble(ntx, nty, 0.0, 1.0)
    ..scaleByDouble(target, target, 1.0, 1.0);
}

/// 缩放复位到单位矩阵（scale=1、无平移）。
Matrix4 resetTransform() => Matrix4.identity();
