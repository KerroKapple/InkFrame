// 外壳空态：四处复用（画布未打开 / 画廊未选项目 / 序列 / 导出）。
// 视觉语汇沿用画廊空态：72 圆形 surface3 底 + 图标 + 标题 + 可选副标题 + 可选 CTA。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_ghost_button.dart';
import '../../../theme/tokens.dart';

class ShellEmptyState extends StatelessWidget {
  const ShellEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.ctaLabel,
    this.onCta,
    this.ctaTooltip,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? ctaLabel;

  /// null ⇒ CTA 渲染为禁用态（仍然可见，用户看得到"为什么不能点"）。
  final VoidCallback? onCta;
  final String? ctaTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final Widget? cta = ctaLabel == null
        ? null
        : InkGhostButton(label: ctaLabel!, icon: icon, onPressed: onCta);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surface3,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Icon(icon, size: 32, color: colors.accent),
            ),
            const SizedBox(height: InkSpacing.lg),
            Text(
              title,
              style: typo.dialogTitle.copyWith(color: colors.fg1),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: InkSpacing.sm),
              Text(
                body!,
                style: typo.body.copyWith(color: colors.fg3),
                textAlign: TextAlign.center,
              ),
            ],
            if (cta != null) ...<Widget>[
              const SizedBox(height: InkSpacing.lg),
              ctaTooltip == null
                  ? cta
                  : Tooltip(message: ctaTooltip!, child: cta),
            ],
          ],
        ),
      ),
    );
  }
}
