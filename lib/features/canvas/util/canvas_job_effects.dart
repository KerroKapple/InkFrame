// 监听 jobsRegistry 后的副作用判定（纯函数，可单测）：
//   - 当前画布出现新 job（占位 result 节点需显示）或 job 转入终态 → 需重拉节点；
//     进度 tick / 中间态流转 / 注册表清理不重拉——避免内存拖拽位置回弹（HI-14）
//   - 当前画布新转入 failed 的 job → 收集其 InkError 供 toast（cancelled 不收）
import '../../../core/errors/ink_error.dart';
import '../../generation/models/job_state.dart';

class CanvasJobEffect {
  const CanvasJobEffect({required this.shouldReloadNodes, required this.toastErrors});
  final bool shouldReloadNodes;
  final List<InkError> toastErrors;
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

    final toastErrors = <InkError>[];
    for (final e in n.entries) {
      final cur = e.value;
      final was = p[e.key];
      if (cur is JobFailed && was is! JobFailed) {
        toastErrors.add(cur.error);
      }
    }
    return CanvasJobEffect(shouldReloadNodes: changed, toastErrors: toastErrors);
  }
}
