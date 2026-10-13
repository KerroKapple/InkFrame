// 可达性断言的共用件。
//
// 由来（BOARD 214）：这一轮把 `Ink{Primary,Secondary}Button` 外面那些手搓点击壳
// 换成 theme 层的 `InkActivatable`，每处都要问同样三个问题——能 Tab 到吗 / 回车
// 走的是不是同一条回调 / 禁用态还能不能聚焦。问法只该有一份，否则 6 个测试文件
// 里会长出 6 种"大概差不多"的写法，下一次改动时谁都说不清哪个才是契约。
//
// 【刻意不去改已有的两份局部 helper】
// test/theme/primitives/ink_activatable_test.dart 与
// test/features/shell/shell_tab_bar_actions_a11y_test.dart 各有一份同名的
// `_focusOf`——那两份是 #249 / #252 "行为未变"的证据，一字不动。本文件只服务本轮
// 新增的用例。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [key] 所在 `InkActivatable` 持有的焦点节点。
///
/// 禁用态（`onTap: null`）的壳**仍在树上**，只是 `canRequestFocus == false`——
/// 所以这个函数在禁用态也取得到节点，正是"不可聚焦"那条要断言的对象。
FocusNode activatableFocus(WidgetTester tester, Key key) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

/// 真的按 Tab 走焦点环，走到 [node] 就停；返回是否走到了。
///
/// 刻意**不**断言"第 N 次 Tab"：各屏焦点环的长度与本轮改造无关，钉死次数只会在
/// 毫不相干的改动上红在一个看不出因果的地方。本轮要证的是"键盘到得了"，不是
/// "它排第几"。
Future<bool> tabUntilFocused(
  WidgetTester tester,
  FocusNode node, {
  int maxTabs = 24,
}) async {
  for (int i = 0; i < maxTabs; i++) {
    if (node.hasPrimaryFocus) return true;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  return node.hasPrimaryFocus;
}

/// 把焦点放到 [node] 上再按键激活（默认 Enter）。
///
/// 三个激活键（Enter / NumpadEnter / Space）在包装件自己那层已经钉死
/// （test/theme/primitives/ink_activatable_test.dart）；消费点这层要证的是
/// "键盘激活走的是**本处**那条回调"，一个键足够。
Future<void> activateByKey(
  WidgetTester tester,
  FocusNode node, {
  LogicalKeyboardKey key = LogicalKeyboardKey.enter,
}) async {
  node.requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(key);
  await tester.pump();
}
