// PreferencesService 实现：InMemory（默认 DI / 单测）+ File（config/preferences.json）。
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/preferences_service.dart';
import '../core/models/app_preferences.dart';
import '../core/paths/app_paths.dart';

/// 纯内存：默认 DI 与单测用，不碰磁盘。
class InMemoryPreferencesService implements PreferencesService {
  InMemoryPreferencesService([AppPreferences initial = const AppPreferences()])
      : _cache = initial;

  AppPreferences _cache;

  @override
  AppPreferences get current => _cache;

  @override
  Future<AppPreferences> load() async => _cache;

  @override
  Future<void> update(AppPreferences Function(AppPreferences) mutate) async {
    _cache = mutate(_cache);
  }
}

/// 文件实现：~/InkFrame/config/preferences.json。读/解析/写失败一律降级（不抛）。
class FilePreferencesService implements PreferencesService {
  FilePreferencesService(this._paths);

  final AppPaths _paths;
  AppPreferences _cache = const AppPreferences();

  File get _file => File(p.join(_paths.config.path, 'preferences.json'));

  @override
  AppPreferences get current => _cache;

  @override
  Future<AppPreferences> load() async {
    try {
      final f = _file;
      if (!await f.exists()) return _cache;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map) {
        _cache = AppPreferences.fromMap(decoded.cast<String, Object?>());
      }
    } on FileSystemException {
      // 读失败 → 用默认值，不阻断启动。
    } on FormatException {
      // 文件损坏 → 用默认值。
    }
    return _cache;
  }

  @override
  Future<void> update(AppPreferences Function(AppPreferences) mutate) async {
    _cache = mutate(_cache);
    try {
      await _paths.config.create(recursive: true);
      await _file.writeAsString(jsonEncode(_cache.toMap()), flush: true);
    } on FileSystemException {
      // 写失败 → 仅内存更新，下次再试；绝不让设置操作炸 UI。
    }
  }
}
