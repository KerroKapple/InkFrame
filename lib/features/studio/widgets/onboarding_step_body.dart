// 首启向导每一步共用的正文外壳：标题 17 → 说明 12 → 内容，内边距 24 / 24 / 20。
//
// 从 onboarding_dialog.dart 拆出来：那边连这一步有 986 行，是仓库第 4 长的文件。
// 三步共用这一层壳，拆开后向导本体只剩「哪一步 + 怎么走」。

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
/// 每一步共用的正文外壳：标题 17 → 说明 12 → 内容，内边距 24 / 24 / 20。
class OnboardingStepBody extends StatelessWidget {
  const OnboardingStepBody({
    super.key,
    required this.title,
    this.description,
    this.child,
  });

  final String title;
  final String? description;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.lg,
        InkSpacing.lg,
        InkSpacing.lg,
        InkSpacing.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: t.dialogTitle.copyWith(color: c.fg1)),
          if (description != null) ...<Widget>[
            const SizedBox(height: InkSpacing.sm),
            Text(description!, style: t.body.copyWith(color: c.fg4)),
          ],
          if (child != null) ...<Widget>[
            const SizedBox(height: InkSpacing.md),
            child!,
          ],
        ],
      ),
    );
  }
}

