// 未配置生成 provider 时的警告横幅：warning 左条 + 提示文案 + 配置入口 + 可选关闭。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class StudioProviderBanner extends StatelessWidget {
  const StudioProviderBanner({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.onDismiss,
    this.dismissTooltip = 'Dismiss',
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;
  final String dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface2,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(InkRadius.md),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(InkRadius.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 3, color: colors.warning),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InkSpacing.md,
                      vertical: InkSpacing.sm + 2,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(
                            right: InkSpacing.sm + 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            message,
                            style: typo.body.copyWith(color: colors.fg2),
                          ),
                        ),
                        const SizedBox(width: InkSpacing.md),
                        GestureDetector(
                          onTap: onAction,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            actionLabel,
                            style: typo.caption.copyWith(
                              color: colors.accent,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        if (onDismiss != null) ...<Widget>[
                          const SizedBox(width: InkSpacing.sm),
                          Tooltip(
                            message: dismissTooltip,
                            child: GestureDetector(
                              onTap: onDismiss,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: colors.fg3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
