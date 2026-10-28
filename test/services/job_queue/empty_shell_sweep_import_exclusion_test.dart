// 队列 init 的空壳清扫（JobStatePersister.init → softDeleteEmptyOrphanResults）不碰正在复制的
// 导入壳。
//
// 清扫挂在 jobQueueServiceProvider 的首次解析上——懒：会话里第一次点「生成」、DB 恢复后重建
// 队列都会跑，不只在启动时。复制中的导入壳是「result、三个 url 皆空、无 slot、无 job」，
// 不排除就会被软删，复制完回写写 0 行，重开画布卡片就没了。判据：本次 PG 实例启动之后建的
// 导入壳（origin=import 且 created_at >= pg_postmaster_start_time()）不收；之前建的是上次
// 进程崩溃遗留的空壳，照收。
//
// SQL 模板单测（不触 PG），同 test/storage/repositories/repository_sql_templates_test.dart。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/import_keys.dart';
import 'package:inkframe/storage/repositories/postgres_node_repository.dart';
import 'package:postgres/postgres.dart';

void main() {
  test('softDeleteEmptyOrphanResults 排除本次 PG 实例启动后建的导入壳', () async {
    final _SpySession spy = _SpySession();
    await PostgresNodeRepository(spy).softDeleteEmptyOrphanResults();
    final String sql = spy.lastSql!;

    expect(
      sql,
      contains(
        "AND NOT (COALESCE(type_config->>'${ImportKeys.origin}','') "
        "= '${ImportKeys.originImport}' "
        'AND created_at >= pg_postmaster_start_time())',
      ),
    );
    // 排除只针对导入壳：生成侧空壳的判据照旧。
    expect(sql, contains("node_role = 'result'"));
    expect(sql, contains("COALESCE(type_config->>'image_url','') = ''"));
  });
}

class _SpySession implements Session {
  String? lastSql;

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
    return Result(
      rows: const <ResultRow>[],
      affectedRows: 0,
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
