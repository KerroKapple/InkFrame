// 死 API 回归闸：`ShellState` / `ShellNavigator` 的每个具名迁移都必须有生产调用点。
//
// 由来：BOARD 记过一条「有测试的死 API」——`setProject` 在 `lib/` 下只有定义，
// 全部消费点都在测试里。测试让它看起来是活的：表驱动单测钉死了它的语义，
// 于是没人发现它从未被调用过。这类债只有源码级闸能抓——analyzer 不会报
// 「public 方法无人调用」，而测试覆盖率反而是满的。
//
// 口径（刻意写明限制，别让下一个人以为它比实际更严）：
// - 迁移清单从两个定义文件里正则抽：`ShellState <name>(` 与 `void <name>(`，
//   私有（下划线开头）跳过。
// - 调用点扫 `lib/**/*.dart`【除这两个定义文件】，匹配 `.<name>(`。两个定义
//   文件互为彼此的实现（navigator 委托给 state 同名方法），不算生产消费。
// - **按名字判定，不按接收者类型**：`nav.resetSession()` 同时让
//   `ShellState.resetSession` 与 `ShellNavigator.resetSession` 判活。这对
//   「整条迁移是死的」这个目标足够——两层是一对一委托，一层死另一层必然也死。
// - 逐行正则，不是静态分析器：调用写成跨行（`.` 与方法名拆到两行）会漏。
//   目标是拦住"加了个迁移、只用测试养着"的自然写法。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _stateFile = 'lib/features/shell/models/shell_state.dart';
const String _navFile = 'lib/features/shell/providers/shell_controller.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

/// 注释行不算声明，也不算调用点。
bool _isComment(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

Set<String> _declaredIn(String path, RegExp pattern) {
  final File f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path not found');
  final Set<String> names = <String>{};
  for (final String line in f.readAsLinesSync()) {
    if (_isComment(line)) continue;
    for (final RegExpMatch m in pattern.allMatches(line)) {
      final String name = m.group(1)!;
      if (name.startsWith('_')) continue;
      names.add(name);
    }
  }
  return names;
}

/// `lib/` 下（除两个定义文件）调用过 `.<name>(` 的位置。
List<String> _callSites(String name) {
  final RegExp call = RegExp('\\.$name\\s*\\(');
  final List<String> hits = <String>[];
  for (final FileSystemEntity e in Directory('lib').listSync(recursive: true)) {
    if (e is! File) continue;
    final String path = e.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') || _isGenerated(path)) continue;
    if (path.endsWith(_stateFile) || path.endsWith(_navFile)) continue;
    final List<String> lines = e.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_isComment(lines[i])) continue;
      if (call.hasMatch(lines[i])) hits.add('$path:${i + 1}');
    }
  }
  return hits;
}

void main() {
  test('ShellState / ShellNavigator 的每个具名迁移都有生产调用点', () {
    final Set<String> transitions = <String>{
      // `ShellState goTab(...)` 这类返回新态的迁移。
      ..._declaredIn(_stateFile, RegExp(r'\bShellState\s+([A-Za-z_]\w*)\s*\(')),
      // navigator 侧的 `void goTab(...)` 委托。
      ..._declaredIn(_navFile, RegExp(r'\bvoid\s+([A-Za-z_]\w*)\s*\(')),
    };
    expect(transitions, isNotEmpty, reason: '迁移清单抽空了 = 正则失效，不是"全死"');

    final List<String> dead = <String>[
      for (final String t in transitions.toList()..sort())
        if (_callSites(t).isEmpty) t,
    ];

    expect(
      dead,
      isEmpty,
      reason: '以下外壳迁移在 lib/ 下只有定义、没有任何生产调用点：\n'
          '${dead.join('\n')}\n'
          '要么接上真实 UI 动作，要么连同它的测试一起删——'
          '"有测试的死 API" 是本闸专治的那种债。',
    );
  });
}
