// jobs / batch_results 状态**列**的字符串常量——业务逻辑的单一真相源。
//
// 值必须与 schema CHECK 完全对齐（schema_v1.dart：jobs.status 七态 :179 /
// batch_results.status 四态 :214）。schema DDL 是 DB 层契约（SQL 字面量），
// 本文件是 Dart 层引用点；二者对齐，业务代码一律引用本文件、不再散落字面量。
// LB-01：LB-03（JobQueue 拆分）的降噪前置。
//
// 命名区分（勿混）：
//   - [JobStatuses] / [SlotStatuses]（本文件）：**持久化状态列的字符串值**。
//   - `JobStatus`（core/models/job_status.dart）：Provider 单次 poll 的瞬时结果（sealed）。
//   - `JobState`（features/generation/models/job_state.dart）：UI 状态机（sealed）。
//   见 ADR-0008。

/// jobs.status 七态（持久化字符串值）。
abstract final class JobStatuses {
  static const String pending = 'pending';
  static const String submitted = 'submitted';
  static const String polling = 'polling';
  static const String success = 'success';
  static const String error = 'error';
  static const String cancelled = 'cancelled';
  static const String timeout = 'timeout';

  /// 全集（与 schema CHECK 一致，顺序无关）。
  static const Set<String> all = <String>{
    pending,
    submitted,
    polling,
    success,
    error,
    cancelled,
    timeout,
  };

  /// 终态（不再推进）——retention/purge 与收敛逻辑用。
  static const Set<String> terminal = <String>{
    success,
    error,
    cancelled,
    timeout,
  };
}

/// batch_results.status（slot）四态（持久化字符串值）。
abstract final class SlotStatuses {
  static const String generating = 'generating';
  static const String success = 'success';
  static const String error = 'error';
  static const String cancelled = 'cancelled';

  /// 全集（与 schema CHECK 一致，顺序无关）。
  static const Set<String> all = <String>{
    generating,
    success,
    error,
    cancelled,
  };
}
