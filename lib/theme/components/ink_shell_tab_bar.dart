// InkShellTabBar：持久标签条（44）。
//
// 【绝不进 chrome 的槽位】——整条 InkWindowChrome 包在 DragToMoveArea 里，其
// onDoubleTap 让其中任何单击等满 kDoubleTapTimeout(300ms)。标签是全应用最高频
// 交互，300ms 延迟是真 UX 回归，还会给每个外壳测试加固定 400ms 税。
// 若哪天 tapShellTab() 必须补 pump(400ms) 才稳，说明有人把标签条挪进了 chrome。
//
// 顺序由 ShellTab.values 决定（shell_tab_order_test.dart 钉死声明序 == 渲染序
// == 保活宿主 children 序）。
//
// 窄屏退化阈值 [compactBelow] 取 LayoutBuilder 的【实际约束】而非
// MediaQuery.size：这样 textScale 放大也会先触发退化。取值是实测得来的——
// 见 test/theme/ink_shell_tab_bar_test.dart 里「五个 chip 的自然宽度之和 + 左右
// gutter 不超过阈值」那条断言，它会在文案变长/字重变化时把阈值钉住。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shell/models/shell_state.dart';
import '../../features/shell/providers/shell_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_x.dart';
import '../app_theme.dart';
import '../tokens.dart';

class InkShellTabBar extends ConsumerWidget {
  const InkShellTabBar({super.key});

  static const double height = 44;

  /// chip 高 32，在 44 的条里垂直居中。
  static const double chipHeight = 32;

  /// 实际约束窄于此值 ⇒ chip 收成纯图标 + Tooltip。
  static const double compactBelow = 620;

  static String labelOf(AppLocalizations l, ShellTab tab) => switch (tab) {
        ShellTab.studio => l.shellTabStudio,
        ShellTab.canvas => l.shellTabCanvas,
        ShellTab.sequence => l.shellTabSequence,
        ShellTab.gallery => l.shellTabGallery,
        ShellTab.export => l.shellTabExport,
      };

  static IconData iconOf(ShellTab tab) => switch (tab) {
        ShellTab.studio => Icons.home_outlined,
        ShellTab.canvas => Icons.account_tree_outlined,
        ShellTab.sequence => Icons.view_timeline_outlined,
        ShellTab.gallery => Icons.collections_outlined,
        ShellTab.export => Icons.movie_creation_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final InkColors colors = context.inkColors;
    final ShellTab active =
        ref.watch(shellControllerProvider.select((ShellState s) => s.tab));
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceCanvas,
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
                  for (final ShellTab t in ShellTab.values)
                    _ShellTabChip(
                      key: ValueKey<String>('shellTab-${t.name}'),
                      tab: t,
                      selected: t == active,
                      compact: compact,
                      onTap: () =>
                          ref.read(shellControllerProvider.notifier).goTab(t),
                    ),
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
    required this.tab,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final ShellTab tab;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_ShellTabChip> createState() => _ShellTabChipState();
}

class _ShellTabChipState extends State<_ShellTabChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    final typo = context.inkTypography;
    final String label = InkShellTabBar.labelOf(context.l10n, widget.tab);
    final Color fg = widget.selected ? colors.fg1 : colors.fg3;
    // 选中项在纯图标条上只靠琥珀下边框太弱 ⇒ compact 下同样给 surface5 底。
    final Color bg = widget.selected
        ? colors.surface5
        : (_hover ? colors.surface4 : Colors.transparent);

    final Widget content = widget.compact
        ? Icon(InkShellTabBar.iconOf(widget.tab), size: 18, color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(InkShellTabBar.iconOf(widget.tab), size: 16, color: fg),
              const SizedBox(width: InkSpacing.xs),
              Text(
                label,
                style: typo.body.copyWith(
                  color: fg,
                  fontWeight:
                      widget.selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      selected: widget.selected,
      label: label,
      child: Tooltip(
        message: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
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
                      color:
                          widget.selected ? colors.accent : Colors.transparent,
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
