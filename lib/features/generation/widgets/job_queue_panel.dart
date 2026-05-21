// JobQueuePanel：右侧抽屉风格的渲染队列面板。
//
// 四态：
//   - empty：列表空 → 占位文案
//   - active：含 queued/submitting/running，进度条 + 取消按钮
//   - failed：失败条目，错误文案 + 重试按钮（若 InkError.retryable）
//   - succeeded/cancelled：终态条目，仅显示状态 + 移除
//
// 状态源：[jobsRegistryProvider]。取消委托给 JobQueueService（核心服务）。
// 重试由 generation controller 处理——本 widget 只发信号 (onRetry 回调)。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/job_queue.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/job_state.dart';
import '../providers/jobs_registry.dart';

typedef JobRetryCallback = void Function(String jobId);

class JobQueuePanel extends ConsumerWidget {
  const JobQueuePanel({
    super.key,
    this.width = 320,
    this.onRetry,
  });

  /// 面板宽度（侧抽屉）。
  final double width;

  /// 重试回调——controller 在外层注入。null 时重试按钮 disabled。
  final JobRetryCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final jobs = ref.watch(jobsRegistryProvider);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border(left: BorderSide(color: colors.borderSubtle)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PanelHeader(jobs: jobs),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: jobs.isEmpty
                  ? const _EmptyState()
                  : _JobList(jobs: jobs, onRetry: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends ConsumerWidget {
  const _PanelHeader({required this.jobs});
  final List<JobState> jobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final activeCount = jobs.where((e) => e.isActive).length;
    final hasTerminated = jobs.any((e) => e.isTerminal);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.md,
        InkSpacing.md,
        InkSpacing.sm,
        InkSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l.generationQueueTitle.toUpperCase(),
                  style: typo.caption.copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: colors.fg3,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.generationCountActive(activeCount),
                  style: typo.body.copyWith(color: colors.fg2),
                ),
              ],
            ),
          ),
          if (hasTerminated)
            IconButton(
              tooltip: l.generationQueueClearTerminated,
              icon: const Icon(Icons.cleaning_services_outlined),
              iconSize: 18,
              color: colors.fg3,
              onPressed: () =>
                  ref.read(jobsRegistryProvider.notifier).clearTerminated(),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.lg),
        child: Text(
          context.l10n.generationQueueEmpty,
          style: typo.body.copyWith(color: colors.fg3),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({required this.jobs, required this.onRetry});
  final List<JobState> jobs;
  final JobRetryCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: InkSpacing.md,
        vertical: InkSpacing.sm,
      ),
      itemCount: jobs.length,
      separatorBuilder: (BuildContext _, int _) =>
          const SizedBox(height: InkSpacing.sm),
      itemBuilder: (context, i) =>
          _JobRow(key: ValueKey(jobs[i].jobId), job: jobs[i], onRetry: onRetry),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({super.key, required this.job, required this.onRetry});

  final JobState job;
  final JobRetryCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(InkRadius.md),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(InkSpacing.sm + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                _StatusDot(job: job),
                const SizedBox(width: InkSpacing.sm),
                Expanded(
                  child: Text(
                    job.providerId,
                    style: typo.body.copyWith(color: colors.fg1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _statusLabel(context, job),
                  style: typo.caption.copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: _statusColor(context, job),
                  ),
                ),
              ],
            ),
            if (job is JobRunning ||
                job is JobQueued ||
                job is JobSubmitting) ...<Widget>[
              const SizedBox(height: InkSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: job is JobRunning ? job.progressValue : null,
                    backgroundColor: colors.surface3,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.cta),
                  ),
                ),
              ),
            ],
            if (job case final JobFailed failed) ...<Widget>[
              const SizedBox(height: InkSpacing.sm),
              Text(
                _errorMessage(context, failed),
                style: typo.caption.copyWith(color: colors.danger),
              ),
            ],
            const SizedBox(height: InkSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _actions(context, ref, job),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, JobState job) {
    final l = context.l10n;
    final widgets = <Widget>[];
    if (job.isCancellable) {
      widgets.add(
        TextButton(
          onPressed: () => _cancel(ref, job.jobId),
          child: Text(l.generationQueueCancel),
        ),
      );
    }
    if (job.isRetryable && onRetry != null) {
      widgets.add(
        TextButton(
          onPressed: () => onRetry!(job.jobId),
          child: Text(l.generationQueueRetry),
        ),
      );
    }
    if (job.isTerminal) {
      widgets.add(
        TextButton(
          onPressed: () =>
              ref.read(jobsRegistryProvider.notifier).remove(job.jobId),
          child: Text(l.generationQueueRemove),
        ),
      );
    }
    return widgets;
  }

  void _cancel(WidgetRef ref, String jobId) {
    final queue = ref.read(jobQueueServiceProvider);
    queue.cancel(jobId);
  }

  String _statusLabel(BuildContext context, JobState job) {
    final l = context.l10n;
    return switch (job) {
      JobQueued() => l.generationStatusQueued,
      JobSubmitting() => l.generationStatusSubmitting,
      JobRunning(:final progress) =>
        '${l.generationStatusRunning} ${(progress.clamp(0.0, 1.0) * 100).round()}%',
      JobSucceeded() => l.generationStatusSucceeded,
      JobFailed() => l.generationStatusFailed,
      JobCancelled() => l.generationStatusCancelled,
    };
  }

  Color _statusColor(BuildContext context, JobState job) {
    final colors = context.inkColors;
    return switch (job) {
      JobSucceeded() => colors.success,
      JobFailed() => colors.danger,
      JobCancelled() => colors.fg4,
      _ => colors.fg3,
    };
  }

  String _errorMessage(BuildContext context, JobFailed job) {
    final l = context.l10n;
    final key = job.error.messageKey;
    // ARB → 字符串：messageKey 与 InkErrorCode 一一映射，直接 switch。
    return switch (key) {
      'errorInvalidKey' => l.errorInvalidKey,
      'errorInsufficientBalance' => l.errorInsufficientBalance,
      'errorContentPolicy' => l.errorContentPolicy,
      'errorInvalidParameter' => l.errorInvalidParameter,
      'errorNetworkTimeout' => l.errorNetworkTimeout,
      'errorNetworkOffline' => l.errorNetworkOffline,
      'errorProviderServer' => l.errorProviderServer,
      'errorProviderBusy' => l.errorProviderBusy,
      'errorPollTimeout' => l.errorPollTimeout,
      'errorDownloadFailed' => l.errorDownloadFailed,
      'errorLocalIO' => l.errorLocalIO,
      'errorCancelled' => l.errorCancelled,
      'errorCancelledOnExit' => l.errorCancelledOnExit,
      _ => l.errorUnknown,
    };
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.job});
  final JobState job;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final Color dotColor = switch (job) {
      JobQueued() => colors.fg4,
      JobSubmitting() => colors.cta,
      JobRunning() => colors.cta,
      JobSucceeded() => colors.success,
      JobFailed() => colors.danger,
      JobCancelled() => colors.fg4,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    );
  }
}
