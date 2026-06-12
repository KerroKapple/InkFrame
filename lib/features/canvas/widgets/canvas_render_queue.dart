// CanvasRenderQueue：Inspector 下方折叠面板 — 标题 + 当前画布活跃任务进度行。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_progress_bar.dart';
import '../../../theme/tokens.dart';
import '../../generation/models/job_state.dart';
import '../../generation/providers/jobs_registry.dart';
import '../providers/current_canvas_id.dart';

class CanvasRenderQueue extends ConsumerWidget {
  const CanvasRenderQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;

    final canvasId = ref.watch(currentCanvasIdProvider);
    final jobs = canvasId == null
        ? const <JobState>[]
        : ref
            .watch(jobsRegistryProvider)
            .where((s) => s.canvasId == canvasId && !s.isTerminal)
            .toList();
    final running = jobs.whereType<JobRunning>().length;

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
                '$running · ${jobs.length} ▾',
                style: typo.caption.copyWith(color: colors.fg3),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s10),
          if (jobs.isEmpty)
            Text(
              l.canvasRenderQueueEmpty,
              style: typo.caption.copyWith(color: colors.fg4),
            )
          else
            for (final job in jobs) ...<Widget>[
              _JobRow(
                name: job.jobId,
                percent: job.progressValue,
                running: job is JobRunning,
              ),
              const SizedBox(height: InkSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.name,
    required this.percent,
    required this.running,
  });

  final String name;
  final double percent; // 0..1
  final bool running;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
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
}
