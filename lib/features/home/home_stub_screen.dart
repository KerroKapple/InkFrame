// T1 阶段首屏占位：纯空 Scaffold，仅验证主题+i18n 装配正常。
// T4+ 将替换为真正的项目列表页。
import 'package:flutter/material.dart';

import '../../l10n/l10n_x.dart';
import '../../theme/app_theme.dart';

class HomeStubScreen extends StatelessWidget {
  const HomeStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Scaffold(
      backgroundColor: colors.surface1,
      body: Center(
        child: DefaultTextStyle(
          style: context.inkTypography.display.copyWith(color: colors.fg1),
          child: Text(context.l10n.appTitle),
        ),
      ),
    );
  }
}
