// 被遮蔽的扩展成员回归闸：freezed union 的「共享 mixin getter」不得在扩展里再写一遍。
//
// 由来（BOARD「`JobStateX` 的 5 个字段访问器是被遮蔽的死代码」那一行）：
// `JobState` 的六个变体都带 `jobId` / `providerId` / `canvasId` / `projectId` /
// `sourceNodeId` / `resultNodeId`，且类型一致 ⇒ freezed 3 把它们生成成**共享
// `mixin _$JobState` 上的实例 getter**，`sealed class JobState with _$JobState`
// 直接带上。而 Dart 的成员解析规则是**实例成员优先于扩展成员**：接收者的静态
// 类型上有同名实例成员时，扩展里的同名成员永远不会被选中——不是"被覆盖"，是
// 根本不可达。于是 `extension JobStateX on JobState` 里那 5 个手写六臂 switch
// 是死代码，而且两道常规防线都看不见它：
//   - analyzer 没有"扩展成员被遮蔽"这条诊断（删掉那 5 个 getter，analyze 仍 0 issue）；
//   - 单测反而是绿的——`s.jobId` 解析到的是生成码那一份，测试覆盖率满格。
// 与 `shell_transition_reachability_test.dart`（死 API）/
// `no_dead_theme_component_test.dart`（死呈现件）同一个病：只有源码级闸能抓。
//
// 【本闸的口径】
// - 真相源是**生成码**：逐个 `lib/**/*.freezed.dart` 抽 `mixin _$T { ... }` 里
//   声明的实例成员名。生成码由机器写、格式规整，这一侧不是猜的。
// - 然后扫 `lib/` + `test/` 下的 `extension X on T`，若 `T` 有共享 mixin，
//   则其扩展体内不得出现这些名字的 getter 声明。
// - 名字命中即判死：这是语言规则的直接套用，不是启发式——`on T` 的扩展只对
//   静态类型为 `T`（及其子类型，子类型同样继承该实例成员）的接收者生效。
//
// 【已知局限，逐条写明，别让下一个人以为它比实际更严】
// - 只扫 **getter 声明**（`get <name>`）。freezed 的共享成员全是字段，扩展里
//   重写只会写成 getter；方法形式（`T name()`）不扫。
// - 只覆盖 **freezed** 生成的共享 mixin。手写 sealed 基类上的同名成员遮蔽扩展
//   成员**不在覆盖范围内**（那种情况基类成员就写在眼前，不是本闸要抓的"生成码
//   在背后悄悄长出一个同名成员"）。2026-10-13 全仓手工量过一遍：`lib/` 下共
//   7 个扩展（`DbRow` / `_LevelWire` / `CanvasEdgeMapping` / `CanvasNodeMapping`
//   / `JobStateX` / `AppL10nX` / `InkThemeX`，`test/` 下 0 个），除 `JobStateX`
//   外无一与宿主类型的实例成员撞名（两个 `*Mapping` 全是 static 成员，静态成员
//   按 `扩展名.成员` 取，不走遮蔽那条规则）。
// - 显式应用（`JobStateX(x).jobId`）仍然能调到扩展那一份。全仓没有这种写法，
//   真要这么写，本闸会误报——那也该算提醒。
// - 逐行正则 + 花括号配平，不是静态分析器：整行注释会被剔除，但**字符串字面量
//   里的 `//` 或不配平花括号**会让区间判错。model 文件里没有这种内容。
//
// 本文件第二条用例是**阳性对照**：喂一段合成的"遮蔽写法"给同一个探测函数，
// 断言它能被抓到。没有这条，探测器某天正则失效会静默变成永远绿。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

