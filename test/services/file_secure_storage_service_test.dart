import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_secure_storage_service.dart';

void main() {
  late Directory tmp;
  late FileSecureStorageService storage;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ink_fss_');
    final paths = DefaultAppPaths.forRoot(tmp);
    storage = FileSecureStorageService(() => paths);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('store → retrieve 往返', () async {
    await storage.store('provider.dashscope.apiKey', 'sk-test-1');
    expect(await storage.retrieve('provider.dashscope.apiKey'), 'sk-test-1');
  });

  test('retrieve 未知 key 返回 null', () async {
    expect(await storage.retrieve('nope'), isNull);
  });

  test('exists 反映存储状态', () async {
    expect(await storage.exists('k'), isFalse);
    await storage.store('k', 'v');
    expect(await storage.exists('k'), isTrue);
  });

  test('delete 后不存在', () async {
    await storage.store('k', 'v');
    await storage.delete('k');
    expect(await storage.exists('k'), isFalse);
    expect(await storage.retrieve('k'), isNull);
  });

  test('覆盖写同 key', () async {
    await storage.store('k', 'v1');
    await storage.store('k', 'v2');
    expect(await storage.retrieve('k'), 'v2');
  });

  test('落盘为 config/secrets.dev.json 的 JSON 对象', () async {
    await storage.store('a', '1');
    final f = File('${tmp.path}/config/secrets.dev.json');
    expect(await f.exists(), isTrue);
    expect(jsonDecode(await f.readAsString()), {'a': '1'});
  });
}
