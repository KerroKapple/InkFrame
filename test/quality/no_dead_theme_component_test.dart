// 死件回归闸：`lib/theme/components/` 与 `lib/theme/primitives/` 里每个公开件
// 都必须有 `lib/` 下的消费点。
//
// 由来：复刻脚手架随 #245 退场、`Ws*` 随 #247 更名，留下一批"只有定义没有调用"
// 的呈现件。这类债 analyzer 不报（Dart 没有"public 类无人使用"的诊断），而
// **测试覆盖率反而是满的**——`InkAccentChip` / `InkSurfaceButton` 各带着一个
// widget test 活着，看起来完全健康。与
// `shell_transition_reachability_test.dart`（死 API 闸）同一个病、同一种药。
//
// 【判定口径 = lib/ 下有无消费点，测试里的引用不算活】这是刻意的：组件的用户是
// 界面，不是它自己的单测。"有测试的死件"正是本闸要抓的那一类。
//
// 口径与已知局限（逐条写明，别让下一个人以为它比实际更严）：
// - 声明清单：行首（允许缩进 / abstract / sealed / final / base）的
//   `class|enum|mixin <Name>`，下划线开头跳过。typedef 不扫（它们是函数类型别名，
//   在调用点以字面闭包出现，按名字找必然误判为死）。
// - 消费点：`lib/**/*.dart` 中**除声明文件本身**的任一非注释行出现
//   `\b<Name>\b`。注释里点名不算活——`delivery_panel_rows.dart` 曾在注释里解释
//   "几何与 InkToggle 相同但不引用它"，那正是死件的典型现场。
// - 逐行正则，不是静态分析器：声明与名字拆成两行、或只在生成文件里被消费，会漏。
//
// 本闸断言的是 `dead == _knownDead`（**不是** isEmpty）：既抓新增死件，也在某个
// 已知死件被复活或删除时强制更新这份清单，不让它悄悄烂掉。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 两个被扫的目录——它们是"可复用呈现件"的家，死件只会长在这里。
const List<String> _homes = <String>[
  'lib/theme/components',
  'lib/theme/primitives',
];

/// 已知无消费点，但**不在本次收口范围内**的公开件。各自的理由：
/// - `InkCardElevation`：`InkCard.elevation` 的入参枚举，只在 `ink_card.dart`
///   内部被读；调用方全用默认值。删它要改 `InkCard` 的签名，是另一件事。
/// - `InkToolBar` / `InkAccentChip` / `InkSurfaceButton`：真·死件（后两个还各带
///   一个 widget test 养着），与 2026-10-10 删掉的
///   `InkSelect` / `InkMonoField` / `InkSlider` / `InkToggle` 同源，但任务书点名
///   的只有 `ink_primitives.dart` 那四个。记在 BOARD，不在那个 PR 里顺手扩大范围。
const List<String> _knownDead = <String>[
  'InkAccentChip',
  'InkCardElevation',
  'InkSurfaceButton',
  'InkToolBar',
];

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

bool _isComment(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

final RegExp _decl = RegExp(
  r'^\s*(?:abstract\s+|sealed\s+|final\s+|base\s+)*(?:class|enum|mixin)\s+'
  r'([A-Za-z]\w*)',
);

String _normalize(String p) => p.replaceAll(r'\', '/');

List<File> _dartFilesUnder(String dir) {
  final Directory root = Directory(dir);
  expect(root.existsSync(), isTrue, reason: '$dir not found');
  return <File>[
    for (final FileSystemEntity e in root.listSync(recursive: true))
      if (e is File &&
          _normalize(e.path).endsWith('.dart') &&
          !_isGenerated(_normalize(e.path)))
        e,
  ];
}

void main() {
  test('theme 的 components / primitives 里无死件（lib 下必须有消费点）', () {
    // 1) 声明清单：名字 → 它的声明文件。
    final Map<String, String> declaredIn = <String, String>{};
    for (final String home in _homes) {
      for (final File f in _dartFilesUnder(home)) {
        for (final String line in f.readAsLinesSync()) {
          if (_isComment(line)) continue;
          final RegExpMatch? m = _decl.firstMatch(line);
          if (m == null) continue;
          final String name = m.group(1)!;
          if (name.startsWith('_')) continue;
          declaredIn[name] = _normalize(f.path);
        }
      }
    }
    expect(
      declaredIn,
      isNotEmpty,
      reason: '清单抽空了 = 正则失效，不是"全是死件"',
    );

    // 2) 消费点扫描：一次读完 lib/，避免 N×M 次 IO。
    final Map<String, List<String>> lines = <String, List<String>>{
      for (final File f in _dartFilesUnder('lib'))
        _normalize(f.path): f.readAsLinesSync(),
    };

    final List<String> dead = <String>[];
    for (final String name in declaredIn.keys.toList()..sort()) {
      final RegExp use = RegExp('\\b$name\\b');
      bool alive = false;
      for (final MapEntry<String, List<String>> e in lines.entries) {
        if (e.key == declaredIn[name]) continue; // 声明文件自己不算消费
        for (final String line in e.value) {
          if (_isComment(line)) continue;
          if (use.hasMatch(line)) {
            alive = true;
            break;
          }
        }
        if (alive) break;
      }
      if (!alive) dead.add(name);
    }

    expect(
      dead,
      _knownDead,
      reason: '无消费点的公开呈现件与已知清单不符。\n'
          '多出来的 = 新死件：接上真实界面，或连同它的测试一起删。\n'
          '少掉的 = 某个已知死件被复活或删除了：更新本文件 _knownDead 的清单与理由。',
    );
  });
}
