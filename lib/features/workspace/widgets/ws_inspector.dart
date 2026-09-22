// 检查器 300px：三标签 | 选中节点摘要 | 三个可折叠分组（26px 标题行，96|1fr 两列，行高 26）| 底部操作条。
import 'package:flutter/widgets.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/workspace_fixture.dart';
import 'ws_primitives.dart';

class WsInspector extends StatelessWidget {
  const WsInspector({super.key});

  /// 稿是 content-box：width 300 + border-left 1。
  static const double width = 301;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(left: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WsPanelTabs(tabs: WorkspaceFixture.inspectorTabs, trailing: WsPanelMenuGlyph()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s12, InkSpacing.s12, InkSpacing.s10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
                  child: Row(
                    children: <Widget>[
                      WsSquareDot(size: 8, color: c.accent),
                      const SizedBox(width: InkSpacing.s10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(WorkspaceFixture.inspectorNodeName, style: t.bodyStrong.copyWith(color: c.fg1)),
                            const SizedBox(height: InkSpacing.s2),
                            Text(WorkspaceFixture.inspectorNodeMeta, style: t.meta.copyWith(color: c.fg5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (final WsInspectorGroup g in WorkspaceFixture.groups) _Group(group: g),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12, vertical: InkSpacing.s10),
            decoration: BoxDecoration(
              color: c.surface2,
              border: Border(top: BorderSide(color: c.borderStrong)),
            ),
            child: Row(
              children: <Widget>[
                const WsSecondaryButton(WorkspaceFixture.reset, height: 26),
                const Spacer(),
                Text(WorkspaceFixture.inspectorHint, style: t.meta.copyWith(color: c.fg6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group});
  final WsInspectorGroup group;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderStrong))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
            child: Row(
              children: <Widget>[
                Text('▼', style: t.micro.copyWith(color: c.fg5)),
                const SizedBox(width: InkSpacing.s6),
                Text(group.title, style: t.bodyStrong.copyWith(color: c.fg3)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
            child: Column(
              children: <Widget>[for (final WsInspectorRow r in group.rows) _Row(row: r)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final WsInspectorRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final Widget control = switch (row.kind) {
      WsRowKind.select => WsSelect(row.value),
      WsRowKind.slider => WsSlider(fraction: row.fraction, value: row.value),
      WsRowKind.text => WsMonoField(row.value),
      WsRowKind.toggle => WsToggle(on: row.on, label: row.value),
    };
    return SizedBox(
      height: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 96,
              child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body.copyWith(color: c.fg4)),
            ),
            const SizedBox(width: InkSpacing.sm),
            Expanded(child: control),
          ],
        ),
      ),
    );
  }
}
