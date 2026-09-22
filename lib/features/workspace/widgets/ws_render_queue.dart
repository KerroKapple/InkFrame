// 渲染队列 172px：三标签 + 右侧并发/清除 | 24px 表头 | 28px 行。列宽 28 220 110 1fr 90 120 60，间距 12。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';
import '../../../theme/components/ws_primitives.dart';
import 'ws_tone.dart';

class WsRenderQueue extends StatelessWidget {
  const WsRenderQueue({super.key});

  /// 稿是 content-box：height 172 + border-top 1。
  static const double height = 173;
  static const List<double?> _columns = <double?>[28, 220, 110, null, 90, 120, 60];

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(top: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WsPanelTabs(
            tabs: WorkspaceFixture.queueTabs,
            badge: WorkspaceFixture.queueCount,
            trailing: Padding(
              padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
              child: Row(
                children: <Widget>[
                  Text(WorkspaceFixture.concurrency, style: t.meta.copyWith(color: c.fg5)),
                  const SizedBox(width: InkSpacing.s14),
                  Text(WorkspaceFixture.clearDone, style: t.meta.copyWith(color: c.fg5)),
                ],
              ),
            ),
          ),
          Container(
            height: 25, // content 24 + border-bottom 1
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
            child: _GridRow(
              cells: <Widget>[
                for (final String h in WorkspaceFixture.queueHeaders) Text(h, style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
          for (final WsJob j in WorkspaceFixture.jobs) _JobRow(job: j),
        ],
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < cells.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: InkSpacing.s12),
            if (WsRenderQueue._columns[i] == null)
              Expanded(child: cells[i])
            else
              SizedBox(width: WsRenderQueue._columns[i], child: cells[i]),
          ],
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job});
  final WsJob job;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final bool running = job.tone == WsTone.accent;
    return Container(
      height: 29, // content 28 + border-bottom 1
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.surface1))),
      child: _GridRow(
        cells: <Widget>[
          Text(job.idx, style: t.monoSmall.copyWith(color: c.fg6)),
          Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg2)),
          Text(job.kind, style: t.body.copyWith(color: c.fg4)),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(color: c.control, borderRadius: BorderRadius.circular(InkRadius.xs)),
                  clipBehavior: Clip.antiAlias,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: job.fraction,
                    child: ColoredBox(color: running || job.fraction < 1 ? c.accent : c.fg6),
                  ),
                ),
              ),
              const SizedBox(width: InkSpacing.s10),
              SizedBox(width: 64, child: Text(job.status, style: t.meta.copyWith(color: job.tone.fg(c)))),
            ],
          ),
          Text(job.time, style: t.mono.copyWith(color: c.fg4)),
          Text(job.model, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg4)),
          Text(job.action, style: t.meta.copyWith(color: c.fg5)),
        ],
      ),
    );
  }
}
