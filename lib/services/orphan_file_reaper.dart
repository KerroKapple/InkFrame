// DiskOrphanFileReaper：OrphanFileReaper 的磁盘实现（LB-13 slice B）。
//
// 只扫 projects/<p>/canvases/<c>/{images,videos}——绝不碰其它任何目录（安全#3）。
// 三重安全：
//   #1 mtime 守卫：只有 mtime 早于 kOrphanMinAge（7d）的文件才可能是孤儿——
//      保护刚写盘、DB 行还在提交中的新文件。
//   #2 引用集含软删节点：NodeRepository.listAllMediaUrls 连 deleted_at IS NOT NULL
//      的节点也算引用——软删可 LB-15 恢复，其产物必须留。
//   #3 目录白名单：只列 images/ 与 videos/，其余一律不扫描、不识别。
//
// 只读：识别到的孤儿只 logger.info('orphan.reap.dryrun', ...)，**这个类里没有任何
// 删除代码**——2026-08-31 审计 P0：曾经的 reap(dryRun:false) 分支是一条真实可达、
// 无恢复机制的删除路径，即便当时没有调用点传 false，也不该让删除实现待在一个号称
// "只读审计"的服务里。真正的删除功能必须是独立评审的另一个实现。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/batch_result_repository.dart';
import '../core/interfaces/node_repository.dart';
import '../core/interfaces/orphan_file_reaper.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';

/// 日志 module 名（内部标识，非 UI，English-only）。
const String kOrphanReapModule = 'orphan.reap';

/// 孤儿判据：文件 mtime 必须早于此阈值才可能被判孤儿（安全#1）。
const Duration kOrphanMinAge = Duration(days: 7);

/// 节流：两次回收至少间隔此时长（持久化到 config/orphan_reap.marker）。
const Duration kOrphanReapThrottle = Duration(days: 7);

/// 唯一允许扫描的画布子目录（安全#3）。
const List<String> kOrphanMediaSubdirs = <String>['images', 'videos'];

/// dry-run 单条命中日志的 msg（测试按此断言）。
const String kOrphanDryRunMsg = 'orphan.reap.dryrun';

/// 节流标记文件名（存 config/ 下，内容为上次回收的 UTC ISO8601 时间戳）。
const String kOrphanReapMarkerName = 'orphan_reap.marker';

class DiskOrphanFileReaper implements OrphanFileReaper {
  DiskOrphanFileReaper({
    required AppPaths paths,
    required NodeRepository nodeRepo,
    required BatchResultRepository batchResultRepo,
    required Clock clock,
    LoggerService? logger,
  })  : _paths = paths,
        _nodeRepo = nodeRepo,
        _batchResults = batchResultRepo,
        _clock = clock,
        _logger = logger;

  final AppPaths _paths;
  final NodeRepository _nodeRepo;
  final BatchResultRepository _batchResults;
  final Clock _clock;
  final LoggerService? _logger;

  File get _throttleMarker =>
      File(p.join(_paths.config.path, kOrphanReapMarkerName));

  @override
  Future<OrphanReapReport> reap() async {
    final now = _clock.nowUtc();

    // 节流：距上次成功回收不足阈值直接跳过（免得每次启动刷屏）。
    final last = _readLastReap();
    if (last != null && now.difference(last) < kOrphanReapThrottle) {
      return const OrphanReapReport.skipped();
    }

    // 引用集：节点全量 url（含软删）∪ batch_results.output_url。
    // 构建失败必须中止——拿不到引用集就无法安全判孤儿（否则全部文件误判无引用、
    // 触发大规模误报）。此处不 try：InkError 直接上抛给启动兜底 swallow 成 warn。
    final referenceSet = await _buildReferenceSet();

    final candidates = identifyOrphans(referenceSet: referenceSet, now: now);

    var totalBytes = 0;
    for (final c in candidates) {
      totalBytes += c.sizeBytes;
      _logger?.info(
        kOrphanReapModule,
        kOrphanDryRunMsg,
        extra: <String, Object?>{
          'path': c.relativePath,
          'size_bytes': c.sizeBytes,
          'age_days': c.ageDays,
        },
      );
    }

    _logger?.info(
      kOrphanReapModule,
      'orphan.reap.summary',
      extra: <String, Object?>{
        'orphan_count': candidates.length,
        'total_bytes': totalBytes,
        'dry_run': true,
      },
    );

    _writeLastReap(now);

    return OrphanReapReport(
      throttledSkip: false,
      dryRun: true,
      orphanCount: candidates.length,
      totalBytes: totalBytes,
    );
  }

