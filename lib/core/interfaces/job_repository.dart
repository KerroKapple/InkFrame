// JobRepository 契约：jobs 表——生成任务真相源（PRD §4.5.1）。
//
// 【刻意没有读路径】曾有 findById / listByStatus / listByCanvas 三条，在 lib/ 下
// 零消费点、只被测试养着（listByStatus 的位置早被 bulkTransition 的单条 UPDATE
// 顶掉——启动孤儿回收不再先读一遍再逐行改）。已退役。
// 真要复活（任务面板 / 诊断页）得在同一个 PR 里接上调用点，并当场定夺「是
// JOIN canvases … AND c.deleted_at IS NULL，还是沿用队列恢复看全库的语义」
// ——jobs 表自己没有 deleted_at 列，这个取舍绕不开。
// 守这条的是 test/quality/job_repository_reachability_test.dart。
abstract class JobRepository {
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    String? resultNodeId,
    required String providerId,
    required String jobType,
    required String fullPrompt,
    required String userPrompt,
    Map<String, Object?> parameters = const <String, Object?>{},
    int batchSize = 1,
    DateTime? timeoutAt,
  });

  Future<int> update(String id, Map<String, Object?> patch);

  /// 原子状态跃迁：仅当 current status 在 from 集合内时更新。返回受影响行数（0/1）。
  Future<int> transitionStatus({
    required String id,
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  });

  /// 批量状态跃迁：所有 status ∈ [fromStatuses] 的行一次性置 [toStatus]（+ extra 列），
  /// 返回受影响行数。无 per-row 并发仲裁——用于启动期无并发的孤儿回收（单条 UPDATE，消除 N+1）。
  Future<int> bulkTransition({
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  });

  /// 按 PRD §21 retention：清 30 天前终态 job，排除孤儿 result 依赖。
  Future<int> purgeExpired({required Duration retention});

  /// 按 canvas 限额 500——只清终态行（在途 job 不占槽位也不被删），
  /// 排除孤儿 result 依赖。
  Future<int> purgePerCanvasCap({required int cap});

  Future<int> hardDelete(String id);
}
