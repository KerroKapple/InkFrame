// DatabaseBackupService DI + 启动触发（LB-10 每日 pg_dump 冷备）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/database_backup_service.dart';
import '../../storage/pg_controller.dart';
import '../interfaces/database_backup_service.dart';
import 'clock.dart';
import 'database.dart';
import 'logger.dart';
import 'paths.dart';
import 'process_runner.dart';

/// app-scoped：pg_dump 冷备服务。纯装配，不触发 PG（启动触发器负责就绪等待）。
final databaseBackupServiceProvider = Provider<DatabaseBackupService>((ref) {
  return PgDumpBackupService(
    paths: ref.watch(appPathsProvider),
    locator: ref.watch(pgBinaryLocatorProvider),
    runner: ref.watch(processRunnerProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  );
}, name: 'databaseBackupServiceProvider');

/// 启动首帧后触发一次每日冷备。housekeeping：任何失败只 warn，绝不阻断启动。
///
/// 先 await pgMigratedPool 确保 PG 已起 + 迁移到位（拿得到 runtime，且备份的是
/// 一致的当前 schema）；trust 集群 runtime.password=null，pg_dump 走 trust 连接。
final databaseBackupStartupProvider = FutureProvider<void>((ref) async {
  final logger = ref.watch(loggerProvider);
  try {
    // 确保 PG 启动 + 迁移完成（runtime 此后必非空）。
    await ref.watch(pgMigratedPoolProvider.future);
    final runtime = ref.watch(pgControllerProvider).runtime;
    if (runtime == null) {
      logger.warn(kBackupModule, 'backup.skipped.no_runtime');
      return;
    }
    final service = ref.watch(databaseBackupServiceProvider);
    await service.backup(BackupConnection(
      host: runtime.host,
      port: runtime.port,
      username: kPgSuperuser,
      database: kPgDatabaseName,
      password: runtime.password,
    ));
  } catch (e, st) {
    // 放行点（sanctioned swallow）：冷备是 housekeeping，绝不阻断启动。任何失败
    // ——InkError（PG 未就绪）、逻辑异常（非 InkError）——都只 warn，下次启动再试。
    // 刻意 catch-all 而非 on InkError：否则非 InkError 绕过 warn 静默落 AsyncError。
    logger.warn(
      kBackupModule,
      'backup.startup_failed',
      extra: <String, Object?>{
        'error': e.toString(),
        'stack': st.toString(),
      },
    );
  }
}, name: 'databaseBackupStartupProvider');
