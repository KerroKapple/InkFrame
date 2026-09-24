// CanvasProjectPanel：左侧项目面板 241px（稿 240 + 1px 右沿）。
//
// 三标签「画布 / 资产 / 角色」——资产与角色在仓库里没有面板内容（角色目前只在
// 检查器里挂载），只画标签不挂交互，另开卡。
// 22px 筛选字段：客户端过滤画布树与节点列表。
// 画布树：activeProject 下的画布（workspaceProjectsProvider），行高 26，点击 openCanvas；
// 当前画布 ▾ + surface5 底。计数列：CanvasRef 没有节点数，留空。
// 当前画布节点列表：行高 24，方点 + 名称 + 类型；选中行 surface5，点击 = 单选。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../../theme/tokens.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/active_project.dart';
import '../../shell/providers/shell_controller.dart';
import '../../studio/models/project_with_canvases.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import 'node_card.dart';

class CanvasProjectPanel extends ConsumerStatefulWidget {
  const CanvasProjectPanel({super.key, required this.canvasId});

  final String canvasId;

  /// 稿是 content-box：width 240 + border-right 1。
  static const double width = 241;

  @override
  ConsumerState<CanvasProjectPanel> createState() => _CanvasProjectPanelState();
}

class _CanvasProjectPanelState extends ConsumerState<CanvasProjectPanel> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String q = _filter.text.trim().toLowerCase();

    final ProjectRef? project = ref.watch(activeProjectProvider);
    final List<CanvasRef> canvases = project == null
        ? const <CanvasRef>[]
        : (ref.watch(workspaceProjectsProvider).valueOrNull ?? const <ProjectWithCanvases>[])
            .where((p) => p.id == project.id)
            .expand((p) => p.canvases)
            .where((cv) => q.isEmpty || cv.name.toLowerCase().contains(q))
            .toList();
    final List<CanvasNode> nodes =
        (ref.watch(canvasNodesControllerProvider(widget.canvasId)).valueOrNull ?? const <CanvasNode>[])
            .where((n) => q.isEmpty || nodeDisplayName(context, n).toLowerCase().contains(q))
            .toList();
    final Set<String> selected = ref.watch(canvasSelectionControllerProvider(widget.canvasId));

    return Container(
      width: CanvasProjectPanel.width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WsPanelTabs(
            tabs: <String>[l.projectPanelCanvases, l.projectPanelAssets, l.projectPanelCharacters],
            trailing: const WsPanelMenuGlyph(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(InkSpacing.sm, InkSpacing.sm, InkSpacing.sm, InkSpacing.xs),
            child: WsUnderlineField(
              child: TextField(
                controller: _filter,
                onChanged: (_) => setState(() {}),
                style: t.body.copyWith(color: c.fg2),
                cursorColor: c.accent,
                decoration: InputDecoration.collapsed(
                  hintText: l.projectPanelFilterHint,
                  hintStyle: t.body.copyWith(color: c.fg6),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: InkSpacing.xs),
              children: <Widget>[
                for (final CanvasRef cv in canvases)
                  _CanvasRow(
                    name: cv.name.isEmpty ? l.canvasDefaultName : cv.name,
                    current: cv.id == widget.canvasId,
                    onTap: cv.id == widget.canvasId
                        ? null
                        : () => ref.read(shellControllerProvider.notifier).openCanvas(cv.id),
                  ),
                Container(height: 1, margin: const EdgeInsets.symmetric(vertical: InkSpacing.s6), color: c.borderStrong),
                Padding(
                  padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.s6, InkSpacing.s12, InkSpacing.xs),
                  child: Text(l.projectPanelCurrentNodes, style: t.meta.copyWith(color: c.fg6)),
                ),
                for (final CanvasNode n in nodes)
                  _NodeRow(
                    name: nodeDisplayName(context, n),
                    kind: n.type.name,
                    selected: selected.contains(n.id),
                    onTap: () => ref.read(canvasSelectionControllerProvider(widget.canvasId).notifier).select(n.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasRow extends StatelessWidget {
  const _CanvasRow({required this.name, required this.current, required this.onTap});
  final String name;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.only(left: InkSpacing.s12, right: InkSpacing.s10),
        color: current ? c.surface5 : null,
        child: Row(
          children: <Widget>[
            SizedBox(width: 8, child: Text(current ? '▾' : '▸', style: t.micro.copyWith(color: c.fg6))),
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
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: current ? c.fg1 : c.fg3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.name, required this.kind, required this.selected, required this.onTap});
  final String name;
  final String kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: InkSpacing.s28, right: InkSpacing.s10),
        color: selected ? c.surface5 : null,
        child: Row(
          children: <Widget>[
            WsSquareDot(size: 6, color: selected ? c.accent : c.fg5),
            const SizedBox(width: InkSpacing.sm),
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: selected ? c.fg1 : c.fg3)),
            ),
            const SizedBox(width: InkSpacing.sm),
            Text(kind, style: t.micro.copyWith(color: c.fg6)),
          ],
        ),
      ),
    );
  }
}
