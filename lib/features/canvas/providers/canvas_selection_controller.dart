// CanvasSelectionController — 画布选中态，纯 UI state。
//
// 与节点集合分离：节点加载/刷新是异步 (AsyncValue)，而选中态只随用户交互变化，
// 独立存活在一个 autoDispose Notifier 中，避免 AsyncValue reload 时丢选择。

import 'package:flutter_riverpod/flutter_riverpod.dart';

final canvasSelectionControllerProvider =
    AutoDisposeNotifierProvider<CanvasSelectionController, Set<String>>(
  CanvasSelectionController.new,
  name: 'canvasSelectionControllerProvider',
);

class CanvasSelectionController extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void select(String id, {bool toggle = false}) {
    final next = Set<String>.of(state);
    if (toggle) {
      next.contains(id) ? next.remove(id) : next.add(id);
    } else {
      next
        ..clear()
        ..add(id);
    }
    state = next;
  }

  void clear() {
    if (state.isEmpty) return;
    state = const <String>{};
  }

  void removed(String id) {
    if (!state.contains(id)) return;
    final next = Set<String>.of(state)..remove(id);
    state = next;
  }
}
