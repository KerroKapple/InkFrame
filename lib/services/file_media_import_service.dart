// FileMediaImportService：MediaImportService 的磁盘实现——复制进 `canvases/<id>/imports/`。
//
// 写盘顺序：`<uuid>.<ext>.partial` → flush → rename 成 `<uuid>.<ext>`；任何一步失败都删掉
// `.partial` 再抛 LocalIOError——目录里不留半截文件（做法同 file_notification_sound_store）。
//
// 按块读写而不是 File.copy：一是要报进度；二是 File.copy 在 Windows 上会把源文件的只读
// 属性一起带过来。路径一律经 FileResolverService.resolve（画布根内），源路径 / 目标路径的
// PathSecurityError、FileSystemException 都包成 LocalIOError，不让 ArgumentError 漏到调用方。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/errors/ink_error.dart';
import '../core/interfaces/file_resolver_service.dart';
import '../core/interfaces/media_import_service.dart';
import '../core/logging/logger_service.dart';
import '../core/media/png_dimensions.dart';

/// 日志 module 名（内部标识，English-only）。
const String kMediaImportLogModule = 'canvas.media_import';

/// 一次读写的块大小。
const int kMediaImportChunkBytes = 1024 * 1024;

/// `.partial` → 目标文件的改名 seam（测试注入失败；Windows 上造不出「目标目录只读」）。
typedef PartialRename = Future<File> Function(File partial, String targetPath);

class FileMediaImportService implements MediaImportService {
  FileMediaImportService({
    required FileResolverService resolver,
    LoggerService? logger,
    String Function()? newId,
    ImageSizeProbe? imageSizeProbe,
    PartialRename? rename,
    int chunkBytes = kMediaImportChunkBytes,
  })  : assert(chunkBytes > 0),
        _resolver = resolver,
        _logger = logger,
        _newId = newId ?? const Uuid().v4,
        _probe = imageSizeProbe ?? probeEncodedImageSize,
        _rename = rename ?? _defaultRename,
        _chunkBytes = chunkBytes;

  final FileResolverService _resolver;
  final LoggerService? _logger;
  final String Function() _newId;
  final ImageSizeProbe _probe;
  final PartialRename _rename;
  final int _chunkBytes;

  static Future<File> _defaultRename(File partial, String targetPath) =>
      partial.rename(targetPath);

  @override
  Future<ImportedMedia> copyIntoCanvas({
    required String projectId,
    required String canvasId,
    required String sourcePath,
    void Function(double fraction)? onProgress,
  }) async {
    final MediaImportKind? kind = mediaImportKindOf(sourcePath);
    final String ext = importExtensionOf(sourcePath);
    if (kind == null) {
      throw LocalIOError(
        extra: <String, Object?>{'reason': kImportReasonUnsupported, 'ext': ext},
      );
    }

    final File source = File(sourcePath);
    final int total;
    try {
      total = await source.length();
    } on FileSystemException catch (e, st) {
      throw _ioError(kImportReasonUnreadable, 'stat', e, st);
    }
    if (total == 0) {
      throw const LocalIOError(
        extra: <String, Object?>{'reason': kImportReasonEmpty},
      );
    }

    // 目标名一律 <uuid>.<小写扩展名>；原名不进磁盘。
    final String relativePath = '$kImportsSubdir/${_newId()}.$ext';
    final File target;
    try {
      target = _resolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: relativePath,
      );
    } on PathSecurityError catch (e, st) {
      throw LocalIOError(
        cause: e,
        stackTrace: st,
        extra: const <String, Object?>{
          'reason': kImportReasonCopyFailed,
          'op': 'resolve',
        },
      );
    }
    final File partial = File('${target.path}.partial');

