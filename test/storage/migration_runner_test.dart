// MigrationRunner 单测：currentVersion / 顺序执行 / 高版本拒绝 / gap 拦截 / 事务边界。
// 真 PG 场景（含 42P01 空库分支）由 migration_runner_integration_test.dart 覆盖。
//
// ME-31：每条迁移的 DDL + schema_version UPSERT 必须在同一事务（runTx）内，
// 失败时回滚且不写版本号。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:inkframe/storage/schema/schema_v1.dart';
import 'package:inkframe/storage/schema/schema_v3.dart';
import 'package:inkframe/storage/schema/schema_v4.dart';
import 'package:inkframe/storage/schema/schema_v5.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('MigrationRunner', () {
    test('schema_version 表返回空 → 视为 v=0，事务内执行 v=1 + 写版本', () async {
      final exec = _FakeExecutor()
        ..session.queueResult(const [], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        exec,
        migrations: const [Migration(version: 1, sql: 'DDL-v1')],
      );
      await runner.migrate();
      expect(
        exec.session.executedSql,
        orderedEquals(<Object>[
          contains('FROM schema_version'),
          'BEGIN',
          contains('DDL-v1'),
          contains('INSERT INTO schema_version'),
          'COMMIT',
        ]),
      );
    });

    test('已 v=1 无缺失 → no-op，不开事务', () async {
      final exec = _FakeExecutor()
        ..session.queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        exec,
        migrations: const [Migration(version: 1, sql: 'DDL-v1')],
      );
      await runner.migrate();
      expect(exec.session.executedSql.length, 1);
      expect(exec.txCount, 0);
    });

    test('当前 v=1，目标 v=3 → 每版本独立事务：DDL + 版本 UPSERT 同事务', () async {
      final exec = _FakeExecutor()
        ..session.queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version');

      final runner = MigrationRunner(
        exec,
        migrations: const [
          Migration(version: 1, sql: 'DDL-v1'),
          Migration(version: 2, sql: 'DDL-v2'),
          Migration(version: 3, sql: 'DDL-v3'),
        ],
      );
      await runner.migrate();

      final sql = exec.session.executedSql;
      expect(exec.txCount, 2);
      // v2 事务
      expect(sql[1], 'BEGIN');
      expect(sql[2], 'DDL-v2');
      expect(sql[3], contains('VALUES (1, 2)'));
      expect(sql[4], 'COMMIT');
      // v3 事务
      expect(sql[5], 'BEGIN');
      expect(sql[6], 'DDL-v3');
      expect(sql[7], contains('VALUES (1, 3)'));
      expect(sql[8], 'COMMIT');
    });

    test('迁移 SQL 抛错 → 事务回滚，版本号不写入，错误冒泡', () async {
      final exec = _FakeExecutor()
        ..session.queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version')
        ..session.failOn = 'DDL-v2';
      final runner = MigrationRunner(
        exec,
        migrations: const [
          Migration(version: 1, sql: 'DDL-v1'),
          Migration(version: 2, sql: 'DDL-v2'),
        ],
      );
      await expectLater(runner.migrate, throwsA(isA<StateError>()));
      final sql = exec.session.executedSql;
      expect(sql.last, 'ROLLBACK');
      expect(
        sql.where((s) => s.contains('INSERT INTO schema_version')),
        isEmpty,
        reason: '失败迁移绝不写版本号',
      );
    });

    test('数据库版本高于应用期望 → 拒绝', () async {
      final exec = _FakeExecutor()
        ..session.queueResult(const [
          [5],
        ], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        exec,
        migrations: const [
          Migration(version: 1, sql: 'DDL-v1'),
          Migration(version: 2, sql: 'DDL-v2'),
        ],
      );
      await expectLater(runner.migrate, throwsA(isA<SchemaMigrationError>()));
    });

    test('迁移列表存在 gap → 拒绝', () async {
      final exec = _FakeExecutor()
        ..session.queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        exec,
        migrations: const [
          Migration(version: 1, sql: 'DDL-v1'),
          Migration(version: 3, sql: 'DDL-v3'),
        ],
      );
      await expectLater(runner.migrate, throwsA(isA<SchemaMigrationError>()));
    });

    test('schema_v1 SQL 常量包含关键表/CHECK/索引，且不再自写版本号', () {
      for (final needle in <String>[
        'CREATE TABLE projects',
        'CREATE TABLE canvases',
        'CREATE TABLE style_lanes',
        'CREATE TABLE nodes',
        'CREATE TABLE edges',
        'CREATE TABLE jobs',
        'CREATE TABLE batch_results',
        'CREATE TABLE IF NOT EXISTS schema_version',
        'CHECK (id = 1)',
        'chk_grid_consistency',
        'chk_job_prompt_len',
        'chk_projects_name',
        'chk_canvases_name',
        'chk_node_label_len',
        'chk_lane_label_len',
        'chk_lane_prompt_len',
        'chk_base_style_len',
        'CHECK (progress BETWEEN 0.0 AND 1.0)',
        "CHECK (type IN ('image','video','text','shot'))",
        "CHECK (node_role IN ('config','result'))",
        "CHECK (edge_type IN ('data','narrative','generation_source'))",
        "CHECK (role IN ('reference','first_frame','last_frame'))",
        'UNIQUE (source_node_id, target_node_id, edge_type)',
        'UNIQUE (node_id, slot_index)',
        'idx_nodes_deleted',
        'idx_jobs_next_poll',
      ]) {
        expect(kSchemaV1, contains(needle), reason: 'missing: $needle');
      }
      // ME-31：版本号统一由 runner 在事务内 UPSERT，v1 不再自写。
      expect(kSchemaV1, isNot(contains('INSERT INTO schema_version')));
    });

    test('schema_v3 SQL 常量：部分唯一索引 + cover FK + 死 retry 列删除', () {
      // HI-10：软删行不占唯一槽位
      expect(kSchemaV3, contains('DROP CONSTRAINT'));
      expect(kSchemaV3, contains('CREATE UNIQUE INDEX uq_edges_live'));
      expect(kSchemaV3, contains('WHERE deleted_at IS NULL'));
      // LO-14：cover_node_id FK SET NULL
      expect(kSchemaV3, contains('projects_cover_node_id_fkey'));
      expect(kSchemaV3, contains('ON DELETE SET NULL'));
      // 死列处置：retry 由 JobQueue 内存退避负责（FIX-003 ME-04），列删除
      expect(kSchemaV3, contains('DROP COLUMN retry_count'));
      expect(kSchemaV3, contains('DROP COLUMN max_retries'));
    });

    test('schema_v4 SQL 常量：删除续轮死列 next_poll_at + 死索引', () {
      // 崩溃-续轮决策 B：cancel-on-restart 终态设计，续轮死列/索引删除
      expect(kSchemaV4, contains('DROP INDEX IF EXISTS idx_jobs_next_poll'));
      expect(kSchemaV4, contains('DROP COLUMN next_poll_at'));
    });

    test('schema_v5 SQL 常量：jobs(canvas_id, created_at DESC) 复合索引', () {
      expect(kSchemaV5,
          contains('CREATE INDEX IF NOT EXISTS idx_jobs_canvas_created'));
      expect(kSchemaV5, contains('jobs(canvas_id, created_at DESC)'));
    });
  });
}

