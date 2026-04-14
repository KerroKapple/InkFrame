// Database providers：PgController + Postgres Connection 的 app-scoped 注入。
//
// 生命周期（PRD §22.1）：
//   - pgControllerProvider：keepAlive，持有 initdb/start/stop 策略
//   - pgConnectionProvider：FutureProvider.keepAlive，首次读触发 start + 建连接
//   - ref.onDispose：先 close connection，再 pg_ctl stop
//
// 被 widget/viewmodel import 是反模式——仓储层才是 Connection 的直接使用者。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgres/postgres.dart';

import '../../storage/pg_binary_locator.dart';
import '../../storage/migrations/migration_runner.dart';
import '../../storage/pg_controller.dart';
import '../../storage/schema/schema_v1.dart';
import 'paths.dart';

/// 二进制定位器——默认按平台探测；单测可以覆盖为指向测试 fixture。
final pgBinaryLocatorProvider = Provider<PgBinaryLocator>(
  (ref) => DefaultPgBinaryLocator(),
  name: 'pgBinaryLocatorProvider',
);

/// PgController——keepAlive；ref.onDispose 触发 graceful stop。
final pgControllerProvider = Provider<PgController>(
  (ref) {
    final controller = PgController(
      paths: ref.watch(appPathsProvider),
      locator: ref.watch(pgBinaryLocatorProvider),
    );
    ref.onDispose(() async {
      try {
        await controller.stop();
      } on PgLifecycleError {
        // 退出路径上的失败不再扩散——上层已有崩溃恢复逻辑。
      }
    });
    return controller;
  },
  name: 'pgControllerProvider',
);

/// Connection——首次读触发 PG 启动 + 建立单连接。
final pgConnectionProvider = FutureProvider<Connection>(
  (ref) async {
    final controller = ref.watch(pgControllerProvider);
    final runtime = await controller.start();
    final conn = await Connection.open(
      Endpoint(
        host: runtime.host,
        port: runtime.port,
        database: 'postgres',
        username: 'inkframe',
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    ref.onDispose(() async {
      await conn.close();
    });
    return conn;
  },
  name: 'pgConnectionProvider',
);


/// Connection + schema migrated——应用层仓储层实际应该依赖的 provider。
/// 首次读：启动 PG → 建连 → CREATE EXTENSION pgcrypto → MigrationRunner.migrate()。
final pgMigratedConnectionProvider = FutureProvider<Connection>(
  (ref) async {
    final conn = await ref.watch(pgConnectionProvider.future);
    // pgcrypto：gen_random_uuid() 依赖；IF NOT EXISTS 幂等。
    try {
      await conn.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
    } on ServerException catch (e) {
      // 23505 并发竞争；其余重抛。
      if (e.code != '23505') rethrow;
    }
    final runner = MigrationRunner(
      conn,
      migrations: const [Migration(version: 1, sql: kSchemaV1)],
    );
    await runner.migrate();
    return conn;
  },
  name: 'pgMigratedConnectionProvider',
);