    RandomAccessFile? src;
    RandomAccessFile? dst;
    var written = 0;
    var reported = 0.0;
    // 出错时按所处的一步归因：读源算 unreadable，建目录 / 写 / flush / 改名算 copy_failed。
    var reason = kImportReasonUnreadable;
    var op = 'open_source';
    try {
      src = await source.open();
      reason = kImportReasonCopyFailed;
      op = 'create_dir';
      await target.parent.create(recursive: true);
      op = 'open_partial';
      dst = await partial.open(mode: FileMode.writeOnly);
      while (true) {
        reason = kImportReasonUnreadable;
        op = 'read';
        final Uint8List chunk = await src.read(_chunkBytes);
        if (chunk.isEmpty) break;
        reason = kImportReasonCopyFailed;
        op = 'write';
        await dst.writeFrom(chunk);
        written += chunk.length;
        // 源文件在复制途中变长时比例会超过 1：夹住，保证单调不减、不越过 1.0。
        final double fraction = written >= total ? 1.0 : written / total;
        if (fraction > reported) {
          reported = fraction;
          onProgress?.call(fraction);
        }
      }
      reason = kImportReasonCopyFailed;
      op = 'flush';
      await dst.flush();
      await dst.close();
      dst = null;
      await src.close();
      src = null;
      if (written > 0) {
        op = 'rename';
        await _rename(partial, target.path);
      }
    } on FileSystemException catch (e, st) {
      await _closeQuietly(dst);
      await _closeQuietly(src);
      await _deleteQuietly(partial);
      throw _ioError(reason, op, e, st);
    }

    // stat 时有字节、读的时候一个都没读到（复制途中被清空）：按空文件处理。
    if (written == 0) {
      await _deleteQuietly(partial);
      throw const LocalIOError(
        extra: <String, Object?>{'reason': kImportReasonEmpty},
      );
    }
    // 源文件在复制途中变短：最后一块没走到 1.0，成功后补一次。
    if (reported < 1.0) onProgress?.call(1.0);

    int? width;
    int? height;
    if (kind == MediaImportKind.image) {
      final ({int width, int height})? size =
          ext == 'png' ? await _pngSize(target) : await _probe(target.path);
      width = size?.width;
      height = size?.height;
    }

    return ImportedMedia(
      relativePath: relativePath,
      kind: kind,
      bytes: written,
      width: width,
      height: height,
    );
  }

  @override
  Future<void> discard({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) async {
    try {
      final File f = _resolver.resolve(
        projectId: projectId,
        canvasId: canvasId,
        relativePath: relativePath,
      );
      if (await f.exists()) await f.delete();
    } on FileSystemException catch (e) {
      _logger?.warn(
        kMediaImportLogModule,
        'media_import.discard_failed',
        extra: <String, Object?>{
          'path': relativePath,
          'os_error': e.osError?.toString(),
        },
      );
    } on PathSecurityError {
      _logger?.warn(
        kMediaImportLogModule,
        'media_import.discard_unsafe_path',
        extra: <String, Object?>{'path': relativePath},
      );
    }
  }

  /// PNG：读文件头 [kPngHeaderProbeBytes] 字节取宽高；读不到 / 不是 PNG ⇒ null。
  Future<({int width, int height})?> _pngSize(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final Uint8List head = await raf.read(kPngHeaderProbeBytes);
      return pngDimensions(head);
    } on FileSystemException {
      return null;
    } finally {
      await _closeQuietly(raf);
    }
  }

  LocalIOError _ioError(
    String reason,
    String op,
    FileSystemException e,
    StackTrace st,
  ) =>
      LocalIOError(
        cause: e,
        stackTrace: st,
        extra: <String, Object?>{
          'reason': reason,
          'op': op,
          'os_error': e.osError?.toString(),
        },
      );

  Future<void> _closeQuietly(RandomAccessFile? f) async {
    if (f == null) return;
    try {
      await f.close();
    } on FileSystemException {
      // 关闭失败不掩盖主错误。
    }
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException catch (e) {
      // 清理失败不掩盖主错误；残留的 .partial 只会被孤儿回收器记成候选日志。
      _logger?.warn(
        kMediaImportLogModule,
        'media_import.partial_delete_failed',
        extra: <String, Object?>{
          'file': p.basename(f.path),
          'os_error': e.osError?.toString(),
        },
      );
    }
  }
}

/// 默认的 [ImageSizeProbe]：dart:ui 的 ImageDescriptor 只读编码头取宽高，不解码像素。
///
/// 整个文件交给 ImmutableBuffer：JPG 的 SOF 段可能排在大块 EXIF 之后，只喂开头几 KB 会探不出。
/// 格式不认 / 文件读不到 ⇒ null。
Future<({int width, int height})?> probeEncodedImageSize(String absolutePath) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(absolutePath);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final int width = descriptor.width;
    final int height = descriptor.height;
    if (width <= 0 || height <= 0) return null;
    return (width: width, height: height);
  } on Exception {
    // dart:ui 读不到文件、不认格式时抛的是裸 Exception（没有更具体的类型可接）。
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
