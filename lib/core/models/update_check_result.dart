// UpdateCheckResult：一次更新检查的结果（UPD-1）。
//
// 手写不可变类（与 AppPreferences 同例外）：纯结果 DTO,不落盘不进 JSON 协议,
// 不为它引 freezed/json 代码生成。
import 'package:flutter/foundation.dart';

@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    this.latestVersion,
    this.releaseUrl,
  });

  /// 本机运行版本（pubspec version,不含 build number）。
  final String currentVersion;

  /// 仅当远端存在更高版本时非空（规范化 semver 字符串,无 v 前缀）。
  final String? latestVersion;

  /// 新版 Release 页链接（https）。远端未给合法 https 链接时为 null。
  final String? releaseUrl;

  bool get updateAvailable => latestVersion != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateCheckResult &&
          other.currentVersion == currentVersion &&
          other.latestVersion == latestVersion &&
          other.releaseUrl == releaseUrl;

  @override
  int get hashCode => Object.hash(currentVersion, latestVersion, releaseUrl);
}
