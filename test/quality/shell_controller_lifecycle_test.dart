// R21（fix round 2）源码级契约测试：ShellNavigator 永不被 invalidate / refresh。
//
// 背景：ShellState 值对象层用「无 copyWith、无 closeCanvas」把"清 canvasId"
// 挡在类型层面之外（见 shell_state.dart 头部注释），但这条不变式只在值对象的
// 具名迁移方法面上成立。Riverpod 的 provider 生命周期是另一层：任何地方写
// `ref.invalidate(shellControllerProvider)` 或 `ref.refresh(shellControllerProvider)`
// 都会重跑 ShellNavigator.build()，拿回默认的 const ShellState()——canvasId
// 静默归 null，画布保活当场销毁，而且绕过 resetSession() 里对
// galleryControllerProvider 的联动 invalidate。
//
// 这个写法尤其危险：它「看起来是对的」——调用方通常是想实现"还原备份后回到
// Studio"，invalidate 之后 tab 确实变回了 studio，表面行为对，但悄悄带崩了
// canvasId 与画廊联动，且没有任何运行时异常。会话重置的唯一正确入口是
// ShellNavigator.resetSession()。
//
// 形制照抄 test/quality/no_direct_instantiation_test.dart：纯 dart:io 读文件 +
// expect(offenders, isEmpty)，不引入 flutter_test 以外的依赖。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

void main() {
  // 命中 invalidate(shellControllerProvider / refresh(shellControllerProvider，
  // 不论紧跟 `)`、`.notifier`还是其它成员访问——\b 保证不会误伤某个以
  // shellControllerProvider 为前缀的别的标识符（当前仓库里没有，纯防御）。
  final offendingCall =
      RegExp(r'\b(invalidate|refresh)\(\s*shellControllerProvider\b');

  test('lib 下禁止 invalidate/refresh(shellControllerProvider)——会话重置只走 resetSession()',
      () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ not found');

    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (_isGenerated(path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final trimmed = raw.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;

        if (offendingCall.hasMatch(raw)) {
          offenders.add(
            '$path:${i + 1}  invalidate/refresh(shellControllerProvider) 会静默'
            '重跑 build() 清空 canvasId、绕过 resetSession() 的画廊联动清理；'
            '会话重置请改调 ShellNavigator.resetSession()：${raw.trim()}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'R21 生命周期契约违例：\n${offenders.join('\n')}',
    );
  });
}
