// SettingsScreen — 设置页。
//
// 组合：ApiKeys / Theme / Canvas / Language / Storage / About 六个 section。
// 路由展示由 inkframe-dev 在 core/di/currentScreenProvider 落地后接管；当前
// 仍可由其他 slice push 进入。

import 'package:flutter/material.dart';

import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'widgets/about_section.dart';
import 'widgets/api_keys_section.dart';
import 'widgets/canvas_appearance_section.dart';
import 'widgets/language_section.dart';
import 'widgets/storage_path_section.dart';
import 'widgets/theme_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Scaffold(
      backgroundColor: colors.surface1,
      appBar: AppBar(
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
                AboutSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
