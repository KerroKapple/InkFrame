// StudioHomeScreen：Amber Noir 风格的首页。
//
// 布局：Column(chrome, Expanded(Row(LibrarySidebar 280, Expanded(Stack(main, fab)))))
// 状态：workspaceProjectsProvider 的 loading / error / empty / data 四态。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/current_screen.dart';
import '../../core/di/repositories.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/ink_error_banner.dart';
import '../../theme/primitives/ink_amber_button.dart';
import '../../theme/primitives/ink_compact_text_field.dart';
import '../../theme/primitives/ink_ghost_button.dart';
import '../../theme/primitives/ink_noir_card.dart';
import '../../theme/tokens.dart';
import 'controllers/studio_state.dart';
import 'models/project_with_canvases.dart';
import 'open_canvas.dart';
import 'widgets/library_sidebar.dart';
import 'widgets/project_card.dart';
import 'widgets/studio_provider_banner.dart';
import 'widgets/studio_top_chrome.dart';
import '../generation/services/toast_service.dart';

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
                    style: typo.display.copyWith(
                      fontSize: 32,
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
              child: InkAmberButton(
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
            ),
        ],
      ),
    );
  }

  Future<void> _showNewProjectDialog(
    BuildContext context,
    WidgetRef ref,
    List<ProjectWithCanvases> existing,
  ) async {
    final existingNames =
        existing.map((p) => p.name.trim().toLowerCase()).toSet();
    final name = await showDialog<String>(
      context: context,
      barrierColor: context.inkColors.scrim,
      builder: (_) => _NewProjectDialog(existingNames: existingNames),
    );
    if (name == null || name.isEmpty) return;
    try {
      final projects = await ref.read(projectRepositoryProvider.future);
      final canvases = await ref.read(canvasRepositoryProvider.future);
      final projectId = await projects.create(name: name);
      await canvases.create(
        projectId: projectId,
        name: 'Canvas 1',
      );
      ref.invalidate(workspaceProjectsProvider);
    } catch (_) {
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
  const _StudioEmptyState({required this.onCreate});

  final VoidCallback onCreate;

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
            ],
          ),
        ),
      ),
    );
  }
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog({required this.existingNames});

  final Set<String> existingNames;

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  static const int _maxNameLength = 60;
  final TextEditingController _controller = TextEditingController();
  String? _errorKey; // 'empty' | 'tooLong' | 'duplicate'

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
                context.l10n.studioNewProjectDialogTitle,
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
                    label: context.l10n.studioCreate,
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
              metaLine: 'EP 01 · 2026.05 · ${_box()} ${p.canvases.length}',
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
                } catch (_) {
                  if (context.mounted) {
                    ref.read(toastServiceProvider).show(
                          failedMsg,
                          kind: ToastKind.error,
                        );
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  String _box() => '\u{1F4E6}';
}
