// InkShellTabBar：标签栏的**纯呈现层**（Workspace v2 稿：34 + 1px 下沿 = 35）。
//
// 【它不认识 ShellTab】——只吃一串 InkShellTabBarItem 的纯数据。theme/ 是可复用
// 样式层，知道 feature 的领域模型就等于分层白拆了（R47）。谁是当前标签、点了要
// 做什么，全部由 features/shell/widgets/shell_tab_bar.dart 那层薄壳决定。
// 这条由 test/quality/no_reverse_layer_import_test.dart 源码级钉死。
//
// 视觉规格（稿 CSS）：
// - 条高 34（+1 下沿 borderStrong），surface2 底，左内边距 12
// - 标签水平内边距 16；选中 fg1 + w500 + 2px accent 下边框、**无底色**；未选中 fg4，hover fg2
// - 标签右侧：1px control 竖线（上下 margin 8，左右 6）→ [after]（面包屑）→ 撑开 → [actions]
//
// 窄屏退化阈值 [compactBelow] 取 LayoutBuilder 的【实际约束】而非
// MediaQuery.size：这样 textScale 放大也会先触发退化。退化时标签收成纯图标 +
// Tooltip，且**选中项加 surface5 底**——纯图标条上只靠琥珀下边框太弱。
//
// 阈值取值是实测得来的，钉住它的断言在
// test/features/shell/shell_tab_bar_test.dart（那里才拿得到真实 en/zh 文案）：
// 「五个标签的自然宽度之和 + 左右 gutter ≤ compactBelow」。
//
// 【键盘可达】chip 走 FocusableActionDetector：可 Tab 聚焦、Enter / Space 激活、
// 聚焦时画一圈 accent 焦点环。标签条是全应用最高频交互，此前它是裸
// GestureDetector + Semantics，键盘用户根本到不了（BOARD 旧债）。
// 用例在 test/theme/ink_shell_tab_bar_test.dart「键盘可达性」组，
// 端到端那条（Tab 到画廊格 + Enter 真切标签）在
// test/features/shell/shell_tab_bar_test.dart。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Enter / Space → 激活。**不依赖 WidgetsApp 的默认 shortcuts 表**：theme 层
/// 是可复用组件，不该假设宿主一定是 MaterialApp；显式写出来也让"哪些键能激活"
/// 变成读得到的契约而不是框架默认值。
const Map<ShortcutActivator, Intent> _kActivateChip =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

/// 标签栏的一格。**纯数据，刻意不含任何领域类型**——带上 ShellTab 就等于
/// theme 层又认识 feature 的领域模型了。
///
/// [key] 由调用方给定并原样落到标签上：外壳测试的 `tapShellTab()` 靠
/// `ValueKey('shellTab-<name>')` 命中，这个取值是跨层契约，透传时不许加工。
@immutable
class InkShellTabBarItem {
  const InkShellTabBarItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.dimmed = false,
    this.trailing,
  });

  final Key key;
  final String label;
  final IconData icon;
  final bool selected;

  /// null = 这一格此刻不可点（**不是空闭包**，见
  /// test/quality/no_dead_interactive_test.dart）。
  final VoidCallback? onTap;

  /// 降 0.5 不透明度。调用方用它表达"此刻锁住了"（P6：交付进行中锁其余标签）。
  /// theme 层不知道锁的理由，只知道这一格要变暗。
  final bool dimmed;

  /// 标签右侧的小挂件（P6：交付进行中「序列」标签右边的 12px 进度环）。
  /// 收 Widget 而不是领域类型——theme 层照旧不认识任何 feature 模型。
  final Widget? trailing;
}

class InkShellTabBar extends StatelessWidget {
  const InkShellTabBar({
    super.key,
    required this.items,
    this.after,
    this.actions = const <Widget>[],
  });

  /// 稿是 content-box：height 34 + border-bottom 1。
  static const double height = 35;

