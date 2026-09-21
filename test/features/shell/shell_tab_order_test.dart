// ShellTab 的声明序 == 标签条序 == IndexedStack children 序。
// index 与 children 顺序错位是最难查的一类 bug：界面显示 A 的内容、选中态标在 B 上。
// 任何人插入新标签，必须显式改这条断言。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';

void main() {
  test('ShellTab 顺序被钉死', () {
    expect(
      ShellTab.values.map((t) => t.name).toList(),
      <String>['studio', 'canvas', 'sequence', 'gallery', 'export'],
    );
  });
}
