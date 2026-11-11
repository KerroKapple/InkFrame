// PostgresDirectorRepository —— director_sessions / director_events（迁移 v9）。
//
// seq 分配：appendEvent 在单事务里先 `SELECT … FOR UPDATE` 锁会话行，再取
// MAX(seq)+1——同一会话的并发追加在行锁上排队，号连续不撞；
// uq_director_events_session_seq 唯一索引兜底（真撞了是 23505，翻成 LocalIOError）。
// 读路径与 prompt_presets 同：活项目写在 JOIN 条件里，会话软删的事件一并隐藏。
import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/db/columns.dart';
import '../../core/db/row_reader.dart';
import '../../core/errors/ink_error.dart';
import '../../core/interfaces/director_repository.dart';
import '../../core/models/director.dart';
import '../base_repository.dart';

class PostgresDirectorRepository
    with BaseRepository
    implements DirectorRepository {
  /// [session] 需同时是 [SessionExecutor]（Pool / Connection 均满足）——追加事件要开事务。
  PostgresDirectorRepository(this.session)
      : assert(session is SessionExecutor);

  @override
  final Session session;

  static const String _sessions = 'director_sessions';
  static const String _events = 'director_events';

  static const String _selectAliveSession = 'SELECT ds.* FROM director_sessions ds '
      'JOIN projects p ON p.id = ds.project_id AND p.deleted_at IS NULL';

  @override
  Future<DirectorSession> createSession({
    required String projectId,
    required String canvasId,
    String contentLanguage = '',
    DirectorSetting setting = DirectorSetting.empty,
  }) {
    return guard('createSession', _sessions, () async {
      final Result r = await session.execute(
        Sql.named(
          'INSERT INTO director_sessions '
          '(project_id, canvas_id, content_language, setting) '
          'VALUES (@pid, @cid, @lang, @setting::jsonb) RETURNING *',
        ),
        parameters: <String, Object?>{
          'pid': projectId,
          'cid': canvasId,
          'lang': contentLanguage,
          'setting': jsonEncode(setting.toJson()),
        },
      );
      return _sessionOf(firstRow(r)!);
    });
  }

  @override
  Future<DirectorSession?> findSession(String id) {
    return guard('findSession', _sessions, () async {
      final Result r = await session.execute(
        Sql.named('$_selectAliveSession WHERE ds.id = @id AND ds.deleted_at IS NULL'),
        parameters: <String, Object?>{'id': id},
      );
      final Map<String, Object?>? row = firstRow(r);
      return row == null ? null : _sessionOf(row);
    });
  }

  @override
  Future<DirectorEvent> appendEvent(
    String sessionId, {
    required DirectorEventKind kind,
    int? parentSeq,
    Map<String, Object?> payload = const <String, Object?>{},
    String? contentLanguage,
    DirectorSetting? setting,
  }) {
    return guard('appendEvent', _events, () async {
      return (session as SessionExecutor).runTx<DirectorEvent>((tx) async {
        final Result locked = await tx.execute(
          Sql.named(
            '$_selectAliveSession WHERE ds.id = @id AND ds.deleted_at IS NULL '
            'FOR UPDATE OF ds',
          ),
          parameters: <String, Object?>{'id': sessionId},
        );
        if (locked.isEmpty) {
          throw const LocalIOError(extra: <String, Object?>{
            'op': 'appendEvent',
            'table': _events,
            'reason': 'session_not_found',
          });
        }
        final Result inserted = await tx.execute(
          Sql.named(
            'INSERT INTO director_events (session_id, seq, kind, parent_seq, payload) '
            'SELECT @sid, COALESCE(MAX(seq), 0) + 1, @kind, @parent, @payload::jsonb '
            'FROM director_events WHERE session_id = @sid RETURNING *',
          ),
          parameters: <String, Object?>{
            'sid': sessionId,
            'kind': kind.wire,
            'parent': parentSeq,
            'payload': jsonEncode(payload),
          },
        );
        final Map<String, Object?> patch = <String, Object?>{
          DirectorSessionCol.contentLanguage: ?contentLanguage,
          if (setting != null) DirectorSessionCol.setting: jsonEncode(setting.toJson()),
        };
        final q = buildUpdate(_sessions, sessionId, patch);
        await tx.execute(
          Sql.named(q.sql.replaceFirst(
            '${DirectorSessionCol.setting} = @p_${DirectorSessionCol.setting}',
            '${DirectorSessionCol.setting} = @p_${DirectorSessionCol.setting}::jsonb',
          )),
          parameters: q.params,
        );
        return _eventOf(firstRow(inserted)!);
      });
    });
  }

  @override
  Future<List<DirectorEvent>> listEvents(String sessionId) {
    return guard('listEvents', _events, () async {
      final Result r = await session.execute(
        Sql.named(
          'SELECT de.* FROM director_events de '
          'JOIN director_sessions ds ON ds.id = de.session_id AND ds.deleted_at IS NULL '
          'JOIN projects p ON p.id = ds.project_id AND p.deleted_at IS NULL '
          'WHERE de.session_id = @sid ORDER BY de.seq ASC',
        ),
        parameters: <String, Object?>{'sid': sessionId},
      );
      return allRows(r).map(_eventOf).toList(growable: false);
    });
  }

  @override
  Future<int> softDeleteSession(String id) {
    return guard('softDeleteSession', _sessions, () async {
      final q = buildUpdate(_sessions, id, softDeletePatch());
      final Result r = await session.execute(Sql.named(q.sql), parameters: q.params);
      return r.affectedRows;
    });
  }

  DirectorSession _sessionOf(Map<String, Object?> row) => DirectorSession(
        id: row.reqId(DirectorSessionCol.id),
        projectId: row.reqId(DirectorSessionCol.projectId),
        canvasId: row.reqId(DirectorSessionCol.canvasId),
        contentLanguage: row.reqString(DirectorSessionCol.contentLanguage),
        setting: DirectorSetting.fromJson(_json(row[DirectorSessionCol.setting])),
        createdAt: _time(row, DirectorSessionCol.createdAt),
        updatedAt: _time(row, DirectorSessionCol.updatedAt),
      );

  DirectorEvent _eventOf(Map<String, Object?> row) {
    final String wire = row.reqString(DirectorEventCol.kind);
    final DirectorEventKind? kind = DirectorEventKind.fromWire(wire);
    if (kind == null) {
      throw LocalIOError(extra: <String, Object?>{
        'op': 'decode',
        'column': DirectorEventCol.kind,
        'actual': wire,
      });
    }
    final Object? payload = _json(row[DirectorEventCol.payload]);
    return DirectorEvent(
      id: row.reqId(DirectorEventCol.id),
      sessionId: row.reqId(DirectorEventCol.sessionId),
      seq: row.reqInt(DirectorEventCol.seq),
      kind: kind,
      parentSeq: row.optInt(DirectorEventCol.parentSeq),
      payload: payload is Map ? payload.cast<String, Object?>() : const <String, Object?>{},
      createdAt: _time(row, DirectorEventCol.createdAt),
    );
  }

  /// JSONB 驱动通常回已解码的值；兜住回文本的情形。
  Object? _json(Object? raw) => raw is String ? jsonDecode(raw) : raw;

  DateTime _time(Map<String, Object?> row, String col) {
    final DateTime? t = row.optDateTime(col);
    if (t == null) {
      throw LocalIOError(extra: <String, Object?>{'op': 'decode', 'column': col});
    }
    return t;
  }
}
