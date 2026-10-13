// PreferencesService 实现：InMemory（默认 DI / 单测）+ File（config/preferences.json）。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/preferences_service.dart';
import '../core/logging/logger_service.dart';
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

/// 文件实现：`<root>/config/preferences.json`。读/解析/写失败一律降级（不抛）——
/// 但**降级必须留痕**，而且**写必须原子**。
///
/// 原来是 `writeAsString(..., flush: true)` 直接覆写，读写失败的 catch 块是空的。
/// 合起来的后果：写到一半被杀，留下半截 JSON → 下次启动 `FormatException` → 静默
/// 用默认值 → 下一次任何设置改动把默认值写回去 → 原来的设置**永久没了**，日志里
/// 什么都没有。而最危险的那次写恰好发生在最危险的时刻：退出时保存窗口位置，正是
/// 系统关机 / 注销强杀进程的窗口。丢的是全部 14 项设置，包括「首启向导已完成」
/// ——重启后向导重新弹出。`custom_providers.json` 早就是 `.partial` → rename 原子
/// 落盘了，这个文件是漏网的那个。
class FilePreferencesService implements PreferencesService {
  FilePreferencesService(this._paths, {LoggerService? logger})
      : _logger = logger;

  final AppPaths _paths;
  final LoggerService? _logger;
  AppPreferences _cache = const AppPreferences();

  static const String _logModule = 'app.preferences';

  /// 写盘串行链：每次只有一个写在跑，按 update 的先后落盘。
  ///
  /// 原子改名之后这一层是必需的：两次 update 并发（改主题的同时退出保存窗口位置）
  /// 若各写各的，**谁后改名谁赢**——旧快照可能盖掉新快照，新改的设置在磁盘上丢失。
  ///
  /// 诚实注记：这条是推理，**没有测试覆盖**。写过一条「并发两次 update 后磁盘是
  /// 后一次的值」，但本机文件系统太快，去掉串行链三轮都还是绿的——不承重的用例
  /// 只是装饰，删了。
  Future<void> _tail = Future<void>.value();

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
    } on FileSystemException catch (e) {
      // 读失败 → 用默认值，不阻断启动。
      _logger?.warn(_logModule, 'preferences.read_failed',
          extra: <String, Object?>{'os_error': e.osError?.toString()});
    } on FormatException catch (e) {
      // 文件损坏 → 用默认值。但先把坏文件另存一份：下一次 update 就会拿默认值把它
      // 覆盖掉，不留这一份，用户的设置就连同「为什么丢了」一起没了。
      _preserveCorrupt();
      _logger?.warn(_logModule, 'preferences.corrupt',
          extra: <String, Object?>{'reason': e.message});
    }
    return _cache;
  }

  void _preserveCorrupt() {
    try {
      _file.copySync('${_file.path}.corrupt');
    } on FileSystemException {
      // 另存失败不阻断启动——上面那条 warn 仍然会落。
    }
  }

  @override
  Future<void> update(AppPreferences Function(AppPreferences) mutate) {
    _cache = mutate(_cache);
    final AppPreferences snapshot = _cache;
    final Completer<void> done = Completer<void>();
    _tail = _tail.then((_) async {
      // 透明转发而非吞异常：_write 自己已处理 FileSystemException；万一别的异常
      // 漏出来，原样交回调用方，同时保证链尾恒常态完成——否则之后的每一次设置
      // 都永远排在一个失败的 future 后面，再也写不进盘（同 SerialMutationQueue 的
      // 放行点理由）。
      try {
        await _write(snapshot);
        done.complete();
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<void> _write(AppPreferences snapshot) async {
    final File f = _file;
    final File tmp = File('${f.path}.partial');
    try {
      await _paths.config.create(recursive: true);
      await tmp.writeAsString(jsonEncode(snapshot.toMap()), flush: true);
      await tmp.rename(f.path);
    } on FileSystemException catch (e) {
      // 写失败 → 仅内存更新，下次再试；绝不让设置操作炸 UI。但要留痕：持续写不
      // 进去的话，用户每次重启都会丢设置，日志是唯一的线索。
      _logger?.warn(_logModule, 'preferences.write_failed',
          extra: <String, Object?>{'os_error': e.osError?.toString()});
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } on FileSystemException {
        // 清理失败不掩盖主错误；残留的 .partial 下次写入时会被覆盖。
      }
    }
  }
}
