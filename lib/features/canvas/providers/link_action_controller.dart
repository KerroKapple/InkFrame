// LinkActionController — 连线动作编排 + 结果事件（HI-18 / ME-08）。
//
// CanvasView 通过 ref.listen 消费 [LinkActionEvent]，snackbar 映射收在副作用层。
// 错误按 extra.db_code 分流：23505（edges 部分唯一索引冲突）→ duplicate，
// 其余 InkError → failed——不再把一切错误误报为「连线已存在」。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import 'canvas_edges_controller.dart';
import 'link_mode_controller.dart';

/// 一次连线动作的结局。
enum LinkActionResult { created, selfLinkRejected, duplicate, failed }

/// 连线动作结果事件。每次动作产生新实例，保证 listener 每次触发。
class LinkActionEvent {
  LinkActionEvent(this.result);
  final LinkActionResult result;
}

final linkActionControllerProvider = AutoDisposeNotifierProviderFamily<
    LinkActionController, LinkActionEvent?, String>(
  LinkActionController.new,
  name: 'linkActionControllerProvider',
);

class LinkActionController
    extends AutoDisposeFamilyNotifier<LinkActionEvent?, String> {
  @override
  LinkActionEvent? build(String canvasId) => null;

  /// 把当前 link source 连到 [targetNodeId]；非 link 模式下 no-op。
  /// 无论成败都退出 link 模式。
  Future<void> linkTo(String targetNodeId) async {
    final sourceId = ref.read(linkModeControllerProvider);
    if (sourceId == null) return;
    final linkCtrl = ref.read(linkModeControllerProvider.notifier);

    if (targetNodeId == sourceId) {
      linkCtrl.cancel();
      state = LinkActionEvent(LinkActionResult.selfLinkRejected);
      return;
    }
    try {
      await ref
          .read(canvasEdgesControllerProvider(arg).notifier)
          .addEdge(sourceNodeId: sourceId, targetNodeId: targetNodeId);
      state = LinkActionEvent(LinkActionResult.created);
    } on InkError catch (e) {
      state = LinkActionEvent(
        e.extra['db_code'] == '23505'
            ? LinkActionResult.duplicate
            : LinkActionResult.failed,
      );
    } finally {
      linkCtrl.cancel();
    }
  }
}
