// ARB 卫生回归：保证 en/zh key 集合完全一致，且不残留死 key（workspace* 系列）。
// CLAUDE.md 声明的"两 locale key 集合必须相同"在此固化为可执行断言。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 读取 ARB 文件里"真实"的 message key —— 排除 @@locale 与 @ 开头的 metadata。
Set<String> _messageKeys(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    fail('ARB not found: $path');
  }
  final Map<String, dynamic> json =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return json.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  const String enPath = 'lib/l10n/app_en.arb';
  const String zhPath = 'lib/l10n/app_zh.arb';

  test('en 与 zh 的 message key 集合完全一致', () {
    final Set<String> en = _messageKeys(enPath);
    final Set<String> zh = _messageKeys(zhPath);
    expect(en.difference(zh), isEmpty,
        reason: 'keys present in en but missing in zh');
    expect(zh.difference(en), isEmpty,
        reason: 'keys present in zh but missing in en');
  });

  test('不残留 workspace* 死 key（已被 Studio 重写取代）', () {
    final Set<String> all = <String>{
      ..._messageKeys(enPath),
      ..._messageKeys(zhPath),
    };
    final Iterable<String> orphans = all.where((k) => k.startsWith('workspace'));
    expect(orphans, isEmpty, reason: 'orphaned workspace* keys: $orphans');
  });
}
