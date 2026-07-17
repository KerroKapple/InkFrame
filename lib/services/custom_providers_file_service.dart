// custom_providers.json 读取/校验/兜底（PROVIDER-API §13.1）。
//
// 兜底策略：文件缺失=空列表（静默）；不可读/JSON 损坏/顶层非数组=空列表+WARN；
// 单条非法=仅剔除该条+WARN（含 index 与 reason），绝不整文件作废、绝不炸启动。
// load() 由 main() 在构建 ProviderContainer 前调用（同 FilePreferencesService）。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/errors/ink_error.dart';
import '../core/interfaces/custom_provider_source.dart';
import '../core/interfaces/custom_provider_store.dart';
import '../core/logging/logger_service.dart';
import '../core/models/custom_provider_config.dart';
import '../core/models/custom_provider_validation.dart';
import '../core/paths/app_paths.dart';

/// 空实现：默认 DI 与单测用，不碰磁盘。
class EmptyCustomProviderSource implements CustomProviderSource {
  const EmptyCustomProviderSource();

  @override
  List<CustomProviderConfig> get configs => const [];
}

/// 文件实现：`<root>/config/custom_providers.json`。
///
/// 写侧（GAP-1,CustomProviderStore）：按 raw 条目操作保真——读侧剔除的
/// 非法/未知条目原位保留;损坏文件拒写（LocalIOError）绝不覆盖;
/// `.partial`→rename 原子落盘,2 空格缩进保持可手编。写不触会话内快照。
class CustomProvidersFileService
    implements CustomProviderSource, CustomProviderStore {
  CustomProvidersFileService({
    required AppPaths paths,
    required LoggerService logger,
    Set<String> reservedProviderIds = const <String>{},
  })  : _paths = paths,
        _logger = logger,
        _reservedProviderIds = reservedProviderIds;

  static const String _module = 'custom_providers';
  static const String fileName = 'custom_providers.json';

  final AppPaths _paths;
  final LoggerService _logger;
  final Set<String> _reservedProviderIds;

  List<CustomProviderConfig> _configs = const [];

  File get _file => File(p.join(_paths.config.path, fileName));

  @override
  List<CustomProviderConfig> get configs => _configs;

  Future<void> load() async {
    _configs = const [];
    final File f = _file;
    final String raw;
    try {
      if (!await f.exists()) return;
      raw = await f.readAsString();
    } on FileSystemException catch (e) {
      _warnFile('config file unreadable', e.message);
      return;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      _warnFile('config file corrupted', e.message);
      return;
    }
    if (decoded is! List) {
      _warnFile('top-level must be a json array', decoded.runtimeType.toString());
      return;
    }

    final seenIds = <String>{};
    final parsed = <CustomProviderConfig>[];
    for (var i = 0; i < decoded.length; i++) {
      final config = _parseEntry(decoded[i], i, seenIds);
      if (config != null) parsed.add(config);
    }
    _configs = List.unmodifiable(parsed);
  }

  CustomProviderConfig? _parseEntry(
    Object? entry,
    int index,
    Set<String> seenIds,
  ) {
    if (entry is! Map) {
      _warnEntry(index, 'entry_not_an_object');
      return null;
    }
    String? field(String key) {
      final v = entry[key];
      if (v is! String) return null;
      final trimmed = v.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    for (final key in const [
      'id',
      'display_name',
      'template',
      'base_url',
      'model_id',
    ]) {
      if (field(key) == null) {
        _warnEntry(index, 'missing_or_empty_field', field: key);
        return null;
      }
    }

    // 各字段规则统一走 custom_provider_validation 纯函数（与设置页内联
    // 校验同一事实源）；告警顺序与 seenIds 语义保持原样。
    final id = field('id')!;
    if (kCustomProviderIdPattern.hasMatch(id) == false) {
      _warnEntry(index, 'invalid_id', id: id);
      return null;
    }
    if (!seenIds.add(id)) {
      _warnEntry(index, 'duplicate_id', id: id);
      return null;
    }

    final template = field('template')!;
    if (validateTemplate(template) != null) {
      _warnEntry(index, 'unknown_template', id: id, extra: {
        'template': template,
      });
      return null;
    }

    final rawUrl = field('base_url')!;
    if (validateBaseUrl(rawUrl) != null) {
      _warnEntry(index, 'invalid_base_url', id: id);
      return null;
    }
    final baseUri = Uri.parse(rawUrl);

    final config = CustomProviderConfig(
      id: id,
      displayName: field('display_name')!,
      template: template,
      // 尾部 `/` 规范化：Dio baseUrl + '/path' 拼接避免双斜杠。
      baseUrl: _stripTrailingSlash(baseUri.toString()),
      modelId: field('model_id')!,
    );
    if (_reservedProviderIds.contains(config.providerId)) {
      _warnEntry(index, 'conflicts_with_builtin_provider', id: id);
      seenIds.remove(id);
      return null;
    }
    return config;
  }

  static String _stripTrailingSlash(String url) => normalizeBaseUrl(url);

  // ── 写侧（CustomProviderStore）────────────────────────────────────────

  @override
  Future<List<CustomProviderConfig>> list() async {
    final raw = await _readRawForEdit(missingOk: true);
    final seenIds = <String>{};
    final parsed = <CustomProviderConfig>[];
    for (var i = 0; i < raw.length; i++) {
      final config = _parseEntry(raw[i], i, seenIds);
      if (config != null) parsed.add(config);
    }
    return List.unmodifiable(parsed);
  }

  @override
  Future<void> upsert(CustomProviderConfig config) async {
    final raw = await _readRawForEdit(missingOk: true);
    final entry = <String, Object?>{
      'id': config.id,
      'display_name': config.displayName,
      'template': config.template,
      'base_url': config.baseUrl,
      'model_id': config.modelId,
    };
    final idx = _indexOfId(raw, config.id);
    if (idx >= 0) {
      // 被编辑条目自身也保真（#200 评审 P2-1）：以旧 raw map 为基底合并,
      // 用户手编的未知字段（如 "_note"）不随 UI 编辑丢失。
      final old = raw[idx];
      raw[idx] = <String, Object?>{
        if (old is Map) ...old.cast<String, Object?>(),
        ...entry,
      };
    } else {
      raw.add(entry);
    }
    await _writeAtomic(raw);
  }

  @override
  Future<void> remove(String id) async {
    final raw = await _readRawForEdit(missingOk: true);
    final idx = _indexOfId(raw, id);
    if (idx < 0) return;
    raw.removeAt(idx);
    await _writeAtomic(raw);
  }

  static int _indexOfId(List<Object?> raw, String id) {
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e is Map && e['id'] == id) return i;
    }
    return -1;
  }

  /// 编辑用 raw 读取：文件缺失=空数组;损坏/顶层非数组=拒写抛 LocalIOError
  /// （读侧兜底是「app 能启动」,写侧兜底是「不销毁用户数据」——语义相反）。
  Future<List<Object?>> _readRawForEdit({required bool missingOk}) async {
    final f = _file;
    final String raw;
    try {
      if (!await f.exists()) {
        if (missingOk) return <Object?>[];
        throw const LocalIOError(extra: {'op': 'custom_providers.read'});
      }
      raw = await f.readAsString();
    } on FileSystemException {
      throw const LocalIOError(extra: {'op': 'custom_providers.read'});
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const LocalIOError(
        extra: {'op': 'custom_providers.read', 'reason': 'corrupted'},
      );
    }
    if (decoded is! List) {
      throw const LocalIOError(
        extra: {'op': 'custom_providers.read', 'reason': 'not_an_array'},
      );
    }
    return List<Object?>.of(decoded);
  }

  Future<void> _writeAtomic(List<Object?> raw) async {
    final f = _file;
    final tmp = File('${f.path}.partial');
    try {
      await f.parent.create(recursive: true);
      await tmp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(raw),
        flush: true,
      );
      await tmp.rename(f.path);
    } on FileSystemException {
      // 放行点：清理残留 .partial 后以 InkError 语义上抛。
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } on FileSystemException {
        // 清理失败不掩盖主错误。
      }
      throw const LocalIOError(extra: {'op': 'custom_providers.write'});
    }
  }

  void _warnFile(String msg, String detail) {
    _logger.warn(_module, msg, extra: {
      'path': _file.path,
      'detail': detail,
    });
  }

  void _warnEntry(
    int index,
    String reason, {
    String? id,
    String? field,
    Map<String, Object?>? extra,
  }) {
    _logger.warn(_module, 'entry rejected', extra: {
      'index': index,
      'reason': reason,
      'id': ?id,
      'field': ?field,
      ...?extra,
    });
  }
}
