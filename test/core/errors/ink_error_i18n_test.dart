// 错误码 ↔ i18n key 编译期闸门（评审 P2#7）：
// 每个 InkErrorCode 必须有 messageKey 映射，且该 key 必须同时存在于
// app_en.arb 与 app_zh.arb。防"新增错误码忘配文案 → messageKey 运行时崩溃 /
// 静默退化 errorUnknown"。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';

Map<String, Object?> _arb(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

void main() {
  final en = _arb('lib/l10n/app_en.arb');
  final zh = _arb('lib/l10n/app_zh.arb');

  test('每个 InkErrorCode 都有 messageKey 映射', () {
    for (final code in InkErrorCode.values) {
      expect(
        kInkErrorMessageKeys[code],
        isNotNull,
        reason: '$code 缺 kInkErrorMessageKeys 映射（messageKey 会 ! 崩溃）',
      );
    }
  });

  test('每个 messageKey 同时存在于 app_en.arb 与 app_zh.arb', () {
    for (final entry in kInkErrorMessageKeys.entries) {
      final key = entry.value;
      expect(en.containsKey(key), isTrue,
          reason: '${entry.key} → "$key" 不在 app_en.arb');
      expect(zh.containsKey(key), isTrue,
          reason: '${entry.key} → "$key" 不在 app_zh.arb');
    }
  });
}
