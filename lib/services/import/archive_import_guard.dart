// 项目包导入安全门（LB-12 拍板 4 rev2）。
//
// 三层职责，全部纯逻辑可穷测：
//   1) validateArchiveEntries——条目名正面校验 + 声明尺寸粗筛 + 重名拒绝；
//      **声明尺寸是 zip 头的攻击者可控值，只作早期粗筛**，真防线是
//      CountingLimitOutputStream 的实测字节截停（解压层）。
//   2) validateManifest——formatVersion 严格相等 + schemaVersion 禁降级来源。
//   3) CountingLimitOutputStream——解压计数 sink，超限抛 ImportLimitExceeded。
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

/// 上限常量（实测字节；声明值粗筛共用）。
const int kImportMaxEntryBytes = 2 * 1024 * 1024 * 1024; // 2 GiB
const int kImportMaxTotalBytes = 16 * 1024 * 1024 * 1024; // 16 GiB
const int kImportMaxDataJsonBytes = 256 * 1024 * 1024; // 256 MiB
/// 条目名长度上限（叠加 projects/{uuid} 根后仍留 MAX_PATH 余量）。
const int kImportMaxEntryNameLength = 180;

/// 期望的顶级条目。
const String kImportManifestEntry = 'manifest.json';
const String kImportDataEntry = 'data.json';
const String kImportFilesPrefix = 'files/';

/// Windows 保留设备名（剥扩展名后大小写不敏感比较）。
const Set<String> kWindowsReservedNames = <String>{
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

final RegExp _uuidShape = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
  r'-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');
final RegExp _driveLetter = RegExp(r'^[A-Za-z]:');

/// guard 输入行（与提取共用同一解码后 Archive 派生，杜绝验一份解另一份）。
class ArchiveEntryMeta {
  const ArchiveEntryMeta({
    required this.name,
    required this.declaredSize,
    required this.isSymlink,
  });

  final String name;
  final int declaredSize;
  final bool isSymlink;
}

/// 条目集校验：违规返回拒绝原因（English-only 内部标识），null=放行。
String? validateArchiveEntries(List<ArchiveEntryMeta> entries) {
  final Set<String> seen = <String>{};
  var total = 0;
  for (final e in entries) {
    final String name = e.name;
    if (!seen.add(name)) return 'duplicate_entry'; // 重名=解码来源分裂，整包拒。
    if (e.isSymlink) return 'symlink_entry';
    if (name.isEmpty || name.length > kImportMaxEntryNameLength) {
      return 'entry_name_length';
    }
    if (name.contains(r'\')) return 'backslash';
    if (name.startsWith('/')) return 'absolute_path';
    if (_driveLetter.hasMatch(name)) return 'drive_letter';
    if (_controlChars.hasMatch(name)) return 'control_chars';

    // 名单外条目拒绝。
    final bool isTop =
        name == kImportManifestEntry || name == kImportDataEntry;
    final bool isFiles = name.startsWith(kImportFilesPrefix);
    if (!isTop && !isFiles) return 'unexpected_entry';

    final List<String> segments = name.split('/');
    for (final s in segments) {
      if (s.isEmpty || s == '.' || s == '..') return 'dot_segment';
      if (s.endsWith('.') || s.endsWith(' ')) return 'trailing_dot_or_space';
      final String base = s.contains('.') ? s.split('.').first : s;
      if (kWindowsReservedNames.contains(base.toUpperCase())) {
        return 'reserved_device_name';
      }
    }
    // files/canvases/{seg}/... 的 seg 必须 UUID 形（孤儿目录注入关死；
    // 是否命中 canvasIdMap 由重映射层再验）。
    if (isFiles && segments.length >= 3 && segments[1] == 'canvases') {
      if (!_uuidShape.hasMatch(segments[2])) return 'canvas_segment_shape';
    }

    // 声明尺寸粗筛（advisory；实测防线在 CountingLimitOutputStream）。
    if (e.declaredSize < 0 || e.declaredSize > kImportMaxEntryBytes) {
      return 'entry_size_declared';
    }
    total += e.declaredSize;
    if (total > kImportMaxTotalBytes) return 'total_size_declared';
  }
  if (!seen.contains(kImportManifestEntry)) return 'missing_manifest';
  if (!seen.contains(kImportDataEntry)) return 'missing_data';
  return null;
}

/// manifest 校验：违规返回拒绝原因，null=放行（Zero-BC：只认 formatVersion 1，
/// 拒绝更新 schema 的包——旧 app 不解释新数据）。
String? validateManifest(
  Map<String, Object?> manifest, {
  required int currentSchemaVersion,
}) {
  final Object? format = manifest['formatVersion'];
  if (format is! int || format != 1) return 'format_version';
  final Object? schema = manifest['schemaVersion'];
  if (schema is! int) return 'schema_version_missing';
  if (schema > currentSchemaVersion) return 'schema_version_newer';
  return null;
}

/// 实测字节超限（解压层防线命中）。
class ImportLimitExceeded implements Exception {
  const ImportLimitExceeded(this.what);
  final String what;
  @override
  String toString() => 'ImportLimitExceeded($what)';
}

/// 解压计数 sink：包装真实输出流，实测字节超限即刻抛——**这才是 zip bomb
/// 的真防线**（声明尺寸可被谎报为 0）。totalCounter 跨条目共享累计。
class CountingLimitOutputStream extends OutputStream {
  CountingLimitOutputStream(
    this._inner, {
    required this.entryLimit,
    required this.totalCounter,
  }) : super(byteOrder: _inner.byteOrder);

  final OutputStream _inner;
  final int entryLimit;
  final ImportByteBudget totalCounter;
  int _entryBytes = 0;

  void _count(int n) {
    _entryBytes += n;
    if (_entryBytes > entryLimit) throw const ImportLimitExceeded('entry');
    totalCounter.add(n);
  }

  @override
  int get length => _inner.length;

  @override
  void clear() => _inner.clear();

  @override
  void flush() => _inner.flush();

  @override
  void writeByte(int value) {
    _count(1);
    _inner.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _count(length ?? bytes.length);
    _inner.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _count(stream.length);
    _inner.writeStream(stream);
  }

  @override
  Future<void> close() => _inner.close();

  @override
  void closeSync() => _inner.closeSync();

  @override
  Uint8List subset(int start, [int? end]) => _inner.subset(start, end);
}

/// 跨条目总量预算。
class ImportByteBudget {
  ImportByteBudget({this.limit = kImportMaxTotalBytes});
  final int limit;
  int _used = 0;
  int get used => _used;

  void add(int n) {
    _used += n;
    if (_used > limit) throw const ImportLimitExceeded('total');
  }
}
