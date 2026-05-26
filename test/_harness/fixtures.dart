// Provider fixture loader：消除每个 provider test 自己写 _loadFixture 的重复。
//
// 约定：fixture 位于 test/fixtures/providers/<providerId>/<name>.json。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 读取 JSON fixture 并解析为 Map。
/// 文件不存在 → `fail()`，给出清晰路径而非抛 IO 异常。
Map<String, Object?> loadProviderFixture(String providerId, String name) {
  final String path = 'test/fixtures/providers/$providerId/$name.json';
  final File file = File(path);
  if (!file.existsSync()) {
    fail('fixture not found: $path');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// 原文返回（用于非 JSON / Response.fromJson 以外的场景）。
String loadProviderFixtureRaw(String providerId, String name) {
  final String path = 'test/fixtures/providers/$providerId/$name.json';
  final File file = File(path);
  if (!file.existsSync()) {
    fail('fixture not found: $path');
  }
  return file.readAsStringSync();
}