bool _isComment(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

String _normalize(String p) => p.replaceAll(r'\', '/');

/// 整行注释剔成空行（保留行号对位，便于报点）。
List<String> _stripComments(List<String> lines) =>
    <String>[for (final String l in lines) if (_isComment(l)) '' else l];

/// `mixin _$T {` 这一行。
final RegExp _mixinDecl = RegExp(r'^mixin\s+_\$([A-Za-z_]\w*)\s*\{');

/// `extension X on T {`（`on` 后取裸类型名，泛型实参不管）。
final RegExp _extensionDecl =
    RegExp(r'^\s*extension\s+\w+\s+on\s+([A-Za-z_]\w*)');

/// getter 声明里的名字。
final RegExp _getterDecl = RegExp(r'\bget\s+([A-Za-z_]\w*)');

/// 从 [from] 行开始（该行须含块起始 `{`）按花括号配平取块体，返回 `[起, 止)`。
/// 取不到配平的闭合时返回 null——宁可报"抽空了"也不给一个错的区间。
({int start, int end})? _blockRange(List<String> lines, int from) {
  int depth = 0;
  bool opened = false;
  for (int i = from; i < lines.length; i++) {
    for (final int c in lines[i].codeUnits) {
      if (c == 0x7B) {
        depth++;
        opened = true;
      } else if (c == 0x7D) {
        depth--;
      }
    }
    if (opened && depth == 0) return (start: from + 1, end: i);
  }
  return null;
}

/// 一份生成文件里 `类型名 → 共享 mixin 上声明的实例成员名`。
Map<String, Set<String>> sharedMixinMembers(List<String> rawLines) {
  final List<String> lines = _stripComments(rawLines);
  final Map<String, Set<String>> out = <String, Set<String>>{};
  for (int i = 0; i < lines.length; i++) {
    final RegExpMatch? m = _mixinDecl.firstMatch(lines[i]);
    if (m == null) continue;
    final ({int start, int end})? r = _blockRange(lines, i);
    expect(r, isNotNull, reason: 'mixin _\$${m.group(1)} 的花括号没配平');
    final Set<String> names = <String>{};
    for (int j = r!.start; j < r.end; j++) {
      for (final RegExpMatch g in _getterDecl.allMatches(lines[j])) {
        names.add(g.group(1)!);
      }
    }
    out[m.group(1)!] = names;
  }
  return out;
}

/// 一份源码文件里「扩展成员被共享 mixin 遮蔽」的位置。
///
/// [sharedMembers] = `类型名 → 该类型共享 mixin 上的实例成员名`。
List<String> shadowedExtensionMembers({
  required String path,
  required List<String> rawLines,
  required Map<String, Set<String>> sharedMembers,
}) {
  final List<String> lines = _stripComments(rawLines);
  final List<String> hits = <String>[];
  for (int i = 0; i < lines.length; i++) {
    final RegExpMatch? m = _extensionDecl.firstMatch(lines[i]);
    if (m == null) continue;
    final Set<String>? shared = sharedMembers[m.group(1)!];
    if (shared == null || shared.isEmpty) continue;
    final ({int start, int end})? r = _blockRange(lines, i);
    if (r == null) continue; // 取不到区间就不报，避免凭错区间误伤
    for (int j = r.start; j < r.end; j++) {
      for (final RegExpMatch g in _getterDecl.allMatches(lines[j])) {
        final String name = g.group(1)!;
        if (!shared.contains(name)) continue;
        hits.add('$path:${j + 1}  $name（已在 mixin _\$${m.group(1)} 上）');
      }
    }
  }
  return hits;
}

List<File> _dartFilesUnder(String dir, {required bool generated}) {
  final Directory root = Directory(dir);
  expect(root.existsSync(), isTrue, reason: '$dir not found');
  return <File>[
    for (final FileSystemEntity e in root.listSync(recursive: true))
      if (e is File &&
          _normalize(e.path).endsWith('.dart') &&
          _isGenerated(_normalize(e.path)) == generated)
        e,
  ];
}

void main() {
  test('freezed 共享 mixin 的成员没有被扩展里重写一遍（遮蔽 = 死代码）', () {
    // 1) 真相源：生成码里每个共享 mixin 声明的实例成员。
    final Map<String, Set<String>> sharedMembers = <String, Set<String>>{};
    for (final File f in _dartFilesUnder('lib', generated: true)) {
      if (!_normalize(f.path).endsWith('.freezed.dart')) continue;
      sharedMembers.addAll(sharedMixinMembers(f.readAsLinesSync()));
    }

    // 抽空 = 生成码一侧的解析失效，不是"没有共享 mixin"。
    expect(
      sharedMembers,
      isNotEmpty,
      reason: '一个 mixin _\$ 都没抽到 = 生成码解析失效（freezed 换了输出格式？）',
    );
    expect(
      sharedMembers.values.where((Set<String> s) => s.isNotEmpty),
      isNotEmpty,
      reason: '所有共享 mixin 都抽成空成员集 = getter 正则失效。\n'
          '至少 JobState 必须有共享字段 getter（六变体同名同类型）。',
    );

    // 2) 扫全部手写源码（lib + test）里的扩展。
    final List<String> hits = <String>[
      for (final String dir in <String>['lib', 'test'])
        for (final File f in _dartFilesUnder(dir, generated: false))
          ...shadowedExtensionMembers(
            path: _normalize(f.path),
            rawLines: f.readAsLinesSync(),
            sharedMembers: sharedMembers,
          ),
    ];

    expect(
      hits,
      isEmpty,
      reason: '以下扩展成员被 freezed 生成的共享 mixin 实例成员遮蔽，永远不会被调用：\n'
          '${hits.join('\n')}\n'
          'Dart 的解析规则是实例成员优先于扩展成员——删掉扩展里这一份，'
          '直接用 mixin 上的。analyzer 不报这件事，单测也会照常绿（测到的是生成码），'
          '所以只能靠本闸。',
    );
  });

  test('阳性对照：探测器能抓到合成的遮蔽写法', () {
    // 合成一份「共享 mixin 已有 jobId，扩展里又写一遍」的源码，
    // 并刻意混入三种不该被抓的写法。
    const List<String> synthetic = <String>[
      'extension FooX on Foo {',
      '  String get jobId => switch (this) { A(:final jobId) => jobId };',
      '  // String get providerId => ...  ← 注释里的写法不算声明',
      '  bool get isTerminal => true; // 共享 mixin 上没有，真逻辑，不该被抓',
      '}',
      'extension BarX on Bar {',
      '  String get jobId => \'\'; // Bar 没有共享 mixin，不在管辖范围',
      '}',
    ];

    final List<String> hits = shadowedExtensionMembers(
      path: 'synthetic.dart',
      rawLines: synthetic,
      sharedMembers: <String, Set<String>>{
        'Foo': <String>{'jobId', 'providerId'},
      },
    );

    expect(hits, hasLength(1), reason: '应当只抓到 Foo 扩展里那一个 jobId：\n$hits');
    expect(hits.single, contains('synthetic.dart:2'));
    expect(hits.single, contains('jobId'));
  });

  test('阳性对照：生成码一侧能抽出 JobState 的六个共享字段 getter', () {
    final Map<String, Set<String>> m = sharedMixinMembers(
      File('lib/features/generation/models/job_state.freezed.dart')
          .readAsLinesSync(),
    );
    // copyWith / hashCode 也在 mixin 上，一并抽到是对的——它们同样遮蔽同名扩展成员。
    expect(
      m['JobState'],
      containsAll(<String>[
        'jobId',
        'providerId',
        'canvasId',
        'projectId',
        'sourceNodeId',
        'resultNodeId',
      ]),
      reason: 'JobState 的六个共享字段必须出现在 mixin _\$JobState 上——'
          '这正是「扩展里不要再写一遍」的依据',
    );
  });
}
