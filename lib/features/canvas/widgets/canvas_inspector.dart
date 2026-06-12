// CanvasInspector：右侧 320 宽折叠面板 — Transform / Camera / Composition / Metadata / Notes + Add Attribute。
//
// 本轮纯视觉：数据来自传入的 mock 字段，不读真实节点。Task 13 起接 selection。
import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

class CanvasInspector extends StatelessWidget {
  const CanvasInspector({
    super.key,
    required this.nodeTitle,
    required this.nodeKindLabel,
    required this.nodeId,
  });

  final String nodeTitle;
  final String nodeKindLabel;
  final String nodeId;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(left: BorderSide(color: colors.borderSubtle)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                InkSpacing.s18,
                InkSpacing.s18,
                InkSpacing.s18,
                InkSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    nodeTitle,
                    style: typo.headline.copyWith(color: colors.fg1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${nodeKindLabel.toUpperCase()} · $nodeId',
                    style: typo.monoNano.copyWith(color: colors.fg3),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: colors.borderSubtle),
            _CollapseSection(
              title: l.canvasInspectorTransform,
              expanded: true,
              rows: const <_KvRow>[
                _KvRow('Position', '140, 220, 0'),
                _KvRow('Rotation', '0°, 12°, 0°'),
                _KvRow('Scale', '1.00'),
              ],
            ),
            _CollapseSection(
              title: l.canvasInspectorCamera,
              expanded: true,
              rows: const <_KvRow>[
                _KvRow('Focal length', '50 mm'),
                _KvRow('Aperture', 'f/4.0'),
                _KvRow('Focus distance', '2.7 m'),
                _KvRow('Sensor', 'S35'),
              ],
            ),
            _CollapseSection(
              title: l.canvasInspectorComposition,
              expanded: false,
              rows: const <_KvRow>[],
            ),
            _CollapseSection(
              title: l.canvasInspectorMetadata,
              expanded: false,
              rows: const <_KvRow>[],
            ),
            _CollapseSection(
              title: l.canvasInspectorNotes,
              expanded: true,
              rows: const <_KvRow>[],
              trailingBody: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Establishing the docks. Hold for 4 s before pushing in.',
                  style: typo.body.copyWith(color: colors.fg2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                InkSpacing.md,
                0,
                InkSpacing.md,
                InkSpacing.md,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Text(
                  '+ ${l.canvasInspectorAddAttribute}',
                  style: typo.caption.copyWith(color: colors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KvRow {
  const _KvRow(this.key, this.value);
  final String key;
  final String value;
}

class _CollapseSection extends StatefulWidget {
  const _CollapseSection({
    required this.title,
    required this.expanded,
    required this.rows,
    this.trailingBody,
  });

  final String title;
  final bool expanded;
  final List<_KvRow> rows;
  final Widget? trailingBody;

  @override
  State<_CollapseSection> createState() => _CollapseSectionState();
}

class _CollapseSectionState extends State<_CollapseSection> {
  late bool _open = widget.expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(
        InkSpacing.md,
        InkSpacing.s12,
        InkSpacing.md,
        InkSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title.toUpperCase(),
                    style: typo.overline.copyWith(color: colors.fg3),
                  ),
                ),
                Text(
                  _open ? '▾' : '▸',
                  style: typo.caption.copyWith(color: colors.fg4),
                ),
              ],
            ),
          ),
          if (_open) ...<Widget>[
            const SizedBox(height: InkSpacing.sm),
            for (final r in widget.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      r.key,
                      style: typo.body.copyWith(color: colors.fg2),
                    ),
                    Text(
                      r.value,
                      style: typo.caption.copyWith(color: colors.fg1),
                    ),
                  ],
                ),
              ),
            if (widget.trailingBody != null) widget.trailingBody!,
          ],
        ],
      ),
    );
  }
}
