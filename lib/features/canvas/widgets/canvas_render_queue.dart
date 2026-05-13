// CanvasRenderQueue：Inspector 下方折叠面板 — 标题 + N 条进度行（mock 数据）。
//
// 本轮为视觉占位，Task 13 起接 jobQueueService 真数据。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class CanvasRenderQueue extends StatelessWidget {
  const CanvasRenderQueue({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
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
        InkSpacing.sm + 4,
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
                  style: typo.caption.copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: colors.fg3,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              Text(
                '3 · 2 ▾',
                style: typo.caption.copyWith(
                  fontFamily: 'JetBrainsMono',
                  color: colors.fg3,
                ),
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.sm + 2),
          _JobRow(name: l.canvasRenderQueueJobWatch, percent: 0.45, running: true),
          const SizedBox(height: InkSpacing.sm),
          _JobRow(name: l.canvasRenderQueueJobHarbor, percent: 0.18, running: true),
          const SizedBox(height: InkSpacing.sm),
          _JobRow(name: l.canvasRenderQueueJobNocturne, percent: 0, running: false),
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
            const SizedBox(width: InkSpacing.sm + 2),
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
                fontFamily: 'JetBrainsMono',
                color: running ? colors.fg3 : colors.fg4,
              ),
            ),
          ],
        ),
        if (running) ...<Widget>[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 3,
                color: colors.surface3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: percent.clamp(0.0, 1.0),
                    child: Container(color: colors.cta),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
