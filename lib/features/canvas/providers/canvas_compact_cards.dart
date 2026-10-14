// 缩小态节点卡（提示词条与节点文字稿）：画布缩到 [kCompactCardScale] 以下时，config 卡的
// 提示词正文与底部摘要行都收起，只留居中的类型图标——那个缩放下几行小字糊成一团，谁也读不了。
//
// 只在越过阈值时通知：TransformationController 每个缩放 / 平移帧都会响，卡片要是直接
// 监听它就会每帧重建；这里把它折成一个 bool，值没变就不发，卡片只在翻转那一下重建一次。
// 与 canvasTransformControllerProvider 同样按 canvasId 分族、autoDispose——换画布时
// 旧画布的条目随卡片一起回收，监听在 onDispose 里摘掉。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/canvas_zoom.dart';
import 'canvas_transform_controller.dart';

/// 缩放严格低于此值即进入缩小态（恰好 0.6 仍画正文）。
///
/// 行为阈值而非视觉 token——与 canvas_zoom.dart 的缩放上下限同一性质。
const double kCompactCardScale = 0.6;

/// 缩放 [scale] 下 config 卡是否该收成类型图标。
bool isCompactCardScale(double scale) => scale < kCompactCardScale;

/// 某画布当前是否处于缩小态（true = config 卡只画类型图标）。
final canvasCompactCardsProvider =
    AutoDisposeNotifierProviderFamily<CanvasCompactCards, bool, String>(
      CanvasCompactCards.new,
      name: 'canvasCompactCardsProvider',
    );

class CanvasCompactCards extends AutoDisposeFamilyNotifier<bool, String> {
  @override
  bool build(String canvasId) {
    final TransformationController transform =
        ref.watch(canvasTransformControllerProvider(canvasId));
    void sync() {
      final bool next = isCompactCardScale(scaleOf(transform.value));
      if (next != state) state = next;
    }

    transform.addListener(sync);
    ref.onDispose(() => transform.removeListener(sync));
    return isCompactCardScale(scaleOf(transform.value));
  }
}
