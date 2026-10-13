// LinkActionController — 连线动作编排 + 结果事件（HI-18 / ME-08）。
//
// CanvasView 通过 ref.listen 消费 [LinkActionEvent]，snackbar 映射收在副作用层。
// 错误按 extra.db_code 分流：23505（edges 部分唯一索引冲突）→ duplicate，
// 其余 InkError → failed——不再把一切错误误报为「连线已存在」。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import 'canvas_edges_controller.dart';
import 'canvas_nodes_controller.dart';
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
    final sourceId = ref.read(linkModeControllerProvider(arg));
    if (sourceId == null) return;
    final linkCtrl = ref.read(linkModeControllerProvider(arg).notifier);

    if (targetNodeId == sourceId) {
      linkCtrl.cancel();
      state = LinkActionEvent(LinkActionResult.selfLinkRejected);
      return;
    }
    try {
      // 节点类型的判断在队列外做（节点早就建好了，不参与竞态，而且这里还活着
      // ——ref.read 安全）；"目标有没有首帧入边"必须进队列里算，见下。
      final bool wantsFirstFrame = _firstFrameCandidate(sourceId, targetNodeId);
      await ref.read(canvasEdgesControllerProvider(arg).notifier).addEdge(
            sourceNodeId: sourceId,
            targetNodeId: targetNodeId,
            // 传解析器而不是算好的值：默认首帧的前提是"目标此刻还没有首帧入边"，
            // 在队列外读边快照的话，第一条首帧边写入在途时连第二条，两次都判
            // "还没有" ⇒ 双首帧。解析器只吃传进来的列表、不碰 ref，所以队列跑到
            // 它的时候即使本 notifier 已 autoDispose 也不会抛。
            roleResolver: wantsFirstFrame
                ? (List<CanvasEdge> current) =>
                    _hasFirstFrame(current, targetNodeId)
                        ? EdgeRole.reference
                        : EdgeRole.firstFrame
                : null,
          );
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

  /// 智能默认 role 的**第一半**：image 连 video 十有八九是图生视频首帧意图。
  ///
  /// 只判节点类型。这一半不参与竞态（节点早就建好了），所以留在队列外算。
  /// 第二半「目标此刻有没有首帧入边」在 [_hasFirstFrame]，由 addEdge 在串行
  /// 队列里调。状态未就绪（nodes 还在 loading）⇒ false ⇒ 退回 reference。
  /// 用户可在 Inspector 入边区（NodeInputsSection）随时改。
  bool _firstFrameCandidate(String sourceId, String targetId) {
    final nodes = ref.read(canvasNodesControllerProvider(arg)).valueOrNull;
    if (nodes == null) return false;
    CanvasNode? byId(String id) {
      for (final n in nodes) {
        if (n.id == id) return n;
      }
      return null;
    }

    return byId(targetId)?.type == CanvasNodeType.video &&
        byId(sourceId)?.type == CanvasNodeType.image;
  }

  /// 智能默认 role 的**第二半**：[targetId] 在 [edges] 里已经有首帧入边了吗。
  ///
  /// 纯函数，只吃传进来的列表——由 `CanvasEdgesController.addEdge` 在它的串行
  /// 队列**内部**调用，看到的是队头之前所有变更落完之后的边集合。
  static bool _hasFirstFrame(List<CanvasEdge> edges, String targetId) =>
      edges.any(
        (e) =>
            e.targetNodeId == targetId &&
            e.edgeType == EdgeType.data &&
            e.role == EdgeRole.firstFrame,
      );
}
