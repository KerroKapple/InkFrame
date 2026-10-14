// 直连 SnackBar 回归闸：lib/ 下不许再自己弹 Material SnackBar。
//
// 由来：右下角通知卡（ToastService）上线之后，「告诉用户发生了什么」全应用只有
// 一个出口——toastServiceProvider。卡片画在 MaterialApp.builder 的 ToastLayer 里、
// 所有路由之上：设置浮层、对话框开着也看得见、点得到。直连的 SnackBar 走
// ScaffoldMessenger，跟着某个 Scaffold 画在窗口底部：对话框开着时压在遮罩底下
// （看得见、点不到）；而且一个 messenger 一次只放一条，后来的排队等前一条走完——
// 一句「已复制」就能把紧跟着的失败提示压后好几秒。两套并存时，同一类提示在不同
// 地方长得不一样、出现的位置也不一样。
//
// 迁移分三片落地（设置页 / 画布与命令面板 / 工作室·画廊·分镜·导出），本闸钉的是
// 终态：lib/ 下一处都不剩，所以没有豁免名单。
//
// 【口径】逐行扫 lib/**/*.dart，跳过生成码（.g.dart / .freezed.dart /
// lib/l10n/generated/）与整行注释（// /// * /*），四条规则：
//   [showSnackBar]       `showSnackBar(`
//   [SnackBar]           `SnackBar(`，带词边界——`showSnackBar(` 里那半截不重复算，
//                        `InkSnackBar(` 这类名字也不算
//   [SnackBarAction]     `SnackBarAction(`
//   [ScaffoldMessenger]  `ScaffoldMessenger.of(` / `ScaffoldMessenger.maybeOf(`
// 同一行命中几条就报几条。
//
// 【已知局限，别让下一个人以为它比实际更严】
// - 逐行正则，不是静态分析器：`ScaffoldMessenger` 与 `.of(` 拆到两行写抓不到。
// - 只跳过「整行」注释：代码行尾的 `// …SnackBar(…` 照样报（宁可误报，改一下措辞即可）。
// - 字符串字面量里出现这几个写法也会报（写本闸时 lib/ 里没有这种内容）。
// - `ScaffoldMessengerState` 这个类型名本身不报。拿到它的常规途径是
//   `ScaffoldMessenger.of/maybeOf(`（有规则）；绕开它的写法（比如
//   `GlobalKey<ScaffoldMessengerState>`）要弹 SnackBar 最终还得 `.showSnackBar(`（也有规则）。
//
// 第二条用例是阳性对照：喂一段合成源码给同一个探测函数，断言四条规则各抓得到、
// 注释行与相似名字不误报。没有它，正则某天失效会静默变成永远绿。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.contains('lib/l10n/generated/');

/// 整行注释：`//`、`///`、块注释的 `*` 续行与 `/*` 起头。
bool _isComment(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

String _normalize(String p) => p.replaceAll(r'\', '/');

/// 规则名 → 正则。插入顺序就是同一行多条命中时的报告顺序。
final Map<String, RegExp> _rules = <String, RegExp>{
  'showSnackBar': RegExp(r'\bshowSnackBar\s*\('),
  'SnackBar': RegExp(r'\bSnackBar\s*\('),
  'SnackBarAction': RegExp(r'\bSnackBarAction\s*\('),
  'ScaffoldMessenger':
      RegExp(r'\bScaffoldMessenger\s*\.\s*(?:of|maybeOf)\s*\('),
};

/// 一份源码里直连 SnackBar 的位置，每条形如 `path:行号  [规则] 该行原文`。
List<String> directSnackBarHits({
  required String path,
  required List<String> lines,
}) {
  final List<String> hits = <String>[];
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (_isComment(line)) continue;
    for (final MapEntry<String, RegExp> rule in _rules.entries) {
      if (rule.value.hasMatch(line)) {
        hits.add('$path:${i + 1}  [${rule.key}] ${line.trim()}');
      }
    }
  }
  return hits;
}

void main() {
  test('lib/ 下没有直连的 SnackBar / ScaffoldMessenger（通知一律走 toastServiceProvider）',
      () {
    final Directory lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'lib/ not found');

    int scanned = 0;
    final List<String> hits = <String>[];
    for (final FileSystemEntity e in lib.listSync(recursive: true)) {
      if (e is! File) continue;
      final String path = _normalize(e.path);
      if (!path.endsWith('.dart') || _isGenerated(path)) continue;
      scanned++;
      hits.addAll(directSnackBarHits(path: path, lines: e.readAsLinesSync()));
    }

    // 正控：只扫到寥寥几份 = 扫描路径失效（工作目录不对），不是「全干净」。
    expect(
      scanned,
      greaterThan(100),
      reason: '只扫到 $scanned 份 lib/**/*.dart ⇒ 扫描路径失效，本闸形同不存在',
    );

    expect(
      hits,
      isEmpty,
      reason: '以下位置直接弹了 Material SnackBar / 直接找了 ScaffoldMessenger：\n'
          '${hits.join('\n')}\n'
          '给用户看的通知一律走 toastServiceProvider——右下角通知卡，画在所有路由之上，'
          '设置浮层和对话框开着也看得见、点得到。直连的 SnackBar 画在窗口底部，'
          '对话框开着时压在遮罩底下，而且一次只放一条、后来的排队。\n'
          '改法：有 ref 就 ref.read(toastServiceProvider).show(文案, kind: ToastKind.xxx)；'
          '只有 BuildContext 的地方照 lib/features/canvas/util/canvas_snackbars.dart 取服务。',
    );
  });

  test('阳性对照：四条规则各抓得到，注释行与相似名字不误报', () {
    const List<String> synthetic = <String>[
      '    ScaffoldMessenger.of(context).showSnackBar(',
      '      const SnackBar(content: Text(message)),',
      '    messenger?.showSnackBar(SnackBar(content: Text(msg), action: SnackBarAction(label: undo, onPressed: f)));',
      '    final ScaffoldMessengerState? m = ScaffoldMessenger.maybeOf(context);',
      '    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(old)));',
      '    /// 以前这里是 showSnackBar(SnackBar(...))',
      '     * SnackBarAction(label: old, onPressed: f)',
      '    /* SnackBar(content: Text(old)) */',
      '    InkSnackBar(message: msg);',
      '    void relay(ScaffoldMessengerState? messenger) {}',
      '    toast.show(msg, kind: ToastKind.error);',
    ];

    final List<String> hits =
        directSnackBarHits(path: 'synthetic.dart', lines: synthetic);

    // 先只比「位置 + 规则」，行文另断一条。
    expect(
      <String>[for (final String h in hits) h.substring(0, h.indexOf(']') + 1)],
      <String>[
        'synthetic.dart:1  [showSnackBar]',
        'synthetic.dart:1  [ScaffoldMessenger]',
        'synthetic.dart:2  [SnackBar]',
        'synthetic.dart:3  [showSnackBar]',
        'synthetic.dart:3  [SnackBar]',
        'synthetic.dart:3  [SnackBarAction]',
        'synthetic.dart:4  [ScaffoldMessenger]',
      ],
      reason: '注释行（5–8）、InkSnackBar（9）、只有类型名的 ScaffoldMessengerState（10）'
          '与新 API（11）都不该报：\n${hits.join('\n')}',
    );
    expect(
      hits.first,
      'synthetic.dart:1  [showSnackBar] ScaffoldMessenger.of(context).showSnackBar(',
    );
  });
}
