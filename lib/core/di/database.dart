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

import '../../storage/database_bootstrap.dart';
import '../../storage/migrations/migration_runner.dart';
import '../../storage/pg_binary_locator.dart';
import '../../storage/pg_controller.dart';
import '../errors/ink_error.dart';
import 'logger.dart';
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
      logger: ref.watch(loggerProvider),
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
/// 首次读：启动 PG → 建池 → DatabaseBootstrap.run()（pgcrypto + 迁移链；
/// 底层 PG 异常在储层边界收口，见 storage/database_bootstrap.dart）。
///
/// LB-09：DI 边界只把**已知的启动失败**（PG 生命周期 / 引导 / 迁移，含
/// SchemaDowngradeError——它 extends SchemaMigrationError）翻成可渲染的
/// [LocalIOError]，AsyncError 因此携带 InkError，供启动失败 surface 经
/// l10nAsyncError 本地化呈现，而非白屏泄漏裸错误。
///
/// 泛化 [StateError]（如 postgres "Cannot execute on a closed pool"、误用 .first
/// 等真正的程序 bug）刻意**不**翻译、原样上抛，交由 runZonedGuarded / CrashReporter
/// 捕获——避免把编程错误误标成用户可读的磁盘 I/O 错误并吞掉诊断线索。
final pgMigratedPoolProvider = FutureProvider<Pool<void>>(
  (ref) async {
    try {
      final pool = await ref.watch(pgPoolProvider.future);
      await DatabaseBootstrap(pool).run();
      return pool;
    } on PgLifecycleError catch (e, st) {
      throw LocalIOError(cause: e, stackTrace: st);
    } on DatabaseBootstrapError catch (e, st) {
      // TODO(LB-07): SCRAM 28P01（引导期 ServerException code '28P01'，此处已被
      //   收口成 DatabaseBootstrapError）应走"重置数据库口令"引导分支，而非泛化 LocalIOError。
      throw LocalIOError(cause: e, stackTrace: st);
    } on SchemaMigrationError catch (e, st) {
      // SchemaDowngradeError 亦属此族（extends SchemaMigrationError）。
      throw LocalIOError(cause: e, stackTrace: st);
    }
  },
  name: 'pgMigratedPoolProvider',
);
