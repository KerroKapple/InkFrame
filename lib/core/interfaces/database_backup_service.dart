// DatabaseBackupService：嵌入式 PG 每日冷备契约（LB-10）。
//
// 单机本地库的兜底安全网：每日一份 pg_dump 自定义格式（-Fc）快照，保留 7 份。
// 任何失败仅告警、绝不阻断启动或其它流程（housekeeping 语义，同孤儿回收）。
// 还原路径见 LB-22 / SETUP.md「恢复」段。

/// 备份连接参数（运行时从 PgController.runtime + 常量组装）。
class BackupConnection {
  const BackupConnection({
    required this.host,
    required this.port,
    required this.username,
    required this.database,
    this.password,
  });

  final String host;
  final int port;
  final String username;
  final String database;

  /// SCRAM 口令；null = 存量 trust 集群（不设 PGPASSWORD，LB-07 Zero-BC）。
  final String? password;
}

/// 一次备份的结果（供启动触发器分级记日志；均非异常路径）。
enum BackupOutcome {
  /// 新备份已写入。
  created,

  /// 当日已有备份，跳过。
  skippedAlreadyToday,

  /// 无打包 PG 二进制（开发机 / 未 fetch-binaries），跳过——不算失败。
  skippedNoBinaries,

  /// pg_dump 执行失败（非零退出 / 无法启动）；半成品已清理。
  failed,
}

abstract class DatabaseBackupService {
  Future<BackupOutcome> backup(BackupConnection connection);
}
