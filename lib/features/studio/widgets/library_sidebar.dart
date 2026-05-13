// LibrarySidebar：左侧 280 宽工作库树。
//
// 两段 section：LIBRARY（Studio → Projects → episode 节点）和 ARCHIVE。
// 底部一行图标 quick-actions（settings / archive / people / trash）—— 当前 stub onTap。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../workspace/workspace_home_screen.dart' show workspaceProjectsProvider;
import '../controllers/studio_state.dart';

class LibrarySidebar extends ConsumerWidget {
  const LibrarySidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final projectsAsync = ref.watch(workspaceProjectsProvider);
    final studioName = ref.watch(currentStudioProvider);
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
                  const SizedBox(height: InkSpacing.md),
                  _SectionLabel(label: context.l10n.studioArchive),
                  _TreeRow(
                    indent: 0,
                    twirl: '▸',
                    icon: Icons.archive_outlined,
                    label: context.l10n.studioArchivedProjects,
                    trailing: '0',
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
  // 用 dynamic 是因为 workspace_home_screen 的 _ProjectWithCanvases 是私有；
  // 这里只读 .id / .name / .canvases 这些 getter（duck typing on Dart 不直接支持，
  // 但 dynamic 调用解析在运行期 OK）。
  final List<dynamic> projects;
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
          label: 'Projects',
          trailing: '${projects.length}',
          selected: selectedId == null,
          onTap: () => onSelect(null),
        ),
        for (final p in projects)
          _TreeRow(
            indent: 2,
            twirl: '▸',
            icon: null,
            label: (p.name as String),
            trailing: null,
            selected: (p.id as String) == selectedId,
            onTap: () => onSelect(p.id as String),
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
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: typo.caption.copyWith(
                color: colors.fg3,
                letterSpacing: 2,
              ),
            ),
          ),
          Icon(Icons.add, size: 14, color: colors.fg3),
        ],
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

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();
  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.lg,
        vertical: InkSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _FooterIcon(icon: Icons.settings_outlined),
          _FooterIcon(icon: Icons.inventory_2_outlined),
          _FooterIcon(icon: Icons.person_outline),
          _FooterIcon(icon: Icons.delete_outline),
        ],
      ),
    );
  }
}

class _FooterIcon extends StatefulWidget {
  const _FooterIcon({required this.icon});
  final IconData icon;

  @override
  State<_FooterIcon> createState() => _FooterIconState();
}

class _FooterIconState extends State<_FooterIcon> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Icon(
        widget.icon,
        size: 16,
        color: _hover ? colors.accent : colors.fg3,
      ),
    );
  }
}
