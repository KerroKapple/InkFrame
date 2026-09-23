// StudioHomeScreen：Amber Noir 风格的首页。
//
// 布局：Column(StudioProviderBanner, Expanded(Row(LibrarySidebar 280, Expanded(Stack(main, fab)))))
// 状态：workspaceProjectsProvider 的 loading / error / empty / data 四态。
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/database_restore.dart';
import '../../core/di/logger.dart';
import '../../core/di/preferences.dart';
import '../../core/di/project_archive.dart';
import '../../core/di/repositories.dart';
import '../../core/errors/ink_error.dart';
import '../../core/models/app_preferences.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/ink_error_banner.dart';
import '../../theme/components/ws_primitives.dart';
import '../../theme/primitives/ink_amber_button.dart';
import '../../theme/primitives/ink_compact_text_field.dart';
import '../../theme/primitives/ink_ghost_button.dart';
import '../../theme/primitives/ink_noir_card.dart';
import '../../theme/tokens.dart';
import '../../services/project_archive_service.dart';
import '../canvas/providers/canvas_bootstrap_controller.dart';
import '../gallery/util/gallery_time.dart';
import '../generation/models/job_state.dart';
import '../generation/providers/jobs_registry.dart';
import '../settings/providers/shell_keep_last_canvas_controller.dart';
import '../shell/models/shell_state.dart';
import '../shell/providers/shell_controller.dart';
import 'controllers/studio_projects_controller.dart';
import 'providers/project_export_busy.dart';
import 'providers/trashed_items_providers.dart';
import 'models/project_with_canvases.dart';
import 'open_canvas.dart';
import 'project_import_flow.dart';
import 'providers/workspace_projects_provider.dart';
import 'util/last_session.dart';
import 'widgets/library_sidebar.dart';
import 'widgets/project_card.dart';
import 'widgets/studio_provider_banner.dart';
import '../generation/services/toast_service.dart';

const String _logModule = 'studio.home';

