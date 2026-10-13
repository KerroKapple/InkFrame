// DatabaseBootstrap：池就绪后的一次性数据库引导。
//
// 职责（原先内联在 core/di/database.dart 的 pgMigratedPoolProvider）：
//   1) CREATE EXTENSION pgcrypto（gen_random_uuid 依赖，IF NOT EXISTS 幂等）
//   2) MigrationRunner.migrate()——按 kAppMigrations 前向迁移到目标版本
//
// LB-08：把底层 [ServerException] 收口在**储层边界**翻译成 [DatabaseBootstrapError]，
// 杜绝 postgres 异常越过储层泄漏进 DI/应用层（DI 层不再出现 ServerException）。
// 幂等：可安全重复 run（IF NOT EXISTS + MigrationRunner 达标即 no-op）。
import 'package:postgres/postgres.dart';

import 'migrations/app_migrations.dart';
import 'migrations/migration_runner.dart';

/// 数据库引导失败——储层边界翻译的底层 [ServerException]（扩展/迁移执行期
/// 未预期的服务器错误）。StateError 系，与 [SchemaMigrationError] 同族，
/// 由 DI/app 边界统一翻 LocalIOError（见 LB-09）。
class DatabaseBootstrapError extends StateError {
  DatabaseBootstrapError(super.message, {this.sqlState});

  /// 底层 [ServerException] 的 SQLSTATE（如 `28P01`）。原来只埋在 message 字符串里，
  /// 上层想按错误种类分流（口令对不上 ≠ 磁盘坏了）就只能解析文本——现在结构化带出。
  final String? sqlState;
}

/// SQLSTATE 28P01 invalid_password：SCRAM 口令对不上。
///
/// 嵌入式 PG 的口令随机生成、存在系统凭据里（LB-07）。凭据丢了（用户清过系统凭据
/// 管理器、或这个数据目录来自另一台电脑），库还在、口令却再也对不上——引导期第一条
/// 语句（建 pgcrypto 扩展）就会以它失败。2026-10-13 用 SCRAM 临时集群实测确认。
const String kPgSqlStateInvalidPassword = '28P01';

/// 池就绪后一次性引导：pgcrypto 扩展 + schema 迁移链。
class DatabaseBootstrap {
  DatabaseBootstrap(this._executor, {List<Migration>? migrations})
      : _migrations = migrations ?? kAppMigrations;

  final SessionExecutor _executor;
  final List<Migration> _migrations;

  Future<void> run() async {
    await _ensurePgcrypto();
    await _migrate();
  }

  /// gen_random_uuid() 依赖 pgcrypto；IF NOT EXISTS 幂等，容忍并发建扩展竞争。
  Future<void> _ensurePgcrypto() async {
    try {
      await _executor.run(
        (s) => s.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto'),
      );
    } on ServerException catch (e) {
      // 23505 duplicate_object：并发建扩展竞争——幂等语义下安全忽略。
      if (e.code == '23505') return;
      throw DatabaseBootstrapError(
        'pgcrypto extension bootstrap failed [${e.code}]: ${e.message}',
        sqlState: e.code,
      );
    }
  }

  /// 前向迁移。SchemaMigrationError / SchemaDowngradeError（储层领域错误）原样上抛；
  /// 仅把未预期的底层 [ServerException] 翻成 [DatabaseBootstrapError]。
  Future<void> _migrate() async {
    try {
      await MigrationRunner(_executor, migrations: _migrations).migrate();
    } on ServerException catch (e) {
      throw DatabaseBootstrapError(
        'schema migration failed [${e.code}]: ${e.message}',
        sqlState: e.code,
      );
    }
  }
}