/// 假 SessionExecutor：run 直通共享 session；runTx 记录 BEGIN/COMMIT/ROLLBACK。
class _FakeExecutor implements SessionExecutor {
  final _FakeSession session = _FakeSession();
  int txCount = 0;

  @override
  Future<R> run<R>(
    Future<R> Function(Session session) fn, {
    SessionSettings? settings,
  }) =>
      fn(session);

  @override
  Future<R> runTx<R>(
    Future<R> Function(TxSession session) fn, {
    TransactionSettings? settings,
  }) async {
    txCount += 1;
    session.executedSql.add('BEGIN');
    try {
      final r = await fn(_FakeTxSession(session));
      session.executedSql.add('COMMIT');
      return r;
    } catch (_) {
      session.executedSql.add('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> close({bool force = false}) async {}
}

class _FakeTxSession implements TxSession {
  _FakeTxSession(this._inner);
  final _FakeSession _inner;

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) =>
      _inner.execute(
        query,
        parameters: parameters,
        ignoreRows: ignoreRows,
        queryMode: queryMode,
        timeout: timeout,
      );

  @override
  Future<void> rollback() async {}

  @override
  Future<Statement> prepare(Object query) =>
      throw UnimplementedError('prepare not used in migration tests');

  @override
  bool get isOpen => true;

  @override
  Future<void> get closed async {}
}

class _FakeSession implements Session {
  final List<String> executedSql = <String>[];
  final List<_Expectation> _queue = <_Expectation>[];

  /// 命中该片段的 SQL 直接抛错（模拟迁移失败）。
  String? failOn;

  void queueResult(List<List<Object?>> rows,
      {required String forQueryFragment}) {
    _queue.add(_Expectation(fragment: forQueryFragment, rows: rows));
  }

  @override
  Future<Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    QueryMode? queryMode,
    Duration? timeout,
  }) async {
    final sql = query.toString();
    executedSql.add(sql);
    final f = failOn;
    if (f != null && sql.contains(f)) {
      throw StateError('boom: $f');
    }
    final idx = _queue.indexWhere((e) => sql.contains(e.fragment));
    if (idx == -1) {
      return _emptyResult();
    }
    final match = _queue.removeAt(idx);
    return Result(
      rows: match.rows
          .map(
            (values) =>
                ResultRow(values: values, schema: ResultSchema(const [])),
          )
          .toList(),
      affectedRows: 0,
      schema: ResultSchema(const []),
    );
  }

  Result _emptyResult() => Result(
        rows: const [],
        affectedRows: 0,
        schema: ResultSchema(const []),
      );

  @override
  Future<Statement> prepare(Object query) =>
      throw UnimplementedError('prepare not used in migration tests');

  @override
  bool get isOpen => true;

  @override
  Future<void> get closed async {}
}

class _Expectation {
  _Expectation({required this.fragment, required this.rows});
  final String fragment;
  final List<List<Object?>> rows;
}
