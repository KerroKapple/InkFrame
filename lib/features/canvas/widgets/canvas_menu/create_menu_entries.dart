// 新建菜单的项、分组与执行（画布重设计稿 › 画布交互「拖线到空白处 → 建节点」）。
//
// 四个入口开的是同一个菜单：从卡片出端口拖到空白处松手（带「从哪张卡拖出来」的连线上下文）、双击舞台空白、
// 画布持焦时按 Tab、空白处右键菜单里的「新建…」。菜单项判据在 util/create_menu_model.dart（CreateMenuAction
// 驱动，不进 menu_registry.dart 的表），建节点 / 连线 / 回滚在 util/canvas_tool_actions.dart（addNodeFromMenu）。
// 新节点落在菜单锚点上；Tab 开的菜单例外——它的锚点只是视口中心，不带上下文的项与工具条 / I / G / T 同一条路，
// 落在「视口中心 + 散布」。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../theme/components/ink_menu_panel.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../models/canvas_node.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../util/canvas_tool_actions.dart';
import '../../util/create_menu_model.dart';
import '../canvas_shortcuts.dart';
import 'canvas_menu_request.dart';

/// 新建菜单一项的呈现：文案 + 图标 + 键位提示。键位取工具条用的同一组常量（CanvasToolKeys），
/// 与工具条 tooltip、快捷键表同源。
InkMenuEntry<CreateMenuAction> createMenuEntry(
  AppLocalizations l,
  CreateMenuAction action,
) =>
    switch (action) {
      CreateMenuAction.asFirstFrame => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuAsFirstFrame,
          glyph: InkGlyph.videoConfig,
        ),
      CreateMenuAction.asLastFrame => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuAsLastFrame,
          glyph: InkGlyph.videoConfig,
        ),
      CreateMenuAction.asReference => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuAsReference,
          glyph: InkGlyph.imageConfig,
        ),
      CreateMenuAction.nextShot => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuNextShot,
          glyph: InkGlyph.link,
        ),
      CreateMenuAction.imageConfig => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuImageConfig,
          glyph: InkGlyph.imageConfig,
          keyHint: CanvasToolKeys.imageNode.keyLabel,
        ),
      CreateMenuAction.videoConfig => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuVideoConfig,
          glyph: InkGlyph.videoConfig,
          keyHint: CanvasToolKeys.videoNode.keyLabel,
        ),
      CreateMenuAction.text => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuText,
          glyph: InkGlyph.text,
          keyHint: CanvasToolKeys.textNode.keyLabel,
        ),
      CreateMenuAction.shot => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuShot,
          glyph: InkGlyph.shot,
        ),
      CreateMenuAction.lane => InkMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuLane,
          glyph: InkGlyph.lane,
          keyHint: CanvasToolKeys.lane.keyLabel,
        ),
    };

/// 新建菜单的分组（菜单开着时调，跟着节点表变）。带连线上下文时，拖出来的那张卡已经不在了（菜单开着时被删）
/// ⇒ 一项都不出，也不退回不带上下文的那一组。
List<List<InkMenuEntry<CreateMenuAction>>> buildCreateMenuGroups(
  WidgetRef ref,
  AppLocalizations l, {
  required String canvasId,
  required CanvasMenuRequest request,
}) {
  final List<CanvasNode> nodes =
      ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  final String? sourceId = request.sourceNodeId;
  CanvasNode? source;
  if (sourceId != null) {
    for (final CanvasNode n in nodes) {
      if (n.id == sourceId) source = n;
    }
  }
  // 拖出来的那张卡已经不在了（菜单开着时被删）：一项都不出，也不退回不带上下文的那一组。
  final List<List<CreateMenuAction>> groups = sourceId != null && source == null
      ? const <List<CreateMenuAction>>[]
      : createMenuGroups(source: source, nodes: nodes);
  return <List<InkMenuEntry<CreateMenuAction>>>[
    for (final List<CreateMenuAction> g in groups)
      <InkMenuEntry<CreateMenuAction>>[
        for (final CreateMenuAction a in g) createMenuEntry(l, a),
      ],
  ];
}

/// 执行新建菜单选中的 [action]。菜单由调用方先关（宿主先把焦点还给画布再关，见 CanvasMenuHost 的 _dismiss）。
void runCreateMenuPick(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required CanvasMenuRequest request,
  required CreateMenuAction action,
}) {
  if (action == CreateMenuAction.lane) {
    addLaneViaDialog(context, ref, canvasId: canvasId);
    return;
  }
  final List<CanvasNode> nodes =
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
  final String? sourceId = request.sourceNodeId;
  CanvasNode? source;
  if (sourceId != null) {
    for (final CanvasNode n in nodes) {
      if (n.id == sourceId) source = n;
    }
  }
  final CanvasNodeType? type = createdNodeType(action, source: source, nodes: nodes);
  if (type == null) return;
  // Tab 开在视口中心的菜单、不带上下文的项：与工具条 / I / G / T 同一条路——视口中心 + 散布、判泳道、只单选。
  if (request.viewportCentered && request.sourceNodeId == null) {
    addNodeAtViewportCenter(context, ref, canvasId: canvasId, type: type);
    return;
  }
  addNodeFromMenu(
    context,
    ref,
    canvasId: canvasId,
    type: type,
    placement: menuNodePlacement(
      ref,
      canvasId: canvasId,
      viewportPoint: request.anchor,
    ),
    // 「下一镜」的叙事边从叙事锚点连出（产物卡 ⇒ 它的来源配置节点），其余从拖出来的那张卡。
    sourceNodeId: createdEdgeSourceId(action, source: source, nodes: nodes),
    edge: createdEdge(action),
  );
}
