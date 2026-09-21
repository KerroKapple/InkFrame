// InkFrameApp：MaterialApp 装配 + 顶层路由。
//
// - 主题走 ThemeModeController（dark/light/highContrast + textScale）
// - 平台亮度变化通过 StatefulWidget 生命周期订阅并转发给 controller
// - i18n delegates 走生成的 AppLocalizations；locale 来自 LocaleController
// - ScaffoldMessenger 走全局 toastMessengerKeyProvider，便于 ToastService 跨 context 提示
// - 锁屏后路由：ShellState.canvasId 优先；其次 tab==gallery && project（项目产物画廊）；
//   否则按 ShellState.overlay 在 Studio / Settings / Showcase 切换
// - 启动失败 gate（LB-09）：DB-ready future（pgMigratedPoolProvider）为 AsyncError
//   时以 StartupErrorView 替代白屏；loading/data 均照常进 _UnlockedShell
// - 首帧闸门（ON-1，挂 DB-ready 之后）：onboardingCompleted=false → 弹首启向导并
//   跳过该次会话恢复；=true → 照常触发 restoreLastSession（在 _UnlockedShell，
//   Navigator 之下）；PG 失败/未就绪不弹向导也不恢复
// - 新增节点 FAB 已下沉到 CanvasScreen 内部，本文件不再托管
// - ⌘K/Ctrl+K 命令面板（PL-1）：CommandPaletteShortcuts 包住 shell 全路由生效

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/database.dart';
import 'core/di/database_backup.dart';
import 'core/di/locale.dart';
import 'core/di/orphan_reaper.dart';
import 'core/di/preferences.dart';
import 'core/di/theme.dart';
import 'core/di/video_backfill.dart';
import 'features/canvas/widgets/canvas_screen.dart';
import 'features/command_palette/widgets/command_palette_shortcuts.dart';
import 'features/gallery/widgets/gallery_screen.dart';
import 'features/generation/services/toast_service.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/models/shell_state.dart';
import 'features/shell/providers/shell_controller.dart';
import 'features/showcase/widgets/built_in_showcase_screen.dart';
import 'features/startup/widgets/startup_error_view.dart';
import 'features/studio/providers/restore_last_session.dart';
import 'features/studio/studio_home_screen.dart';
import 'features/studio/widgets/onboarding_dialog.dart';
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
    // 首帧启动决策（onboarding / 会话恢复）在 _UnlockedShell——需要 Navigator 之下
    // 的 context 才能 showDialog。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // LB-13：首帧后触发磁盘孤儿文件回收（只读扫描 + ≥7d 节流;该服务无删除实现）。fire-and-forget，
      // housekeeping，内部吞错只 warn，绝不阻断启动或抢占其它流程。
      ref.read(orphanReapStartupProvider);
      // XM-1b：存量视频元数据回填（同级 housekeeping，稳态只花一条 SQL）。
      ref.read(videoBackfillStartupProvider);
      // LB-10：每日 pg_dump 冷备（当日已有则跳过，保留 7 份）。同级 housekeeping，
      // 内部吞错只 warn，绝不阻断启动。
      ref.read(databaseBackupStartupProvider);
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

class _UnlockedShell extends ConsumerStatefulWidget {
  const _UnlockedShell();

  @override
  ConsumerState<_UnlockedShell> createState() => _UnlockedShellState();
}

class _UnlockedShellState extends ConsumerState<_UnlockedShell> {
  bool _startupDecisionDone = false;

  @override
  void initState() {
    super.initState();
    // 首帧启动决策（ON-1）挂在 DB-ready 成功之后才做：向导第三步（建示例项目）与
    // 会话恢复都依赖 DB；PG 失败由 _StartupGate 全屏接管——不弹向导也不恢复，
    // 避免向导悬浮在 StartupErrorView 之上。
    // 决策本身：首启向导优先，该次跳过会话恢复（避免向导底下偷偷切画布）；
    // 非首启照常 best-effort 恢复上次会话。
    ref.listenManual(pgMigratedPoolProvider, fireImmediately: true, (_, next) {
      if (_startupDecisionDone || next is! AsyncData) return;
      _startupDecisionDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final prefs = ref.read(preferencesServiceProvider);
        if (prefs.current.onboardingCompleted) {
          ref.read(restoreLastSessionProvider);
        } else {
          showOnboardingDialog(context);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // T6 过渡态：状态层已换成 ShellState，但渲染仍是单 body 的 if 链。
    // 【判序 overlay-first】（fix round 1，R25）：ShellState.openOverlay 刻意
    // 保留 canvasId（保活语义），若判序仍 canvasId-first，浮层会被画布分支
    // 永久遮死——画布/画廊上开设置或示例页会变成死键。浮层盖住标签宿主是
    // spec 的目标语义（外层 IndexedStack 二选一：浮层槽 vs 标签宿主），
    // 本次判序调整就是提前落地这一条，不等 T7。
    // 【画布分支带 tab 判据】（fix round 2，R33）：goTab() 同样保留 canvasId
    // （标签保活语义），且 ShellState 没有任何能清 canvasId 的公共动词
    // （resetSession() 除外）。若这支只看 canvasId != null，本次会话一旦打
    // 开过画布，canvasId 就再也不会变回 null——goTab(studio) 后画面纹丝不
    // 动，整个会话回不到 Studio。canvasId 继续留着 = 画布标签保活，
    // 但只有 tab 仍是 canvas 时它才是【当前可见】标签，这与 T7 的保活宿主
    // 语义一致。
    // 外壳骨架（两级 IndexedStack + 标签条）在 T7 接上。
    final s = ref.watch(shellControllerProvider);
    final Widget body;
    if (s.overlay == ShellOverlay.settings) {
      body = const SettingsScreen();
    } else if (s.overlay == ShellOverlay.showcase) {
      body = const Scaffold(body: BuiltInShowcaseScreen());
    } else if (s.tab == ShellTab.canvas && s.canvasId != null) {
      body = const CanvasScreen(isVisible: true);
    } else if (s.tab == ShellTab.gallery && s.project != null) {
      body = Scaffold(
        body: GalleryScreen(projectId: s.project!.id, projectName: s.project!.name),
      );
    } else {
      body = const Scaffold(body: StudioHomeScreen());
    }
    return CommandPaletteShortcuts(child: body);
  }
}
