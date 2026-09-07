// OrphanFileReaper 契约：磁盘孤儿媒体文件回收（GC）。
//
// 「孤儿」= projects/*/canvases/*/{images,videos} 下、画布相对路径不在引用集、
// 且 mtime 早于阈值（默认 7 天）的文件。本服务只识别 + 记 orphan.reap.dryrun 日志，
// **没有任何删除实现**——不是"默认关闭的开关"，是这个类里根本不存在删除代码。
// 真正的删除需要独立实现、独立评审，不在本契约里。
abstract class OrphanFileReaper {
  /// 扫描并识别孤儿文件，只记 orphan.reap.dryrun 日志、不删除、不碰任何媒体文件（唯一落盘 = config/ 下的节流标记）。
  /// 节流：距上次成功回收不足阈值则直接跳过（返回 [OrphanReapReport.skipped]）。
  /// 引用集构建失败（InkError）向上抛——由启动兜底 swallow 成 warn，绝不阻断。
  Future<OrphanReapReport> reap();
}

/// 一次回收的结果快照（供启动日志 / 测试断言）。
///
/// 本服务从不删除文件，故此处不含「已删列表」——只有识别统计。
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

  /// 恒 true——本服务没有删除实现，报告字段保留以标记"这是一次只读扫描"。
  final bool dryRun;

  /// 识别出的孤儿文件数。
  final int orphanCount;

  /// 孤儿文件总字节数。
  final int totalBytes;
}
