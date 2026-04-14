// MigrationRunner 单测：currentVersion / 顺序执行 / 高版本拒绝 / gap 拦截。
// 真 PG 场景（含 42P01 空库分支）由 schema_integration_test.dart 覆盖。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/migrations/migration_runner.dart';
import 'package:inkframe/storage/schema/schema_v1.dart';
import 'package:postgres/postgres.dart';

void main() {
  group('MigrationRunner', () {
    test('schema_version 表返回空 → 视为 v=0，执行 v=1 迁移', () async {
      // 真实 PG 上，表不存在会抛 42P01；这里 runner 先做 SELECT；
      // 此用例测的是"表存在但无行"的退化分支（同样 current=0）。
      final session = _FakeSession()
        ..queueResult(const [], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        session,
        migrations: const [Migration(version: 1, sql: 'DDL-v1')],
      );
      await runner.migrate();
      expect(session.executedSql.length, 2);
      expect(session.executedSql[1], contains('DDL-v1'));
    });

    test('已 v=1 无缺失 → no-op', () async {
      final session = _FakeSession()
        ..queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        session,
        migrations: const [Migration(version: 1, sql: 'DDL-v1')],
      );
      await runner.migrate();
      expect(session.executedSql.length, 1);
    });

    test('当前 v=1，目标 v=3 → 按序执行 v2/v3 + 写版本', () async {
      final session = _FakeSession()
        ..queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version');

      final runner = MigrationRunner(
        session,
        migrations: const [
          Migration(version: 1, sql: 'DDL-v1'),
          Migration(version: 2, sql: 'DDL-v2'),
          Migration(version: 3, sql: 'DDL-v3'),
        ],
      );
      await runner.migrate();

      expect(session.executedSql.length, 5);
      expect(session.executedSql[1], 'DDL-v2');
      expect(session.executedSql[2], contains('INSERT INTO schema_version'));
      expect(session.executedSql[3], 'DDL-v3');
    });

    test('数据库版本高于应用期望 → 拒绝', () async {
      final session = _FakeSession()
        ..queueResult(const [
          [5],
        ], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        session,
        migrations: const [
          Migration(version: 1, sql: 'DDL-v1'),
          Migration(version: 2, sql: 'DDL-v2'),
        ],
      );
      await expectLater(runner.migrate, throwsA(isA<SchemaMigrationError>()));
    });

    test('迁移列表存在 gap → 拒绝', () async {
      final session = _FakeSession()
        ..queueResult(const [
          [1],
        ], forQueryFragment: 'FROM schema_version');
      final runner = MigrationRunner(
        session,
        migrations: const [
          Migration(version: 1, sql: 'DDL-v1'),
          Migration(version: 3, sql: 'DDL-v3'),
        ],
      );
      await expectLater(runner.migrate, throwsA(isA<SchemaMigrationError>()));
    });

    test('schema_v1 SQL 常量包含关键表/CHECK/索引', () {
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
    });
  });
}

class _FakeSession implements Session {
  final List<String> executedSql = <String>[];
  final List<_Expectation> _queue = <_Expectation>[];

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
