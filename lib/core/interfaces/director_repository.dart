// DirectorRepository 契约：director_sessions + director_events（迁移 v9，ADR-0015）。
//
// 事件只追加：没有改 / 删事件的方法。会话软删后它和它的事件都读不到。
// 唯一写入口是 features/director 的 DirectorSessionController。
import '../models/director.dart';

abstract class DirectorRepository {
  /// 新建会话；返回落库后的会话（id / 时间戳由库生成）。
  Future<DirectorSession> createSession({
    required String projectId,
    required String canvasId,
    String contentLanguage = '',
    DirectorSetting setting = DirectorSetting.empty,
  });

  /// 活会话（会话与所属项目都没软删）；不存在 ⇒ null。
  Future<DirectorSession?> findSession(String id);

  /// 追加一件事件，返回带 seq 的事件行。
  ///
  /// 单事务：锁会话行 → 取下一个 seq（会话内连续，从 1 起）→ 插事件 → touch 会话
  /// updated_at；[contentLanguage] / [setting] 非 null 时同一事务写回会话
  /// （让会话字段的每次变化都有一件事件作依据）。
  /// 会话不存在或已软删 ⇒ LocalIOError(reason: session_not_found)。
  Future<DirectorEvent> appendEvent(
    String sessionId, {
    required DirectorEventKind kind,
    int? parentSeq,
    Map<String, Object?> payload = const <String, Object?>{},
    String? contentLanguage,
    DirectorSetting? setting,
  });

  /// 会话的全部事件，按 seq 升序；会话软删 ⇒ 空。
  Future<List<DirectorEvent>> listEvents(String sessionId);

  Future<int> softDeleteSession(String id);
}
