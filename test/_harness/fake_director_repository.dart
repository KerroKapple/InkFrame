// InMemoryDirectorRepository：内存版导演会话 / 事件日志（seq 分配与真仓储同口径）。
//
// payload 经 JSON 往返存储——与真库 JSONB 一样，读回来的是新解码的值，不是调用方那份对象。
import 'dart:convert';

import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/director_repository.dart';
import 'package:inkframe/core/models/director.dart';

class InMemoryDirectorRepository implements DirectorRepository {
  InMemoryDirectorRepository({DateTime Function()? now})
      : _now = now ?? (() => DateTime.utc(2026, 11, 11, 9));

  final DateTime Function() _now;
  final Map<String, DirectorSession> sessions = <String, DirectorSession>{};
  final Map<String, List<DirectorEvent>> _events = <String, List<DirectorEvent>>{};
  final Set<String> _deleted = <String>{};
  int _ids = 0;

  /// 第 n 次 appendEvent（0 起）抛 LocalIOError；null = 不失败。
  int? failAppendAt;
  int _appends = 0;

  List<DirectorEvent> eventsOf(String sessionId) =>
      List<DirectorEvent>.unmodifiable(_events[sessionId] ?? const <DirectorEvent>[]);

  @override
  Future<DirectorSession> createSession({
    required String projectId,
    required String canvasId,
    String contentLanguage = '',
    DirectorSetting setting = DirectorSetting.empty,
  }) async {
    final String id = 'ds${_ids++}';
    final DirectorSession s = DirectorSession(
      id: id,
      projectId: projectId,
      canvasId: canvasId,
      contentLanguage: contentLanguage,
      setting: setting,
      createdAt: _now(),
      updatedAt: _now(),
    );
    sessions[id] = s;
    _events[id] = <DirectorEvent>[];
    return s;
  }

  @override
  Future<DirectorSession?> findSession(String id) async =>
      _deleted.contains(id) ? null : sessions[id];

  @override
  Future<DirectorEvent> appendEvent(
    String sessionId, {
    required DirectorEventKind kind,
    int? parentSeq,
    Map<String, Object?> payload = const <String, Object?>{},
    String? contentLanguage,
    DirectorSetting? setting,
  }) async {
    if (_appends++ == failAppendAt) throw const LocalIOError();
    final DirectorSession? s = await findSession(sessionId);
    if (s == null) {
      throw const LocalIOError(extra: <String, Object?>{'reason': 'session_not_found'});
    }
    final List<DirectorEvent> list = _events[sessionId]!;
    final int seq = list.length + 1;
    assert(parentSeq == null || parentSeq < seq, 'parent_seq must precede seq');
    final DirectorEvent e = DirectorEvent(
      id: 'de${_ids++}',
      sessionId: sessionId,
      seq: seq,
      kind: kind,
      parentSeq: parentSeq,
      payload: (jsonDecode(jsonEncode(payload)) as Map).cast<String, Object?>(),
      createdAt: _now(),
    );
    list.add(e);
    sessions[sessionId] = s.copyWith(
      contentLanguage: contentLanguage,
      setting: setting,
      updatedAt: _now(),
    );
    return e;
  }

  @override
  Future<List<DirectorEvent>> listEvents(String sessionId) async =>
      _deleted.contains(sessionId) ? const <DirectorEvent>[] : eventsOf(sessionId);

  @override
  Future<int> softDeleteSession(String id) async {
    if (!sessions.containsKey(id) || !_deleted.add(id)) return 0;
    return 1;
  }
}
