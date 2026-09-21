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

  // 通道 1：在树里吗。V4 的核心——必须显式 skipOffstage: false。
  //
  // 【别删 mounted:false 的那些调用点】T7 复评实测澄清过一次：把本通道改回
  // 默认 skipOffstage，7 例里红 5 绿 2；仍绿的 2 条都是 mounted:false 型。
  // 但那**只说明它对"改回默认 skipOffstage"这一种改法恒真**，不等于它没用——
  // 换一条真实变异（把浮层槽改成常驻保活）就能把 studio 例 SettingsScreen 的
  // 本通道打红。mounted:false 守的是"浮层/标签被意外保活、后台常驻 pending
  // frame"这一类回归，是 load-bearing 的。
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
