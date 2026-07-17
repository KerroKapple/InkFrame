// LibrarySidebar：左侧 280 宽工作库树。
//
// LIBRARY section（Studio → Projects → project 节点）+ 底部 settings 入口。
// CV-1（D-7 d6）：ARCHIVE 死行、SectionLabel '+'、archive/people/trash stub
// 图标均已裁撤；footer 只留接真的 settings（GAP-2 激活时 ARCHIVE 再回）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/current_screen.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../controllers/studio_state.dart';
import '../models/project_with_canvases.dart';
import '../providers/workspace_projects_provider.dart';
import 'trash_dialog.dart';

class LibrarySidebar extends ConsumerWidget {
  const LibrarySidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final projectsAsync = ref.watch(workspaceProjectsProvider);
    final studioName =
        ref.watch(currentStudioProvider) ?? context.l10n.studioDefaultName;
    final selectedId = ref.watch(selectedProjectIdProvider);
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(right: BorderSide(color: colors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                vertical: InkSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SectionLabel(label: context.l10n.studioLibrary),
                  projectsAsync.when(
                    loading: () => const _SidebarLoading(),
                    // 良性降级（GAP-3 审计 B 类）：同 provider 的错误由主区
                    // _StudioErrorState 呈现（横幅+重试，重试同时救活本树）。
                    error: (_, _) => const SizedBox.shrink(),
                    data: (projects) => _LibraryTree(
                      studioName: studioName,
                      projects: projects,
                      selectedId: selectedId,
                      onSelect: (id) => ref
                          .read(selectedProjectIdProvider.notifier)
                          .state = id,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _SidebarFooter(),
        ],
      ),
    );
  }
}

class _LibraryTree extends StatelessWidget {
  const _LibraryTree({
    required this.studioName,
    required this.projects,
    required this.selectedId,
    required this.onSelect,
  });

  final String studioName;
  final List<ProjectWithCanvases> projects;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TreeRow(
          indent: 0,
          twirl: '▾',
          icon: Icons.folder_outlined,
          label: studioName,
          trailing: '${projects.length}',
        ),
        _TreeRow(
          indent: 1,
          twirl: '▾',
          icon: Icons.folder_open_outlined,
          label: context.l10n.studioLibraryProjects,
          trailing: '${projects.length}',
          selected: selectedId == null,
          onTap: () => onSelect(null),
        ),
        for (final p in projects)
          _TreeRow(
            indent: 2,
            twirl: '▸',
            icon: null,
            label: p.name,
            trailing: null,
            selected: p.id == selectedId,
            onTap: () => onSelect(p.id),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.lg,
        InkSpacing.md,
        InkSpacing.lg,
        InkSpacing.sm,
      ),
      child: Text(
        label,
        style: typo.caption.copyWith(
          color: colors.fg3,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _TreeRow extends StatefulWidget {
  const _TreeRow({
    required this.indent,
    required this.twirl,
    required this.icon,
    required this.label,
    required this.trailing,
    this.selected = false,
    this.onTap,
  });

  final int indent;
  final String twirl;
  final IconData? icon;
  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final Color bg = widget.selected
        ? colors.surface3
        : _hover
            ? colors.surface2
            : Colors.transparent;
    final Color fg = widget.selected ? colors.accent : colors.fg2;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: InkMotion.fast,
          color: bg,
          padding: EdgeInsets.fromLTRB(
            InkSpacing.lg + widget.indent * InkSpacing.md,
            InkSpacing.xs,
            InkSpacing.lg,
            InkSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 14,
                child: Text(
                  widget.twirl,
                  style: typo.caption.copyWith(color: colors.fg4),
                ),
              ),
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 14, color: fg),
                const SizedBox(width: InkSpacing.xs),
              ] else
                const SizedBox(width: InkSpacing.xs),
              Expanded(
                child: Text(
                  widget.label,
                  style: typo.body.copyWith(color: fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailing != null)
                Text(
                  widget.trailing!,
                  style: typo.caption.copyWith(color: colors.fg4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLoading extends StatelessWidget {
  const _SidebarLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(InkSpacing.lg),
      child: SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// footer 唯一入口：settings，导航到设置页（与顶栏 Settings 同语义）。
class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.lg,
        vertical: InkSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          _FooterIconButton(
            icon: Icons.settings_outlined,
            label: context.l10n.studioOpenSettings,
            onTap: () => ref.read(currentScreenProvider.notifier).state =
                AppScreen.settings,
          ),
          const SizedBox(width: InkSpacing.md),
          // 回收站（LB-15/GAP-2）：CV-1 裁撤 ARCHIVE 死 stub 时预告的真入口。
          _FooterIconButton(
            icon: Icons.delete_outline,
            label: context.l10n.studioTrash,
            onTap: () => showDialog<void>(
              context: context,
              barrierColor: context.inkColors.scrim,
              builder: (_) => const TrashDialog(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterIconButton extends StatefulWidget {
  const _FooterIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_FooterIconButton> createState() => _FooterIconButtonState();
}

class _FooterIconButtonState extends State<_FooterIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final label = widget.label;
    return Semantics(
      button: true,
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
            child: Icon(
              widget.icon,
              size: 16,
              color: _hover ? colors.accent : colors.fg3,
            ),
          ),
        ),
      ),
    );
  }
}
