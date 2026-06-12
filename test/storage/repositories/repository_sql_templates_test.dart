// Repository SQL 模板单测（不触 PG）：
//   - 各 repo 的 create / list / softDelete / transition SQL 骨架正确
//   - 参数正确绑定
//   - JobRepository.transitionStatus 使用 ANY(@from)
//   - PurgeExpired / PurgePerCanvasCap 包含 PRD §21 retention 字面量
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/repositories/postgres_batch_result_repository.dart';
import 'package:inkframe/storage/repositories/postgres_canvas_repository.dart';
import 'package:inkframe/storage/repositories/postgres_edge_repository.dart';
import 'package:inkframe/storage/repositories/postgres_job_repository.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:inkframe/storage/repositories/postgres_project_repository.dart';
import 'package:inkframe/storage/repositories/postgres_style_lane_repository.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('ProjectRepository SQL', () {
    test('create 使用 RETURNING id', () async {
      final spy = _SpySession(returnRows: const [
        ['new-id']
      ]);
      final repo = PostgresProjectRepository(spy);
      final id = await repo.create(name: 'P');
      expect(id, 'new-id');
      expect(spy.lastSql, contains('INSERT INTO projects'));
      expect(spy.lastSql, contains('RETURNING id'));
    });

    test('listAll 过滤 deleted_at IS NULL 并按 created_at DESC', () async {
      final spy = _SpySession();
      await PostgresProjectRepository(spy).listAll();
      expect(spy.lastSql, contains('WHERE deleted_at IS NULL'));
      expect(spy.lastSql, contains('ORDER BY created_at DESC'));
    });

    test('listTrashed 过滤 deleted_at IS NOT NULL', () async {
      final spy = _SpySession();
      await PostgresProjectRepository(spy).listTrashed();
      expect(spy.lastSql, contains('deleted_at IS NOT NULL'));
    });

    test('softDelete 写 deleted_at', () async {
      final spy = _SpySession();
      await PostgresProjectRepository(spy).softDelete('p1');
      expect(spy.lastSql, contains('UPDATE projects SET'));
      expect(spy.lastParams?['p_deleted_at'], isA<String>());
    });
  });

  group('CanvasRepository SQL', () {
    test('create 带 base_style', () async {
      final spy = _SpySession(returnRows: const [
        ['c1']
      ]);
      final id = await PostgresCanvasRepository(spy).create(
        projectId: 'p',
        name: 'C',
        baseStylePrefix: 'pre',
        baseStyleSuffix: 'suf',
      );
      expect(id, 'c1');
      expect(spy.lastSql, contains('INSERT INTO canvases'));
      expect(spy.lastParams?['pre'], 'pre');
      expect(spy.lastParams?['suf'], 'suf');
    });

    test('listByProject 过滤 + order ASC', () async {
      final spy = _SpySession();
      await PostgresCanvasRepository(spy).listByProject('p1');
      expect(spy.lastSql, contains('project_id = @pid'));
      expect(spy.lastSql, contains('ORDER BY created_at ASC'));
    });
  });

  group('NodeRepository SQL', () {
    test('create 将 type_config JSON 编码 + ::jsonb cast', () async {
      final spy = _SpySession(returnRows: const [
        ['n1']
      ]);
      await PostgresNodeRepository(spy).create(
        canvasId: 'c',
        type: 'image',
        nodeRole: 'config',
        typeConfig: {'prompt': 'hello'},
      );
      expect(spy.lastSql, contains('@cfg::jsonb'));
      expect(spy.lastParams?['cfg'], contains('"prompt":"hello"'));
    });

    test('listOrphanResults 使用 node_role result + source_node_id IS NULL',
        () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listOrphanResults('c');
      expect(spy.lastSql, contains("node_role = 'result'"));
      expect(spy.lastSql, contains('source_node_id IS NULL'));
    });

    // CR-01：nodes 行必须带 project_id（来自 canvases JOIN），
    // 否则生成链路读到 null → 产物静默丢弃。
    test('findById JOIN canvases 带出 project_id', () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).findById('n1');
      expect(spy.lastSql, contains('c.project_id'));
      expect(spy.lastSql, contains('JOIN canvases c ON c.id = n.canvas_id'));
      expect(spy.lastSql, contains('n.deleted_at IS NULL'));
    });

    test('listByCanvas JOIN canvases 带出 project_id 并保持排序', () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listByCanvas('c1');
      expect(spy.lastSql, contains('c.project_id'));
      expect(spy.lastSql, contains('JOIN canvases c ON c.id = n.canvas_id'));
      expect(spy.lastSql, contains('ORDER BY n.z_index ASC, n.created_at ASC'));
    });

    test('listOrphanResults JOIN canvases 带出 project_id', () async {
      final spy = _SpySession();
      await PostgresNodeRepository(spy).listOrphanResults('c1');
      expect(spy.lastSql, contains('c.project_id'));
      expect(spy.lastSql, contains('JOIN canvases c ON c.id = n.canvas_id'));
    });
  });

  group('EdgeRepository SQL', () {
    test('create 绑定 UNIQUE 关键参数', () async {
      final spy = _SpySession(returnRows: const [
        ['e1']
      ]);
      await PostgresEdgeRepository(spy).create(
        canvasId: 'c',
        sourceNodeId: 'a',
        targetNodeId: 'b',
        edgeType: 'data',
      );
      expect(spy.lastParams?['src'], 'a');
      expect(spy.lastParams?['tgt'], 'b');
      expect(spy.lastParams?['type'], 'data');
      expect(spy.lastParams?['role'], 'reference');
    });

    test('softDelete 写 deleted_at（edges 表无 updated_at）', () async {
      final spy = _SpySession();
      await PostgresEdgeRepository(spy).softDelete('e1');
      expect(spy.lastSql, contains('UPDATE edges SET deleted_at'));
      expect(spy.lastSql, isNot(contains('updated_at')));
    });

    test('listOutgoing / listIncoming SQL 匹配', () async {
      final spy = _SpySession();
      await PostgresEdgeRepository(spy).listOutgoing('a');
      expect(spy.lastSql, contains('source_node_id = @sid'));
      await PostgresEdgeRepository(spy).listIncoming('b');
      expect(spy.lastSql, contains('target_node_id = @tid'));
    });
  });

  group('StyleLaneRepository SQL', () {
    test('listByCanvas 按 sort_order ASC', () async {
      final spy = _SpySession();
      await PostgresStyleLaneRepository(spy).listByCanvas('c');
      expect(spy.lastSql, contains('ORDER BY sort_order ASC'));
    });
  });

  group('JobRepository SQL', () {
    test('create 将 parameters 序列化为 jsonb', () async {
      final spy = _SpySession(returnRows: const [
        ['j1']
      ]);
      await PostgresJobRepository(spy).create(
        canvasId: 'c',
        sourceNodeId: 'n',
        providerId: 'kling',
        jobType: 'image',
        fullPrompt: 'fp',
        userPrompt: 'up',
        parameters: {'model': 'kling'},
      );
      expect(spy.lastSql, contains('@params::jsonb'));
      expect(spy.lastParams?['params'], contains('"model":"kling"'));
      // 死列处置：retry 由 JobQueue 内存退避负责，INSERT 不再写 max_retries
      expect(spy.lastSql, isNot(contains('max_retries')));
    });

    test('listDuePolling 过滤 polling + next_poll_at', () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy).listDuePolling(10);
      expect(spy.lastSql, contains("status = 'polling'"));
      expect(spy.lastSql, contains('next_poll_at'));
    });

    test('transitionStatus 使用 ANY(@from) 做原子跃迁', () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy).transitionStatus(
        id: 'j1',
        fromStatuses: const ['pending', 'submitted'],
        toStatus: 'polling',
        extra: {'remote_task_id': 'x'},
      );
      expect(spy.lastSql, contains('UPDATE jobs SET status = @to'));
      expect(spy.lastSql, contains('ANY(@from)'));
      expect(spy.lastSql, contains('remote_task_id = @p_remote_task_id'));
      expect(spy.lastParams?['from'], const ['pending', 'submitted']);
      expect(spy.lastParams?['to'], 'polling');
    });

    test('purgeExpired 包含 retention 30 天字面量 + 孤儿保留子查询', () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy)
          .purgeExpired(retention: const Duration(days: 30));
      expect(spy.lastSql, contains('DELETE FROM jobs'));
      expect(spy.lastSql, contains('completed_at <'));
      expect(spy.lastSql, contains('source_node_id IS NULL'));
      expect(spy.lastParams?['days'], 30);
    });

    test('purgePerCanvasCap 使用 ROW_NUMBER PARTITION BY，且只清终态行', () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy).purgePerCanvasCap(cap: 500);
      expect(spy.lastSql, contains('ROW_NUMBER() OVER'));
      expect(spy.lastSql, contains('PARTITION BY canvas_id'));
      expect(spy.lastParams?['cap'], 500);
      // ME-32：在途 job（pending/submitted/polling）绝不被限额清除
      expect(
        spy.lastSql,
        contains("status IN ('success','error','cancelled','timeout')"),
      );
    });

    test('update 对 parameters 做 ::jsonb cast', () async {
      final spy = _SpySession();
      await PostgresJobRepository(spy).update('j1', {
        'parameters': {'k': 'v'},
      });
      expect(spy.lastSql, contains('parameters = @p_parameters::jsonb'));
    });
  });

  group('BatchResultRepository SQL', () {
    test('findBySlot 按 (node_id, slot_index) 定位', () async {
      final spy = _SpySession();
      await PostgresBatchResultRepository(spy).findBySlot('n', 3);
      expect(spy.lastSql, contains('node_id = @nid AND slot_index = @si'));
      expect(spy.lastParams?['nid'], 'n');
      expect(spy.lastParams?['si'], 3);
    });

    test('markPromoted 写 promoted + promoted_node_id', () async {
      final spy = _SpySession();
      await PostgresBatchResultRepository(spy)
          .markPromoted(id: 'br1', promotedNodeId: 'n2');
      expect(spy.lastSql, contains('promoted = true'));
      expect(spy.lastSql, contains('promoted_node_id = @pnid'));
    });
  });
}

class _SpySession implements Session {
  _SpySession({this.returnRows = const []});
  final List<List<Object?>> returnRows;
  String? lastSql;
  Map<String, Object?>? lastParams;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    if (query is String) {
      lastSql = query;
    } else {
      try {
        lastSql = (query as dynamic).sql as String;
      } on NoSuchMethodError {
        lastSql = query.toString();
      }
    }
    if (parameters is Map<String, Object?>) {
      lastParams = parameters;
    } else if (parameters is Map) {
      lastParams = parameters.cast<String, Object?>();
    }
    return Result(
      rows: returnRows
          .map((v) => ResultRow(values: v, schema: ResultSchema(const [])))
          .toList(),
      affectedRows: returnRows.length,
      schema: ResultSchema(const []),
    );
  }

  @override
  Future<Statement> prepare(Object query) => throw UnimplementedError();
  @override
  bool get isOpen => true;
  @override
  Future<void> get closed async {}
}
