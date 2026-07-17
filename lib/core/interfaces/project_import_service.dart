// ProjectImportService：项目包导入契约（LB-12）。
//
// 顺序（拍板 5 rev2）：安全门 → 解析/重映射 → **staging 提取 → rename 落位 →
// DB 单事务**——崩溃窗口残留=一个无行背书的孤儿目录（不可见、可清扫），
// 绝不出现「行在图裂」的可见残缺项目。失败以返回值分类表达（UI 必须呈现）。
abstract class ProjectImportService {
  Future<ImportResult> importArchive({required String zipPath});
}

enum ImportOutcome {
  /// 导入完成——新项目行与文件均已落位。
  imported,

  /// 不是 InkFrame 项目包（manifest formatVersion 不符）。
  failedFormat,

  /// 包来自更新 schema 的版本（Zero-BC 拒绝降级解读）。
  failedVersionNewer,

  /// 包损坏/不可信（zip 结构、安全门、超限、data.json 损坏、条目与清单不符）。
  failedCorrupt,

  /// 其它失败（IO / 写库）——已补偿清理，零残留。
  failed,
}

class ImportResult {
  const ImportResult({required this.outcome, this.newProjectId, this.reason});

  final ImportOutcome outcome;

  /// imported 时非空。
  final String? newProjectId;

  /// 内部诊断标识（English-only；UI 不直接展示）。
  final String? reason;
}
