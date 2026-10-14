// 监听 jobsRegistry 后的副作用判定（纯函数，可单测）：
//   - 当前画布出现新 job（占位 result 节点需显示）或 job 转入终态 → 需重拉节点；
//     进度 tick / 中间态流转 / 注册表清理不重拉——避免内存拖拽位置回弹（HI-14）
//   （失败的通知卡改由应用级的 JobNotificationListener 统一发，这里不再收集）
//   - 当前画布新转入终态且携带 resultNodeId 的 job → 定点刷新批量网格
import '../../generation/models/job_state.dart';

class CanvasJobEffect {
  const CanvasJobEffect({
    required this.shouldReloadNodes,
    this.invalidateBatchNodes = const <String>[],
  });
  final bool shouldReloadNodes;

  /// 需 invalidate batchResultsControllerProvider 的 result 节点 id。
  final List<String> invalidateBatchNodes;
}

class CanvasJobEffects {
  static CanvasJobEffect diff({
    required List<JobState> prev,
    required List<JobState> next,
    required String canvasId,
  }) {
    final p = {for (final s in prev.where((e) => e.canvasId == canvasId)) s.jobId: s};
    final n = {for (final s in next.where((e) => e.canvasId == canvasId)) s.jobId: s};

    final changed = n.entries.any((e) {
      final was = p[e.key];
      if (was == null) return true; // 新 job：占位 result 节点需上屏
      return e.value.isTerminal && !was.isTerminal; // 转入终态：产物落库
    });

    final invalidateBatchNodes = <String>[];
    for (final e in n.entries) {
      final cur = e.value;
      final was = p[e.key];
      final resultNodeId = cur.resultNodeId;
      if (resultNodeId != null &&
          cur.isTerminal &&
          (was == null || !was.isTerminal)) {
        invalidateBatchNodes.add(resultNodeId);
      }
    }
    return CanvasJobEffect(
      shouldReloadNodes: changed,
      invalidateBatchNodes: invalidateBatchNodes,
    );
  }
}
