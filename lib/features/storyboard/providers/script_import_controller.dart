// SB-2 批量建链：把 SB-1 拆出来的 [ShotDraft] 清单一次性落成画布上的分镜链。
//
// 「一次性」是硬要求：N 个 shot 节点 + N-1 条 narrative 边全部收进**单个事务**。
// 中途任一步失败就整体回滚——半条链（几个建好的散镜 + 几条边）比一个错误提示
// 难收拾得多，用户既不知道哪几镜落地了，也没有一键撤销。
//
// 落地后 invalidate 节点与边两个控制器：这里绕过 CanvasNodesController 直接写库
// （它一次只建一个节点，且不参与事务），内存态不会自动跟上。

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_edges_controller.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../util/script_splitter.dart';

/// 相邻两镜的横向间距。shot 卡宽 240，留 20 的走线余量。
const double kShotChainSpacingX = 260;

/// **不加 autoDispose**：调用方只会 `ref.read` 拿一次控制器（不订阅），
/// autoDispose 会在 read 之后立刻销毁 ref——事务 await 完再 invalidate 就会
/// 撞上已销毁的 ref，画布刷不出新链。控制器本身无状态，常驻代价可忽略。
final scriptImportControllerProvider =
    Provider.family<ScriptImportController, String>(
  ScriptImportController.new,
  name: 'scriptImportControllerProvider',
);

class ScriptImportController {
  ScriptImportController(this._ref, this._canvasId);

  final Ref _ref;
  final String _canvasId;

  /// 把 [drafts] 落成一条分镜链，返回建出的镜数。
  ///
  /// [origin] 是**第一镜的左上角世界坐标**，后续各镜沿 x 轴排开；缺省落世界原点。
  /// 空清单直接返回 0，不开空事务。
  /// 任一步失败抛 InkError（事务已回滚），由调用方提示。
  Future<int> importDrafts(
    List<ShotDraft> drafts, {
    Offset origin = Offset.zero,
  }) async {
    if (drafts.isEmpty) return 0;
    final uow = await _ref.read(unitOfWorkProvider.future);
    final Size size = defaultNodeSize(CanvasNodeType.shot);

    await uow.run((scope) async {
      final ids = <String>[];
      for (var i = 0; i < drafts.length; i++) {
        final ShotDraft draft = drafts[i];
        ids.add(
          await scope.nodes.create(
            canvasId: _canvasId,
            type: CanvasNodeType.shot.name,
            nodeRole: NodeRole.config.name,
            label: draft.label,
            positionX: origin.dx + i * kShotChainSpacingX,
            positionY: origin.dy,
            width: size.width,
            height: size.height,
            // 与 ShotConfigInspector 同键：导入后点开面板就能接着编辑。
            typeConfig: <String, Object?>{'shot_notes': draft.notes},
          ),
        );
      }
      for (var i = 0; i < ids.length - 1; i++) {
        await scope.edges.create(
          canvasId: _canvasId,
          sourceNodeId: ids[i],
          targetNodeId: ids[i + 1],
          edgeType: CanvasEdgeMapping.typeToDb(EdgeType.narrative),
          sortOrder: i,
        );
      }
    });

    _ref.invalidate(canvasNodesControllerProvider(_canvasId));
    _ref.invalidate(canvasEdgesControllerProvider(_canvasId));
    return drafts.length;
  }
}
