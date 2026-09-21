// 外壳级测试禁止 override 只读投影——override 投影会把它与真相源脱钩：
// widget 读投影看到 'c1'，任何读 shellControllerProvider 的代码看到 null。
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const _banned = <String>[
  'currentCanvasIdProvider.overrideWith',
  'activeProjectProvider.overrideWith',
];

void main() {
  test('外壳级测试不得 override ShellState 的只读投影', () {
    final files = <File>[
      ...Directory('test/features/shell')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      File('test/app/app_routing_test.dart'),
    ];
    final offenders = <String>[];
    for (final f in files) {
      if (!f.existsSync()) continue;
      final src = f.readAsStringSync();
      for (final b in _banned) {
        if (src.contains(b)) offenders.add('${f.path}: $b');
      }
    }
    expect(offenders, isEmpty,
        reason: '请改用 shellControllerProvider.overrideWith(() => '
            'ShellNavigator(initial: ShellState(...))) 播种。\n违规：$offenders');
  });
}
