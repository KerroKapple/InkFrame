// InspectorStatusPanel：image/video Inspector 共用的四态生成视图。
//
// 四态：idle / submitting / running(progress?) / error(code)。
// idle 渲染 Generate 按钮（带 disabled 原因 tooltip），其它三态接管按钮位置
// 显示进度 / 错误 + Retry。
//
// JobState 绑定点（agent-generation slice 落地后接线）：
//   - features/generation/models/job_state.dart 提供 freezed JobState 后，
//     ImageConfigInspector / VideoConfigInspector 应改为
//     `ref.watch(jobStateProvider(nodeId))` 直接得到状态流，
//     再 `.map(...)` 转成本文件的 InspectorJobView。
//   - 本 sealed class 是临时 view-model，落地后可整体删除并由 JobState 替代。

import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

sealed class InspectorJobView {
  const InspectorJobView();
}

class InspectorJobIdle extends InspectorJobView {
  const InspectorJobIdle();
}

class InspectorJobSubmitting extends InspectorJobView {
  const InspectorJobSubmitting();
}

class InspectorJobRunning extends InspectorJobView {
  const InspectorJobRunning({this.progress});

  /// [0.0, 1.0]；为 null 时渲染 indeterminate 进度条。
  final double? progress;
}

class InspectorJobError extends InspectorJobView {
  const InspectorJobError({required this.code});

  /// 错误码标识（如 InkErrorCode.name 或 'unknown'）。
  /// 详细描述由 l10n 层映射，本字段保留可观测原始码方便排查。
  final String code;
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

  final InspectorJobView view;
  final String generateLabel;
  final bool canSubmit;
  final VoidCallback onSubmit;

  /// idle 态按钮 disabled 时的 tooltip；canSubmit=true 则忽略。
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return switch (view) {
      InspectorJobIdle() => _IdleButton(
          label: generateLabel,
          canSubmit: canSubmit,
          disabledReason: disabledReason,
          onPressed: onSubmit,
        ),
      InspectorJobSubmitting() => _ProgressRow(
          label: context.l10n.inspectorStatusSubmitting,
        ),
      InspectorJobRunning(progress: final p) => _RunningPanel(progress: p),
      InspectorJobError(code: final code) => _ErrorPanel(
          code: code,
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
  const _ErrorPanel({required this.code, required this.onRetry});
  final String code;
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
                      code,
                      style: typo.caption.copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: colors.fg3,
                      ),
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
