// MediaImportService 契约：把用户选的图片 / 视频复制进画布的 imports/ 目录。
//
// 导入、OS 拖入、粘贴图片、跨画布素材四个入口共用这一条路：文件一律落
// `canvases/<id>/imports/<uuid>.<小写扩展名>`——FileResolverService 不许路径越出画布根，
// 所以媒体必须先复制进来，库里只存画布相对路径。原文件名只进节点 label 与
// type_config.original_name（见 core/constants/import_keys.dart），不进磁盘文件名：
// 不撞名，也不受 Windows 大小写不敏感 / 非法字符、macOS NFD 文件名的影响。
//
// 本文件无 Flutter import：纯函数（白名单判定、原文件名）与契约类型。
import 'package:path/path.dart' as p;

/// 可导入的图片扩展名（小写，不带点）。
const List<String> kImportImageExtensions = <String>['png', 'jpg', 'jpeg', 'webp'];

/// 可导入的视频扩展名（小写，不带点）。
const List<String> kImportVideoExtensions = <String>['mp4', 'mov', 'webm'];

/// 画布根下的导入目录名。
const String kImportsSubdir = 'imports';

/// 复制失败时 `LocalIOError.extra['reason']` 的取值（内部标识，English-only）。
const String kImportReasonUnsupported = 'unsupported';
const String kImportReasonUnreadable = 'unreadable';
const String kImportReasonEmpty = 'empty';
const String kImportReasonCopyFailed = 'copy_failed';

/// 导入的媒体种类。
enum MediaImportKind { image, video }

/// 按扩展名判种类：大小写不敏感，`.jpeg` 归图片；无扩展名 / 不在白名单 ⇒ null。
///
/// 只看 basename 的扩展名——目录名里带点、Windows 反斜杠、盘符大小写都不影响。
/// [context] 给测试注入 `p.windows` / `p.posix`，生产用当前平台的。
MediaImportKind? mediaImportKindOf(String path, {p.Context? context}) {
  final String ext = importExtensionOf(path, context: context);
  if (ext.isEmpty) return null;
  if (kImportImageExtensions.contains(ext)) return MediaImportKind.image;
  if (kImportVideoExtensions.contains(ext)) return MediaImportKind.video;
  return null;
}

/// 小写、不带点的扩展名；没有扩展名 ⇒ 空串。
String importExtensionOf(String path, {p.Context? context}) {
  final p.Context ctx = context ?? p.context;
  return ctx.extension(ctx.basename(path)).toLowerCase().replaceFirst('.', '');
}

/// 原文件名（basename，含扩展名，大小写原样）。
String importOriginalName(String path, {p.Context? context}) =>
    (context ?? p.context).basename(path);

/// 图片像素尺寸探针：给绝对路径，返回宽高；探不出（格式不认、文件坏了）⇒ null，不抛。
typedef ImageSizeProbe = Future<({int width, int height})?> Function(
  String absolutePath,
);

/// 一次复制的结果。
class ImportedMedia {
  const ImportedMedia({
    required this.relativePath,
    required this.kind,
    required this.bytes,
    this.width,
    this.height,
  });

  /// 画布相对路径，形如 `imports/<uuid>.png`（正斜杠）。
  final String relativePath;
  final MediaImportKind kind;

  /// 复制进来的字节数。
  final int bytes;

  /// 图片的像素宽高；探不出、或是视频（视频的宽高由抽帧探针给）⇒ null。
  final int? width;
  final int? height;
}

abstract class MediaImportService {
  /// 复制 [sourcePath] 到画布 `imports/<uuid>.<小写扩展名>`：先写 `.partial`、flush、
  /// rename；返回画布相对路径与字节数（图片顺带宽高）。
  ///
  /// [onProgress] 收 0..1 的已复制比例，单调不减，成功时最后一次为 1.0。
  ///
  /// 不在白名单 / 源不可读 / 0 字节 / 写盘失败 ⇒ 抛 LocalIOError，
  /// `extra['reason']` 分别为 [kImportReasonUnsupported] / [kImportReasonUnreadable] /
  /// [kImportReasonEmpty] / [kImportReasonCopyFailed]；失败时磁盘上不留 `.partial`
  /// 也不留目标文件。
  Future<ImportedMedia> copyIntoCanvas({
    required String projectId,
    required String canvasId,
    required String sourcePath,
    void Function(double fraction)? onProgress,
  });

  /// 删掉此前复制进来的 [relativePath]。尽力而为：文件不在、删不掉、路径非法都吞掉
  /// 记日志，不抛。
  Future<void> discard({
    required String projectId,
    required String canvasId,
    required String relativePath,
  });
}
