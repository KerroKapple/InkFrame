// InkFrameApp：MaterialApp 装配。
//
// - 主题走 ThemeModeController（dark/light/highContrast + textScale）
// - 平台亮度变化通过 StatefulWidget 生命周期订阅并转发给 controller
// - i18n delegates 走生成的 AppLocalizations
// - 首屏：CanvasView
// - FAB：当前有 canvas 开着时 → PopupMenu 选择新增 image / video 节点

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/secure_storage.dart';
import 'core/di/theme.dart';
import 'features/canvas/models/canvas_node.dart';
import 'features/canvas/providers/canvas_nodes_controller.dart';
import 'features/canvas/providers/current_canvas_id.dart';
import 'features/canvas/widgets/canvas_view.dart';
import 'features/debug/primitives_showcase_screen.dart';
import 'features/lock/lock_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/studio/studio_home_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/l10n_x.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class InkFrameApp extends ConsumerStatefulWidget {
  const InkFrameApp({super.key});

  @override
  ConsumerState<InkFrameApp> createState() => _InkFrameAppState();
}

class _InkFrameAppState extends ConsumerState<InkFrameApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(themeModeControllerProvider.notifier).onPlatformBrightnessChanged();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeModeControllerProvider);
    return MaterialApp(
      title: 'InkFrame',
      theme: buildAppTheme(
        variant: themeState.variant,
        textScale: themeState.textScale,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _HomeScaffold(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _HomeScaffold extends ConsumerWidget {
  const _HomeScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedAsync = ref.watch(apiKeyUnlockedProvider);
    return unlockedAsync.when(
      loading: () => const _LockSplash(),
      error: (_, _) => const LockScreen(),
      data: (unlocked) =>
          unlocked ? const _UnlockedShell() : const LockScreen(),
    );
  }
}

class _LockSplash extends StatelessWidget {
  const _LockSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.inkColors.surfaceCanvas,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _UnlockedShell extends ConsumerWidget {
  const _UnlockedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    final inCanvas = canvasId != null;
    if (!inCanvas) {
      return const Scaffold(body: StudioHomeScreen());
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.l10n.workspaceBackToWorkspace,
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              ref.read(currentCanvasIdProvider.notifier).state = null,
        ),
        title: Text(context.l10n.appTitle),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Primitives Showcase',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrimitivesShowcaseScreen(),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: context.l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: const CanvasView(),
      floatingActionButton: _AddNodeFab(canvasId: canvasId),
    );
  }
}

class _AddNodeFab extends ConsumerWidget {
  const _AddNodeFab({required this.canvasId});
  final String canvasId;

  // 简单随机位置，避免新节点全叠在原点。InteractiveViewer 下用户可平移找到。
  static final _rand = Random();

  Offset _pickPosition() {
    return Offset(
      200 + _rand.nextDouble() * 400,
      200 + _rand.nextDouble() * 400,
    );
  }

  Future<void> _addNode(
    BuildContext context,
    WidgetRef ref,
    CanvasNodeType type,
  ) async {
    try {
      await ref
          .read(canvasNodesControllerProvider(canvasId).notifier)
          .addNode(
            label: context.l10n.canvasNodeDefaultLabel,
            type: type,
            position: _pickPosition(),
          );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.canvasAddNodeFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final Offset topLeft =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight =
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay);
    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    );

    final selected = await showMenu<CanvasNodeType>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<CanvasNodeType>(
          value: CanvasNodeType.image,
          child: Row(
            children: [
              const Icon(Icons.add_photo_alternate_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddImageNode),
            ],
          ),
        ),
        PopupMenuItem<CanvasNodeType>(
          value: CanvasNodeType.video,
          child: Row(
            children: [
              const Icon(Icons.videocam_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddVideoNode),
            ],
          ),
        ),
      ],
    );
    if (selected == null || !context.mounted) return;
    await _addNode(context, ref, selected);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      tooltip: context.l10n.canvasAddNodeTooltip,
      onPressed: () => _showMenu(context, ref),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.canvasAddNodeTooltip),
    );
  }
}
