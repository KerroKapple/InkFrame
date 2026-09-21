// InkFrameApp：MaterialApp 装配 + 顶层路由。
//
// - 主题走 ThemeModeController（dark/light/highContrast + textScale）
// - 平台亮度变化通过 StatefulWidget 生命周期订阅并转发给 controller
// - i18n delegates 走生成的 AppLocalizations；locale 来自 LocaleController
// - ScaffoldMessenger 走全局 toastMessengerKeyProvider，便于 ToastService 跨 context 提示
// - 解锁后不再有"路由"：body 恒为 InkShell（持久标签外壳），哪个 surface 在台上
//   由 ShellContentStack 的两级 IndexedStack 依 ShellState 决定，本文件零判据
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
import 'features/command_palette/widgets/command_palette_shortcuts.dart';
import 'features/generation/services/toast_service.dart';
import 'features/shell/widgets/ink_shell.dart';
import 'features/startup/widgets/startup_error_view.dart';
import 'features/studio/providers/restore_last_session.dart';
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

  // T6 的 if 链已在 T7 退役：渲染全部交给 InkShell（唯一根 Scaffold + 唯一
  // chrome + 持久标签条 + 两级 IndexedStack）。本文件不再持有任何路由判据——
  // "哪个 surface 在台上"这件事只在 ShellContentStack 一处决定。
  //
  // CommandPaletteShortcuts 必须留在 InkShell【之上】：ShellContentStack 的
  // _shellFocus 在切换时无条件夺焦，若 ⌘K 绑定在它之下会被一并抢走。
  @override
  Widget build(BuildContext context) =>
      const CommandPaletteShortcuts(child: InkShell());
}
