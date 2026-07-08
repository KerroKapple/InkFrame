// JobQueue 共享内件（LB-03）：日志 module 常量、纯裁决谓词、运行态值对象。
import 'dart:async';

import '../../core/interfaces/generation_provider.dart';
import '../../core/interfaces/job_media_persister.dart';
import 'job_handle_impl.dart';

/// 队列日志 module 名（内部标识，非 i18n）。
const String kJobQueueLogModule = 'jobqueue';

/// 错误消息落库截断上限守卫。
String truncate(String s, int max) => s.length <= max ? s : s.substring(0, max);

/// 终态写库被 cancel 抢先的单一真相源：running 已取消 且 affectedRows 为
/// 0（被抢写）/ null（纯内存无行数）。orchestrator 的 _lostToCancel 与
/// media persister 的 slot 收敛共用同一谓词，杜绝二处漂移。
bool lostToCancel({required int? rows, required bool cancelled}) =>
    cancelled && (rows == null || rows == 0);

/// 运行中的任务：provider 句柄 + 取消位 + 可中断退避睡眠句柄。
class RunningJob implements CancelSignal {
  RunningJob({required this.provider, required this.handle});
  final Submittable provider;
  final JobHandleImpl handle;
  String? providerJobId;
  @override
  bool cancelled = false;

  /// 当前退避睡眠的句柄；cancel/dispose 经 [wake] 提前唤醒。
  Completer<void>? sleeper;

  void wake() {
    final s = sleeper;
    if (s != null && !s.isCompleted) s.complete();
  }
}
