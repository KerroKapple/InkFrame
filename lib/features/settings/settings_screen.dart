// SettingsScreen — 设置页。
//
// 组合：ApiKeys / Theme / Canvas / Language / Storage / About 六个 section。
// 路由展示由 inkframe-dev 在 core/di/currentScreenProvider 落地后接管；当前
// 仍可由其他 slice push 进入。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/current_screen.dart';
import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'widgets/about_section.dart';
import 'widgets/api_keys_section.dart';
import 'widgets/backup_section.dart';
import 'widgets/canvas_appearance_section.dart';
import 'widgets/diagnostics_section.dart';
import 'widgets/language_section.dart';
import 'widgets/storage_path_section.dart';
import 'widgets/theme_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    return Scaffold(
      backgroundColor: colors.surface1,
      appBar: AppBar(
        // shell 路由走 currentScreenProvider（非 Navigator），返回键手动挂。
        leading: const SettingsBackButton(),
        title: Text(context.l10n.settingsTitle),
      ),
      body: SingleChildScrollView(
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
                ThemeSection(),
                SizedBox(height: InkSpacing.xl),
                CanvasAppearanceSection(),
                SizedBox(height: InkSpacing.xl),
                LanguageSection(),
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
    );
  }
}

/// 设置页返回键：shell 路由回 studio（独立小件方便单测，不用整页 pump——
/// 全屏 pump 受 StoragePathSection ticker 挂起坑影响，见其测试头注）。
class SettingsBackButton extends ConsumerWidget {
  const SettingsBackButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () =>
          ref.read(currentScreenProvider.notifier).state = AppScreen.studio,
    );
  }
}
