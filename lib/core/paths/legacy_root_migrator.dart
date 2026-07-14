// LegacyRootMigrator：DIR-1 数据目录一次性搬迁（`~/InkFrame` → 平台惯例路径）。
//
// 语义（对齐 ADR-0012 前向迁移：用户数据必须存活）：
// - 目标已存在 → 已迁移或新装,一律不动文件系统（防重复搬迁）
// - 旧址不存在 → 全新安装,无事可做
// - 旧址存在且目标不存在 → 原子 rename 整树;成功后旧址留 MOVED 标记文件
// - rename 失败 → 本次会话回退旧址（绝不走 copy 半态路径）
import 'dart:io';

import 'package:path/path.dart' as p;

enum LegacyMigrationOutcome { freshInstall, alreadyAtTarget, migrated, keptLegacy }

class LegacyMigrationResult {
  const LegacyMigrationResult({
    required this.outcome,
    required this.effectiveRoot,
    this.failureReason,
    this.legacyDataIgnored = false,
  });

  final LegacyMigrationOutcome outcome;

  /// 本次会话应实际使用的根目录（迁移失败时=旧址）。
  final Directory effectiveRoot;

  /// keptLegacy 时的底层失败原因（诊断用）。
  final String? failureReason;

  /// alreadyAtTarget 且旧址仍有真实数据（非仅标记）——供启动日志告警。
  final bool legacyDataIgnored;
}

class LegacyRootMigrator {
  LegacyRootMigrator({
    required Directory legacyRoot,
    required Directory targetRoot,
    Future<void> Function(Directory from, String toPath)? moveDirectory,
  })  : _legacyRoot = legacyRoot,
        _targetRoot = targetRoot,
        _moveDirectory = moveDirectory ?? _rename;

  static const String markerFileName = 'INKFRAME-MOVED.txt';

  /// 迁移启用守卫：惯例根解析失败（fallback 根）或无旧址或同路径 → 不迁移。
  /// fallback 根一旦参与迁移，环境变量的一次抖动即可把数据搬进错误目录（评审 P1）。
  static bool shouldRun({
    required String? conventionalRoot,
    required String? legacyRoot,
  }) {
    return conventionalRoot != null &&
        legacyRoot != null &&
        legacyRoot != conventionalRoot;
  }

  final Directory _legacyRoot;
  final Directory _targetRoot;
  final Future<void> Function(Directory from, String toPath) _moveDirectory;

  static Future<void> _rename(Directory from, String toPath) async {
    await from.rename(toPath);
  }

  Future<LegacyMigrationResult> migrate() async {
    if (await _targetRoot.exists()) {
      return LegacyMigrationResult(
        outcome: LegacyMigrationOutcome.alreadyAtTarget,
        effectiveRoot: _targetRoot,
        legacyDataIgnored: await _legacyHasRealData(),
      );
    }
    // 空目录/只剩标记的空壳不算存量数据——搬空壳会把过期标记植入活动根，
    // 且在 fallback 根场景下参与制造密码覆写链（评审 P1）。
    if (!await _legacyHasRealData()) {
      return LegacyMigrationResult(
        outcome: LegacyMigrationOutcome.freshInstall,
        effectiveRoot: _targetRoot,
      );
    }
    try {
      await _targetRoot.parent.create(recursive: true);
      await _moveDirectory(_legacyRoot, _targetRoot.path);
    } on FileSystemException catch (e) {
      return LegacyMigrationResult(
        outcome: LegacyMigrationOutcome.keptLegacy,
        effectiveRoot: _legacyRoot,
        failureReason: e.toString(),
      );
    }
    await _writeMarker();
    return LegacyMigrationResult(
      outcome: LegacyMigrationOutcome.migrated,
      effectiveRoot: _targetRoot,
    );
  }

  /// 旧址是否存在「标记文件以外」的真实内容。
  Future<bool> _legacyHasRealData() async {
    if (!await _legacyRoot.exists()) {
      return false;
    }
    await for (final FileSystemEntity e in _legacyRoot.list()) {
      if (p.basename(e.path) != markerFileName) {
        return true;
      }
    }
    return false;
  }

  /// 旧址留信息性标记（用户翻旧目录时能找到数据去向）；写失败不影响迁移结果。
  Future<void> _writeMarker() async {
    try {
      await _legacyRoot.create(recursive: true);
      await File(p.join(_legacyRoot.path, markerFileName)).writeAsString(
        'InkFrame data moved to: ${_targetRoot.path}\n'
        'Moved at: ${DateTime.now().toUtc().toIso8601String()}\n',
      );
    } on FileSystemException {
      // 标记纯信息性。
    }
  }
}
