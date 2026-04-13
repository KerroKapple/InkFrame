// InkErrorBanner：错误横幅骨架。消费 InkError.messageKey（由调用方解析 i18n 后传入）。
import 'package:flutter/widgets.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkErrorBanner extends StatelessWidget {
  const InkErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Semantics(
      liveRegion: true,
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface2,
          border: Border.all(color: colors.danger, width: 1),
          borderRadius: BorderRadius.circular(InkRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.md),
          child: DefaultTextStyle(
            style: context.inkTypography.body.copyWith(color: colors.danger),
            child: Text(message),
          ),
        ),
      ),
    );
  }
}
