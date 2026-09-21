// 分层回归闸：`lib/theme/` 与 `lib/core/` 不得 import `features/`。
//
// theme/ 是可复用样式层，core/ 是共享抽象层；两者都在 features/ 【之下】。
// 反向依赖一旦出现，"样式组件"就开始认识某个 feature 的领域模型，组件不再可复用，
// 而且 analyzer 一声不吭（Dart 没有包内分层约束）。
//
// 这条闸是 T7 复评 R47 的产物：`ink_shell_tab_bar.dart` 曾 import
// `features/shell/models/shell_state.dart` + `.../shell_controller.dart`，
// 修法是把接线拆到 `features/shell/widgets/shell_tab_bar.dart`，theme 侧只收
// `InkShellTabBarItem` 纯数据。没有这条闸，下一个人会照着原样再写一遍。
//
// 已知局限（与 no_direct_instantiation_test.dart 同款、同样接受）：逐行正则，
// 拆行写的 import 或 `as` 别名绕得过去。目标是拦住随手写出来的自然写法，
// 不是做静态分析器。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

/// 命中 `import 'xxx/features/yyy.dart'` / `import "package:inkframe/features/…"`。
final RegExp _featuresImport = RegExp(
  '''^\\s*import\\s+['"][^'"]*features/[^'"]*['"]''',
);

List<String> _scan(String dir) {
  final Directory root = Directory(dir);
  expect(root.existsSync(), isTrue, reason: '$dir not found');
  final offenders = <String>[];
  for (final FileSystemEntity entity in root.listSync(recursive: true)) {
    if (entity is! File) continue;
    final String path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') || _isGenerated(path)) continue;
    final List<String> lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (_featuresImport.hasMatch(lines[i])) {
        offenders.add('$path:${i + 1}  ${lines[i].trim()}');
      }
    }
  }
  return offenders;
}

void main() {
  test('lib/theme 不得 import features/', () {
    expect(
      _scan('lib/theme'),
      isEmpty,
      reason: 'theme 是可复用样式层，不该认识任何 feature 的领域模型。\n'
          '把接线拆成 features/ 下的薄壳，theme 侧只收纯数据'
          '（参见 InkShellTabBarItem / ShellTabBar）。',
    );
  });

  test('lib/core 不得 import features/', () {
    expect(
      _scan('lib/core'),
      isEmpty,
      reason: 'core 是共享抽象层，feature 依赖 core，反过来不行。',
    );
  });
}
