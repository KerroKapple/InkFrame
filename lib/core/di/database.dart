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
import 'secure_storage.dart';

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
      secureStorage: ref.watch(secureStorageServiceProvider),
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
///
/// LB-07：runtime.password 由 PgController 从 SecureStorage 取出——
/// 新集群 SCRAM 必需；存量 trust 集群为 null（trust 忽略密码，Zero-BC）。
/// SslMode.disable 保留：回环内无窃听面。
final pgPoolProvider = FutureProvider<Pool<void>>(
  (ref) async {
    final controller = ref.watch(pgControllerProvider);
    final runtime = await controller.start();
    final Pool<void> pool = Pool.withEndpoints(
      [
        Endpoint(
          host: runtime.host,
          port: runtime.port,
          database: kPgDatabaseName,
          username: kPgSuperuser,
          password: runtime.password,
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
      throw bootstrapFailureToInkError(e, st);
    } on SchemaMigrationError catch (e, st) {
      // SchemaDowngradeError 亦属此族（extends SchemaMigrationError）。
      throw schemaFailureToInkError(e, st);
    }
  },
  name: 'pgMigratedPoolProvider',
);

/// 数据库口令对不上时，[LocalIOError] 的 `extra['reason']`。启动失败页据此换文案。
const String kDbAuthFailedReason = 'db_auth_failed';

/// 引导失败 → 用户可读的 InkError。
///
/// 口令对不上（SQLSTATE 28P01）单独标 [kDbAuthFailedReason]。原来一律泛化成
/// LocalIOError，启动失败页于是显示「本地磁盘 I/O 错误，请检查空间与权限」——
/// 方向完全错了：磁盘好好的，是系统凭据里那份口令丢了或对不上。
///
/// 这里只做到「说实话」。真正的出路（「重置数据库口令」引导流程：临时改认证方式重设
/// 口令）涉及安全取舍，记在 BOARD 待拍板，不在这里做。
LocalIOError bootstrapFailureToInkError(
  DatabaseBootstrapError e,
  StackTrace st,
) =>
    LocalIOError(
      cause: e,
      stackTrace: st,
      extra: <String, Object?>{
        if (e.sqlState == kPgSqlStateInvalidPassword)
          'reason': kDbAuthFailedReason,
      },
    );

/// 库比应用新（旧版应用打开了新版库）时，[LocalIOError] 的 `extra['reason']`。
const String kDbNewerThanAppReason = 'db_newer_than_app';

/// 前向迁移失败时，[LocalIOError] 的 `extra['reason']`。
const String kDbMigrationFailedReason = 'db_migration_failed';

/// 迁移失败 → 用户可读的 InkError。
///
/// 两种情况原来都泛化成 LocalIOError，启动失败页一律说「本地磁盘 I/O 错误，请检查
/// 空间与权限」：
/// - **库比应用新**（[SchemaDowngradeError]）：用户装回了旧版本——比如新版有 bug 想
///   回退。正解是装回最新版，跟磁盘毫无关系。而且这时页上的「从最近备份还原」不只
///   没用、还有风险：最近一份能还原的若恰好是升级前的旧备份，一键还原会把升级后的
///   所有改动回滚掉，用户却不知道。启动页据此隐藏它。
/// - **前向迁移失败**：失败的那一步在单事务里回滚了（MigrationRunner 逐版本 runTx），
///   数据停在上一个完整版本。这是程序问题，用户能做的是把日志交给开发者。
LocalIOError schemaFailureToInkError(SchemaMigrationError e, StackTrace st) =>
    LocalIOError(
      cause: e,
      stackTrace: st,
      extra: <String, Object?>{
        'reason': e is SchemaDowngradeError
            ? kDbNewerThanAppReason
            : kDbMigrationFailedReason,
      },
    );
