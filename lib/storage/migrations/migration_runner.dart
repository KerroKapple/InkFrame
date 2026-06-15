// MigrationRunner — schema 版本迁移执行器。
//
// PRD §22.0 规则：
//   - schema_version 单行表，CHECK(id = 1)
//   - 版本匹配 → 正常启动
//   - 当前版本 < 应用期望 → 顺序执行 002_*.sql、003_*.sql ...
//   - 当前版本 > 应用期望 → 抛错提示用户升级
//
// ME-31：每条迁移的 DDL 与 schema_version UPSERT 必须原子——runTx 单事务包裹，
// 失败回滚后版本号保持原值，下次启动重跑同一迁移。版本号统一由 runner 写，
// 迁移 SQL 自身不写 schema_version。
//
// 本 runner 不做 SQL 文件扫描，由调用方组装 migrations 列表。
import 'package:postgres/postgres.dart';

/// 单条迁移：版本号递增 + SQL 语句块。
class Migration {
  const Migration({
    required this.version,
    required this.sql,
    this.queryMode = QueryMode.simple,
  });
  final int version;
  final String sql;

  /// 多语句 DDL 在 postgres-dart 上必须走 simple 协议；默认即为 simple。
  final QueryMode queryMode;
}

class SchemaMigrationError extends StateError {
  SchemaMigrationError(super.message);
}

class MigrationRunner {
  MigrationRunner(this._executor, {required this.migrations})
      : assert(migrations.isNotEmpty, 'migrations must be non-empty');

  /// Connection / Pool 皆可——runTx 保证单迁移落在同一条连接的单事务内。
  final SessionExecutor _executor;

  /// 按版本升序的迁移列表；v=1 必须位于首位。
  final List<Migration> migrations;

  /// 应用期望达到的 schema 版本 = 最后一条迁移的 version。
  int get targetVersion => migrations.last.version;

  /// 读取数据库当前 schema 版本；空库返回 0（schema_version 表未建）。
  Future<int> currentVersion() async {
    try {
      final r = await _executor.run(
        (s) => s.execute('SELECT version FROM schema_version WHERE id = 1'),
      );
      if (r.isEmpty) return 0;
      final v = r.first[0];
      if (v is int) return v;
      throw SchemaMigrationError(
        'schema_version.version type unexpected: ${v.runtimeType}',
      );
    } on ServerException catch (e) {
      // 42P01 = relation does not exist → 空库
      if (e.code == '42P01') return 0;
      rethrow;
    }
  }

  /// 核心：运行所有缺少的迁移，每条迁移 = DDL + 版本 UPSERT 同一事务。
  Future<void> migrate() async {
    final current = await currentVersion();
    final target = targetVersion;
    if (current == target) return;
    if (current > target) {
      throw SchemaMigrationError(
        'Database schema version $current is newer than application '
        'target $target. Upgrade the application or migrate data manually.',
      );
    }

    final pending = migrations.where((m) => m.version > current).toList()
      ..sort((a, b) => a.version.compareTo(b.version));

    // 校验版本单调递增无缺口（current+1, current+2, ...）
    for (var i = 0; i < pending.length; i++) {
      final expected = current + i + 1;
      if (pending[i].version != expected) {
        throw SchemaMigrationError(
          'Migration gap detected: expected version $expected, '
          'got ${pending[i].version}',
        );
      }
    }

    for (final m in pending) {
      await _executor.runTx((tx) async {
        await tx.execute(m.sql, queryMode: m.queryMode);
        // version 由 runner 自身控制，用字符串插值而非绑定参数，
        // 便于测试断言 SQL 内容；无注入风险。
        await tx.execute(
          'INSERT INTO schema_version (id, version) VALUES (1, ${m.version}) '
          'ON CONFLICT (id) DO UPDATE SET version = EXCLUDED.version, '
          'applied_at = now()',
        );
      });
    }
  }
}
