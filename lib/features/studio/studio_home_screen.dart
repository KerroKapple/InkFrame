// StudioHomeScreen：Amber Noir 风格的首页。
//
// 布局：Column(chrome, Expanded(Row(LibrarySidebar 280, Expanded(Stack(main, fab)))))
// 状态：workspaceProjectsProvider 的 loading / error / empty / data 四态。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/current_screen.dart';
import '../../core/di/database_restore.dart';
import '../../core/di/logger.dart';
import '../../core/di/project_archive.dart';
import '../../core/di/repositories.dart';
import '../../core/errors/ink_error.dart';
import '../../core/interfaces/project_import_service.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/ink_error_banner.dart';
import '../../theme/primitives/ink_amber_button.dart';
import '../../theme/primitives/ink_compact_text_field.dart';
import '../../theme/primitives/ink_ghost_button.dart';
import '../../theme/primitives/ink_noir_card.dart';
import '../../theme/tokens.dart';
import '../../services/project_archive_service.dart';
import '../canvas/providers/canvas_bootstrap_controller.dart';
import '../gallery/providers/current_gallery_project.dart';
import 'controllers/studio_projects_controller.dart';
import 'providers/project_export_busy.dart';
import 'providers/trashed_items_providers.dart';
import 'controllers/studio_state.dart';
import 'models/project_with_canvases.dart';
import 'open_canvas.dart';
import 'providers/workspace_projects_provider.dart';
import 'widgets/library_sidebar.dart';
import 'widgets/project_card.dart';
import 'widgets/studio_provider_banner.dart';
import 'widgets/studio_top_chrome.dart';
import '../generation/services/toast_service.dart';

const String _logModule = 'studio.home';

