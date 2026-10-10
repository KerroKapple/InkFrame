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
///
/// 【订阅锚不在本文件，在 CanvasShortcuts】本 provider 的全部读点都在回调里
/// （⌘± 缩放、新建节点落点），没有一个是 watch；autoDispose 于是会在
/// LayoutBuilder 上报完 setSize 的下一拍就把 entry 回收并复位 Size.zero，
/// 让缩放围绕 (0,0) 而非视口中心（D2）。
///
/// 这件事原先靠 `ref.keepAlive()` 挡住，代价是 family + keepAlive ⇒ 每个开过的
/// canvasId 都永久留一个 entry（进程级泄漏）。现在改由 CanvasShortcuts.build
/// 的一条 watch 做订阅锚：它与画布标签同生共死，换画布时旧 canvasId 的 watcher
/// 当场断开 ⇒ 旧 entry 随之回收，"与 transform 对称"这句话在 dispose 语义上
/// 才真正成立。
///
/// 两个方向各有护栏（canvas_shortcuts_test.dart）：锚掉了 ⇒ D2「⌘+ 围绕视口
/// 中心」红；keepAlive 回来 ⇒「切换画布 → 旧画布的视口尺寸 entry 被回收」红。
/// 外壳侧「切走标签 / 浮层遮挡后尺寸不丢」由 shell_canvas_viewport_retention_test
/// 钉住——那是保活槽的性质，画布级 pump 测不到。
final canvasViewportSizeProvider =
    AutoDisposeNotifierProviderFamily<CanvasViewportSize, Size, String>(
      CanvasViewportSize.new,
      name: 'canvasViewportSizeProvider',
    );

class CanvasViewportSize extends AutoDisposeFamilyNotifier<Size, String> {
  @override
  Size build(String canvasId) => Size.zero;

  void setSize(Size size) {
    if (size == state) return;
    state = size;
  }
}