class StudioHomeScreen extends ConsumerWidget {
  const StudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    return ColoredBox(
      color: colors.surface1,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudioProviderBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

/// 项目区（Screens 稿第 1 屏）：32px 工具行（全部项目 N | 排序：最近修改 | 网格）+ padding 20 的内容：
/// 「上次离开时」恢复条 + 4 列项目网格（末位虚线「新建项目」格）。
/// 稿上的「列表」视图无对应实现，不画；「排序：最近修改」是唯一排序，只作标签。
class _StudioMainArea extends ConsumerWidget {
  const _StudioMainArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final projectsAsync = ref.watch(workspaceProjectsProvider);
    final int? count = projectsAsync.valueOrNull?.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 33, // content 32 + border-bottom 1
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
          child: Row(
            children: <Widget>[
              Text(l.studioLibraryAllProjects, style: t.bodyStrong.copyWith(color: c.fg1)),
              if (count != null) ...<Widget>[
                const SizedBox(width: InkSpacing.s14),
                Text('$count', style: t.mono.copyWith(color: c.fg5)),
              ],
              const Spacer(),
              Text(l.studioSortRecent, style: t.body.copyWith(color: c.fg5)),
              const SizedBox(width: InkSpacing.s14),
              Text(l.studioViewGrid, style: t.body.copyWith(color: c.fg1)),
            ],
          ),
        ),
        Expanded(
          child: projectsAsync.when(
            loading: () => const _StudioLoadingState(),
            error: (e, _) => _StudioErrorState(
              onRetry: () => ref.invalidate(workspaceProjectsProvider),
            ),
            data: (projects) {
              final importBusy = ref.watch(projectImportBusyProvider) ||
                  ref.watch(databaseRestoreBusyProvider) ||
                  ref.watch(projectExportBusyProvider);
              if (projects.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(InkSpacing.s20),
                  child: _StudioEmptyState(
                    onCreate: () => showStudioNewProjectDialog(context, ref),
                    onCreateSample: () => createStudioSampleProject(context, ref),
                    onOpenShowcase: () =>
                        ref.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.showcase),
                    onImport: importBusy ? null : () => runProjectImportFlow(context, ref),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(InkSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ResumeBar(projects: projects),
                    _ProjectGrid(projects: projects),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 「上次离开时」恢复条：只在 hasRestorableLastSession（与启动恢复守卫同一谓词）为真、
/// 且记录仍指向列表里存在的项目 / 画布时显示；开关关掉整条不出现，不是空态。
/// 稿上的第二行「3 个渲染任务已在上次退出时保存进度」没有对应数据，不画。
class _ResumeBar extends ConsumerWidget {
  const _ResumeBar({required this.projects});
  final List<ProjectWithCanvases> projects;

  static const Key resumeKey = Key('studio.resume.continue');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 开关经 controller 订阅（设置里改了立刻生效）；id 从当前偏好读。
    final bool keep = ref.watch(shellKeepLastCanvasControllerProvider);
    final AppPreferences prefs = ref.read(preferencesServiceProvider).current;
    if (!keep || !hasRestorableLastSession(prefs)) return const SizedBox.shrink();
    ProjectWithCanvases? project;
    CanvasRef? canvas;
    for (final ProjectWithCanvases p in projects) {
      if (p.id != prefs.lastProjectId) continue;
      project = p;
      for (final CanvasRef cv in p.canvases) {
        if (cv.id == prefs.lastCanvasId) canvas = cv;
      }
    }
    if (project == null || canvas == null) return const SizedBox.shrink();

    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final ProjectRef pref = ProjectRef(id: project.id, name: project.name);
    final String canvasId = canvas.id;
    return Container(
      margin: const EdgeInsets.only(bottom: InkSpacing.s22),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md, vertical: InkSpacing.s14),
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Row(
        children: <Widget>[
          Text(l.studioResumeLabel, style: t.meta.copyWith(color: c.fg4)),
          const SizedBox(width: InkSpacing.s10),
          Flexible(
            child: Text(
              l.studioResumeName(project.name, canvas.name.isEmpty ? l.canvasDefaultName : canvas.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: c.fg1),
            ),
          ),
          const SizedBox(width: InkSpacing.s10),
          Text(
            galleryTimeAgo(l, project.updatedAt, DateTime.now().toUtc()),
            style: t.mono.copyWith(color: c.fg6),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: l.studioResumeAction,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: resumeKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(shellControllerProvider.notifier).openCanvas(canvasId, withProject: pref),
                child: WsPrimaryButton(
                  l.studioResumeAction,
                  height: 26,
                  bordered: false,
                  horizontalPadding: InkSpacing.s14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 示例项目：建项目 + 画布并切到画布（ON-2）。
Future<void> createStudioSampleProject(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final failedMsg = l10n.studioCreateSampleFailed;
  final bootstrap = ref.read(canvasBootstrapControllerProvider);
  try {
    await bootstrap.createSample(
      projectName: l10n.canvasSampleProjectName,
      canvasName: l10n.canvasSampleCanvasName,
      seed: (
        laneLabel: l10n.canvasSampleLaneLabel,
        laneStylePrompt: l10n.canvasSampleLaneStylePrompt,
        nodeLabel: l10n.canvasSampleNodeLabel,
        nodePrompt: l10n.canvasSampleNodePrompt,
      ),
    );
  } on InkError catch (e, st) {
    ref.read(loggerProvider).error(
          _logModule,
          'create sample project failed',
          cause: e,
          stackTrace: st,
        );
    if (context.mounted) {
      ref.read(toastServiceProvider).show(failedMsg, kind: ToastKind.error);
    }
  }
}

/// 新建项目对话框 → 建项目（含首个画布）。标签栏「新建项目」与网格末位的虚线格共用。
Future<void> showStudioNewProjectDialog(BuildContext context, WidgetRef ref) async {
  final List<ProjectWithCanvases> existing =
      ref.read(workspaceProjectsProvider).valueOrNull ?? const <ProjectWithCanvases>[];
  final existingNames = existing.map((p) => p.name.trim().toLowerCase()).toSet();
  final firstCanvasName = context.l10n.canvasDefaultName;
  final name = await showDialog<String>(
    context: context,
    barrierColor: context.inkColors.scrim,
    builder: (_) => _NewProjectDialog(existingNames: existingNames),
  );
  if (name == null || name.isEmpty) return;
  try {
    await ref.read(studioProjectsControllerProvider).createProject(
          name: name,
          firstCanvasName: firstCanvasName,
        );
  } on InkError {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l10n.studioNewProjectFailed),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _StudioLoadingState extends StatelessWidget {
  const _StudioLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _StudioErrorState extends StatelessWidget {
  const _StudioErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkErrorBanner(message: context.l10n.studioErrorTitle),
            const SizedBox(height: InkSpacing.md),
            Text(
              context.l10n.studioEmptySubtitle,
              style: typo.body.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: InkGhostButton(
                label: context.l10n.studioErrorRetry,
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioEmptyState extends StatelessWidget {
  const _StudioEmptyState({
    required this.onCreate,
    required this.onImport,
    required this.onCreateSample,
    required this.onOpenShowcase,
  });

  final VoidCallback onCreate;
  final VoidCallback? onImport;
  final VoidCallback onCreateSample;
  final VoidCallback onOpenShowcase;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    // 外壳固定占 100（chrome 56 + 标签条 44）之后，960×600 最小窗口只剩 500 内容
    // 高，而本卡片自然高约 540 ⇒ 短视口必须可滚，否则 RenderFlex 直接溢出（T7）。
    // minHeight = maxHeight 保证视口够高时仍然垂直居中。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: InkNoirCard(
          padding: const EdgeInsets.all(InkSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface3,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Icon(
                  Icons.movie_filter_outlined,
                  size: 32,
                  color: colors.accent,
                ),
              ),
              const SizedBox(height: InkSpacing.lg),
              Text(
                context.l10n.studioEmptyTitle,
                style: typo.dialogTitle.copyWith(color: colors.fg1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: InkSpacing.sm),
              Text(
                context.l10n.studioEmptySubtitle,
                style: typo.body.copyWith(color: colors.fg3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: InkSpacing.lg),
              InkAmberButton(
                label: context.l10n.studioNewProject,
                icon: Icons.add,
                onPressed: onCreate,
              ),
              const SizedBox(height: InkSpacing.sm),
              // 2026-08-31 审计 P0：零项目用户手里只有归档文件时，此前完全没有
              // 入口能导入——项目卡 ⋮ 菜单此时不存在，FAB 也只在非空态渲染。
              InkGhostButton(
                label: context.l10n.studioImportProject,
                icon: Icons.unarchive_outlined,
                onPressed: onImport,
              ),
              const SizedBox(height: InkSpacing.sm),
              InkGhostButton(
                label: context.l10n.studioCreateSampleProject,
                icon: Icons.auto_awesome_outlined,
                onPressed: onCreateSample,
              ),
              const SizedBox(height: InkSpacing.sm),
              // 零项目用户的内置示例入口——项目卡 ⋮ 菜单此时不存在（评审 P1-1）。
              InkGhostButton(
                label: context.l10n.showcaseEntryLabel,
                icon: Icons.photo_library_outlined,
                onPressed: onOpenShowcase,
              ),
            ],
          ),
        ),
      ),
          ),
        ),
      ),
    );
  }
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog({
    required this.existingNames,
    this.initialName = '',
    this.title,
    this.confirmLabel,
  });

  final Set<String> existingNames;
  final String initialName;
  final String? title;
  final String? confirmLabel;

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  static const int _maxNameLength = 60;
  late final TextEditingController _controller;
  String? _errorKey; // 'empty' | 'tooLong' | 'duplicate'

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _validate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'empty';
    if (trimmed.length > _maxNameLength) return 'tooLong';
    if (widget.existingNames.contains(trimmed.toLowerCase())) {
      return 'duplicate';
    }
    return '';
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    final err = _validate(trimmed);
    if (err.isNotEmpty) {
      setState(() => _errorKey = err);
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  String? _errorMessage(BuildContext context) {
    switch (_errorKey) {
      case 'empty':
        return context.l10n.studioNewProjectErrorEmpty;
      case 'tooLong':
        return context.l10n.studioNewProjectErrorTooLong;
      case 'duplicate':
        return context.l10n.studioNewProjectErrorDuplicate;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final error = _errorMessage(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(InkSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: InkNoirCard(
          padding: const EdgeInsets.all(InkSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.title ?? context.l10n.studioNewProjectDialogTitle,
                style: typo.dialogTitle.copyWith(color: colors.fg1),
              ),
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.studioNewProjectNameLabel,
                style: typo.meta.copyWith(
                  color: colors.fg3,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: InkSpacing.xs),
              InkCompactTextField(
                controller: _controller,
                placeholder: context.l10n.studioNewProjectNameHint,
                autofocus: true,
                onChanged: (_) {
                  if (_errorKey != null) setState(() => _errorKey = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: InkSpacing.sm),
                Text(
                  error,
                  style: typo.meta.copyWith(color: colors.danger),
                ),
              ],
              const SizedBox(height: InkSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  InkGhostButton(
                    label: context.l10n.commonCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: InkSpacing.sm),
                  InkAmberButton(
                    label: widget.confirmLabel ?? context.l10n.studioCreate,
                    icon: Icons.check,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 项目网格：4 列、gap 16（稿），末位虚线「新建项目」格 + 下方「空白 / 短剧示例」两个入口。
/// 卡片元信息 = 最近修改时间 [+ N 节点在渲染]（渲染数从 jobsRegistry 按项目的画布聚合）。
class _ProjectGrid extends ConsumerWidget {
  const _ProjectGrid({required this.projects});

  final List<ProjectWithCanvases> projects;

  static const Key newProjectCardKey = Key('studio.grid.newProject');
  static const Key newProjectSampleKey = Key('studio.grid.newProject.sample');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final List<JobState> jobs = ref.watch(jobsRegistryProvider);
    final DateTime now = DateTime.now().toUtc();
    return LayoutBuilder(
      builder: (context, constraints) {
        const int cols = 4;
        final double w = (constraints.maxWidth - InkSpacing.md * (cols - 1)) / cols;
        return Wrap(
          spacing: InkSpacing.md,
          runSpacing: InkSpacing.md,
          children: <Widget>[
            for (final ProjectWithCanvases p in projects)
              SizedBox(
                width: w,
                child: StudioProjectCard(
                  name: p.name,
                  metaLine: _metaLine(l, p, jobs, now),
                  canvasCount: p.canvases.length,
                  onTap: () async {
                    final defaultName = context.l10n.canvasDefaultName;
                    final failedMsg = context.l10n.studioOpenCanvasFailed;
                    try {
                      await openProjectCanvas(
                        ref.read,
                        p,
                        createCanvas: (projectId) async {
                          final repo = await ref.read(canvasRepositoryProvider.future);
                          return repo.create(projectId: projectId, name: defaultName);
                        },
                      );
                    } on InkError catch (e, st) {
                      ref.read(loggerProvider).error(
                            _logModule,
                            'open project canvas failed',
                            extra: {'project_id': p.id},
                            cause: e,
                            stackTrace: st,
                          );
                      if (context.mounted) {
                        ref.read(toastServiceProvider).show(failedMsg, kind: ToastKind.error);
                      }
                    }
                  },
                  onOpenGallery: () => ref
                      .read(shellControllerProvider.notifier)
                      .openGallery(ProjectRef(id: p.id, name: p.name)),
                  onOpenShowcase: () =>
                      ref.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.showcase),
                  onRename: () => _renameProject(context, ref, p),
                  onExport: () => _exportProject(context, ref, p),
                  onManageCanvases: () => showDialog<void>(
                    context: context,
                    barrierColor: context.inkColors.scrim,
                    builder: (_) => _ManageCanvasesDialog(project: p),
                  ),
                  onDelete: () => _deleteProject(context, ref, p),
                ),
              ),
            SizedBox(width: w, child: const _NewProjectCard()),
          ],
        );
      },
    );
  }

  /// 「2 小时前」，有在跑的任务时追加「· N 节点在渲染」（按项目的画布聚合）。
  static String _metaLine(AppLocalizations l, ProjectWithCanvases p, List<JobState> jobs, DateTime now) {
    final Set<String> canvasIds = <String>{for (final CanvasRef c in p.canvases) c.id};
    final int rendering = jobs.where((JobState j) => !j.isTerminal && canvasIds.contains(j.canvasId)).length;
    final String time = galleryTimeAgo(l, p.updatedAt, now);
    return rendering == 0 ? time : l.studioCardMeta(time, l.studioCardRendering(rendering));
  }

  Future<void> _exportProject(
    BuildContext context,
    WidgetRef ref,
    ProjectWithCanvases p,
  ) async {
    // 全部依赖在首个 await 前一次性 read 持有（#188 评审 P1-1）：导出耗时段内
    // 用户切进画布会 unmount 本 widget，之后再触 ref 抛 StateError——连 finally
    // 的 busy 复位一起炸，导出功能本会话内永久假死。持有的都是容器级对象，
    // unmount 后依然有效。
    final busy = ref.read(projectExportBusyProvider.notifier);
    if (busy.state) return;
    // 债158：三大重操作互斥的反向补查——导入/还原进行中不得开导出
    //（此前只有导入侧单向查,导入中仍可点导出）。
    if (ref.read(projectImportBusyProvider) ||
        ref.read(databaseRestoreBusyProvider)) {
      return;
    }
    final toast = ref.read(toastServiceProvider);
    final logger = ref.read(loggerProvider);
    final picker = ref.read(saveLocationPickerProvider);
    final serviceFuture = ref.read(projectArchiveServiceProvider.future);
    final doneMsg = context.l10n.studioExportProjectDone;
    final failedMsg = context.l10n.studioExportProjectFailed;
    // busy 在 picker 之前置位：对话框开着时的二次触发也要挡（#188 评审 P3-6）。
    busy.state = true;
    try {
      final path = await picker(suggestedArchiveName(p.name));
      if (path == null) return; // 用户取消保存对话框。
      final service = await serviceFuture;
      await service.exportProject(projectId: p.id, targetPath: path);
      toast.show(doneMsg);
    } on InkError catch (e, st) {
      logger.error(
        _logModule,
        'export project failed',
        extra: {'project_id': p.id},
        cause: e,
        stackTrace: st,
      );
      toast.show(failedMsg, kind: ToastKind.error);
    } finally {
      busy.state = false;
    }
  }

  Future<void> _renameProject(
    BuildContext context,
    WidgetRef ref,
    ProjectWithCanvases p,
  ) async {
    final existingNames = projects
        .where((o) => o.id != p.id)
        .map((o) => o.name.trim().toLowerCase())
        .toSet();
    final title = context.l10n.studioRenameProject;
    final confirm = context.l10n.studioRename;
    final failedMsg = context.l10n.studioRenameFailed;
    final name = await showDialog<String>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (_) => _NewProjectDialog(
        existingNames: existingNames,
        initialName: p.name,
        title: title,
        confirmLabel: confirm,
      ),
    );
    if (name == null || name.isEmpty || name == p.name) return;
    try {
      await ref
          .read(studioProjectsControllerProvider)
          .renameProject(id: p.id, name: name);
    } on InkError {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(failedMsg),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    ProjectWithCanvases p,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.inkColors.surface2,
        title: Text(ctx.l10n.studioDeleteConfirmTitle),
        content: Text(ctx.l10n.studioDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.studioDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final failedMsg = context.l10n.studioDeleteFailed;
    try {
      await ref.read(studioProjectsControllerProvider).deleteProject(p.id);
    } on InkError {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(failedMsg),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// 画布管理对话框：列出项目内画布，行内重命名/删除（软删可恢复）。
/// 本地列表随操作即时更新；工作库网格经 controller invalidate 自行刷新。
class _ManageCanvasesDialog extends ConsumerStatefulWidget {
  const _ManageCanvasesDialog({required this.project});

  final ProjectWithCanvases project;

  @override
  ConsumerState<_ManageCanvasesDialog> createState() =>
      _ManageCanvasesDialogState();
}

class _ManageCanvasesDialogState extends ConsumerState<_ManageCanvasesDialog> {
  late List<CanvasRef> _canvases;

  @override
  void initState() {
    super.initState();
    _canvases = List.of(widget.project.canvases);
  }

  void _showError(String msg) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _rename(CanvasRef c) async {
    final existing = _canvases
        .where((o) => o.id != c.id)
        .map((o) => o.name.trim().toLowerCase())
        .toSet();
    final title = context.l10n.studioRenameCanvas;
    final confirm = context.l10n.studioRename;
    final failedMsg = context.l10n.studioRenameCanvasFailed;
    final name = await showDialog<String>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (_) => _NewProjectDialog(
        existingNames: existing,
        initialName: c.name,
        title: title,
        confirmLabel: confirm,
      ),
    );
    if (name == null || name.isEmpty || name == c.name || !mounted) return;
    try {
      await ref
          .read(studioProjectsControllerProvider)
          .renameCanvas(id: c.id, name: name);
      if (!mounted) return;
      setState(() {
        _canvases = <CanvasRef>[
          for (final o in _canvases)
            if (o.id == c.id) CanvasRef(id: o.id, name: name) else o,
        ];
      });
    } on InkError {
      if (mounted) _showError(failedMsg);
    }
  }

  /// 恢复软删画布（LB-15）：repo 清 deleted_at → 刷新已删区 → 行迁回活列表。
  Future<void> _restoreTrashed(TrashedItem t) async {
    final failedMsg = context.l10n.studioRestoreFailed;
    try {
      await ref.read(studioProjectsControllerProvider).restoreCanvas(t.id);
      if (!mounted) return;
      ref.invalidate(trashedCanvasesProvider(widget.project.id));
      setState(() {
        // 按 id 查重：refetch 窗口内 stale 已删行仍可双击，二次 restore
        // 返 0 不抛——不得追加第二条同 id（#190 评审 P2-2）。
        if (!_canvases.any((o) => o.id == t.id)) {
          _canvases = <CanvasRef>[
            ..._canvases,
            CanvasRef(id: t.id, name: t.name),
          ];
        }
      });
    } on InkError {
      if (mounted) _showError(failedMsg);
    }
  }

  Future<void> _delete(CanvasRef c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.inkColors.surface2,
        title: Text(ctx.l10n.studioCanvasDeleteConfirmTitle),
        content: Text(ctx.l10n.studioCanvasDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.studioDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final failedMsg = context.l10n.studioDeleteCanvasFailed;
    try {
      await ref.read(studioProjectsControllerProvider).deleteCanvas(c.id);
      if (!mounted) return;
      // 删除迁入已删区：同对话框正 watch 着 trashed family，不失效会显示
      // 「刚删的画布不在回收站」（#190 评审 P2-1）。
      ref.invalidate(trashedCanvasesProvider(widget.project.id));
      setState(() {
        _canvases =
            _canvases.where((o) => o.id != c.id).toList(growable: false);
      });
    } on InkError {
      if (mounted) _showError(failedMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return AlertDialog(
      backgroundColor: colors.surface2,
      title: Text(context.l10n.studioManageCanvases),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_canvases.isEmpty)
                Text(
                  context.l10n.studioNoCanvases,
                  style: typo.body.copyWith(color: colors.fg3),
                )
              else
                for (final c in _canvases)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          c.name,
                          style: typo.body.copyWith(color: colors.fg1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.studioRenameCanvas,
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colors.fg2,
                        ),
                        onPressed: () => _rename(c),
                      ),
                      IconButton(
                        tooltip: context.l10n.studioCanvasDeleteConfirmTitle,
                        icon: Icon(
                          Icons.delete_outline,
                          color: colors.fg2,
                        ),
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
              // 已删区（LB-15）：项目下软删画布，可逐个恢复。空则不渲染。
              ref.watch(trashedCanvasesProvider(widget.project.id)).when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.only(top: InkSpacing.sm),
                      child: InkErrorBanner(
                        message: l10nAsyncError(context, e),
                      ),
                    ),
                    data: (items) => items.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const SizedBox(height: InkSpacing.md),
                              Text(
                                context.l10n.studioTrash,
                                style: typo.meta
                                    .copyWith(color: colors.fg3),
                              ),
                              const SizedBox(height: InkSpacing.xs),
                              for (final t in items)
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            t.name,
                                            style: typo.body.copyWith(
                                                color: colors.fg2),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            context.l10n.studioTrashDeletedAt(
                                                t.deletedAt.toLocal()),
                                            style: typo.meta.copyWith(
                                                color: colors.fg3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _restoreTrashed(t),
                                      child: Text(
                                          context.l10n.studioRestore),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                  ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonClose),
        ),
      ],
    );
  }
}

/// 稿：16:10 虚线框（controlStrong）圆角 4，居中「+」+「新建项目」；下方 11px「空白 / 短剧示例」。
/// 「单画布」没有对应流程，不画。
class _NewProjectCard extends ConsumerWidget {
  const _NewProjectCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          label: l.studioNewProject,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: _ProjectGrid.newProjectCardKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => showStudioNewProjectDialog(context, ref),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: CustomPaint(
                  painter: _DashedBorderPainter(color: c.controlStrong, radius: InkRadius.sm),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('+', style: t.dialogTitle.copyWith(color: c.fg6, height: 1.0)),
                        const SizedBox(height: InkSpacing.s6),
                        Text(l.studioNewProject, style: t.meta.copyWith(color: c.fg6)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: InkSpacing.sm),
        Row(
          children: <Widget>[
            _HintLink(label: l.studioNewProjectHintBlank, onTap: () => showStudioNewProjectDialog(context, ref)),
            Text(' / ', style: t.meta.copyWith(color: c.fg6)),
            _HintLink(
              key: _ProjectGrid.newProjectSampleKey,
              label: l.studioNewProjectHintSample,
              onTap: () => createStudioSampleProject(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _HintLink extends StatelessWidget {
  const _HintLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Text(label, style: t.meta.copyWith(color: c.fg6)),
        ),
      ),
    );
  }
}

/// 1px 虚线圆角框（稿 border: 1px dashed；Flutter 没有原生虚线边框）。
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Offset(0.5, 0.5) & Size(size.width - 1, size.height - 1),
        Radius.circular(radius),
      ));
    const double dash = 3;
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), p);
        d += dash * 2;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}
