// SettingsScreen — 用户设置页。
//
// S2b 只落地 ApiKeysSection；后续 sprint 陆续添加主题 / 网络代理 / 日志级别
// / 生成默认参数等分节。

import 'package:flutter/material.dart';

import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import 'widgets/api_keys_section.dart';

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const ApiKeysSection(),
        ),
      ),
    );
  }
}
