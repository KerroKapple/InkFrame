// 菜单面板的搜索过滤（theme/components/ink_menu_panel.dart 的 filterMenuGroups）：不区分大小写的包含匹配，
// 整组都没匹配上的组不出（不留孤立的分隔线），空白查询原样返回。
//
// 变异对照：去掉 toLowerCase ⇒「不区分大小写」红；把空组也收进结果 ⇒「整组都没匹配上」红；
// 去掉 trim ⇒「空白查询原样返回」红。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_menu_panel.dart';

void main() {
  group('filterMenuGroups', () {
    final List<List<String>> groups = <List<String>>[
      <String>['Alpha', 'Beta'],
      <String>['Gamma'],
    ];
    String label(String s) => s;

    test('不区分大小写的包含匹配', () {
      expect(filterMenuGroups<String>(groups, 'LPH', label), <List<String>>[
        <String>['Alpha'],
      ]);
      expect(filterMenuGroups<String>(groups, 'a', label), groups);
    });

    test('整组都没匹配上的组不出（不留孤立的分隔线）', () {
      expect(filterMenuGroups<String>(groups, 'gam', label), <List<String>>[
        <String>['Gamma'],
      ]);
    });

    test('一项都没匹配上 ⇒ 空；空白查询原样返回', () {
      expect(filterMenuGroups<String>(groups, 'zzz', label), isEmpty);
      expect(filterMenuGroups<String>(groups, '   ', label), groups);
    });
  });
}
