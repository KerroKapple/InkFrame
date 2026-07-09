// CanvasRenderQueue：Inspector 下方折叠面板 —
// 标题 + 当前画布活跃任务进度行（带取消） + 最近失败区（本地化错误文案）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/job_queue.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_progress_bar.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../providers/current_canvas_id.dart';

class CanvasRenderQueue extends ConsumerWidget {
  const CanvasRenderQueue({super.key});

  // 最近失败区展示条数上限——取插入序最新 N 条，防止长会话堆积。
  static const int _kMaxRecentFailures = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;

    final canvasId = ref.watch(currentCanvasIdProvider);
    final scoped = canvasId == null
        ? const <JobState>[]
        : ref
            .watch(jobsRegistryProvider)
            .where((s) => s.canvasId == canvasId)
            .toList();
    final active = scoped.where((s) => !s.isTerminal).toList();
    final failures = scoped.whereType<JobFailed>().toList();
    final recentFailures = failures.length <= _kMaxRecentFailures
        ? failures
        : failures.sublist(failures.length - _kMaxRecentFailures);
    final running = active.whereType<JobRunning>().length;
    final displayNames = ref.watch(providerDisplayNamesProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(
          left: BorderSide(color: colors.borderSubtle),
          top: BorderSide(color: colors.borderSubtle),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.md,
        InkSpacing.s12,
        InkSpacing.md,
        InkSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l.canvasRenderQueue.toUpperCase(),
                  style: typo.overline.copyWith(color: colors.fg3),
                ),
              ),
              Text(
                '$running · ${active.length} ▾',
                style: typo.caption.copyWith(color: colors.fg3),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s10),
          if (active.isEmpty)
            Text(
              l.canvasRenderQueueEmpty,
              style: typo.caption.copyWith(color: colors.fg4),
            )
          else
            for (final job in active) ...<Widget>[
              _JobRow(
                job: job,
                // 行标题用 provider displayName（与 Inspector 下拉一致），
                // 不暴露 jobId(UUID) 给用户。
                name: displayNames[job.providerId] ?? job.providerId,
              ),
              const SizedBox(height: InkSpacing.sm),
            ],
          if (recentFailures.isNotEmpty) ...<Widget>[
            const SizedBox(height: InkSpacing.s12),
            Text(
              l.canvasRenderQueueFailures.toUpperCase(),
              style: typo.overline.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.s10),
            for (final job in recentFailures) ...<Widget>[
              _FailedRow(
                name: displayNames[job.providerId] ?? job.providerId,
                error: job.error,
              ),
              const SizedBox(height: InkSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job, required this.name});

  final JobState job;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final running = job is JobRunning;
    final percent = job.progressValue; // 0..1
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: running ? colors.cta : colors.fg4,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: InkSpacing.s10),
            Expanded(
              child: Text(
                name,
                style: typo.body.copyWith(color: colors.fg1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              running
                  ? '${(percent * 100).round()}%'
                  : context.l10n.canvasRenderQueueStatusQueued,
              style: typo.caption.copyWith(
                color: running ? colors.fg3 : colors.fg4,
              ),
            ),
            if (job.isCancellable) ...<Widget>[
              const SizedBox(width: InkSpacing.sm),
              _CancelButton(onCancel: () => _cancel(ref, job.jobId)),
            ],
          ],
        ),
        if (running) ...<Widget>[
          const SizedBox(height: InkSpacing.xs),
          Padding(
            // 与状态点（8px）+ 间隙（10px）对齐
            padding: const EdgeInsets.only(left: InkSpacing.s18),
            child: InkProgressBar(value: percent),
          ),
        ],
      ],
    );
  }

  // 取消链路复用核心服务：拿到 JobQueueService 后委托 cancel（idempotent）。
  Future<void> _cancel(WidgetRef ref, String jobId) async {
    final queue = await ref.read(jobQueueServiceProvider.future);
    await queue.cancel(jobId);
  }
}

/// 单任务取消控件：小号 icon 按钮，tap 区 ≥ InkSpacing.xxl（48，Material 最小可交互）。
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return IconButton(
      tooltip: context.l10n.canvasRenderQueueCancel,
      onPressed: onCancel,
      icon: const Icon(Icons.close),
      iconSize: InkSpacing.md,
      color: colors.fg3,
      hoverColor: colors.surface3,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(
        minWidth: InkSpacing.xxl,
        minHeight: InkSpacing.xxl,
      ),
    );
  }
}

/// 最近失败行：provider 名 + 本地化错误文案（走统一的 l10nError）。
class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.name, required this.error});

  final String name;
  final InkError error;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.error_outline, size: InkSpacing.md, color: colors.danger),
            const SizedBox(width: InkSpacing.s10),
            Expanded(
              child: Text(
                name,
                style: typo.body.copyWith(color: colors.fg2),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.xs),
        Padding(
          // 与错误图标（16px）+ 间隙（10px）对齐
          padding: const EdgeInsets.only(left: InkSpacing.s28),
          child: Text(
            l10nError(context, error),
            style: typo.caption.copyWith(color: colors.danger),
          ),
        ),
      ],
    );
  }
}
