// ReferenceLibraryReader 的 ai-pose-gallery-zh 实现。
//
// 读图库根目录下 data/ 里的四个 JSON（姿势 / 人像 / 服装 / 历代服装），统一成 ReferenceItem。
// - 解析放在后台 isolate（Isolate.run）：整库约 3,000 条、几 MB JSON，不卡界面。
//   isolate 里只做纯读取 + 解析，返回可传递的数据；logger 留在主 isolate，回来再记 warn。
// - 某个文件存在但读不出来 / 不是合法 JSON 数组：只跳过那一类，记进 skippedFiles 并记 warn。
// - 某个文件不存在：静默跳过（图库版本可能没带那一类）。
// - 一个文件都没解析成：当作「不是参考库」（用户多半选错了一级）。
// - 单条记录字段缺失或类型不对：跳过这一条，不算整个文件坏。
// - 成人向分类在这里就滤掉，不进条目列表。
// - JSON 里的图片路径是正斜杠、相对图库根目录，按段拼成本平台的绝对路径。
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../core/interfaces/reference_library_reader.dart';
import '../../core/logging/logger_service.dart';
import '../../core/models/reference_item.dart';
import 'ai_pose_gallery_zh_keys.dart';

class AiPoseGalleryZhReader implements ReferenceLibraryReader {
  AiPoseGalleryZhReader({required LoggerService logger}) : _logger = logger;

  final LoggerService _logger;

  static const String _logModule = 'reference_library.reader';

  @override
  Future<ReferenceLibraryLoad> load(String rootPath) async {
    if (rootPath.trim().isEmpty) return const ReferenceLibraryNotFound();
    final _ParseOutcome outcome = await _parseInBackground(rootPath);
    for (final _SkippedFile s in outcome.skipped) {
      _logger.warn(
        _logModule,
        'reference data file unreadable, category skipped',
        extra: <String, Object?>{'file': s.fileName, 'reason': s.reason},
      );
    }
    if (outcome.parsedFiles == 0) return const ReferenceLibraryNotFound();
    return ReferenceLibraryLoaded(
      List<ReferenceItem>.unmodifiable(outcome.items),
      List<String>.unmodifiable(
        <String>[for (final _SkippedFile s in outcome.skipped) s.fileName],
      ),
    );
  }

  // 静态方法里起 isolate：闭包只捕获 rootPath，不会把 this（含 logger）带过去。
  static Future<_ParseOutcome> _parseInBackground(String rootPath) =>
      Isolate.run(() => _parseLibrary(rootPath));
}

/// 读失败原因（只进日志 extra，不含路径）。
const String _reasonUnreadable = 'unreadable';
const String _reasonMalformedJson = 'malformed_json';
const String _reasonNotAList = 'not_a_list';

/// 一个数据文件对应哪一类。
typedef _Source = ({String fileName, ReferenceCategory category});

const List<_Source> _kSources = <_Source>[
  (fileName: AiPoseGalleryZhKeys.poseFile, category: ReferenceCategory.pose),
  (
    fileName: AiPoseGalleryZhKeys.portraitFile,
    category: ReferenceCategory.portrait,
  ),
  (
    fileName: AiPoseGalleryZhKeys.costumeFile,
    category: ReferenceCategory.costume,
  ),
  (
    fileName: AiPoseGalleryZhKeys.costumeShiseiFile,
    category: ReferenceCategory.costume,
  ),
];

final class _SkippedFile {
  const _SkippedFile(this.fileName, this.reason);

  final String fileName;
  final String reason;
}

/// isolate 的返回值：只含字符串、枚举与不可变值对象，可跨 isolate 传递。
final class _ParseOutcome {
  const _ParseOutcome(this.items, this.skipped, this.parsedFiles);

  final List<ReferenceItem> items;
  final List<_SkippedFile> skipped;

  /// 成功解析成 JSON 数组的文件个数；0 ⇒ 不是参考库。
  final int parsedFiles;
}

