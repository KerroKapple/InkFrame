// InkShellTabBar：标签条的**纯呈现层**（44）。
//
// 【它不认识 ShellTab】——只吃一串 InkShellTabBarItem 的纯数据。theme/ 是可复用
// 样式层，知道 feature 的领域模型就等于分层白拆了（R47）。谁是当前标签、点了要
// 做什么，全部由 features/shell/widgets/shell_tab_bar.dart 那层薄壳决定。
// 这条由 test/quality/no_reverse_layer_import_test.dart 源码级钉死。
//
// 视觉规格（spec §7.2）：
// - 条高 44，chip 高 32 垂直居中
// - 选中：fg1 + w500 + 2px accent 下边框 + surface5 底
// - 未选中：fg3，hover surface4
// - 下沿 1px borderStrong（外壳三段分区的硬边界；组件内细线仍用 borderSubtle）
//
// 窄屏退化阈值 [compactBelow] 取 LayoutBuilder 的【实际约束】而非
// MediaQuery.size：这样 textScale 放大也会先触发退化。退化时 chip 收成纯图标 +
// Tooltip，且**选中项仍然给 surface5 底**——纯图标条上只靠琥珀下边框太弱。
//
// 阈值取值是实测得来的，钉住它的断言在
// test/features/shell/shell_tab_bar_test.dart（那里才拿得到真实 en/zh 文案）：
// 「五个 chip 的自然宽度之和 + 左右 gutter ≤ compactBelow」。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// 标签条的一格。**纯数据，刻意不含任何领域类型**——带上 ShellTab 就等于
/// theme 层又认识 feature 的领域模型了。
///
/// [key] 由调用方给定并原样落到 chip 上：外壳测试的 `tapShellTab()` 靠
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
  const InkShellTabBar({super.key, required this.items});

  static const double height = 44;

  /// chip 高 32，在 44 的条里垂直居中。
  static const double chipHeight = 32;

  /// 实际约束窄于此值 ⇒ chip 收成纯图标 + Tooltip。
  static const double compactBelow = 620;

  final List<InkShellTabBarItem> items;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface0,
          border: Border(
            bottom: BorderSide(color: colors.borderStrong, width: 1),
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < compactBelow;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.lg),
              child: Row(
                children: <Widget>[
                  for (final InkShellTabBarItem item in items)
                    _ShellTabChip(key: item.key, item: item, compact: compact),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShellTabChip extends StatefulWidget {
  const _ShellTabChip({
    super.key,
    required this.item,
    required this.compact,
  });

  final InkShellTabBarItem item;
  final bool compact;

  @override
  State<_ShellTabChip> createState() => _ShellTabChipState();
}

class _ShellTabChipState extends State<_ShellTabChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    final typo = context.inkTypography;
    final InkShellTabBarItem item = widget.item;
    final Color fg = item.selected ? colors.fg1 : colors.fg3;
    // 选中项在纯图标条上只靠琥珀下边框太弱 ⇒ compact 下同样给 surface5 底。
    final Color bg = item.selected
        ? colors.surface5
        : (_hover ? colors.surface4 : Colors.transparent);

    final Widget content = widget.compact
        ? Icon(item.icon, size: 18, color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(item.icon, size: 16, color: fg),
              const SizedBox(width: InkSpacing.xs),
              Text(
                item.label,
                style: typo.body.copyWith(
                  color: fg,
                  fontWeight:
                      item.selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
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
            child: Padding(
              padding: const EdgeInsets.only(right: InkSpacing.xs),
              child: AnimatedContainer(
                duration: InkMotion.fast,
                height: InkShellTabBar.chipHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.sm,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(InkRadius.sm),
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
      ),
    );
  }
}
