// CanvasProjectPanel：左侧项目面板 241px（稿 240 + 1px 右沿）。
//
// 三标签「画布 / 资产 / 角色」——P4 起「角色」页有真内容（CharacterLibraryPanel）；
// 「资产」仍无页面体，故只画不挂点击（不给它假的可点态）。
// 页签条为什么在本文件里重画：theme 层的 InkPanelTabs 没有 onTap，而它是另一条线
// （批量复刻屏）也在用的共享件，这轮不动它；这里就地复刻同一几何并挂上点击。
// 22px 筛选字段：只属于「画布」页（稿上角色页那个位置是说明行），随页签切换。
// 画布树：activeProject 下的画布（workspaceProjectsProvider），行高 26，点击 openCanvas；
// 当前画布 ▾ + surface5 底。计数列：CanvasRef 没有节点数，留空。
// 当前画布节点列表：行高 24，方点 + 名称 + 类型；选中行 surface5，点击 = 单选。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/tokens.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/active_project.dart';
import '../../shell/providers/shell_controller.dart';
import '../../studio/models/project_with_canvases.dart';
import '../../studio/providers/workspace_projects_provider.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/project_panel_tab.dart';
import 'character_library_panel.dart';
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
    final l = context.l10n;
    final ProjectRef? project = ref.watch(activeProjectProvider);
    final ProjectPanelTab tab = ref.watch(projectPanelTabProvider);
    final ProjectPanelTabController tabs = ref.read(
      projectPanelTabProvider.notifier,
    );

    return Container(
      width: CanvasProjectPanel.width,
      decoration: BoxDecoration(
        color: c.surface3,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelTabs(
            active: tab.index,
            trailing: const InkPanelMenuGlyph(),
            tabs: <(String, VoidCallback?)>[
              (
                l.projectPanelCanvases,
                () => tabs.select(ProjectPanelTab.canvases),
              ),
              // 「资产」还没有页面体：不挂点击，免得画出一个点了没反应的页签。
              (l.projectPanelAssets, null),
              (
                l.projectPanelCharacters,
                () => tabs.select(ProjectPanelTab.characters),
              ),
            ],
          ),
          Expanded(
            child: switch (tab) {
              ProjectPanelTab.characters when project != null =>
                CharacterLibraryPanel(projectId: project.id),
              // 无活动项目 = 角色页无数据源；退回画布页的既有形态，不画空壳。
              ProjectPanelTab.characters ||
              ProjectPanelTab.assets ||
              ProjectPanelTab.canvases => _CanvasesPage(
                canvasId: widget.canvasId,
                project: project,
                filter: _filter,
                onFilterChanged: () => setState(() {}),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// 「画布」页：22px 筛选字段 + 画布树 + 当前画布节点列表（P4 之前的整个面板体）。
class _CanvasesPage extends ConsumerWidget {
  const _CanvasesPage({
    required this.canvasId,
    required this.project,
    required this.filter,
    required this.onFilterChanged,
  });

  final String canvasId;
  final ProjectRef? project;
  final TextEditingController filter;
  final VoidCallback onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    final String q = filter.text.trim().toLowerCase();
    final ProjectRef? p = project;

    final List<CanvasRef> canvases = p == null
        ? const <CanvasRef>[]
        : (ref.watch(workspaceProjectsProvider).valueOrNull ?? const <ProjectWithCanvases>[])
            .where((pr) => pr.id == p.id)
            .expand((pr) => pr.canvases)
            .where((cv) => q.isEmpty || cv.name.toLowerCase().contains(q))
            .toList();
    final List<CanvasNode> nodes =
        (ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[])
            .where((n) => q.isEmpty || nodeDisplayName(context, n).toLowerCase().contains(q))
            .toList();
    final Set<String> selected = ref.watch(canvasSelectionControllerProvider(canvasId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(InkSpacing.sm, InkSpacing.sm, InkSpacing.sm, InkSpacing.xs),
          child: InkUnderlineField(
            child: TextField(
              controller: filter,
              onChanged: (_) => onFilterChanged(),
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
                  current: cv.id == canvasId,
                  onTap: cv.id == canvasId
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
                  onTap: () => ref.read(canvasSelectionControllerProvider(canvasId).notifier).select(n.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 可点的页签条。几何与 theme 层的 InkPanelTabs 逐项一致（29 高 = 28 content + 1px 下沿，
/// 每格左右 12，选中 = surface3 底 + 1px accent 上边 + bodyStrong/fg1）；
/// 差别只有一个：每格挂 onTap，null 即该页不可达（不做假可点）。
class _PanelTabs extends StatelessWidget {
  const _PanelTabs({required this.tabs, required this.active, this.trailing});

  final List<(String, VoidCallback?)> tabs;
  final int active;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final t = context.inkTypography;
    return Container(
      height: InkPanelTabs.height,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.borderStrong)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 面板窄于标签总宽（英文文案）时从右侧裁掉，不报溢出。
          Expanded(
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int i = 0; i < tabs.length; i++)
                      MouseRegion(
                        cursor: tabs[i].$2 == null
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        child: GestureDetector(
                          key: ValueKey<String>('project-panel-tab-$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: tabs[i].$2,
                          child: Container(
                            height: InkPanelTabs.height - 1,
                            padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                            alignment: Alignment.center,
                            decoration: i == active
                                ? BoxDecoration(
                                    color: c.surface3,
                                    border: Border(top: BorderSide(color: c.accent)),
                                  )
                                : null,
                            child: Text(
                              tabs[i].$1,
                              style: i == active
                                  ? t.bodyStrong.copyWith(color: c.fg1)
                                  : t.body.copyWith(color: c.fg5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          ?trailing,
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
            InkSquareDot(size: 6, color: selected ? c.accent : c.fg5),
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
