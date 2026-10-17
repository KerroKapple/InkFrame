// 节点右键菜单的六项（menu_registry.dart 的表里 scope = node 的那几条）。稿：生成 · 复制一份 | 存为角色 ·
// 加入泳道 › · 在序列中定位 | 删除。卡片上右键单击（canvas_view 的卡片插槽在抬起时报上来，按住右键拖动不算）：
// 右键一张没被选中的卡，画布先把选中换成它；右键一张已在多选里的卡，保持多选。
//
// 不可用的项置灰、不隐藏，判据全在 util/node_menu_model.dart；动作在 util/canvas_tool_actions.dart（与 Ctrl+↵ /
// Ctrl+D 共用），「在序列中定位」走 sequence/util/view_in_sequence.dart（与标签栏「在序列中查看」共用），删除走
// canvas_node_delete.dart。键位提示从快捷键表取，与设置「快捷键」页同源。作用范围按 node_menu_model 的口径：
// 生成 / 存为角色只对右键的那一张（菜单只在目标恰好一张时让它们可点），复制一份 / 加入泳道 / 在序列中定位 /
// 删除对整个目标集（多选整批）。
//
// 这一版不放「剪切」「复制」（没有剪贴板）与「当下一镜的首帧」（下一镜已有首帧时是替换还是新建，没有拍板），
// BOARD 有记。组号按 menu_registry.dart 头注的约定：10 做 / 30 归类 · 定位 / 90 删除。
//
// 舞台外（大纲 / 序列的右键菜单，后续切片接）用 [buildNodeMenuGroups] / [runNodeMenuPick]，不经画布的宿主。
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/components/ink_menu_panel.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../../../theme/tokens.dart';
import '../../../sequence/models/sequence_lens.dart';
import '../../../sequence/providers/sequence_lens_provider.dart';
import '../../../sequence/util/shot_index.dart';
import '../../../sequence/util/view_in_sequence.dart';
import '../../../settings/util/shortcut_catalog.dart';
import '../../../shell/models/shell_state.dart';
import '../../../shell/providers/active_project.dart';
import '../../models/canvas_node.dart';
import '../../models/style_lane.dart';
import '../../providers/canvas_lanes_controller.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/inspector_submit_controller.dart';
import '../../util/canvas_node_delete.dart';
import '../../util/canvas_tool_actions.dart';
import '../../util/lane_tint.dart';
import '../../util/node_menu_model.dart';
import '../canvas_shortcuts.dart';
import 'canvas_menu_request.dart';
import 'menu_registry.dart';

// id 用 NodeMenuAction 的名字拼（这一行交回来的值也是它）。
final String _generateId = 'node.${NodeMenuAction.generate.name}';
final String _duplicateId = 'node.${NodeMenuAction.duplicate.name}';
final String _saveAsCharacterId = 'node.${NodeMenuAction.saveAsCharacter.name}';
final String _laneSubmenuId = 'node.${NodeMenuAction.laneSubmenu.name}';
final String _locateInSequenceId = 'node.${NodeMenuAction.locateInSequence.name}';
final String _deleteId = 'node.${NodeMenuAction.delete.name}';

/// 节点右键菜单的项。
final List<CanvasMenuItemDef> nodeMenuItems = <CanvasMenuItemDef>[
  CanvasMenuItemDef(
    id: _generateId,
    scope: CanvasMenuScope.node,
    group: 10,
    order: 10,
    build: _buildGenerate,
    run: _runGenerate,
  ),
  CanvasMenuItemDef(
    id: _duplicateId,
    scope: CanvasMenuScope.node,
    group: 10,
    order: 20,
    build: _buildDuplicate,
    run: _runDuplicate,
  ),
  CanvasMenuItemDef(
    id: _saveAsCharacterId,
    scope: CanvasMenuScope.node,
    group: 30,
    order: 10,
    build: _buildSaveAsCharacter,
    run: _runSaveAsCharacter,
  ),
  CanvasMenuItemDef(
    id: _laneSubmenuId,
    scope: CanvasMenuScope.node,
    group: 30,
    order: 20,
    build: _buildLaneSubmenu,
    run: _runLaneSubmenu,
  ),
  CanvasMenuItemDef(
    id: _locateInSequenceId,
    scope: CanvasMenuScope.node,
    group: 30,
    order: 30,
    build: _buildLocateInSequence,
    run: _runLocateInSequence,
  ),
  CanvasMenuItemDef(
    id: _deleteId,
    scope: CanvasMenuScope.node,
    group: 90,
    order: 10,
    build: _buildDelete,
    run: _runDelete,
  ),
];

