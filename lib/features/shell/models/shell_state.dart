// 外壳状态：唯一真相源。
//
// 手写不可变值对象（仓库禁新增 freezed，build_runner 工具链受阻，见 docs/BOARD.md），
// == / hashCode 手写，由 shell_state_test.dart 表驱动逐字段钉死。
//
// 【禁止补 copyWith】——补了就等于把 tab × overlay × canvasId × project 的
// 合法性还给人工纪律。本文件的全部意义在于：每个合法迁移都有名字，
// 于是 "tab: settings + canvasId: 'x'" 这类自相矛盾的态在类型层面无法构造。
//
// 【没有 closeCanvas()】——本 PR 不提供任何能清 canvasId 的公共动词
// （resetSession 除外）。老代码里那些"清 canvasId"写点的真实意图都是"回 Studio"，
// 正确替代是 goTab(studio)。这让"某处顺手清 canvasId 毁掉画布保活"
// 在类型层面不可达。真需要"关闭画布"菜单时，另加具名迁移 + 一条
// "调用后保活被销毁"的显式断言。
import 'package:flutter/foundation.dart';

/// 声明序 == 标签条渲染序 == 保活宿主 children 序。三者由
/// shell_tab_order_test.dart 钉死。
enum ShellTab { studio, canvas, sequence, gallery, export }

/// 浮层不是标签：它盖在标签宿主之上，关掉后回到原标签。
enum ShellOverlay { settings, showcase }

/// 项目引用。刻意用具名类而非记录 ({String id, String name})：
/// 记录是结构化类型，任何 (id, name) 对（画布引用、角色引用、备份条目）
/// 都能被静默传进项目上下文——正是本 PR 要消灭的那类隐式状态。
@immutable
class ProjectRef {
  const ProjectRef({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectRef && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'ProjectRef($id, $name)';
}

@immutable
class ShellState {
  const ShellState({
    this.tab = ShellTab.studio,
    this.overlay,
    this.canvasId,
    this.project,
  });

  /// 永不为 null；默认 studio（启动恢复守卫 isPristine 依赖这个默认值）。
  final ShellTab tab;

  /// null = 无浮层。
  final ShellOverlay? overlay;

  /// null 是合法态 = 画布标签显示"尚未打开画布"空态。
  final String? canvasId;

  /// 画廊 / 序列 / 导出共享的项目上下文。
  final ProjectRef? project;

  /// 某标签此刻是否可见。浮层盖住时一律不可见 ⇒ 画布让出焦点。
  /// V2 的两条用例（切走标签 / 开浮层遮挡）走同一条代码路径。
  bool isTabVisible(ShellTab t) => overlay == null && tab == t;

  bool get hasOverlay => overlay != null;

  /// 启动恢复守卫：用户尚未发生任何导航。
  /// tab 默认 studio，所以用户在 PG 启动窗口期内切到任何标签，本判据自然为假
  /// ——不需要额外的布尔闩。
  bool get isPristine =>
      canvasId == null && overlay == null && tab == ShellTab.studio;

  // ===== 7 个具名迁移：全量构造，不存在"忘了清某个字段" =====

  ShellState goTab(ShellTab next) =>
      ShellState(tab: next, canvasId: canvasId, project: project);

  ShellState openCanvas(String id, {ProjectRef? withProject}) => ShellState(
        tab: ShellTab.canvas,
        canvasId: id,
        project: withProject ?? project,
      );

  ShellState openGallery(ProjectRef p) =>
      ShellState(tab: ShellTab.gallery, canvasId: canvasId, project: p);

  ShellState setProject(ProjectRef p) => ShellState(
        tab: tab, overlay: overlay, canvasId: canvasId, project: p);

  ShellState openOverlay(ShellOverlay o) => ShellState(
        tab: tab, overlay: o, canvasId: canvasId, project: project);

  ShellState closeOverlay() =>
      ShellState(tab: tab, canvasId: canvasId, project: project);

  /// 还原备份后：库换了，全清。
  ShellState resetSession() => const ShellState();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShellState &&
          other.tab == tab &&
          other.overlay == overlay &&
          other.canvasId == canvasId &&
          other.project == project;

  @override
  int get hashCode => Object.hash(tab, overlay, canvasId, project);

  @override
  String toString() =>
      'ShellState(tab: $tab, overlay: $overlay, canvasId: $canvasId, project: $project)';
}
