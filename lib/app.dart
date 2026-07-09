// InkFrameApp：MaterialApp 装配 + 顶层路由。
//
// - 主题走 ThemeModeController（dark/light/highContrast + textScale）
// - 平台亮度变化通过 StatefulWidget 生命周期订阅并转发给 controller
// - i18n delegates 走生成的 AppLocalizations；locale 来自 LocaleController
// - ScaffoldMessenger 走全局 toastMessengerKeyProvider，便于 ToastService 跨 context 提示
// - 锁屏后路由：currentCanvasId 优先；其次 currentGalleryProject（项目产物画廊）；
//   否则按 currentScreenProvider 在 Studio / Settings 切换
// - 启动失败 gate（LB-09）：DB-ready future（pgMigratedPoolProvider）为 AsyncError
//   时以 StartupErrorView 替代白屏；loading/data 均照常进 _UnlockedShell
// - 新增节点 FAB 已下沉到 CanvasScreen 内部，本文件不再托管

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/current_screen.dart';
import 'core/di/database.dart';
import 'core/di/locale.dart';
import 'core/di/orphan_reaper.dart';
import 'core/di/theme.dart';
import 'features/canvas/providers/current_canvas_id.dart';
import 'features/canvas/widgets/canvas_screen.dart';
import 'features/gallery/providers/current_gallery_project.dart';
import 'features/gallery/widgets/gallery_screen.dart';
import 'features/generation/services/toast_service.dart';
import 'features/settings/settings_screen.dart';
import 'features/startup/widgets/startup_error_view.dart';
import 'features/studio/providers/restore_last_session.dart';
import 'features/studio/studio_home_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/l10n_x.dart';
import 'theme/app_theme.dart';

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
    // 首帧后触发上次会话恢复（best-effort，内部自会校验/清理，见 provider 注释）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(restoreLastSessionProvider);
      // LB-13：首帧后触发磁盘孤儿文件回收（DRY-RUN + ≥7d 节流）。fire-and-forget，
      // housekeeping，内部吞错只 warn，绝不阻断启动或抢占其它流程。
      ref.read(orphanReapStartupProvider);
    });
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
    final locale = ref.watch(localeControllerProvider);
    final messengerKey = ref.watch(toastMessengerKeyProvider);
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: buildAppTheme(
        variant: themeState.variant,
        textScale: themeState.textScale,
      ),
      locale: locale,
      scaffoldMessengerKey: messengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _StartupGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 启动 gate（LB-09）：监听 DB-ready future——AsyncError 时全屏呈现 StartupErrorView，
/// 否则（loading / data）照常进 _UnlockedShell。loading 期不阻断，spinner/首屏照旧，
/// 唯 error 态换上启动失败 surface。
class _StartupGate extends ConsumerWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbReady = ref.watch(pgMigratedPoolProvider);
    return switch (dbReady) {
      AsyncError(:final error) => StartupErrorView(error: error),
      _ => const _UnlockedShell(),
    };
  }
}

class _UnlockedShell extends ConsumerWidget {
  const _UnlockedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId != null) {
      return const CanvasScreen();
    }
    final gallery = ref.watch(currentGalleryProjectProvider);
    if (gallery != null) {
      return Scaffold(
        body: GalleryScreen(projectId: gallery.id, projectName: gallery.name),
      );
    }
    final screen = ref.watch(currentScreenProvider);
    return switch (screen) {
      AppScreen.studio => const Scaffold(body: StudioHomeScreen()),
      AppScreen.settings => const SettingsScreen(),
    };
  }
}
