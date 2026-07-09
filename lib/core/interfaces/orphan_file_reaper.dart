// OrphanFileReaper 契约：磁盘孤儿媒体文件回收（GC）。
//
// 「孤儿」= projects/*/canvases/*/{images,videos} 下、画布相对路径不在引用集、
// 且 mtime 早于阈值（默认 7 天）的文件。本卡（LB-13 slice B）为 DRY-RUN v1：
// 只识别 + 记 orphan.reap.dryrun 日志，**绝不删除任何文件**。
//
// 实际删除藏在 reap(dryRun:) 的显式开关后，且默认 true；本卡任何调用点都不传
// dryRun=false，故删除路径不可达。未来卡在 dry-run 日志验证无误后再翻开关。
abstract class OrphanFileReaper {
  /// 扫描并识别孤儿文件。
  ///
  /// [dryRun]=true（默认，也是本卡唯一取值）只记 orphan.reap.dryrun 日志、不删除。
  /// 节流：距上次成功回收不足阈值则直接跳过（返回 [OrphanReapReport.skipped]）。
  /// 引用集构建失败（InkError）向上抛——由启动兜底 swallow 成 warn，绝不阻断。
  Future<OrphanReapReport> reap({bool dryRun = true});
}

/// 一次回收的结果快照（供启动日志 / 测试断言）。
///
/// 本卡从不删除文件，故此处不含「已删列表」——只有识别统计。
class OrphanReapReport {
  const OrphanReapReport({
    required this.throttledSkip,
    required this.dryRun,
    required this.orphanCount,
    required this.totalBytes,
  });

  /// 因节流未执行本次扫描。
  const OrphanReapReport.skipped()
      : throttledSkip = true,
        dryRun = true,
        orphanCount = 0,
        totalBytes = 0;

  /// 本次因节流被跳过（未扫描）。
  final bool throttledSkip;

  /// 本次是否为 dry-run（本卡恒 true）。
  final bool dryRun;

  /// 识别出的孤儿文件数。
  final int orphanCount;

  /// 孤儿文件总字节数。
  final int totalBytes;
}
