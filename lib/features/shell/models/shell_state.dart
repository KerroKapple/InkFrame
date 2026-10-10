// 外壳状态：唯一真相源。
//
// 手写不可变值对象（仓库禁新增 freezed，build_runner 工具链受阻，见 docs/BOARD.md），
// == / hashCode 手写，由 shell_state_test.dart 表驱动逐字段钉死。
//
// 【禁止补 copyWith】——补了就等于把 tab × overlay × canvasId × project 的
// 合法性还给人工纪律。本文件的全部意义在于：每个合法迁移都有名字，
// 于是"浮层打开的同时顺手把 canvasId 清掉"这类没有对应具名迁移、
// 只有 copyWith 才写得出来的自相矛盾态，在类型层面无法构造。
// （M-7，fix round 2：原注释举的 "tab: settings + canvasId: 'x'" 例子本身
// 就写不出来——settings 是 ShellOverlay 不是 ShellTab，两者类型不同，
// 编译器直接拒绝，不需要靠"无 copyWith"来挡；换成真正被挡住的那种态。）
//
// 【没有 closeCanvas()】——不提供任何能清 canvasId 的公共动词（resetSession
// 除外）。老代码里那些"清 canvasId"写点的真实意图都是"回 Studio"，正确替代是
// goTab(studio)。这让"某处顺手清 canvasId 毁掉画布保活"在类型层面不可达。
//
// 【2026-10-10 复核：这条 BOARD 待补卡已判定不做，别再加】产品里没有任何
// 「关闭画布」入口，加一个没有调用方的具名迁移正是 #249 退役 setProject 时
// 付过代价的那个错误（"有测试养着的死 API"）——而且 #249 立的源码级闸
// test/quality/shell_transition_reachability_test.dart 会当场把它判死。
// 真有入口要求它时，入场条件是：同一个 PR 里接上调用点 + 一条"调用后画布
// 保活槽真被销毁"的显式断言。
// 另见 docs/BOARD.md 新列的那条真 bug：删掉正在打开的画布 / 项目后
// canvasId / project 悬空——那条的正解不只是一个动词，不要当成本条的替身来做。
import 'package:flutter/foundation.dart';

/// 声明序 == 标签条渲染序 == 保活宿主 children 序。三者由
/// shell_tab_order_test.dart 钉死。
enum ShellTab { studio, canvas, sequence, gallery, export }

/// 浮层不是标签：它盖在标签宿主之上，关掉后回到原标签。
/// P7 删掉内置示例页后只剩设置一种——枚举留着是因为「浮层」这个位置本身是
/// 结构的一部分（ShellState.overlay 的 null / 非 null 决定标签可见性）。
enum ShellOverlay { settings }

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

  // ===== 6 个具名迁移：全量构造，不存在"忘了清某个字段" =====
  //
  // 【没有 setProject()】——"只换项目、不动标签"这条语义曾经存在过（spec §5.1
  // 列了它），但从未有任何 UI 动作对应它：切项目一律走 openGallery(ProjectRef)
  // 或 openCanvas(id, withProject:)。它在 lib/ 下只有定义、全部消费点都在测试里，
  // 已删。真出现项目切换器这类"原地换项目"的交互时再加回来 + 接上调用点。
  // 守这条的是 test/quality/shell_transition_reachability_test.dart：
  // 任何只有定义没有生产调用点的迁移当场红。

  ShellState goTab(ShellTab next) =>
      ShellState(tab: next, canvasId: canvasId, project: project);

  /// M-4（fix round 2）：空串不设防会被 openCanvas('') 照单全收——canvasId
  /// 变成 ''，isPristine 判假，画布标签进入"已打开"分支，下游按 id 查库落空。
  /// 用 assert 而非 InkError：这是调用方的编程错误（传了个不存在的 id），
  /// 不是运行时可恢复的业务态。
  ShellState openCanvas(String id, {ProjectRef? withProject}) {
    assert(id.isNotEmpty, 'openCanvas: id must not be empty');
    return ShellState(
      tab: ShellTab.canvas,
      canvasId: id,
      project: withProject ?? project,
    );
  }

  ShellState openGallery(ProjectRef p) =>
      ShellState(tab: ShellTab.gallery, canvasId: canvasId, project: p);

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
