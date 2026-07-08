// JobHandle 实现（LB-03 从 JobQueue 抽出）：last-value 重放 + done completer。
import 'dart:async';

import '../../core/interfaces/job_queue_service.dart';
import '../../core/models/job_status.dart';

/// 提交后任务句柄的内存实现。
///
/// 契约：迟到订阅者先收到最近一次状态（含终态），再接收后续推送；
/// 终态后订阅也能收到终态并立即 done。
class JobHandleImpl implements JobHandle {
  JobHandleImpl(this._jobId, this._controller, this._done);

  final String _jobId;
  final StreamController<JobStatus> _controller;
  final Completer<JobStatus> _done;

  /// ME-03：last-value cache——迟到订阅者先收到最近一次状态（含终态）。
  JobStatus? _last;

  @override
  String get jobId => _jobId;

  @override
  Stream<JobStatus> get status {
    // 尚无可重放状态且流仍开放 → 直接给广播流（零开销，事件时序与广播一致）。
    if (_last == null && !_controller.isClosed) return _controller.stream;
    // 迟到订阅：返回一条新流，onListen 同步建桥（无丢事件窗口），
    // 先重放 _last 再转发广播；广播已关闭则补发终态后立即 done。
    StreamSubscription<JobStatus>? bridge;
    late final StreamController<JobStatus> out;
    out = StreamController<JobStatus>(
      onListen: () {
        final last = _last;
        if (last != null) out.add(last);
        if (_controller.isClosed) {
          out.close();
          return;
        }
        bridge = _controller.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
      },
      onCancel: () => bridge?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<JobStatus> get done => _done.future;

  void emit(JobStatus s) {
    _last = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  void complete(JobStatus terminal) {
    if (!_done.isCompleted) _done.complete(terminal);
    if (!_controller.isClosed) _controller.close();
  }
}
