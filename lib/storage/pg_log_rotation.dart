// pg.log 启动期轮转（BOARD 185，#191 评审 P3-5）。
//
// 由来：`pg_ctl -l pg.log` 是追加写，postgres 自己不轮转（没开
// logging_collector）。app 的 logger 有 10MB 滚动 + 200MB 总预算，但只认
// `inkframe.*` 前缀——pg.log 不在里面。本地优先的应用一跑几个月，它会无界
// 增长，诊断包（`logs/*` 整目录打包）也跟着胀。
//
// 【只能在启动期、`pg_ctl start` 之前做】运行中的 postmaster 持有 pg.log 的
// 句柄，Windows 上改名会因占用而失败。`PgController._doStart` 在「复用存活
// 实例」分支**之后**才调本函数——走到那里可以确定没有我们的 postmaster 在跑。
// 即便如此仍可能失败（别的进程开着它：编辑器、杀软），所以失败一律吞掉、
// 只报结果——轮转是卫生，不该挡住数据库启动。
//
// 口径与 app logger 对齐：单文件 10MB 封顶；另外只留最近 [kPgLogKeep] 份历史，
// 于是 pg 日志在磁盘上最多约 (1 + 3) × 10MB。
import 'dart:io';

import 'package:path/path.dart' as p;

/// 单个 pg.log 的大小上限，与 app logger 的 `maxFileBytes` 同值。
const int kPgLogMaxBytes = 10 * 1024 * 1024;

/// 轮转出来的历史份数上限。
const int kPgLogKeep = 3;

enum PgLogRotation {
  /// 不存在或没到上限，什么都没动。
  notNeeded,

  /// 已改名为 `pg.<时间戳>.log`（并按 keep 剪掉了更老的）。
  rotated,

  /// 改名失败（文件被占用 / 权限）。pg.log 原样保留，下次启动再试。
  failed,
}

/// [pgLog] 超过 [maxBytes] 就改名为同目录下的 `pg.<UTC 时间戳>.log`，然后只留
/// 最新的 [keep] 份历史。
///
/// 时间戳格式与 app logger 的 `inkframe.<ts>.log` 一致（`yyyyMMddTHHmmss`），
/// 字典序即时间序——剪枝按文件名排，不靠 mtime（mtime 会被复制 / 解压改掉）。
PgLogRotation rotatePgLogIfLarge(
  File pgLog, {
  required DateTime nowUtc,
  int maxBytes = kPgLogMaxBytes,
  int keep = kPgLogKeep,
}) {
  try {
    if (!pgLog.existsSync() || pgLog.lengthSync() < maxBytes) {
      return PgLogRotation.notNeeded;
    }
    final String ts = nowUtc
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
    final String dir = pgLog.parent.path;
    var target = File(p.join(dir, 'pg.$ts.log'));
    var suffix = 0;
    while (target.existsSync()) {
      suffix += 1;
      target = File(p.join(dir, 'pg.$ts-$suffix.log'));
    }
    pgLog.renameSync(target.path);
  } on FileSystemException {
    return PgLogRotation.failed;
  }

  _pruneRotated(pgLog.parent, keep: keep);
  return PgLogRotation.rotated;
}

/// 只认 `pg.<…>.log`，**绝不碰 `pg.log` 本身**，也不碰 app 的 `inkframe.*`。
final RegExp _kRotatedPgLog = RegExp(r'^pg\.[0-9T]+(-\d+)?\.log$');

void _pruneRotated(Directory dir, {required int keep}) {
  final List<File> rotated = <File>[
    for (final FileSystemEntity e in dir.listSync())
      if (e is File && _kRotatedPgLog.hasMatch(p.basename(e.path))) e,
  ]..sort((File a, File b) => p.basename(b.path).compareTo(p.basename(a.path)));
  for (final File old in rotated.skip(keep)) {
    try {
      old.deleteSync();
    } on FileSystemException {
      // 删不掉的老日志下次启动再剪；不为卫生挡启动。
    }
  }
}
