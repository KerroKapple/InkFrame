// MigrationRunner — schema 版本迁移执行器。
//
// PRD §22.0 规则：
//   - schema_version 单行表，CHECK(id = 1)
//   - 版本匹配 → 正常启动
//   - 当前版本 < 应用期望 → 顺序执行 002_*.sql、003_*.sql ...
//   - 当前版本 > 应用期望 → 抛错提示用户升级
//
// 当前版本仅落 v=1：空库 → 运行 kSchemaV1 → schema_version.version = 1。
// v=2 及以后通过 addMigration 注入；本 runner 不做 SQL 文件扫描，由调用方组装 migrations 列表。
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
  MigrationRunner(this._session, {required this.migrations})
      : assert(migrations.isNotEmpty, 'migrations must be non-empty');

  final Session _session;

  /// 按版本升序的迁移列表；v=1 必须位于首位。
  final List<Migration> migrations;

  /// 应用期望达到的 schema 版本 = 最后一条迁移的 version。
  int get targetVersion => migrations.last.version;

  /// 读取数据库当前 schema 版本；空库返回 0（schema_version 表未建）。
  Future<int> currentVersion() async {
    try {
      final r = await _session.execute(
        'SELECT version FROM schema_version WHERE id = 1',
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

  /// 核心：运行所有缺少的迁移，每条单事务。
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
      // v=1 的 SQL 自身会 UPSERT schema_version.version=1。
      // v≥2 的 SQL 不应自己写 schema_version；runner 负责统一 UPSERT。
      await _session.execute(m.sql, queryMode: m.queryMode);
      if (m.version > 1) {
        // version 由 runner 自身控制，用字符串插值而非绑定参数，
        // 便于测试断言 SQL 内容；无注入风险。
        await _session.execute(
          'INSERT INTO schema_version (id, version) VALUES (1, ${m.version}) '
          'ON CONFLICT (id) DO UPDATE SET version = EXCLUDED.version, '
          'applied_at = now()',
        );
      }
    }
  }
}
