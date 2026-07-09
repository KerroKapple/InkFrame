// 画布视图变换 provider（PL-2）。
//
// TransformationController 是有生命周期的 ChangeNotifier——用 autoDispose provider
// 单例化并在 onDispose 释放；InteractiveViewer 绑定它，快捷键层经 provider 驱动缩放。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 画布 InteractiveViewer 的变换控制器。随画布舞台存活，舞台销毁时释放。
final canvasTransformControllerProvider =
    AutoDisposeProvider<TransformationController>((ref) {
      final controller = TransformationController();
      ref.onDispose(controller.dispose);
      return controller;
    }, name: 'canvasTransformControllerProvider');

/// 画布视口尺寸（由舞台层 LayoutBuilder 上报）。围绕视口中心缩放时需要它。
final canvasViewportSizeProvider =
    AutoDisposeNotifierProvider<CanvasViewportSize, Size>(
      CanvasViewportSize.new,
      name: 'canvasViewportSizeProvider',
    );

class CanvasViewportSize extends AutoDisposeNotifier<Size> {
  @override
  Size build() => Size.zero;

  void setSize(Size size) {
    if (size == state) return;
    state = size;
  }
}
