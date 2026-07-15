// AppPaths：文件系统路径单一出口。
//
// 所有代码通过 AppPaths 取路径，不直接调 path_provider / Platform.environment。
// 这让单测可以注入 tmp 目录覆盖，也满足 PRD §12.5「文件系统结构」的集中管理要求。
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class AppPaths {
  /// 数据根目录（Win `%LOCALAPPDATA%\InkFrame`、macOS `~/Library/Application Support/InkFrame`）。
  Directory get root;

  /// `<root>/logs/`
  Directory get logs;

  /// `<root>/crashes/`（未捕获错误崩溃落盘，与 logs 平级）
  Directory get crashes;

  /// `<root>/config/`
  Directory get config;

  /// `<root>/database/`（PG 数据目录）
  Directory get database;

  /// `<root>/projects/`（项目画布产物）
  Directory get projects;

  /// `<root>/backups/`（每日 pg_dump 冷备，LB-10）
  Directory get backups;

  /// 确保所有子目录存在（首次启动调用）。
  Future<void> ensureInitialized();
}

/// 默认实现：平台惯例路径（DIR-1）；缺对应环境变量时退回 `applicationSupportDirectory`。
class DefaultAppPaths implements AppPaths {
  DefaultAppPaths._(this._root);

  static Future<DefaultAppPaths> create() async {
    final String? conventional = conventionalRootPath(
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
      env: Platform.environment,
    );
    if (conventional != null) {
      return DefaultAppPaths._(Directory(conventional));
    }
    final support = await getApplicationSupportDirectory();
    return DefaultAppPaths._(Directory(p.join(support.path, 'InkFrame')));
  }

  /// 测试注入入口：显式指定根目录。
  factory DefaultAppPaths.forRoot(Directory root) => DefaultAppPaths._(root);

  /// 纯函数：平台惯例根路径（D-10/DIR-1）。不满足条件返回 null。
  static String? conventionalRootPath({
    required bool isWindows,
    required bool isMacOS,
    required Map<String, String> env,
  }) {
    if (isWindows) {
      final String? local = env['LOCALAPPDATA'];
      return local == null ? null : p.join(local, 'InkFrame');
    }
    if (isMacOS) {
      final String? home = env['HOME'];
      return home == null
          ? null
          : p.join(home, 'Library', 'Application Support', 'InkFrame');
    }
    return null;
  }

  /// 纯函数：旧版根路径 `~/InkFrame`（迁移检测用）。无 Home 返回 null。
  static String? legacyRootPath(Map<String, String> env) {
    final String? home = env['HOME'] ?? env['USERPROFILE'];
    return home == null ? null : p.join(home, 'InkFrame');
  }

  final Directory _root;

  @override
  Directory get root => _root;

  @override
  Directory get logs => Directory(p.join(_root.path, 'logs'));

  @override
  Directory get crashes => Directory(p.join(_root.path, 'crashes'));

  @override
  Directory get config => Directory(p.join(_root.path, 'config'));

  @override
  Directory get database => Directory(p.join(_root.path, 'database'));

  @override
  Directory get projects => Directory(p.join(_root.path, 'projects'));

  @override
  Directory get backups => Directory(p.join(_root.path, 'backups'));

  @override
  Future<void> ensureInitialized() async {
    for (final Directory d in <Directory>[
      root,
      logs,
      crashes,
      config,
      database,
      projects,
      backups,
    ]) {
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
    }
  }
}
