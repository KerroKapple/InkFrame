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
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

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
  });

  final Key key;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
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
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    final typo = context.inkTypography;
    final InkShellTabBarItem item = widget.item;
    final Color fg = item.selected
        ? colors.fg1
        : (_hover ? colors.fg2 : colors.fg4);

    final Widget content = widget.compact
        ? Icon(item.icon, size: 16, color: fg)
        : Text(
            item.label,
            style: item.selected
                ? typo.bodyStrong.copyWith(color: fg)
                : typo.body.copyWith(color: fg),
          );

    return Semantics(
      button: true,
      selected: item.selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: item.onTap,
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
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
