// WorkspaceHomeScreen：应用首页 / 工作台。
//
// 结构：
//   - Hero 区：App 图标 + 标题 + 副标题（毛玻璃卡）
//   - 项目列表：每个 Project 一张 InkGlassPanel，内含 canvas pill 列表
//   - 右下 FAB：新建项目（创建项目后默认带 "画布 1"）
//   - 点 canvas pill → set currentCanvasIdProvider → 顶层 _HomeScaffold 切换到 CanvasView
//
// 仅在 kDebugMode 下的 PrimitivesShowcase 不走 i18n；本屏是生产界面，全部走 ARB。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/repositories.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/primitives/ink_accent_chip.dart';
import '../../theme/primitives/ink_glass_card.dart';
import '../../theme/primitives/ink_pill_tag.dart';
import '../../theme/primitives/ink_surface_button.dart';
import '../../theme/tokens.dart';
import '../canvas/providers/current_canvas_id.dart';

final workspaceProjectsProvider = FutureProvider.autoDispose<
    List<_ProjectWithCanvases>>((ref) async {
  final projects = await ref.watch(projectRepositoryProvider.future);
  final canvases = await ref.watch(canvasRepositoryProvider.future);
  final rows = await projects.listAll();
  final result = <_ProjectWithCanvases>[];
  for (final row in rows) {
    final id = row['id']?.toString();
    final name = row['name']?.toString();
    if (id == null || name == null) continue;
    final list = await canvases.listByProject(id);
    result.add(
      _ProjectWithCanvases(
        id: id,
        name: name,
        canvases: list
            .map(
              (c) => _CanvasRef(
                id: c['id']!.toString(),
                name: c['name']?.toString() ?? '',
              ),
            )
            .toList(),
      ),
    );
  }
  return result;
});

class WorkspaceHomeScreen extends ConsumerWidget {
  const WorkspaceHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final projectsAsync = ref.watch(workspaceProjectsProvider);
    return Scaffold(
      backgroundColor: colors.surfaceCanvas,
      body: Stack(
        children: <Widget>[
          const _CanvasBackdropDecor(),
          SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                const SliverToBoxAdapter(child: _Hero()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    InkSpacing.xxl,
                    InkSpacing.lg,
                    InkSpacing.xxl,
                    InkSpacing.xxl,
                  ),
                  sliver: projectsAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => SliverToBoxAdapter(
                      child: _LoadError(message: e.toString()),
                    ),
                    data: (projects) {
                      if (projects.isEmpty) {
                        return const SliverToBoxAdapter(child: _EmptyState());
                      }
                      return SliverList.separated(
                        itemCount: projects.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: InkSpacing.md),
                        itemBuilder: (_, i) =>
                            _ProjectCard(project: projects[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewProjectDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.workspaceNewProject),
      ),
    );
  }

  Future<void> _showNewProjectDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _NewProjectDialog(),
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
        decoration: InputDecoration(
          hintText: context.l10n.workspaceNewProjectHint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(context.l10n.commonOk),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.xxl,
        InkSpacing.xxl,
        InkSpacing.xxl,
        InkSpacing.lg,
      ),
      child: InkGlassCard(
        padding: const EdgeInsets.all(InkSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[colors.accent, colors.cta],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(InkRadius.md),
                  ),
                  child: Icon(Icons.auto_awesome, color: colors.fg1, size: 24),
                ),
                const SizedBox(width: InkSpacing.md),
                Text(
                  context.l10n.appTitle,
                  style: typo.display.copyWith(color: colors.fg1),
                ),
              ],
            ),
            const SizedBox(height: InkSpacing.md),
            Text(
              context.l10n.workspaceHeroTagline,
              style: typo.title.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.xs),
            Text(
              context.l10n.workspaceHeroSubtitle,
              style: typo.body.copyWith(color: colors.fg2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final _ProjectWithCanvases project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkGlassCard(
      padding: const EdgeInsets.all(InkSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  project.name,
                  style: typo.title.copyWith(color: colors.fg1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkPillTag(
                label: context.l10n
                    .workspaceCanvasCount(project.canvases.length),
                icon: Icons.dashboard_outlined,
              ),
              const SizedBox(width: InkSpacing.sm),
              InkSurfaceButton(
                label: context.l10n.workspaceNewCanvas,
                icon: Icons.add,
                onPressed: () => _showNewCanvasDialog(context, ref),
              ),
            ],
          ),
          if (project.canvases.isNotEmpty) ...<Widget>[
            const SizedBox(height: InkSpacing.md),
            Wrap(
              spacing: InkSpacing.sm,
              runSpacing: InkSpacing.sm,
              children: <Widget>[
                for (final c in project.canvases)
                  InkAccentChip(
                    label: c.name,
                    icon: Icons.open_in_new,
                    onPressed: () => ref
                        .read(currentCanvasIdProvider.notifier)
                        .state = c.id,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showNewCanvasDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.workspaceNewCanvas),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.workspaceNewCanvasHint,
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(context.l10n.commonOk),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final canvases = await ref.read(canvasRepositoryProvider.future);
    await canvases.create(projectId: project.id, name: name);
    ref.invalidate(workspaceProjectsProvider);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.only(top: InkSpacing.xxl),
      child: Column(
        children: <Widget>[
          Icon(Icons.folder_open_outlined, size: 56, color: colors.fg3),
          const SizedBox(height: InkSpacing.md),
          Text(
            context.l10n.workspaceProjectsEmpty,
            style: typo.body.copyWith(color: colors.fg3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.only(top: InkSpacing.xxl),
      child: Column(
        children: <Widget>[
          Icon(Icons.error_outline, size: 56, color: colors.danger),
          const SizedBox(height: InkSpacing.md),
          Text(
            context.l10n.workspaceLoadError,
            style: typo.title.copyWith(color: colors.fg1),
          ),
          const SizedBox(height: InkSpacing.xs),
          Text(
            message,
            style: typo.micro.copyWith(color: colors.fg3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 背景装饰：几个柔和色斑，给 hero/project 卡的毛玻璃提供可模糊底层。
class _CanvasBackdropDecor extends StatelessWidget {
  const _CanvasBackdropDecor();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: -120,
            top: -80,
            child: _Blob(size: 480, color: colors.accent),
          ),
          Positioned(
            right: -140,
            top: 160,
            child: _Blob(size: 420, color: colors.cta),
          ),
          Positioned(
            left: 80,
            bottom: -160,
            child: _Blob(size: 380, color: colors.brand),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _ProjectWithCanvases {
  const _ProjectWithCanvases({
    required this.id,
    required this.name,
    required this.canvases,
  });
  final String id;
  final String name;
  final List<_CanvasRef> canvases;
}

class _CanvasRef {
  const _CanvasRef({required this.id, required this.name});
  final String id;
  final String name;
}
