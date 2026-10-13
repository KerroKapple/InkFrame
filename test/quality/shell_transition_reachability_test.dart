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

  // 「canvasId 恒属于 state.project」这条不变量的自证闸。
  //
  // 由来：`shell_state.dart` 的 `closeProject()` 注释曾写「openCanvas 的三个
  // 调用点全部带 withProject」——写的那天是真的，到 2026-10-13 已经是六个、
  // 其中一个不带。那句话是 closeProject() 连带清 canvasId 的**全部理由**，
  // 它悄悄烂掉了，而 BOARD 还照着它记了一条「withProject 改成必传」的建议
  // （前提已不成立：真改必传，左栏面板就得重传一份自己并不拥有的 ProjectRef）。
  //
  // 要钉的不变量不是「全部都带」，而是两种调用各自成立：
  //   带 withProject  ⇒ 在换项目，project 与 canvasId 一起写进去；
  //   不带            ⇒ 在同项目内换画布，`withProject ?? project` 原样留住。
  // 两种都让 canvasId 属于 state.project。所以闸钉的是**豁免名单本身**：
  // 不带 withProject 的调用点集合必须恰好等于下面这份写明理由的清单。
  //
  // 口径限制：按文本抽参数（从命中行起拼到圆括号配平），不是静态分析。
  // 把 `withProject` 写成变量再展开（`...args`）这类写法抓不到——Dart 没有
  // 这种写法，真出现了也该当场在评审里被问住。
  test('openCanvas 的调用点要么带 withProject，要么在同项目豁免名单里', () {
    const Map<String, String> exempt = <String, String>{
      'lib/features/canvas/widgets/canvas_project_panel.dart':
          '左栏项目面板在【同一项目内】换画布——沿用 state.project 正是要的语义；'
              '要求它重传一份自己并不拥有的 ProjectRef 只会多一个传错的机会',
    };

    final Set<String> without = <String>{};
    int total = 0;
    final RegExp call = RegExp(r'\.openCanvas\s*\(');
    for (final FileSystemEntity e in Directory('lib').listSync(recursive: true)) {
      if (e is! File) continue;
      final String path = e.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || _isGenerated(path)) continue;
      if (path.endsWith(_stateFile) || path.endsWith(_navFile)) continue;
      final List<String> lines = e.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isComment(lines[i]) || !call.hasMatch(lines[i])) continue;
        total++;
        // 参数可能跨行：从命中行起往下拼，到圆括号配平为止。
        final StringBuffer args = StringBuffer();
        int depth = 0;
        for (var j = i; j < lines.length; j++) {
          args.write('${lines[j]}\n');
          for (final int c in lines[j].codeUnits) {
            if (c == 0x28) depth++;
            if (c == 0x29) depth--;
          }
          if (depth <= 0) break;
        }
        if (!args.toString().contains('withProject')) {
          // 名单按文件记（同一文件里多个同类调用是同一条理由）。
          without.add(path.substring(path.indexOf('lib/')));
        }
      }
    }

    // 正控：抽空了就是正则失效，不是"真没有调用点"。
    expect(total, greaterThanOrEqualTo(5),
        reason: 'openCanvas 生产调用点只抽到 $total 个 ⇒ 正则失效，本闸形同不存在');
    expect(
      without,
      exempt.keys.toSet(),
      reason: '不带 withProject 的 openCanvas 调用点与豁免名单不一致。\n'
          '新增的调用点：要么带上 withProject（换项目），要么连同"为什么同项目"'
          '的理由加进本测试的 exempt 表。\n'
          '名单里却没命中的：说明那个调用点改带 withProject 了，把它从表里删掉'
          '——留着空条目会让下一个人以为这个豁免还在用。',
    );
  });
}
