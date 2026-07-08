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
  DatabaseBootstrapError(super.message);
}

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
      );
    }
  }
}
