// 画布左栏的状态（PR-4 起：43px 图标导航条 + 240 面板）：当前停在哪一页 + 面板展开 / 收起。
//
// 页只有三张：大纲 / 素材 / 角色。原来的「画布」页取消——画布列表挪进了大纲面板头的
// 画布切换胶囊（widgets/left_rail/canvas_switcher.dart）。
//
// 为什么不放面板本地 setState：检查器角色区的「管理」链接要把左栏展开并切到角色页，
// 画布快捷键层的 Ctrl+\ / ⌘\ 要开合左栏——都是别的子树里发起的跳转，面板本地状态够不到。
// 为什么不 autoDispose：停在哪一页、开着还是收着，是用户的阅读位置，切走画布再回来应当
// 原样还在；状态只有一个枚举加一个布尔，常驻代价可忽略。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 左栏三页。声明序 == 导航条上从上到下的顺序。
enum LeftRailPage { outline, assets, characters }

/// 左栏状态：停在哪一页 + 面板是否展开。收起时页照旧记着——再展开回到原页。
@immutable
class LeftRailState {
  const LeftRailState({
    this.page = LeftRailPage.outline,
    this.expanded = true,
  });

  final LeftRailPage page;
  final bool expanded;

  /// 导航条上 [p] 这一键此刻是否点亮：面板展开、且停在这一页。
  bool isActive(LeftRailPage p) => expanded && page == p;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeftRailState && other.page == page && other.expanded == expanded;

  @override
  int get hashCode => Object.hash(page, expanded);

  @override
  String toString() => 'LeftRailState($page, expanded: $expanded)';
}

final leftRailProvider = NotifierProvider<LeftRailController, LeftRailState>(
  LeftRailController.new,
  name: 'leftRailProvider',
);

class LeftRailController extends Notifier<LeftRailState> {
  @override
  LeftRailState build() => const LeftRailState();

  /// 值相等就不通知：导航条与面板都 watch 本 provider，同值重设不该把它们拖进重建。
  @override
  bool updateShouldNotify(LeftRailState previous, LeftRailState next) =>
      previous != next;

  /// 点导航条上的页键：点的正是展开着的当前页 ⇒ 收起；否则展开并切到 [page]。
  void tapPage(LeftRailPage page) {
    state = state.isActive(page)
        ? LeftRailState(page: page, expanded: false)
        : LeftRailState(page: page);
  }

  /// 展开并停在 [page]（检查器角色区的「管理」链接）。
  void open(LeftRailPage page) => state = LeftRailState(page: page);

  /// 开合切换（导航条底部的收起键 / Ctrl+\ / ⌘\）：只动开合，页不变。
  void toggle() =>
      state = LeftRailState(page: state.page, expanded: !state.expanded);
}
