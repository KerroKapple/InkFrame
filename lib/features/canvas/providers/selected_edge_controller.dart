// SelectedEdgeController — 画布当前高亮的连线 id。
//
// 与节点选择互相独立（同一时刻可能节点选中 + 边也选中，UI 各自渲染）。
// 本 Controller 纯 UI 态，不碰 DB。

import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedEdgeControllerProvider =
    AutoDisposeNotifierProviderFamily<SelectedEdgeController, String?, String>(
  SelectedEdgeController.new,
  name: 'selectedEdgeControllerProvider',
);

class SelectedEdgeController extends AutoDisposeFamilyNotifier<String?, String> {
  @override
  String? build(String canvasId) => null;

  void select(String id) {
    if (state == id) return;
    state = id;
  }

  void clear() {
    if (state == null) return;
    state = null;
  }
}
