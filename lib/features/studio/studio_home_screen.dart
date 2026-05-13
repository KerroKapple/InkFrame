// StudioHomeScreen：Amber Noir 风格的首页。
//
// 布局：Column(chrome, Expanded(Row(LibrarySidebar 280, Expanded(Stack(grid, fab)))))
// 数据：workspaceProjectsProvider 位于 models/project_with_canvases.dart。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/repositories.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/primitives/ink_amber_button.dart';
import '../../theme/tokens.dart';
import 'controllers/studio_state.dart';
import 'models/project_with_canvases.dart';
import 'widgets/library_sidebar.dart';
import 'widgets/project_card.dart';
import 'widgets/studio_top_chrome.dart';

class StudioHomeScreen extends ConsumerWidget {
  const StudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final studioName = ref.watch(currentStudioProvider);
    return ColoredBox(
      color: colors.surfaceCanvas,
      child: Column(
        children: <Widget>[
          StudioTopChrome(
            studioName: studioName,
            breadcrumbTail: context.l10n.studioBreadcrumbAll,
          ),
          const Expanded(
            child: Row(
              children: <Widget>[
                LibrarySidebar(),
                Expanded(child: _StudioMainArea()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioMainArea extends ConsumerWidget {
  const _StudioMainArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final projectsAsync = ref.watch(workspaceProjectsProvider);
    return ColoredBox(
      color: colors.surfaceCanvas,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InkSpacing.xl,
              InkSpacing.xl - 4,
              InkSpacing.xl,
              InkSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: InkSpacing.lg),
                  child: Text(
                    context.l10n.studioRecentProjects,
                    style: typo.display.copyWith(
                      fontSize: 32,
                      color: colors.fg1,
                    ),
                  ),
                ),
                Expanded(
                  child: projectsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        e.toString(),
                        style: typo.body.copyWith(color: colors.danger),
                      ),
                    ),
                    data: (projects) =>
                        _ProjectGrid(projects: projects),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: InkSpacing.xl,
            bottom: InkSpacing.xl,
            child: InkAmberButton(
              label: context.l10n.studioNewProject,
              icon: Icons.add,
              onPressed: () => _showNewProjectDialog(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNewProjectDialog(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewProjectDialog(),
    );
    if (name == null || name.isEmpty) return;
    final projects = await ref.read(projectRepositoryProvider.future);
    final canvases = await ref.read(canvasRepositoryProvider.future);
    final projectId = await projects.create(name: name);
    await canvases.create(
      projectId: projectId,
      name: context.mounted
          ? context.l10n.canvasSampleCanvasName
          : 'Canvas 1',
    );
    ref.invalidate(workspaceProjectsProvider);
  }
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();
  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final TextEditingController _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  void _submit() => Navigator.of(context).pop(_controller.text.trim());
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.workspaceNewProject),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.workspaceNewProjectHint),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(onPressed: _submit, child: Text(context.l10n.commonOk)),
      ],
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({required this.projects});

  final List<ProjectWithCanvases> projects;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 1280 ? 4 : 3;
        return GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: projects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: InkSpacing.lg,
            mainAxisSpacing: InkSpacing.lg,
            childAspectRatio: 16 / 14.5,
          ),
          itemBuilder: (_, i) {
            final p = projects[i];
            return StudioProjectCard(
              name: p.name,
              metaLine: 'EP 01 · 2026.05 · ${_box()} ${p.canvases.length}',
              onTap: () {
                // Task 11/13 接 open canvas
              },
            );
          },
        );
      },
    );
  }

  // mono 区域字符里的小盒子（避免直接写 emoji 在源码里）
  String _box() => '\u{1F4E6}';
}
