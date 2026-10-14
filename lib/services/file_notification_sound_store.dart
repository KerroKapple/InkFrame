// FileNotificationSoundStore：NotificationSoundStore 的磁盘实现——`<root>/config/sounds/`。
//
// 只存一份：`notification.<ext>`（扩展名取源文件的、转小写）。同扩展名的新文件经
// `.partial` → rename 原子顶替旧的；扩展名不同的旧文件在新文件就位**之后**再删。
//
// 用「读字节 → 写新文件」而不是 File.copy：copy 在 Windows 上会把源文件的只读属性
// 一起带过来，下一次导入就改名顶替不了它了。文件上限只有 2 MB，读进内存无妨；
// 读完再按实际字节数复核一次上限（stat 之后文件可能还在长）。
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/errors/ink_error.dart';
import '../core/interfaces/notification_sound_store.dart';
import '../core/logging/logger_service.dart';
import '../core/paths/app_paths.dart';
import '../features/notifications/models/notification_prefs.dart';

class FileNotificationSoundStore implements NotificationSoundStore {
  FileNotificationSoundStore({required AppPaths paths, LoggerService? logger})
      : _paths = paths,
        _logger = logger;

  final AppPaths _paths;
  final LoggerService? _logger;

  static const String _logModule = 'notifications.sound_store';

  /// 存下来的文件名主干：`notification.<ext>`。
  static const String _baseName = 'notification';

  Directory get _dir =>
      Directory(p.join(_paths.config.path, kCustomNotificationSoundDir));

  @override
  Future<String> importFile(String sourcePath) async {
    final String ext = p.extension(sourcePath).toLowerCase().replaceFirst('.', '');
    if (!kCustomNotificationSoundExtensions.contains(ext)) {
      throw LocalIOError(
        extra: <String, Object?>{
          'reason': kNotificationSoundUnsupportedReason,
          'ext': ext,
        },
      );
    }

    final File source = File(sourcePath);
    final int statBytes;
    try {
      statBytes = await source.length();
    } on FileSystemException catch (e, st) {
      throw _ioFailed('stat', e, st);
    }
    // 先按 stat 拦一道：别把一个几百 MB 的文件整个读进内存才发现太大。
    _checkSize(statBytes);

    final Uint8List bytes;
    try {
      bytes = await source.readAsBytes();
    } on FileSystemException catch (e, st) {
      throw _ioFailed('read', e, st);
    }
    _checkSize(bytes.length);

    final String fileName = '$_baseName.$ext';
    final File target = File(p.join(_dir.path, fileName));
    final File partial = File('${target.path}.partial');
    try {
      await _dir.create(recursive: true);
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(target.path);
    } on FileSystemException catch (e, st) {
      await _deleteQuietly(partial);
      throw _ioFailed('write', e, st);
    }

    await _deleteOthers(keep: fileName);
    return fileName;
  }

  void _checkSize(int bytes) {
    if (bytes > kCustomNotificationSoundMaxBytes) {
      throw LocalIOError(
        extra: <String, Object?>{
          'reason': kNotificationSoundTooLargeReason,
          'bytes': bytes,
        },
      );
    }
    if (bytes == 0) {
      throw const LocalIOError(
        extra: <String, Object?>{'reason': kNotificationSoundEmptyReason},
      );
    }
  }

  LocalIOError _ioFailed(String op, FileSystemException e, StackTrace st) =>
      LocalIOError(
        cause: e,
        stackTrace: st,
        extra: <String, Object?>{
          'reason': kNotificationSoundIoFailedReason,
          'op': op,
          'os_error': e.osError?.toString(),
        },
      );

  /// 删掉上一份（扩展名不同的 `notification.*`）。只动白名单里的扩展名——目录里别的
  /// 东西不是我们放的，不碰。删不掉（被占用）只记日志：偏好只认新文件名，残留无害，
  /// 下一次导入再清。
  Future<void> _deleteOthers({required String keep}) async {
    for (final String ext in kCustomNotificationSoundExtensions) {
      final String name = '$_baseName.$ext';
      if (name == keep) continue;
      final File stale = File(p.join(_dir.path, name));
      try {
        if (await stale.exists()) await stale.delete();
      } on FileSystemException catch (e) {
        _logger?.warn(
          _logModule,
          'notification_sound.stale_delete_failed',
          extra: <String, Object?>{
            'file': name,
            'os_error': e.osError?.toString(),
          },
        );
      }
    }
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // 清理失败不掩盖主错误；残留的 .partial 下次导入时会被覆盖。
    }
  }

  @override
  String? resolve(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    // 只认单纯的文件名：偏好文件是能手改的 JSON，不能让它把出声方指到数据目录外面去。
    if (fileName == '.' || fileName == '..' || p.basename(fileName) != fileName) {
      return null;
    }
    return p.join(_dir.path, fileName);
  }
}