/// 节点 [nodeId] 的右键菜单分组（菜单开着时调，跟着节点 / 选中 / 泳道 / 提交状态变）。那张卡已经不在了
/// （菜单开着时被删）⇒ 一项都不出。
List<List<InkMenuEntry<String>>> buildNodeMenuGroups(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required String nodeId,
}) {
  final List<CanvasNode> nodes =
      ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  if (!nodes.any((CanvasNode n) => n.id == nodeId)) {
    return const <List<InkMenuEntry<String>>>[];
  }
  return buildMenuGroups(
    CanvasMenuScope.node,
    CanvasMenuContext(
      context: context,
      ref: ref,
      canvasId: canvasId,
      request: _nodeRequest(nodeId),
      targets: nodeMenuTargets(
        ref.watch(canvasSelectionControllerProvider(canvasId)),
        nodeId,
      ),
    ),
  );
}

/// 执行节点 [nodeId] 右键菜单里选中的那一行 [picked]。[dismiss]：关菜单（各项先调它再动作）；找不到这一项
/// ⇒ 只关菜单。作用的节点集此刻按选中现算。
Future<void> runNodeMenuPick(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required String nodeId,
  required String picked,
  VoidCallback? dismiss,
}) async {
  final CanvasMenuItemDef? item = menuItemForPick(CanvasMenuScope.node, picked);
  if (item == null) {
    dismiss?.call();
    return;
  }
  await item.run(
    CanvasMenuContext(
      context: context,
      ref: ref,
      canvasId: canvasId,
      request: _nodeRequest(nodeId),
      targets: nodeMenuTargets(
        ref.read(canvasSelectionControllerProvider(canvasId)),
        nodeId,
      ),
      picked: picked,
      dismiss: dismiss,
    ),
  );
}

/// 节点菜单的项只读请求里的 nodeId（锚点只管菜单开在哪，开菜单的那一方自己管）：舞台外入口没有画布请求，
/// 按这张卡拼一个。
CanvasMenuRequest _nodeRequest(String nodeId) => CanvasMenuRequest(
      kind: CanvasMenuKind.node,
      anchor: Offset.zero,
      nodeId: nodeId,
    );

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// 菜单开着时的节点表（build 用，watch）。
List<CanvasNode> _watchNodes(CanvasMenuContext c) =>
    c.ref.watch(canvasNodesControllerProvider(c.canvasId)).valueOrNull ??
        const <CanvasNode>[];

/// 目标集里此刻还在的节点（build 用，watch）。
List<CanvasNode> _watchTargets(CanvasMenuContext c) => <CanvasNode>[
      for (final CanvasNode n in _watchNodes(c))
        if (c.targets.contains(n.id)) n,
    ];

/// 提交状态在忙：提交中 / 生成中（与提示词条「生成」按钮的 busy 同一个判据）。
bool _isSubmitBusy(InspectorSubmitState state) =>
    state is InspectorSubmitSubmitting || state is InspectorSubmitRunning;

InkMenuEntry<String> _buildGenerate(CanvasMenuContext c) {
  final CanvasNode? generateTarget = generationTarget(_watchTargets(c));
  // 在忙（提交中 / 生成中）时「生成」置灰，与提示词条「生成」按钮同一个判据。只在真能生成时才订阅提交状态。
  final bool busy = generateTarget != null &&
      _isSubmitBusy(
        c.ref.watch(inspectorSubmitControllerProvider(generateTarget.id)),
      );
  return InkMenuEntry<String>(
    value: _generateId,
    label: c.context.l10n.canvasNodeMenuGenerate,
    glyph: InkGlyph.run,
    keyHint: canvasShortcutLabel(
      (Intent intent) => intent is CanvasGenerateIntent,
      isMac: _isMac,
    ),
    enabled: generateTarget != null && !busy,
  );
}

/// 生成只对右键的那一张。
void _runGenerate(CanvasMenuContext c) {
  final String? nodeId = c.request.nodeId;
  if (nodeId == null) return;
  c.dismiss?.call();
  generateNode(c.ref, nodeId: nodeId);
}

InkMenuEntry<String> _buildDuplicate(CanvasMenuContext c) => InkMenuEntry<String>(
      value: _duplicateId,
      label: c.context.l10n.canvasNodeMenuDuplicate,
      keyHint: canvasShortcutLabel(
        (Intent intent) => intent is CanvasDuplicateIntent,
        isMac: _isMac,
      ),
      enabled: duplicateSources(_watchTargets(c)).isNotEmpty,
    );

void _runDuplicate(CanvasMenuContext c) {
  c.dismiss?.call();
  duplicateNodes(c.context, c.ref, canvasId: c.canvasId, nodeIds: c.targets);
}

InkMenuEntry<String> _buildSaveAsCharacter(CanvasMenuContext c) => InkMenuEntry<String>(
      value: _saveAsCharacterId,
      label: c.context.l10n.canvasNodeMenuSaveAsCharacter,
      glyph: InkGlyph.characters,
      enabled: c.ref.watch(activeProjectProvider) != null &&
          characterSource(_watchTargets(c)) != null,
    );