  /// 纯识别逻辑（测试直连）：给定引用集 + [now]，扫盘返回孤儿候选。不删、不记日志。
  ///
  /// [referenceSet] 元素须为画布相对路径（`images/<f>` 或 `videos/<f>`），与仓储
  /// 存储形态一致——文件按同样形态归一后比对。
  List<OrphanCandidate> identifyOrphans({
    required Set<String> referenceSet,
    required DateTime now,
  }) {
    final out = <OrphanCandidate>[];
    final projectsRoot = _paths.projects;
    if (!projectsRoot.existsSync()) return out;

    for (final projectDir in _dirsIn(projectsRoot)) {
      final canvasesDir = Directory(p.join(projectDir.path, 'canvases'));
      if (!canvasesDir.existsSync()) continue;
      for (final canvasDir in _dirsIn(canvasesDir)) {
        // 安全#3：只进 images/ 与 videos/，其余子目录（characters/、exports/ 等）不碰。
        for (final subdir in kOrphanMediaSubdirs) {
          final mediaDir = Directory(p.join(canvasDir.path, subdir));
          if (!mediaDir.existsSync()) continue;
          for (final entity in _filesIn(mediaDir)) {
            final rel = '$subdir/${p.basename(entity.path)}';
            if (referenceSet.contains(rel)) continue; // 被引用：留。
            final FileStat stat;
            try {
              stat = entity.statSync();
            } on FileSystemException {
              continue; // stat 失败：保守跳过（宁可漏删不可误删）。
            }
            // 安全#1：mtime ≤ 阈值的新文件绝不动。UTC 归一避免时区偏差。
            final age = now.difference(stat.modified.toUtc());
            if (age <= kOrphanMinAge) continue;
            out.add(
              OrphanCandidate(
                file: entity,
                relativePath: rel,
                sizeBytes: stat.size,
                ageDays: age.inDays,
              ),
            );
          }
        }
      }
    }
    return out;
  }

  Future<Set<String>> _buildReferenceSet() async {
    final urls = <String>{};
    for (final u in await _nodeRepo.listAllMediaUrls()) {
      urls.add(_normalizeRel(u));
    }
    for (final u in await _batchResults.listAllOutputUrls()) {
      urls.add(_normalizeRel(u));
    }
    return urls;
  }

  // 归一：反斜杠→正斜杠、去首尾空白。仓储本就存正斜杠画布相对路径，这里只做防御。
  String _normalizeRel(String raw) => raw.trim().replaceAll('\\', '/');

  List<Directory> _dirsIn(Directory dir) {
    try {
      return dir.listSync(followLinks: false).whereType<Directory>().toList();
    } on FileSystemException {
      return const <Directory>[];
    }
  }

  List<File> _filesIn(Directory dir) {
    try {
      return dir.listSync(followLinks: false).whereType<File>().toList();
    } on FileSystemException {
      return const <File>[];
    }
  }

  DateTime? _readLastReap() {
    try {
      final f = _throttleMarker;
      if (!f.existsSync()) return null;
      return DateTime.tryParse(f.readAsStringSync().trim())?.toUtc();
    } on FileSystemException {
      return null; // 读不到 → 当作从未回收，照常执行（dry-run 无害）。
    }
  }

  void _writeLastReap(DateTime now) {
    try {
      _paths.config.createSync(recursive: true);
      _throttleMarker.writeAsStringSync(
        now.toUtc().toIso8601String(),
        flush: true,
      );
    } on FileSystemException {
      // 写标记失败：仅影响下次节流（最坏重复一次 dry-run），绝不阻断。
    }
  }
}

/// 孤儿候选：一个被判定为孤儿的文件 + 元信息。
/// 本卡只用于日志 / 统计，从不据此删除。
class OrphanCandidate {
  const OrphanCandidate({
    required this.file,
    required this.relativePath,
    required this.sizeBytes,
    required this.ageDays,
  });

  final File file;

  /// 画布相对路径（`images/<f>` 或 `videos/<f>`）。
  final String relativePath;
  final int sizeBytes;
  final int ageDays;
}
