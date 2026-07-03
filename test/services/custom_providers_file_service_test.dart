// CustomProvidersFileService：有效/缺失/损坏/部分坏条目 的解析与兜底契约
// （PROVIDER-API §13.1）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/custom_providers_file_service.dart';

import '../helpers/recording_logger.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late RecordingLogger logger;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_custom_providers_');
    paths = DefaultAppPaths.forRoot(tmp);
    logger = RecordingLogger();
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  CustomProvidersFileService build({Set<String> reserved = const {}}) =>
      CustomProvidersFileService(
        paths: paths,
        logger: logger,
        reservedProviderIds: reserved,
      );

  void writeConfig(Object content) {
    paths.config.createSync(recursive: true);
    final file =
        File('${paths.config.path}/${CustomProvidersFileService.fileName}');
    file.writeAsStringSync(
      content is String ? content : jsonEncode(content),
    );
  }

  Map<String, Object?> entry({
    String id = 'my-endpoint',
    String displayName = 'My Endpoint',
    String template = 'openai-image',
    String baseUrl = 'https://example.com/v1',
    String modelId = 'flux-pro',
  }) =>
      {
        'id': id,
        'display_name': displayName,
        'template': template,
        'base_url': baseUrl,
        'model_id': modelId,
      };

  List<String?> warnReasons() => logger
      .byLevel(InkLogLevel.warn)
      .map((r) => r.extra?['reason'] as String?)
      .toList();

  test('EmptyCustomProviderSource 恒为空', () {
    expect(const EmptyCustomProviderSource().configs, isEmpty);
  });

  test('文件缺失 → 空列表，零告警', () async {
    final svc = build();
    await svc.load();
    expect(svc.configs, isEmpty);
    expect(logger.records, isEmpty);
  });

  test('有效文件 → 全部解析，保持顺序', () async {
    writeConfig([
      entry(),
      entry(id: 'second', displayName: 'Second', modelId: 'sdxl'),
    ]);
    final svc = build();
    await svc.load();

    expect(svc.configs, hasLength(2));
    expect(svc.configs[0].providerId, 'custom:my-endpoint');
    expect(svc.configs[0].modelId, 'flux-pro');
    expect(svc.configs[1].providerId, 'custom:second');
    expect(logger.records, isEmpty);
  });

  test('base_url 尾部斜杠被规范化剔除', () async {
    writeConfig([entry(baseUrl: 'https://example.com/v1/')]);
    final svc = build();
    await svc.load();
    expect(svc.configs.single.baseUrl, 'https://example.com/v1');
  });

  test('JSON 损坏 → 空列表 + WARN，不抛', () async {
    writeConfig('{not valid json');
    final svc = build();
    await svc.load();
    expect(svc.configs, isEmpty);
    final warns = logger.byLevel(InkLogLevel.warn);
    expect(warns, hasLength(1));
    expect(warns.single.module, 'custom_providers');
  });

  test('顶层不是数组 → 空列表 + WARN', () async {
    writeConfig({'providers': <Object?>[]});
    final svc = build();
    await svc.load();
    expect(svc.configs, isEmpty);
    expect(logger.byLevel(InkLogLevel.warn), hasLength(1));
  });

  test('坏条目逐条剔除并告警，好条目照常生效', () async {
    writeConfig([
      entry(), // 有效
      42, // 非对象
      entry(id: 'no-model', modelId: ''), // 空字段
      {'id': 'missing-fields'}, // 缺字段
      entry(id: 'bad id'), // 非法 id（含空格）
      entry(id: 'unknown-tpl', template: 'no-such-template'), // 未知模板
      entry(id: 'my-endpoint', modelId: 'other'), // id 重复
      entry(id: 'bad-url', baseUrl: 'not a url'), // 非法 base_url
      entry(id: 'ftp-url', baseUrl: 'ftp://example.com'), // 非 http(s)
      // 带 query/fragment:Dio baseUrl 字符串拼接会把路径吞进 query,必须拒。
      entry(id: 'query-url', baseUrl: 'https://relay.example.com/v1?key=abc'),
      entry(id: 'frag-url', baseUrl: 'https://relay.example.com/v1#frag'),
      entry(id: 'ok-2', displayName: 'OK 2'), // 有效
    ]);
    final svc = build();
    await svc.load();

    expect(
      svc.configs.map((c) => c.id).toList(),
      ['my-endpoint', 'ok-2'],
    );
    expect(warnReasons(), [
      'entry_not_an_object',
      'missing_or_empty_field',
      'missing_or_empty_field',
      'invalid_id',
      'unknown_template',
      'duplicate_id',
      'invalid_base_url',
      'invalid_base_url',
      'invalid_base_url',
      'invalid_base_url',
    ]);
    // 告警带 index 定位，便于手编排错。
    final first = logger.byLevel(InkLogLevel.warn).first;
    expect(first.extra?['index'], 1);
  });

  test('providerId 与内置冲突 → 剔除 + WARN', () async {
    writeConfig([
      entry(id: 'clash'),
      entry(id: 'safe'),
    ]);
    final svc = build(reserved: {'custom:clash'});
    await svc.load();

    expect(svc.configs.map((c) => c.id), ['safe']);
    expect(warnReasons(), ['conflicts_with_builtin_provider']);
  });

  test('重复 load 以最后一次为准（无累积）', () async {
    writeConfig([entry()]);
    final svc = build();
    await svc.load();
    expect(svc.configs, hasLength(1));

    writeConfig('{broken');
    await svc.load();
    expect(svc.configs, isEmpty);
  });
}