/// 存为角色要项目上下文（角色是项目级的）与带图的产物节点；菜单在缺任何一样时已经置灰，这里再兜一手。
void _runSaveAsCharacter(CanvasMenuContext c) {
  final String? nodeId = c.request.nodeId;
  if (nodeId == null) return;
  c.dismiss?.call();
  final ProjectRef? project = c.ref.read(activeProjectProvider);
  final List<CanvasNode> nodes =
      c.ref.read(canvasNodesControllerProvider(c.canvasId)).valueOrNull ??
          const <CanvasNode>[];
  CanvasNode? node;
  for (final CanvasNode n in nodes) {
    if (n.id == nodeId) node = n;
  }
  if (project == null || node == null) return;
  saveNodeAsCharacter(
    c.context,
    c.ref,
    projectId: project.id,
    canvasId: c.canvasId,
    node: node,
  );
}

/// 画布上没有泳道 ⇒ 置灰、不带子菜单。
InkMenuEntry<String> _buildLaneSubmenu(CanvasMenuContext c) {
  final List<StyleLane> lanes =
      c.ref.watch(canvasLanesControllerProvider(c.canvasId)).valueOrNull ??
          const <StyleLane>[];
  return InkMenuEntry<String>(
    value: _laneSubmenuId,
    label: c.context.l10n.canvasNodeMenuAddToLane,
    glyph: InkGlyph.lane,
    enabled: lanes.isNotEmpty,
    submenu: lanes.isEmpty
        ? null
        : _laneGroups(c.context.inkColors, c.context.l10n, lanes, _watchTargets(c)),
  );
}

/// 「加入泳道 ›」的子菜单：本画布的泳道（色点 + 名称，目标全在里面的那一条打勾、不可点）| 移出泳道。
/// 行的值是 `node.laneSubmenu:<laneId>`，「移出泳道」是 `node.laneSubmenu:`（冒号后为空）。
List<List<InkMenuEntry<String>>> _laneGroups(
  InkColors c,
  AppLocalizations l,
  List<StyleLane> lanes,
  List<CanvasNode> targets,
) =>
    <List<InkMenuEntry<String>>>[
      <InkMenuEntry<String>>[
        for (final LaneMenuOption option
            in laneMenuOptions(lanes: lanes, targets: targets))
          InkMenuEntry<String>(
            value: '$_laneSubmenuId:${option.lane.id}',
            label: option.lane.label.isEmpty ? l.laneUntitled : option.lane.label,
            // 色点与泳道标题栏同一个口径：手动 tint → 风格词推断 → fg6。
            swatch: effectiveLaneTint(
                  tintColor: option.lane.tintColor,
                  stylePrompt: option.lane.stylePrompt,
                ) ??
                c.fg6,
            enabled: !option.current,
            checked: option.current,
          ),
      ],
      <InkMenuEntry<String>>[
        InkMenuEntry<String>(
          value: '$_laneSubmenuId:',
          label: l.canvasNodeMenuRemoveFromLane,
          enabled: canRemoveFromLane(lanes: lanes, targets: targets),
        ),
      ],
    ];

/// 子菜单的行：冒号后是目标泳道 id；为空 = 移出泳道（laneId 为 null，不是空串）。
void _runLaneSubmenu(CanvasMenuContext c) {
  final int colon = c.picked.indexOf(':');
  // 「加入泳道 ›」那一行只开子菜单，不会交回来；防御一手。
  if (colon < 0) return;
  final String laneId = c.picked.substring(colon + 1);
  c.dismiss?.call();
  moveNodesToLane(
    c.context,
    c.ref,
    canvasId: c.canvasId,
    nodeIds: c.targets,
    laneId: laneId.isEmpty ? null : laneId,
  );
}

InkMenuEntry<String> _buildLocateInSequence(CanvasMenuContext c) {
  final SequenceLens lens = c.ref.watch(sequenceLensProvider(c.canvasId));
  return InkMenuEntry<String>(
    value: _locateInSequenceId,
    label: c.context.l10n.canvasNodeMenuLocateInSequence,
    glyph: InkGlyph.sequence,
    enabled:
        shotIndexForSelection(lens, selection: c.targets, nodes: _watchNodes(c)) >= 0,
  );
}

void _runLocateInSequence(CanvasMenuContext c) {
  c.dismiss?.call();
  viewInSequence(c.ref, canvasId: c.canvasId, nodeIds: c.targets);
}

InkMenuEntry<String> _buildDelete(CanvasMenuContext c) => InkMenuEntry<String>(
      value: _deleteId,
      label: c.context.l10n.canvasNodeMenuDelete,
      keyHint: canvasShortcutLabel(
        (Intent intent) => intent is DeleteSelectionIntent,
        isMac: _isMac,
      ),
      danger: true,
    );

void _runDelete(CanvasMenuContext c) {
  c.dismiss?.call();
  deleteNodesWithUndo(c.context, c.ref, canvasId: c.canvasId, nodeIds: c.targets);
}
