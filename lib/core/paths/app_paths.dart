// AppPaths：文件系统路径单一出口。
//
// 所有代码通过 AppPaths 取路径，不直接调 path_provider / Platform.environment。
// 这让单测可以注入 tmp 目录覆盖，也满足 PRD §12.5「文件系统结构」的集中管理要求。
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class AppPaths {
  /// `~/InkFrame/` 根目录。
  Directory get root;

  /// `~/InkFrame/logs/`
  Directory get logs;

  /// `~/InkFrame/config/`
  Directory get config;

  /// `~/InkFrame/database/`（PG 数据目录）
  Directory get database;

  /// `~/InkFrame/projects/`（项目画布产物）
  Directory get projects;

  /// 确保所有子目录存在（首次启动调用）。
  Future<void> ensureInitialized();
}

/// 默认实现：`~/InkFrame`；若平台未提供 Home，退回 `applicationSupportDirectory`。
class DefaultAppPaths implements AppPaths {
  DefaultAppPaths._(this._root);

  static Future<DefaultAppPaths> create() async {
    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final Directory root;
    if (home != null) {
      root = Directory(p.join(home, 'InkFrame'));
    } else {
      final support = await getApplicationSupportDirectory();
      root = Directory(p.join(support.path, 'InkFrame'));
    }
    return DefaultAppPaths._(root);
  }

  /// 测试注入入口：显式指定根目录。
  factory DefaultAppPaths.forRoot(Directory root) => DefaultAppPaths._(root);

  final Directory _root;

  @override
  Directory get root => _root;

  @override
  Directory get logs => Directory(p.join(_root.path, 'logs'));

  @override
  Directory get config => Directory(p.join(_root.path, 'config'));

  @override
  Directory get database => Directory(p.join(_root.path, 'database'));

  @override
  Directory get projects => Directory(p.join(_root.path, 'projects'));

  @override
  Future<void> ensureInitialized() async {
    for (final Directory d in <Directory>[root, logs, config, database, projects]) {
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
    }
  }
}
