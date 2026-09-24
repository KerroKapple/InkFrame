// 项目面板 240px：三标签（画布 / 资产 / 角色）| 22px 筛选 | 画布树（26 行）| 当前画布节点（24 行）。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';
import '../../../theme/components/ws_primitives.dart';

class WsProjectPanel extends StatelessWidget {
  const WsProjectPanel({super.key});

  /// 稿是 content-box：width 240 + border-right 1。
  static const double width = 241;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WsPanelTabs(tabs: WorkspaceFixture.projectTabs, trailing: WsPanelMenuGlyph()),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.sm, InkSpacing.sm, InkSpacing.sm, InkSpacing.xs),
            child: WsUnderlineField(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(WorkspaceFixture.filterPlaceholder, style: t.body.copyWith(color: c.fg6)),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: InkSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final WsCanvasEntry e in WorkspaceFixture.canvases) _CanvasRow(entry: e),
                  Container(height: 1, margin: const EdgeInsets.symmetric(vertical: InkSpacing.s6), color: c.borderStrong),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s6, InkSpacing.s12, InkSpacing.xs),
                    child: Text(WorkspaceFixture.nodesHeading, style: t.meta.copyWith(color: c.fg6)),
                  ),
                  for (final WsNodeEntry n in WorkspaceFixture.nodeList) _NodeRow(entry: n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasRow extends StatelessWidget {
  const _CanvasRow({required this.entry});
  final WsCanvasEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 26,
      padding: const EdgeInsets.only(left: InkSpacing.s12, right: InkSpacing.s10),
      color: entry.selected ? c.surface5 : null,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 8,
            child: Text(entry.expanded ? '▾' : '▸', style: t.micro.copyWith(color: c.fg6)),
          ),
          const SizedBox(width: InkSpacing.sm),
          // 稿是 content-box：14×10 + 1px 边 ⇒ 16×12。
          Container(
            width: 16,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: c.fg6),
              borderRadius: BorderRadius.circular(InkRadius.s1),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: entry.selected ? c.fg1 : c.fg3),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          Text(entry.count, style: t.monoSmall.copyWith(color: c.fg6)),
        ],
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.entry});
  final WsNodeEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: InkSpacing.s28, right: InkSpacing.s10),
      color: entry.selected ? c.surface5 : null,
      child: Row(
        children: <Widget>[
          WsSquareDot(size: 6, color: entry.selected ? c.accent : c.fg5),
          const SizedBox(width: InkSpacing.sm),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.body.copyWith(color: entry.selected ? c.fg1 : c.fg3),
            ),
          ),
          const SizedBox(width: InkSpacing.sm),
          Text(entry.kind, style: t.micro.copyWith(color: c.fg6)),
        ],
      ),
    );
  }
}
