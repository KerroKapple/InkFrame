// PostgresJobRepository —— jobs 表实现。
import 'dart:convert';

import 'package:postgres/postgres.dart';

import '../../core/interfaces/job_repository.dart';
import '../base_repository.dart';

class PostgresJobRepository with BaseRepository implements JobRepository {
  PostgresJobRepository(this.session);

  @override
  final Session session;

  @override
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
    int maxRetries = 3,
    DateTime? timeoutAt,
  }) {
    return guard('create', 'jobs', () async {
      final r = await session.execute(
        Sql.named(
          'INSERT INTO jobs (canvas_id, source_node_id, result_node_id, provider_id, '
          'job_type, full_prompt, user_prompt, parameters, batch_size, max_retries, timeout_at) '
          'VALUES (@cid, @src, @rn, @pid, @jt, @fp, @up, @params::jsonb, @bs, @mr, @toa) '
          'RETURNING id',
        ),
        parameters: <String, Object?>{
          'cid': canvasId,
          'src': sourceNodeId,
          'rn': resultNodeId,
          'pid': providerId,
          'jt': jobType,
          'fp': fullPrompt,
          'up': userPrompt,
          'params': jsonEncode(parameters),
          'bs': batchSize,
          'mr': maxRetries,
          'toa': timeoutAt?.toUtc().toIso8601String(),
        },
      );
      return r.first[0]!.toString();
    });
  }

  @override
  Future<Map<String, Object?>?> findById(String id) {
    return guard('findById', 'jobs', () async {
      final r = await session.execute(
        Sql.named('SELECT * FROM jobs WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return firstRow(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> statuses) {
    if (statuses.isEmpty) return Future.value(const []);
    return guard('listByStatus', 'jobs', () async {
      final r = await session.execute(
        Sql.named(
          'SELECT * FROM jobs WHERE status = ANY(@ss) ORDER BY created_at ASC',
        ),
        parameters: <String, Object?>{'ss': statuses},
      );
      return allRows(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listDuePolling(int limit) {
    return guard('listDuePolling', 'jobs', () async {
      final r = await session.execute(
        Sql.named(
          "SELECT * FROM jobs WHERE status = 'polling' "
          'AND (next_poll_at IS NULL OR next_poll_at <= now()) '
          'ORDER BY next_poll_at ASC NULLS FIRST, created_at ASC LIMIT @lim',
        ),
        parameters: <String, Object?>{'lim': limit},
      );
      return allRows(r);
    });
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(
    String canvasId, {
    int limit = 200,
  }) {
    return guard('listByCanvas', 'jobs', () async {
      final r = await session.execute(
        Sql.named(
          'SELECT * FROM jobs WHERE canvas_id = @cid '
          'ORDER BY created_at DESC LIMIT @lim',
        ),
        parameters: <String, Object?>{'cid': canvasId, 'lim': limit},
      );
      return allRows(r);
    });
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) {
    if (patch.isEmpty) return Future.value(0);
    return guard('update', 'jobs', () async {
      // jobs 无 updated_at 列（PRD §21 jobs DDL），直接拼。
      final normalized = <String, Object?>{};
      patch.forEach((k, v) {
        if (k == 'parameters' && v is Map<String, Object?>) {
          normalized[k] = jsonEncode(v);
        } else {
          normalized[k] = v;
        }
      });
      final setParts = <String>[];
      final params = <String, Object?>{'id': id};
      normalized.forEach((k, v) {
        final p = 'p_$k';
        setParts.add(
          k == 'parameters' ? '$k = @$p::jsonb' : '$k = @$p',
        );
        params[p] = v;
      });
      final r = await session.execute(
        Sql.named(
          'UPDATE jobs SET ${setParts.join(', ')} WHERE id = @id',
        ),
        parameters: params,
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> transitionStatus({
    required String id,
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    return guard('transitionStatus', 'jobs', () async {
      final extraSet = <String>[];
      final params = <String, Object?>{
        'id': id,
        'from': fromStatuses,
        'to': toStatus,
      };
      extra.forEach((k, v) {
        final p = 'p_$k';
        extraSet.add(', $k = @$p');
        params[p] = v;
      });
      final r = await session.execute(
        Sql.named(
          'UPDATE jobs SET status = @to${extraSet.join()} '
          'WHERE id = @id AND status = ANY(@from)',
        ),
        parameters: params,
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> purgeExpired({required Duration retention}) {
    return guard('purgeExpired', 'jobs', () async {
      // PRD §21 retention：30 天终态 job，保留孤儿 result 依赖。
      final r = await session.execute(
        Sql.named(
          'DELETE FROM jobs j '
          "WHERE j.status IN ('success','error','cancelled','timeout') "
          "AND j.completed_at < now() - (@days::text || ' days')::interval "
          'AND NOT EXISTS ( '
          'SELECT 1 FROM nodes n WHERE n.id = j.result_node_id '
          'AND n.deleted_at IS NULL AND n.source_node_id IS NULL)',
        ),
        parameters: <String, Object?>{'days': retention.inDays},
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> purgePerCanvasCap({required int cap}) {
    return guard('purgePerCanvasCap', 'jobs', () async {
      final r = await session.execute(
        Sql.named(
          'WITH ranked AS ( '
          '  SELECT id, ROW_NUMBER() OVER ( '
          '    PARTITION BY canvas_id ORDER BY created_at DESC) AS rn, '
          '    result_node_id FROM jobs) '
          'DELETE FROM jobs WHERE id IN ( '
          '  SELECT r.id FROM ranked r WHERE r.rn > @cap '
          '  AND NOT EXISTS ( '
          '    SELECT 1 FROM nodes n WHERE n.id = r.result_node_id '
          '    AND n.deleted_at IS NULL AND n.source_node_id IS NULL))',
        ),
        parameters: <String, Object?>{'cap': cap},
      );
      return r.affectedRows;
    });
  }

  @override
  Future<int> hardDelete(String id) {
    return guard('hardDelete', 'jobs', () async {
      final r = await session.execute(
        Sql.named('DELETE FROM jobs WHERE id = @id'),
        parameters: <String, Object?>{'id': id},
      );
      return r.affectedRows;
    });
  }
}
