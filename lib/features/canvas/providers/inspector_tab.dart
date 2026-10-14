// 检查器停在哪个页签（PR-6：属性 / 历史）。
//
// 为什么不放面板本地状态：页签要「换选中节点时不重置」——用户在历史页里点一行，选中就换到那张
// 产物上，这时还该停在历史页。放 provider 里，选中怎么换、属性页的检查器怎么按节点 id 重挂，
// 都碰不到它；测试也能直接读写。
// 为什么 autoDispose：只有检查器面板 watch 它。画布页卸载（关掉画布）后回到默认的「属性」，
// 不必常驻；切画布时面板不卸载，页签照旧。
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 检查器的两个页签。声明序 == 页签条上从左到右的顺序。
enum InspectorTab { properties, history }

final inspectorTabProvider =
    AutoDisposeNotifierProvider<InspectorTabController, InspectorTab>(
  InspectorTabController.new,
  name: 'inspectorTabProvider',
);

class InspectorTabController extends AutoDisposeNotifier<InspectorTab> {
  @override
  InspectorTab build() => InspectorTab.properties;

  /// 切到 [tab]。同值不通知（enum 恒 identical，Notifier 默认就跳过）。
  void select(InspectorTab tab) => state = tab;
}
