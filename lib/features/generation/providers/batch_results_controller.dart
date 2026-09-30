// BatchResultsController —— 某结果节点下的批量 slot 列表（按 nodeId 分族）+ slot 动作。
//
// 读侧投影：build 拉 listByNode；job 终态由 CanvasJobListener 定点 invalidate。
// 写侧落 slot 行见 JobQueueService。
//
// P4 起本 notifier 同时是 slot 动作的唯一入口（转正 / 重跑 / 取消）：widget 只
// 调方法，不认识仓储与 JobQueue。四个动作的落地口径见各自 doc。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';
import '../../../core/di/job_queue.dart';
import '../../../core/di/repositories.dart';
import '../../canvas/models/batch_result.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/util/batch_slot_view.dart';
import '../generation_controller.dart';

final batchResultsControllerProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      BatchResultsController,
      List<BatchResult>,
      String
    >(BatchResultsController.new, name: 'batchResultsControllerProvider');

class BatchResultsController
    extends AutoDisposeFamilyAsyncNotifier<List<BatchResult>, String> {
  bool _alive = false;

  @override
  Future<List<BatchResult>> build(String nodeId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(batchResultRepositoryProvider.future);
    final rows = await repo.listByNode(nodeId);
    return rows.map(BatchResult.fromRow).toList(growable: false);
  }

  /// 生成推进/完成后重新拉取 slot。
  Future<void> refresh() async {
    final repo = ref.read(batchResultRepositoryProvider).valueOrNull;
    if (repo == null) return;
    final rows = await repo.listByNode(arg);
    if (_alive) {
      state = AsyncData(rows.map(BatchResult.fromRow).toList(growable: false));
    }
  }

  /// 转正：把该 slot 写成**当前 result 节点**的产物。
  ///
  /// 一个事务里三件事，缺一不可：
  ///   1. `type_config.image_url` ← slot.outputUrl（节点产物真正换成这一张）；
  ///   2. 同节点其余 promoted 行清零——`batch_results.promoted` 上没有唯一约束，
  ///      单选语义只能由这里维持，否则画廊 `_chosenArtifactOf` 会取到旧那张；
  ///   3. 该行 `markPromoted`。`promotedNodeId` 指向当前 result 节点自己：
  ///      转正不派生新节点（「全部派生节点」不在本期范围）。
  ///
  /// 产物路径为空的 slot 不可转正（上层 [batchSlotCanPromote] 已挡一道，这里兜底）。
  Future<void> promote(BatchResult slot) async {
    final String? url = slot.outputUrl;
    if (url == null || url.isEmpty) return;
    if (!batchSlotCanPromote(slot)) return;
    final uow = await ref.read(unitOfWorkProvider.future);
    final String? canvasId = await uow.run<String?>((scope) async {
      await scope.nodes.patchTypeConfig(arg, <String, Object?>{
        'image_url': url,
      });
      for (final row in await scope.batchResults.listByNode(arg)) {
        final Object? id = row[BatchResultCol.id];
        if (id is! String || id == slot.id) continue;
        if (row[BatchResultCol.promoted] != true) continue;
        await scope.batchResults.update(id, <String, Object?>{
          BatchResultCol.promoted: false,
          BatchResultCol.promotedNodeId: null,
        });
      }
      await scope.batchResults.markPromoted(id: slot.id, promotedNodeId: arg);
      final node = await scope.nodes.findById(arg);
      return node?.optId(NodeCol.canvasId);
    });
    if (!_alive) return;
    await refresh();
    // 节点产物换了图，画布上的缩略图得跟着换——节点集合是另一个 family 的状态，
    // 只能由这里定点 invalidate（没被 watch 时是 no-op）。
    if (_alive && canvasId != null) {
      ref.invalidate(canvasNodesControllerProvider(canvasId));
    }
  }

  /// 重跑：从该 result 节点的溯源 config 节点再发一次生成。
  ///
  /// [seedOverride] 只对这一次生效、**不写回节点**——用户填在检查器里的 seed 是
  /// 他自己的设置，重跑某个 slot 不该把它永久改掉。
  ///
  /// 注意语义：`submitFromConfigNode` 每次都新建一个 result 节点，所以重跑的产物
  /// 落在**新节点**上，当前面板里的 slot 不会就地变化（这是既有生成语义，不是本期改动）。
  Future<String> rerun({required String configNodeId, int? seedOverride}) async {
    final controller = await ref.read(generationControllerProvider.future);
    return controller.submitFromConfigNode(
      configNodeId,
      seedOverride: seedOverride,
    );
  }

  /// 有失败 slot 时重跑：**只发一次**，不按失败格数循环。
  ///
  /// 部分重跑在架构上不成立——provider 一次调用返 N 张，没有「只补第 3 张」这种请求。
  /// 所以一次重跑必然按 config 的 `batch_size` 整批重来，拿到的就是一整批新图，
  /// 失败的那几格自然被覆盖。按失败格数循环发只会得到 k × batch_size 张图，
  /// 纯属浪费额度，用户也不会预期点一次按钮扣 k 倍的钱。
  ///
  /// 没有失败 slot 时是 no-op（按钮本来就只在有失败格时才渲染）。
  Future<void> rerunFailed({required String configNodeId}) async {
    final slots = state.valueOrNull ?? const <BatchResult>[];
    final bool anyFailed = slots.any((s) => batchSlotViewOf(s) == BatchSlotView.error);
    if (!anyFailed) return;
    await rerun(configNodeId: configNodeId);
  }

  /// 取消：**整批**。per-slot 取消在架构上不成立——批量是 provider 的一次调用返
  /// N 张，没有 per-slot 的远端任务，收敛粒度就是 job。UI 的 tooltip 必须说清这点。
  Future<void> cancelBatch(String jobId) async {
    final queue = await ref.read(jobQueueServiceProvider.future);
    await queue.cancel(jobId);
    if (!_alive) return;
    await refresh();
  }
}
