// FileDeliveryService：DeliveryService 的落盘实现（P6）。
//
// 只会两件事：把媒体拷进 `<项目目录>/exports/`、把文本写进去。不认识 EDL、
// 不认识镜头（见 core/interfaces/delivery_service.dart 的头注）。
//
// 两条「别把用户的东西弄坏」的纪律：
//   1) 目录已存在时**只覆盖同名文件，不清目录**——用户往 exports/ 里放过别的东西。
//   2) 文本走 `.partial` → rename。中途取消（关窗）时只需删掉 `.partial`，
//      交付目录里**不会留下半条 EDL**；已拷完的媒体保留（稿 §3）。
//
// 媒体用 `File.copy`：稿的「转码：保持源 · 不重编码」就是字节拷贝，不需要 ffmpeg
// （仓库也不打包它）。
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/errors/ink_error.dart';
import '../core/interfaces/delivery_service.dart';
import '../core/interfaces/file_resolver_service.dart';
import '../core/interfaces/video_export_service.dart' show ExportCancelToken;
import '../core/logging/logger_service.dart';

/// 交付目录（项目根相对）。与视频导出共用 `exports/`。
const String _kExportsDir = 'exports';

/// 可写探针文件名。点开头 + 固定名：万一没删掉也不会被当成交付产物。
const String _kWriteProbeName = '.inkframe-write-probe';

const String _kLogModule = 'delivery';

class FileDeliveryService implements DeliveryService {
  FileDeliveryService({required FileResolverService fileResolver, LoggerService? logger})
      : _fileResolver = fileResolver,
        _logger = logger;

  final FileResolverService _fileResolver;
  final LoggerService? _logger;

  @override
  Future<bool> probeWritable({required String projectId}) async {
    try {
      final Directory dir = _exportsDir(projectId);
      await dir.create(recursive: true);
      final File probe = File(p.join(dir.path, _kWriteProbeName));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on FileSystemException catch (e) {
      _logger?.warn(_kLogModule, 'exports dir not writable',
          extra: <String, Object?>{'reason': e.message});
      return false;
    } on PathSecurityError {
      // projectId 非法（空串 / 带分隔符）——交付前检查照样当「不可写」处理。
      return false;
    }
  }

  @override
  Future<DeliveryOutcome> deliver({
    required String projectId,
    required List<DeliveryMediaCopy> media,
    required List<DeliveryTextFile> textFiles,
    void Function(int done, int total)? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    for (final DeliveryMediaCopy m in media) {
      _assertPlainFileName(m.fileName);
    }
    for (final DeliveryTextFile t in textFiles) {
      _assertPlainFileName(t.fileName);
    }

    final Directory dir = _exportsDir(projectId);
    final List<String> written = <String>[];
    // 半成品清单：取消 / 失败时逐个删掉（媒体不在内——已拷完的保留）。
    final List<File> partials = <File>[];
    try {
      await _createDir(dir);
      onProgress?.call(0, media.length);

      for (int i = 0; i < media.length; i++) {
        _throwIfCancelled(cancelToken);
        final DeliveryMediaCopy item = media[i];
        final File source = _fileResolver.resolveInProject(
          projectId: projectId,
          relativePath: item.sourceRelativePath,
        );
        if (!source.existsSync()) {
          throw LocalIOError(
            extra: <String, Object?>{
              'reason': 'delivery_source_missing',
              'path': item.sourceRelativePath,
            },
          );
        }
        await source.copy(p.join(dir.path, item.fileName));
        written.add(item.fileName);
        onProgress?.call(i + 1, media.length);
      }

      for (final DeliveryTextFile item in textFiles) {
        _throwIfCancelled(cancelToken);
        final File target = File(p.join(dir.path, item.fileName));
        final File partial = File('${target.path}.partial');
        partials.add(partial);
        await partial.writeAsString(item.contents, flush: true);
        _throwIfCancelled(cancelToken);
        await partial.rename(target.path);
        partials.remove(partial);
        written.add(item.fileName);
      }

      return DeliveryOutcome(
        outputDirRelative: _kExportsDir,
        outputDirAbsolutePath: dir.path,
        fileNames: written,
        mediaCount: media.length,
      );
    } on FileSystemException catch (e, st) {
      _cleanPartials(partials);
      throw LocalIOError(
        extra: <String, Object?>{
          'reason': 'delivery_io_failed',
          'detail': e.message,
        },
        cause: e,
        stackTrace: st,
      );
    } on InkError {
      // 取消 / 源缺失已经是具体的 InkError，原样上抛，只负责清半成品。
      _cleanPartials(partials);
      rethrow;
    }
  }

  Directory _exportsDir(String projectId) => Directory(
        _fileResolver
            .resolveInProject(projectId: projectId, relativePath: _kExportsDir)
            .path,
      );

  Future<void> _createDir(Directory dir) async {
    if (await dir.exists()) return;
    await dir.create(recursive: true);
  }

  void _throwIfCancelled(ExportCancelToken? token) {
    if (token != null && token.isCancelled) {
      throw const CancelledError.byUser(
        extra: <String, Object?>{'reason': 'delivery_cancelled'},
      );
    }
  }

  void _cleanPartials(List<File> partials) {
    for (final File f in partials) {
      try {
        if (f.existsSync()) f.deleteSync();
      } on FileSystemException {
        // 清不掉就留着：`.partial` 不是交付产物，下次交付会覆盖。
      }
    }
  }

  /// 单层文件名（与 FfmpegVideoExportService._assertPlainFileName 同规则）。
  /// 调用方给的名字都经 deliveryMediaFileName 清洗过，这里是防御性后置校验：
  /// 带分隔符的名字会把文件写到交付目录**外面**去。
  void _assertPlainFileName(String name) {
    final bool ok = name.isNotEmpty &&
        !name.contains('/') &&
        !name.contains(r'\') &&
        !name.contains(':') &&
        !name.contains('..');
    if (!ok) {
      throw ProviderError(
        code: InkErrorCode.invalidParameter,
        extra: <String, Object?>{
          'reason': 'delivery_bad_file_name',
          'name': name,
        },
      );
    }
  }
}
