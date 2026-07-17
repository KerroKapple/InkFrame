// DatabaseRestoreService：备份还原契约（LB-22）。
//
// 语义（设计评审 rev2 拍板 1）：还原 = scratch 库对换——先把备份灌进临时库
// （pg_restore --single-transaction），成功才把临时库改名换上；除 restored 外
// **原库保证未被改动**（对换夹缝崩溃有自愈路径，见实现）。
// 还原是显式用户动作：失败以返回值分类表达，调用方必须呈现给用户。
import 'database_backup_service.dart';

enum RestoreOutcome {
  /// 对换完成——数据库内容已替换为备份内容。
  restored,

  /// 无打包 PG 二进制（开发机 / 坏安装）。
  failedNoBinaries,

  /// 备份文件校验未通过（sha256 不符 / sidecar 损坏）。
  failedCorrupt,

  /// 备份来自更新版本的 schema（sidecar.schemaVersion > 当前迁移链末端）——
  /// 拒绝还原以免降级循环（Zero-BC：新库旧 app 一律拒绝）。
  failedVersionNewer,

  /// 预备份失败且调用方要求必须先备份（flow 层语义；service 不返回）。
  abortedPreBackup,

  /// 其它失败（非法名 / 文件缺失 / 进程失败 / 维护 SQL 失败）——原库未动。
  failed,
}

abstract class DatabaseRestoreService {
  /// [backupFileName] 必须是 AppPaths.backups 下的识别命名（防穿越）。
  Future<RestoreOutcome> restore(
    BackupConnection connection,
    String backupFileName,
  );
}
