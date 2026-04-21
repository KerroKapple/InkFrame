// LinkModeController — 画布连线模式状态机。
//
// 状态只有两个：idle (null) / fromSource (nodeId)。
// start() 进入连线模式，complete() / cancel() 退出。
// 真正写 edges 表的动作由调用方组合 canvasEdgesController.addEdge 完成——
// 本 Controller 只管 UI 意图，不碰 DB。

import 'package:flutter_riverpod/flutter_riverpod.dart';

final linkModeControllerProvider =
    AutoDisposeNotifierProvider<LinkModeController, String?>(
  LinkModeController.new,
  name: 'linkModeControllerProvider',
);

class LinkModeController extends AutoDisposeNotifier<String?> {
  @override
  String? build() => null;

  void start(String sourceNodeId) {
    state = sourceNodeId;
  }

  void cancel() {
    if (state == null) return;
    state = null;
  }

  bool get active => state != null;
  String? get sourceNodeId => state;
}
