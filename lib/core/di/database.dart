// Database providers：PgController + Postgres Pool 的 app-scoped 注入。
//
// 生命周期（PRD §22.1）：
//   - pgControllerProvider：keepAlive，持有 initdb/start/stop 策略
//   - pgPoolProvider：FutureProvider.keepAlive，首次读触发 start + 建池
//   - ref.onDispose：先 close pool，再 pg_ctl stop（关闭窗口路径见 AppTeardown）
//
// ME-33：单 Connection 断线即永久失联——改用 Pool，连接按需建立，
// 断线后下一次执行自动换新连接，天然具备重连能力。
//
// 被 widget/viewmodel import 是反模式——仓储层才是 Pool 的直接使用者。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgres/postgres.dart';

import '../../storage/pg_binary_locator.dart';
import '../../storage/migrations/migration_runner.dart';
import '../../storage/pg_controller.dart';
import '../../storage/schema/schema_v1.dart';
import '../../storage/schema/schema_v2.dart';
import '../../storage/schema/schema_v3.dart';
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

/// 内嵌 PG 是单机本地库——小池即可，上限防失控连接堆积。
const int kPgMaxConnections = 4;

/// Pool——首次读触发 PG 启动 + 建池；连接懒建，断线自动换新（ME-33）。
final pgPoolProvider = FutureProvider<Pool<void>>(
  (ref) async {
    final controller = ref.watch(pgControllerProvider);
    final runtime = await controller.start();
    final Pool<void> pool = Pool.withEndpoints(
      [
        Endpoint(
          host: runtime.host,
          port: runtime.port,
          database: 'postgres',
          username: 'inkframe',
        ),
      ],
      settings: const PoolSettings(
        sslMode: SslMode.disable,
        maxConnectionCount: kPgMaxConnections,
      ),
    );
    ref.onDispose(() async {
      await pool.close();
    });
    return pool;
  },
  name: 'pgPoolProvider',
);

/// Pool + schema migrated——应用层仓储层实际应该依赖的 provider。
/// 首次读：启动 PG → 建池 → CREATE EXTENSION pgcrypto → MigrationRunner.migrate()。
final pgMigratedPoolProvider = FutureProvider<Pool<void>>(
  (ref) async {
    final pool = await ref.watch(pgPoolProvider.future);
    // pgcrypto：gen_random_uuid() 依赖；IF NOT EXISTS 幂等。
    try {
      await pool.execute('CREATE EXTENSION IF NOT EXISTS pgcrypto');
    } on ServerException catch (e) {
      // 23505 并发竞争；其余重抛。
      if (e.code != '23505') rethrow;
    }
    final runner = MigrationRunner(
      pool,
      migrations: const [
        Migration(version: 1, sql: kSchemaV1),
        Migration(version: 2, sql: kSchemaV2),
        Migration(version: 3, sql: kSchemaV3),
      ],
    );
    await runner.migrate();
    return pool;
  },
  name: 'pgMigratedPoolProvider',
);
