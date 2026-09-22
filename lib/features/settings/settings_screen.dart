// SettingsScreen — 设置页。
//
// 组合：ApiKeys / CustomProviders / Theme / CanvasAppearance / Language /
// Startup / StoragePath / Backup / Diagnostics / About。
// 展示由 ShellState.overlay == ShellOverlay.settings 驱动（shellControllerProvider）；
// 当前仍可由其他 slice push 进入。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/ink_tool_bar.dart';
import '../../theme/tokens.dart';
import '../shell/providers/shell_controller.dart';
import 'widgets/about_section.dart';
import 'widgets/api_keys_section.dart';
import 'widgets/backup_section.dart';
import 'widgets/canvas_appearance_section.dart';
import 'widgets/custom_providers_section.dart';
import 'widgets/diagnostics_section.dart';
import 'widgets/language_section.dart';
import 'widgets/startup_section.dart';
import 'widgets/storage_path_section.dart';
import 'widgets/theme_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    // 【Scaffold 保留】：它因为有外壳根 Scaffold 作祖先而变成 nested，
    // _isRoot 返回 false ⇒ 自动排除出 SnackBar 广播（V3b）。
    return Scaffold(
      backgroundColor: colors.surface1,
      // AppBar(56) → InkToolBar(44)（D10）：chrome 56 + 标签条 44 + AppBar 56 =
      // 156 的三层横栏在 960×600 下只剩 444 内容高，用户已拍板不可接受。
      body: Column(
        children: <Widget>[
          InkToolBar(
            // shell 浮层走 ShellState.overlay（非 Navigator），返回键手动挂。
            leading: const SettingsBackButton(),
            title: Text(
              context.l10n.settingsTitle,
              style: typo.sectionTitle.copyWith(color: colors.fg1),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(InkSpacing.lg),
        // 内容列水平居中（宽屏下贴左不美观）；列内文本仍左对齐。
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ApiKeysSection(),
                SizedBox(height: InkSpacing.xl),
                CustomProvidersSection(),
                SizedBox(height: InkSpacing.xl),
                ThemeSection(),
                SizedBox(height: InkSpacing.xl),
                CanvasAppearanceSection(),
                SizedBox(height: InkSpacing.xl),
                LanguageSection(),
                SizedBox(height: InkSpacing.xl),
                StartupSection(),
                SizedBox(height: InkSpacing.xl),
                StoragePathSection(),
                SizedBox(height: InkSpacing.xl),
                BackupSection(),
                SizedBox(height: InkSpacing.xl),
                DiagnosticsSection(),
                SizedBox(height: InkSpacing.xl),
                AboutSection(),
              ],
            ),
          ),
        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置页返回键：关闭浮层，回到原标签（独立小件方便单测，不用整页 pump——
/// 全屏 pump 受 StoragePathSection ticker 挂起坑影响，见其测试头注）。
class SettingsBackButton extends ConsumerWidget {
  const SettingsBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () =>
          ref.read(shellControllerProvider.notifier).closeOverlay(),
    );
  }
}
