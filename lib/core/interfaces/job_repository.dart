// JobRepository 契约：jobs 表——生成任务真相源（PRD §4.5.1）。
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

  Future<Map<String, Object?>?> findById(String id);

  /// 按 status 过滤，常用于 JobQueueService 恢复扫描。
  Future<List<Map<String, Object?>>> listByStatus(List<String> statuses);

  /// 下一个应轮询的 job（status='polling' AND next_poll_at <= now()），limit 条。
  Future<List<Map<String, Object?>>> listDuePolling(int limit);

  /// 按画布列出，created_at DESC。
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId, {int limit = 200});

  Future<int> update(String id, Map<String, Object?> patch);

  /// 原子状态跃迁：仅当 current status 在 from 集合内时更新。返回受影响行数（0/1）。
  Future<int> transitionStatus({
    required String id,
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
