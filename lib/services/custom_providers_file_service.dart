// custom_providers.json 读取/校验/兜底（PROVIDER-API §13.1）。
//
// 兜底策略：文件缺失=空列表（静默）；不可读/JSON 损坏/顶层非数组=空列表+WARN；
// 单条非法=仅剔除该条+WARN（含 index 与 reason），绝不整文件作废、绝不炸启动。
// load() 由 main() 在构建 ProviderContainer 前调用（同 FilePreferencesService）。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/interfaces/custom_provider_source.dart';
import '../core/logging/logger_service.dart';
import '../core/models/custom_provider_config.dart';
import '../core/models/provider_protocol_template.dart';
import '../core/paths/app_paths.dart';

/// 空实现：默认 DI 与单测用，不碰磁盘。
class EmptyCustomProviderSource implements CustomProviderSource {
  const EmptyCustomProviderSource();

  @override
  List<CustomProviderConfig> get configs => const [];
}

/// 文件实现：`<root>/config/custom_providers.json`。
class CustomProvidersFileService implements CustomProviderSource {
  CustomProvidersFileService({
    required AppPaths paths,
    required LoggerService logger,
    Set<String> reservedProviderIds = const <String>{},
  })  : _paths = paths,
        _logger = logger,
        _reservedProviderIds = reservedProviderIds;

  static const String _module = 'custom_providers';
  static const String fileName = 'custom_providers.json';

  /// `id` 白名单模式——进 SecureStorage key / jobs.provider_id / 日志，收紧字符集。
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$');

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

    final id = field('id')!;
    if (!_idPattern.hasMatch(id)) {
      _warnEntry(index, 'invalid_id', id: id);
      return null;
    }
    if (!seenIds.add(id)) {
      _warnEntry(index, 'duplicate_id', id: id);
      return null;
    }

    final template = field('template')!;
    if (!kProviderProtocolTemplates.containsKey(template)) {
      _warnEntry(index, 'unknown_template', id: id, extra: {
        'template': template,
      });
      return null;
    }

    final baseUri = Uri.tryParse(field('base_url')!);
    // 拒 query/fragment/userinfo：Dio baseUrl 与 path 是字符串拼接，
    // 带 query 的 base_url 会把请求路径吞进 query 值，端点必然 404。
    if (baseUri == null ||
        !baseUri.isAbsolute ||
        (baseUri.scheme != 'http' && baseUri.scheme != 'https') ||
        baseUri.host.isEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        baseUri.userInfo.isNotEmpty) {
      _warnEntry(index, 'invalid_base_url', id: id);
      return null;
    }

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

  static String _stripTrailingSlash(String url) {
    var out = url;
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
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
