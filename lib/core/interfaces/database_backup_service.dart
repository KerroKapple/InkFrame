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

/// 备份族（LB-22）：三族命名分池、各自保留配额——预备份/手动备份永不挤占
/// 每日历史，也永不剪掉用户正要还原的目标（设计评审 P1-3）。
enum BackupKind { daily, manual, preRestore }

/// 备份目录里的一份备份（listBackups 行）。
class BackupFileInfo {
  const BackupFileInfo({
    required this.name,
    required this.kind,
    required this.sizeBytes,
    required this.modified,
  });

  final String name;
  final BackupKind kind;
  final int sizeBytes;
  final DateTime modified;
}

/// backupNow 的结果：created 时携带落盘文件名（UI 提示 / 还原兜底引用）。
class BackupNowResult {
  const BackupNowResult({required this.outcome, this.fileName});

  final BackupOutcome outcome;
  final String? fileName;
}

abstract class DatabaseBackupService {
  /// 每日冷备：当日已有跳过，保留策略见实现（daily 族 cap）。
  Future<BackupOutcome> backup(BackupConnection connection);

  /// 立即备份（manual / preRestore 族）：时间戳命名，不受当日跳过约束。
  /// 失败以返回值表达（housekeeping 同源实现，**不抛**——调用方必须查返回值，
  /// 设计评审 P1-4）。[preserve] 为剪枝排除名——还原流程的兜底备份触发剪枝时
  /// 绝不能删掉用户正要还原的目标（#189 评审 P1-2）。
  Future<BackupNowResult> backupNow(
    BackupConnection connection, {
    required BackupKind kind,
    String? preserve,
  });

  /// 备份目录清单：仅识别命名，新→旧。纯文件系统读，无需 PG 二进制。
  List<BackupFileInfo> listBackups();
}