  /// 实际约束窄于此值 ⇒ 标签收成纯图标 + Tooltip（README §4：560；实测见 shell_tab_bar_test）。
  static const double compactBelow = 560;

  final List<InkShellTabBarItem> items;

  /// 标签右侧竖线之后的内容（外壳放面包屑）。
  final Widget? after;

  /// 最右侧动作（外壳按当前标签决定放什么）。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface2,
          border: Border(
            bottom: BorderSide(color: colors.borderStrong, width: 1),
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < compactBelow;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(width: InkSpacing.s12),
                for (final InkShellTabBarItem item in items)
                  _ShellTab(key: item.key, item: item, compact: compact),
                if (after != null) ...<Widget>[
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(
                      vertical: InkSpacing.sm,
                      horizontal: InkSpacing.s6,
                    ),
                    color: colors.control,
                  ),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
                        child: after,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0; i < actions.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: InkSpacing.s6),
                          actions[i],
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShellTab extends StatefulWidget {
  const _ShellTab({
    super.key,
    required this.item,
    required this.compact,
  });

  final InkShellTabBarItem item;
  final bool compact;

  @override
  State<_ShellTab> createState() => _ShellTabState();
}

class _ShellTabState extends State<_ShellTab> {
  /// 由本 State 持有，而不是让 FocusableActionDetector 自己造一个内部节点：
  /// 测试要断言"焦点此刻落在哪一格"，拿得到节点才测得了。
  final FocusNode _focus = FocusNode();
  bool _hover = false;
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    final typo = context.inkTypography;
    final InkShellTabBarItem item = widget.item;
    final Color fg = item.selected
        ? colors.fg1
        : (_hover ? colors.fg2 : colors.fg4);

    final Widget label = widget.compact
        ? Icon(item.icon, size: 16, color: fg)
        : Text(
            item.label,
            style: item.selected
                ? typo.bodyStrong.copyWith(color: fg)
                : typo.body.copyWith(color: fg),
          );
    final Widget? trailing = item.trailing;
    final Widget content = trailing == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              label,
              const SizedBox(width: InkSpacing.s6),
              trailing,
            ],
          );
    final bool enabled = item.onTap != null;
    final VoidCallback? onTap = item.onTap;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: item.selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        // hover 仍走外层 MouseRegion（光标 + hover 色与改造前逐字相同）；
        // FocusableActionDetector 只负责"焦点与键盘激活"这一件新事。
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: FocusableActionDetector(
            focusNode: _focus,
            // onTap == null ⇒ 既不可点也不可聚焦：Tab 直接跳过这一格，
            // 不会出现"聚焦上去按回车什么都不发生"的假可达。
            enabled: enabled,
            onShowFocusHighlight: (bool v) {
              if (v != _focused) setState(() => _focused = v);
            },
            shortcuts: _kActivateChip,
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                // 与鼠标点击**同一个回调**：键盘与指针不可能走岔。
                onInvoke: (ActivateIntent intent) {
                  onTap?.call();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: item.onTap,
              child: Opacity(
                opacity: item.dimmed ? 0.5 : 1,
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // 选中项在纯图标条上只靠琥珀下边框太弱 ⇒ compact 下给 surface5 底。
                  color: widget.compact && item.selected ? colors.surface5 : null,
                  border: Border(
                    bottom: BorderSide(
                      color: item.selected ? colors.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                // 焦点环走【前景装饰】：foregroundDecoration 不进
                // Container 的 _paddingIncludingDecoration，所以加环不会把 chip
                // 撑宽/撑高，既有视觉与宽度阈值实测都不动。颜色取 accent token
                // （与选中态同色但形状不同：选中是 2px 下边框，焦点是一圈 1px 环）。
                foregroundDecoration: !_focused
                    ? null
                    : BoxDecoration(
                        border: Border.all(color: colors.accent, width: 1),
                      ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
