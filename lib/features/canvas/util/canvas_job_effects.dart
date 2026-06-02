// 监听 jobsRegistry 后的副作用判定（纯函数，可单测）：
//   - 当前画布的 job 集合发生任何生命周期变化 → 需重拉画布节点
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

    final changed = p.length != n.length ||
        n.entries.any((e) => p[e.key].runtimeType != e.value.runtimeType) ||
        n.entries.any((e) {
          final prevS = p[e.key];
          return prevS is JobRunning &&
              e.value is JobRunning &&
              prevS.progress != (e.value as JobRunning).progress;
        }) ||
        p.keys.any((k) => !n.containsKey(k));

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
