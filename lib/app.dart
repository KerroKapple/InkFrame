// InkFrameApp：MaterialApp 装配 + 顶层路由。
//
// - 主题走 ThemeModeController（dark/light/highContrast + textScale）
// - 平台亮度变化通过 StatefulWidget 生命周期订阅并转发给 controller
// - i18n delegates 走生成的 AppLocalizations；locale 来自 LocaleController
// - ScaffoldMessenger 走全局 toastMessengerKeyProvider，便于 ToastService 跨 context 提示
// - 锁屏后路由：currentCanvasId 优先；否则按 currentScreenProvider 在 Studio / Settings 切换
// - 新增节点 FAB 已下沉到 CanvasScreen 内部，本文件不再托管

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/current_screen.dart';
import 'core/di/locale.dart';
import 'core/di/secure_storage.dart';
import 'core/di/theme.dart';
import 'features/canvas/providers/current_canvas_id.dart';
import 'features/canvas/widgets/canvas_screen.dart';
import 'features/generation/services/toast_service.dart';
import 'features/lock/lock_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/studio/studio_home_screen.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/l10n_x.dart';
import 'theme/app_theme.dart';
import 'theme/components/ink_window_chrome.dart';

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
    final locale = ref.watch(localeControllerProvider);
    final messengerKey = ref.watch(toastMessengerKeyProvider);
    return MaterialApp(
      title: 'InkFrame',
      theme: buildAppTheme(
        variant: themeState.variant,
        textScale: themeState.textScale,
      ),
      locale: locale,
      scaffoldMessengerKey: messengerKey,
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
      body: const Column(
        children: <Widget>[
          InkWindowChrome(),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _UnlockedShell extends ConsumerWidget {
  const _UnlockedShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId != null) {
      return CanvasScreen(canvasName: context.l10n.appTitle);
    }
    final screen = ref.watch(currentScreenProvider);
    return switch (screen) {
      AppScreen.studio => const Scaffold(body: StudioHomeScreen()),
      AppScreen.settings => const SettingsScreen(),
    };
  }
}
