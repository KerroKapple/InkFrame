// CanvasBootstrapController — 示例项目创建入口（ON-2/ON-2b）。
//
// createSample 建示例 Project + Canvas 并种入演示内容：1 条示例泳道 +
// 1 个预填 prompt 的 image config 节点（纯本地，不触发生成）。
// 三个 UI 入口（首启向导 / Studio 空态 / 画布空态）传入 l10n 化的 SampleSeed，
// 本控制器不触 l10n（分层：文案属 UI 层）。
//
// 四步落库走 UnitOfWork 单事务——任一步失败整体回滚，不留半成品示例项目。

import 'dart:async' show unawaited;
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/di/repositories.dart';
import '../models/canvas_node.dart';
import 'current_canvas_id.dart';

/// 示例内容文案（UI 层从 ARB 构造传入）。
typedef SampleSeed = ({
  String laneLabel,
  String laneStylePrompt,
  String nodeLabel,
  String nodePrompt,
});

/// 示例节点世界坐标：默认泳道厚 400（horizontal 带 = Y ∈ [0,400)），
/// image 默认尺寸 260×220 → (120, 90) 整体落带内且贴近舞台原点（首启视野）。
const Offset kSampleNodePosition = Offset(120, 90);

final canvasBootstrapControllerProvider = Provider.autoDispose(
  CanvasBootstrapController.new,
  name: 'canvasBootstrapControllerProvider',
);

class CanvasBootstrapController {
  CanvasBootstrapController(this._ref);

  final Ref _ref;

  /// 创建示例 Project + Canvas + 演示内容并切换到该画布。返回新画布 id。
  ///
  /// ME-27：本 provider 是 autoDispose，await 期间可能被 dispose——所有
  /// _ref.read 在入口同步完成，await 之后不再触 _ref。
  Future<String> createSample({
    required String projectName,
    required String canvasName,
    required SampleSeed seed,
  }) async {
    final uowFuture = _ref.read(unitOfWorkProvider.future);
    final currentCanvasId = _ref.read(currentCanvasIdProvider.notifier);
    final prefs = _ref.read(preferencesServiceProvider);
    final uow = await uowFuture;
    final nodeSize = defaultNodeSize(CanvasNodeType.image);
    final ids = await uow.run((s) async {
      final projectId = await s.projects.create(name: projectName);
      final canvasId = await s.canvas.create(
        projectId: projectId,
        name: canvasName,
      );
      final laneId = await s.styleLanes.create(
        canvasId: canvasId,
        label: seed.laneLabel,
        stylePrompt: seed.laneStylePrompt,
      );
      await s.nodes.create(
        canvasId: canvasId,
        type: CanvasNodeType.image.name,
        nodeRole: NodeRole.config.name,
        label: seed.nodeLabel,
        laneId: laneId,
        positionX: kSampleNodePosition.dx,
        positionY: kSampleNodePosition.dy,
        width: nodeSize.width,
        height: nodeSize.height,
        typeConfig: <String, Object?>{'prompt': seed.nodePrompt},
      );
      return (projectId: projectId, canvasId: canvasId);
    });
    currentCanvasId.state = ids.canvasId;
    // 记住上次会话（fire-and-forget，服务内部吞盘错误）。
    unawaited(prefs.update(
      (p) => p.copyWith(
        lastCanvasId: ids.canvasId,
        lastProjectId: ids.projectId,
      ),
    ));
    return ids.canvasId;
  }
}
