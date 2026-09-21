// V4 的断言工具：三条【正交】通道，任何一条单独用都会假绿。
//
// 通道 1（在树里吗）：find.byType(T, skipOffstage: false) —— 保活的证据
// 通道 2（在台上吗）：find.byType(T)（默认 skipOffstage: true）—— 激活的证据
// 通道 3（可命中吗）：find.byType(T).hitTestable() —— 没被浮层盖住的证据
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 断言某个 surface 的三通道状态。
///
/// 刻意【接受类型参数而非 Finder】：三条通道各自需要一个不同参数的
/// find.byType，在内部构造才能保证 skipOffstage 两种取值都真实用上。
/// 传一个 Finder 进来再 .first / .hitTestable() 是做不到的——Finder 的
/// skipOffstage 在构造时就固定了。
///
/// - [mounted]: 是否在 widget 树里（保活 / 懒物化的证据）
/// - [onstage]: 是否在台上（当前激活标签的证据）
/// - [hittable]: 是否可命中（没被浮层盖住的证据）
void expectShellSurface<T extends Widget>({
  required bool mounted,
  required bool onstage,
  required bool hittable,
  String? reason,
}) {
  final String tag = reason == null ? '$T' : '$T · $reason';

  // 通道 1：在树里吗。V4 的核心——必须显式 skipOffstage: false，
  // 否则保活会让 findsNothing 恒真、断言永远绿着却什么都不测。
  expect(
    find.byType(T, skipOffstage: false),
    mounted ? findsOneWidget : findsNothing,
    reason: '$tag [在树通道 · skipOffstage:false]',
  );

  // 通道 2：在台上吗。默认 skipOffstage: true，跳过 Offstage 子树。
  expect(
    find.byType(T),
    onstage ? findsOneWidget : findsNothing,
    reason: '$tag [在台通道 · 默认 skipOffstage:true]',
  );

  // 通道 3：可命中吗。浮层盖住时 RenderIndexedStack.hitTestChildren
  // （rendering/stack.dart:846-861）只命中 index 子，底下的标签体必然落空。
  expect(
    find.byType(T, skipOffstage: false).hitTestable(),
    hittable ? findsOneWidget : findsNothing,
    reason: '$tag [可命中通道]',
  );
}