/// 在后台 isolate 里跑：纯读取 + 解析，不碰 logger。
_ParseOutcome _parseLibrary(String rootPath) {
  final List<ReferenceItem> items = <ReferenceItem>[];
  final List<_SkippedFile> skipped = <_SkippedFile>[];
  if (!Directory(rootPath).existsSync()) {
    return _ParseOutcome(items, skipped, 0);
  }
  var parsedFiles = 0;
  for (final _Source source in _kSources) {
    final File file =
        File(p.join(rootPath, AiPoseGalleryZhKeys.dataDir, source.fileName));
    if (!file.existsSync()) continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FileSystemException {
      // 读不出来（权限、编码不是 UTF-8 等）：只跳过这一类。
      skipped.add(_SkippedFile(source.fileName, _reasonUnreadable));
      continue;
    } on FormatException {
      // 截断 / 不是 JSON：只跳过这一类。
      skipped.add(_SkippedFile(source.fileName, _reasonMalformedJson));
      continue;
    }
    if (decoded is! List<Object?>) {
      skipped.add(_SkippedFile(source.fileName, _reasonNotAList));
      continue;
    }
    parsedFiles++;
    for (final Object? raw in decoded) {
      if (raw is! Map<Object?, Object?>) continue;
      final ReferenceItem? item = _parseRecord(rootPath, source.category, raw);
      if (item != null) items.add(item);
    }
  }
  return _ParseOutcome(items, skipped, parsedFiles);
}

/// 一条记录 → 条目；字段缺失、类型不对或属于成人向 ⇒ null（跳过这一条）。
ReferenceItem? _parseRecord(
  String rootPath,
  ReferenceCategory category,
  Map<Object?, Object?> raw,
) {
  final String? name;
  final String? group;
  final String? angle;
  final List<String> originalKeys;
  switch (category) {
    case ReferenceCategory.pose:
      final String? system = _str(raw, AiPoseGalleryZhKeys.poseSystem);
      // 体系缺失就无从判断是否成人向：宁可跳过。
      if (system == null ||
          AiPoseGalleryZhKeys.adultPoseSystems.contains(system)) {
        return null;
      }
      name = _str(raw, AiPoseGalleryZhKeys.poseName);
      group = _str(raw, AiPoseGalleryZhKeys.poseGroup);
      angle = _str(raw, AiPoseGalleryZhKeys.poseAngle);
      originalKeys = const <String>[AiPoseGalleryZhKeys.original];
    case ReferenceCategory.portrait:
      name = _str(raw, AiPoseGalleryZhKeys.portraitName);
      group = _str(raw, AiPoseGalleryZhKeys.portraitGroup);
      angle = null;
      originalKeys = const <String>[AiPoseGalleryZhKeys.original];
    case ReferenceCategory.costume:
      name = _str(raw, AiPoseGalleryZhKeys.costumeName);
      group = _str(raw, AiPoseGalleryZhKeys.costumeGroup);
      angle = null;
      if (group != null &&
          AiPoseGalleryZhKeys.adultCostumeGroups.contains(group)) {
        return null;
      }
      originalKeys = const <String>[
        AiPoseGalleryZhKeys.original,
        AiPoseGalleryZhKeys.preview,
      ];
  }
  final String? id = _str(raw, AiPoseGalleryZhKeys.id);
  final String? thumb = _str(raw, AiPoseGalleryZhKeys.thumb);
  String? original;
  for (final String key in originalKeys) {
    original = _str(raw, key);
    if (original != null) break;
  }
  if (id == null ||
      name == null ||
      group == null ||
      thumb == null ||
      original == null) {
    return null;
  }
  return ReferenceItem(
    id: id,
    category: category,
    name: name,
    group: group,
    angle: angle,
    thumbPath: _resolve(rootPath, thumb),
    originalPath: _resolve(rootPath, original),
    // 检索字段缺失时退到名字，至少能按名字搜到。
    searchText: _str(raw, AiPoseGalleryZhKeys.search) ?? name,
  );
}

/// 非空字符串才算有值。
String? _str(Map<Object?, Object?> raw, String key) {
  final Object? v = raw[key];
  return v is String && v.isNotEmpty ? v : null;
}

/// JSON 里的相对路径是正斜杠：按段拼，Windows 上得到反斜杠的绝对路径。
String _resolve(String rootPath, String relative) =>
    p.absolute(p.joinAll(<String>[rootPath, ...relative.split('/')]));
