// BatchResultsController —— 某结果节点下的批量 slot 列表（按 nodeId 分族）。
//
// 读侧投影：build 拉 listByNode，refresh 供生成完成后刷新。
// 写侧（job_queue 落 slot 行）与「提升为结果节点」为后续接入点（见 docs/BOARD.md）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../canvas/models/batch_result.dart';

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
}
