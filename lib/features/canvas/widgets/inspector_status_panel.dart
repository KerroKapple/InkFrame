// InspectorStatusPanel：image/video Inspector 共用的四态生成视图。
//
// 直接消费 InspectorSubmitController 的 sealed 状态：
//   idle 渲染 Generate 按钮（带 disabled 原因 tooltip），其它三态接管按钮位置
//   显示进度 / 本地化错误 + Retry。错误文案在本文件统一映射 ARB——
//   原始错误结构留在 InspectorSubmitError，UI 绝不直出 toString / 枚举名。
//
// InspectorStatusBinding：再包一层 hasApiKey（FutureProvider 缓存）+
// disabled 原因分层（就近原则：prompt 空 / 无 API Key），两个 Inspector 复用。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/inspector_submit_controller.dart';

/// InspectorSubmitError → 用户可读文案。exhaustive switch，新错误类型漏映射编译期报错。
String inspectorSubmitErrorText(BuildContext context, InspectorSubmitError e) {
  final l = context.l10n;
  return switch (e) {
    InspectorMissingApiKey() => l.generationMissingKey,
    InspectorInvalidConfig(reason: final r) => l.generationInvalidConfig(r),
    InspectorProviderNotRegistered() => l.generationProviderNotRegistered,
    InspectorInkFailure(error: final err) => l10nError(context, err),
  };
}

/// hasApiKey 解析 + disabled 原因分层，再委托 InspectorStatusPanel。
/// image / video Inspector 复用。
class InspectorStatusBinding extends ConsumerWidget {
  const InspectorStatusBinding({
    super.key,
    required this.nodeId,
    required this.providerId,
    required this.promptEmpty,
    required this.generateLabel,
    required this.disabledEmptyPromptText,
    required this.disabledNoKeyText,
    required this.onSubmit,
  });

  final String nodeId;
  final String? providerId;
  final bool promptEmpty;
  final String generateLabel;
  final String disabledEmptyPromptText;
  final String disabledNoKeyText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inspectorSubmitControllerProvider(nodeId));
    final pid = providerId;
    final hasKey = pid != null &&
        (ref.watch(inspectorHasApiKeyProvider(pid)).valueOrNull ?? false);

    String? disabledReason;
    if (promptEmpty) {
      disabledReason = disabledEmptyPromptText;
    } else if (!hasKey) {
      disabledReason = disabledNoKeyText;
    }
    return InspectorStatusPanel(
      view: state,
      generateLabel: generateLabel,
      canSubmit: !promptEmpty && hasKey,
      disabledReason: disabledReason,
      onSubmit: onSubmit,
    );
  }
}

class InspectorStatusPanel extends StatelessWidget {
  const InspectorStatusPanel({
    super.key,
    required this.view,
    required this.generateLabel,
    required this.canSubmit,
    required this.onSubmit,
    this.disabledReason,
  });

  final InspectorSubmitState view;
  final String generateLabel;
  final bool canSubmit;
  final VoidCallback onSubmit;

  /// idle 态按钮 disabled 时的 tooltip；canSubmit=true 则忽略。
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      InspectorSubmitIdle() => _IdleButton(
          label: generateLabel,
          canSubmit: canSubmit,
          disabledReason: disabledReason,
          onPressed: onSubmit,
        ),
      InspectorSubmitSubmitting() => _ProgressRow(
          label: context.l10n.inspectorStatusSubmitting,
        ),
      InspectorSubmitRunning(progress: final p) => _RunningPanel(progress: p),
      InspectorSubmitFailure(error: final e) => _ErrorPanel(
          message: inspectorSubmitErrorText(context, e),
          onRetry: onSubmit,
        ),
    };
  }
}

class _IdleButton extends StatelessWidget {
  const _IdleButton({
    required this.label,
    required this.canSubmit,
    required this.disabledReason,
    required this.onPressed,
  });

  final String label;
  final bool canSubmit;
  final String? disabledReason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: canSubmit ? onPressed : null,
      child: Text(label),
    );
    if (!canSubmit && disabledReason != null) {
      return Tooltip(message: disabledReason!, child: button);
    }
    return button;
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: InkSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: typo.body.copyWith(color: colors.fg2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RunningPanel extends StatelessWidget {
  const _RunningPanel({required this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final p = progress;
    final label = p == null
        ? context.l10n.inspectorStatusRunning
        : context.l10n.inspectorStatusRunningWithProgress((p * 100).round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(InkRadius.sm),
          child: LinearProgressIndicator(
            value: p?.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: colors.surface3,
          ),
        ),
        const SizedBox(height: InkSpacing.xs),
        Text(label, style: typo.caption.copyWith(color: colors.fg3)),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  /// 已本地化的错误描述（inspectorSubmitErrorText 产出）。
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(InkSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(InkRadius.sm),
            border: Border.all(color: colors.danger),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 16, color: colors.danger),
              const SizedBox(width: InkSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.inspectorStatusErrorTitle,
                      style: typo.body.copyWith(color: colors.fg1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: typo.caption.copyWith(color: colors.fg3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: InkSpacing.sm),
        FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(context.l10n.inspectorRetry),
        ),
      ],
    );
  }
}