class StudioHomeScreen extends ConsumerWidget {
  const StudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final studioName =
        ref.watch(currentStudioProvider) ?? context.l10n.studioDefaultName;
    return ColoredBox(
      color: colors.surfaceCanvas,
      child: Column(
        children: <Widget>[
          StudioTopChrome(
            studioName: studioName,
            breadcrumbTail: context.l10n.studioBreadcrumbAll,
            onOpenSettings: () =>
                ref.read(currentScreenProvider.notifier).state =
                    AppScreen.settings,
          ),
          const StudioProviderBanner(),
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
    final showFab = projectsAsync.maybeWhen(
      data: (p) => p.isNotEmpty,
      orElse: () => false,
    );
    return ColoredBox(
      color: colors.surfaceCanvas,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              InkSpacing.xl,
              InkSpacing.s28,
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
                    style: typo.displayMd.copyWith(
                      color: colors.fg1,
                    ),
                  ),
                ),
                Expanded(
                  child: projectsAsync.when(
                    loading: () => const _StudioLoadingState(),
                    error: (e, _) => _StudioErrorState(
                      onRetry: () =>
                          ref.invalidate(workspaceProjectsProvider),
                    ),
                    data: (projects) => projects.isEmpty
                        ? _StudioEmptyState(
                            onCreate: () =>
                                _showNewProjectDialog(context, ref, const []),
                            onCreateSample: () =>
                                _createSampleProject(context, ref),
                            onOpenShowcase: () => ref
                                .read(currentScreenProvider.notifier)
                                .state = AppScreen.showcase,
                          )
                        : _ProjectGrid(projects: projects),
                  ),
                ),
              ],
            ),
          ),
          if (showFab)
            Positioned(
              right: InkSpacing.xl,
              bottom: InkSpacing.xl,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // LB-12：项目包导入（导入中/还原中/导出中互斥禁用，拍板 9）。
                  InkGhostButton(
                    label: context.l10n.studioImportProject,
                    icon: Icons.unarchive_outlined,
                    onPressed: ref.watch(projectImportBusyProvider) ||
                            ref.watch(databaseRestoreBusyProvider) ||
                            ref.watch(projectExportBusyProvider)
                        ? null
                        : () => _importProject(context, ref),
                  ),
                  const SizedBox(width: InkSpacing.sm),
                  InkAmberButton(
                    label: context.l10n.studioNewProject,
                    icon: Icons.add,
                    onPressed: () => _showNewProjectDialog(
                      context,
                      ref,
                      projectsAsync.maybeWhen(
                        data: (p) => p,
                        orElse: () => const <ProjectWithCanvases>[],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// LB-12：项目包导入——picker → barrier 模态 → service → 成功选中新项目。
  /// 三大重操作（导入/还原/导出）互斥；依赖首 await 前 read 持有（#188 P1-1）。
  Future<void> _importProject(BuildContext context, WidgetRef ref) async {
    final importBusy = ref.read(projectImportBusyProvider.notifier);
    if (importBusy.state ||
        ref.read(databaseRestoreBusyProvider) ||
        ref.read(projectExportBusyProvider)) {
      return;
    }
    final toast = ref.read(toastServiceProvider);
    final logger = ref.read(loggerProvider);
    final picker = ref.read(openFilePickerProvider);
    final serviceFuture = ref.read(projectImportServiceProvider.future);
    final selected = ref.read(selectedProjectIdProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context, rootNavigator: true);
    final l10n = context.l10n;
    final progressMsg = l10n.importInProgress;
    final doneMsg = l10n.importDone;
    importBusy.state = true;
    try {
      final String? path;
      try {
        path = await picker();
      } catch (e, st) {
        // 放行点：平台 picker 异常不得静默（#192 评审 P3-5）。
        logger.error(_logModule, 'import picker failed',
            cause: e, stackTrace: st);
        toast.show(l10n.importFailed, kind: ToastKind.error);
        return;
      }
      if (path == null || !context.mounted) return;

      // barrier 模态罩全程（导入分钟级；LB-22 同款）。
      BuildContext? barrierCtx;
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: context.inkColors.scrim,
        builder: (ctx) {
          barrierCtx = ctx;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: InkSpacing.md),
                  Text(progressMsg),
                ],
              ),
            ),
          );
        },
      ));
      ImportResult result;
      try {
        final service = await serviceFuture;
        result = await service.importArchive(zipPath: path);
      } catch (e, st) {
        // 放行点：service 已收敛所有已知失败——这里兜装配错误，失败必须可见。
        logger.error(_logModule, 'import unexpected', cause: e, stackTrace: st);
        result = const ImportResult(outcome: ImportOutcome.failed);
      } finally {
        final ctx = barrierCtx;
        if (ctx != null && ctx.mounted) {
          Navigator.of(ctx).pop();
        } else {
          navigator.pop();
        }
      }

      if (result.outcome == ImportOutcome.imported) {
        container.invalidate(workspaceProjectsProvider);
        selected.state = result.newProjectId;
        toast.show(doneMsg, kind: ToastKind.success);
      } else {
        final String msg = switch (result.outcome) {
          ImportOutcome.failedFormat => l10n.importFailedFormat,
          ImportOutcome.failedVersionNewer => l10n.importFailedVersionNewer,
          ImportOutcome.failedCorrupt => l10n.importFailedCorrupt,
          ImportOutcome.failed || ImportOutcome.imported => l10n.importFailed,
        };
        toast.show(msg, kind: ToastKind.error);
      }
    } finally {
      importBusy.state = false;
    }
  }

  /// ON-2：示例项目入口。createSample 内部会切 currentCanvasId 直达画布。
  Future<void> _createSampleProject(BuildContext context, WidgetRef ref) async {
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
      // 捕获集 = createSample 真实抛出集：仓储链路只抛 InkError（铁律）。
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

  Future<void> _showNewProjectDialog(
    BuildContext context,
    WidgetRef ref,
    List<ProjectWithCanvases> existing,
  ) async {
    final existingNames =
        existing.map((p) => p.name.trim().toLowerCase()).toSet();
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
    required this.onCreateSample,
    required this.onOpenShowcase,
  });

  final VoidCallback onCreate;
  final VoidCallback onCreateSample;
  final VoidCallback onOpenShowcase;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Center(
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
                style: typo.headline.copyWith(color: colors.fg1),
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
                style: typo.headline.copyWith(color: colors.fg1),
              ),
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.studioNewProjectNameLabel,
                style: typo.caption.copyWith(
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
                  style: typo.caption.copyWith(color: colors.danger),
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

class _ProjectGrid extends ConsumerWidget {
  const _ProjectGrid({required this.projects});

  final List<ProjectWithCanvases> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              metaLine: context.l10n.studioProjectMetaLine(
                p.createdAt,
                p.canvases.length,
              ),
              onTap: () async {
                final defaultName = context.l10n.canvasDefaultName;
                final failedMsg = context.l10n.studioOpenCanvasFailed;
                try {
                  await openProjectCanvas(
                    ref.read,
                    p,
                    createCanvas: (projectId) async {
                      final repo =
                          await ref.read(canvasRepositoryProvider.future);
                      return repo.create(
                        projectId: projectId,
                        name: defaultName,
                      );
                    },
                  );
                } on InkError catch (e, st) {
                  // 捕获集 = try 体真实抛出集：仓储/打开链路只抛 InkError
                  // （guard 翻译边界），不捕宽泛 Exception（铁律）。
                  ref.read(loggerProvider).error(
                        _logModule,
                        'open project canvas failed',
                        extra: {'project_id': p.id},
                        cause: e,
                        stackTrace: st,
                      );
                  if (context.mounted) {
                    ref.read(toastServiceProvider).show(
                          failedMsg,
                          kind: ToastKind.error,
                        );
                  }
                }
              },
              onOpenGallery: () => ref
                  .read(currentGalleryProjectProvider.notifier)
                  .state = (id: p.id, name: p.name),
              onOpenShowcase: () =>
                  ref.read(currentScreenProvider.notifier).state =
                      AppScreen.showcase,
              onRename: () => _renameProject(context, ref, p),
              onExport: () => _exportProject(context, ref, p),
              onManageCanvases: () => showDialog<void>(
                context: context,
                barrierColor: context.inkColors.scrim,
                builder: (_) => _ManageCanvasesDialog(project: p),
              ),
              onDelete: () => _deleteProject(context, ref, p),
            );
          },
        );
      },
    );
  }

  /// 导出整项目 zip（LB-11）：选保存位置 → ProjectArchiveService → 成败 toast。
  /// busy 期间重复触发直接忽略（防两个导出写同一 .partial）。
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
                                style: typo.overline
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
                                            style: typo.caption.copyWith(
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
