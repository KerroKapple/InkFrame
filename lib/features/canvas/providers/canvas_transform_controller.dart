// 画布视图变换 provider（PL-2）。
//
// TransformationController 是有生命周期的 ChangeNotifier——按 canvasId 分族的
// autoDispose provider 单例化并在 onDispose 释放；InteractiveViewer 绑定它，
// 快捷键层经 provider 驱动缩放。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/canvas_zoom.dart';

/// 画布 InteractiveViewer 的变换控制器，按 canvasId 分族——切换画布时旧族
/// autoDispose、新画布拿到全新初始相机，避免 A 的 pan/zoom 串到 B（D3）。
/// InteractiveViewer 与快捷键缩放层必须用「当前 canvasId」读同一实例。
final canvasTransformControllerProvider =
    AutoDisposeProviderFamily<TransformationController, String>((
      ref,
      canvasId,
    ) {
      // 初始相机对准世界原点（居中定舞台，见 canvas_zoom.initialCanvasTransform）。
      final controller = TransformationController(initialCanvasTransform());
      ref.onDispose(controller.dispose);
      return controller;
    }, name: 'canvasTransformControllerProvider');

/// 画布视口尺寸（由舞台层 LayoutBuilder 上报），按 canvasId 分族——与
/// canvasTransformControllerProvider 对称，避免第二个被布局的画布状表面覆盖它。
final canvasViewportSizeProvider =
    AutoDisposeNotifierProviderFamily<CanvasViewportSize, Size, String>(
      CanvasViewportSize.new,
      name: 'canvasViewportSizeProvider',
    );

class CanvasViewportSize extends AutoDisposeFamilyNotifier<Size, String> {
  @override
  Size build(String canvasId) {
    // 无人 watch（仅缩放处 read），不 keepAlive 会在 setSize 后随即自毁并复位
    // Size.zero，令快捷键缩放读到 0×0 → 围绕 (0,0) 而非视口中心（D2）。
    //
    // 债：family 上的 keepAlive 意味着每个开过的 canvasId 都永久留一个 entry
    // ——"与 transform 对称"这句话在 dispose 语义上并不成立。后续让缩放路径
    // 改 watch 后去掉 keepAlive。见 docs/BOARD.md。
    ref.keepAlive();
    return Size.zero;
  }

  void setSize(Size size) {
    if (size == state) return;
    state = size;
  }
}
