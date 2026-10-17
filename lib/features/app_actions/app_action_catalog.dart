// 应用级动作表：菜单栏 / 右键菜单 / ⌘K / 快捷键页共用的一张表（id · 文案 · 键位 · 可用判据 · 执行），改一处处处变。
//
// - 键位不另抄：画布动作从快捷键注册表按绑定 id 取（settings/util/shortcut_catalog.dart 的 canvasBindingActivator），
//   命令面板取 kCommandPaletteActivators，第二批还没接上的动作取 planned_keys.dart 的 PlannedKeys。
// - 执行体只调现有函数：画布动作在 canvas/util/canvas_tool_actions.dart（与工具条 / 快捷键 / 右键菜单同一条路），
//   删除走 canvas_node_delete.dart 的 deleteNodesWithUndo，导出走 export/open_export_dialog.dart。
// - 画布 / 节点两组只在看得见的画布上可用（AppActionContext.canvasId）；不在画布上灰着不藏，原因「先打开一个画布」。
//   节点组的对象 = 当前选中集，判据与节点右键菜单同一组函数（canvas/util/node_menu_model.dart）。
// - 第二批还没落地的动作登记成 [comingSoon] 占位行：恒灰、原因「即将推出」、不进 ⌘K；接上的切片替换自己那一行。
// - 每行的禁用原因与启用判据出自同一个函数（_Blocker）：启用 ⇔ 原因为 null，两者不会走岔。
//
// 表的顺序 = ⌘K 动作组的顺序（buildCommandActions 按表过滤）；菜单栏的排列由菜单栏切片自己的 id 表决定，
// 所以这里各组是交错的：openSettings 排在 backToStudio 之后、exportVideo 排在画布组之后，都是为了 ⌘K 的顺序。
// ⌘K 的上下文规则（原 command_actions.dart 的四个分支）原样编码进各行的 inPalette：
//   设置浮层开着 → 只「返回工作室」；画布标签 → 图像 / 视频 / 镜头节点、导出视频（能导出时）、返回工作室、设置；
//   画廊标签且有项目 → 返回工作室、设置；其余 → 导入项目、短剧示例、设置。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../canvas/models/canvas_node.dart';
import '../canvas/models/style_lane.dart';
import '../canvas/providers/canvas_lanes_controller.dart';
import '../canvas/providers/canvas_menu_state.dart';
import '../canvas/providers/canvas_nodes_controller.dart';
import '../canvas/providers/canvas_selection_controller.dart';
import '../canvas/providers/canvas_tool_mode.dart';
import '../canvas/providers/canvas_transform_controller.dart';
import '../canvas/providers/left_rail_state.dart';
import '../canvas/providers/link_mode_controller.dart';
import '../canvas/util/canvas_node_delete.dart';
import '../canvas/util/canvas_tool_actions.dart';
import '../canvas/util/canvas_zoom.dart';
import '../canvas/util/node_menu_model.dart';
import '../canvas/widgets/shortcuts/core_canvas_keys.dart'
    show resetCanvasZoom, zoomCanvasBy;
import '../command_palette/palette_activators.dart';
import '../command_palette/widgets/command_palette_dialog.dart';
import '../export/open_export_dialog.dart';
import '../export/util/export_order.dart';
import '../sequence/providers/sequence_lens_provider.dart';
import '../sequence/util/shot_index.dart';
import '../sequence/util/view_in_sequence.dart';
import '../settings/util/shortcut_catalog.dart';
import '../shell/models/shell_state.dart';
import '../shell/providers/shell_controller.dart';
import '../storyboard/widgets/script_import_dialog.dart';
import '../studio/project_import_flow.dart';
import '../studio/studio_home_screen.dart'
    show createStudioSampleProject, showStudioNewProjectDialog;
import 'app_action.dart';
import 'app_action_ids.dart';
import 'planned_keys.dart';

/// 禁用原因（取文案）。
typedef _Reason = String Function(AppLocalizations l);

/// 此刻为什么不能用：null = 能用。启用判据与禁用原因都从它来。
typedef _Blocker = _Reason? Function(AppActionContext c);

/// 第二批还没接上的动作的占位行：恒灰、原因「即将推出」、执行为空操作、不进 ⌘K。
AppAction comingSoon(
  String id,
  AppActionGroup group,
  String Function(AppLocalizations l) label, {
  ShortcutActivator? macKey,
  ShortcutActivator? otherKey,
}) =>
    AppAction(
      id: id,
      group: group,
      label: label,
      macKey: macKey,
      otherKey: otherKey,
      isAvailable: _always,
      isEnabled: (AppActionContext c) => false,
      disabledReason: (AppActionContext c, AppLocalizations l) =>
          l.appActionReasonComingSoon,
      run: _noop,
    );

/// 应用级动作表。顺序 = ⌘K 动作组的顺序（见头注）。
final List<AppAction> kAppActions = <AppAction>[
  // ===== 文件（前半） =====
  _action(
    id: AppActionIds.newProject,
    group: AppActionGroup.file,
    label: (AppLocalizations l) => l.studioNewProject,
    run: (AppActionContext c) => showStudioNewProjectDialog(c.context, c.ref),
  ),
  // studio：导入项目与短剧示例是全局动作，项目卡菜单在零项目空态下不存在——⌘K 与空态 CTA 一起保证零项目用户
  // 也够得到（评审 P1-1；2026-08-31 审计 P0-3，见 studio/project_import_flow.dart）。
  _action(
    id: AppActionIds.importProject,
    group: AppActionGroup.file,
    label: (AppLocalizations l) => l.studioImportProject,
    icon: Icons.unarchive_outlined,
    inPalette: _paletteStudio,
    run: (AppActionContext c) => runProjectImportFlow(c.context, c.ref),
  ),
  // 短剧示例：原「内置示例」浮层的继任者——打包的两张成片是这个真项目里的真产物（P7）。建完直接落在画布上，
  // 与 Studio 空态 / 网格虚线格同一条路径。帮助菜单复用这个 id。
  _action(
    id: AppActionIds.openSampleProject,
    group: AppActionGroup.file,
    label: (AppLocalizations l) => l.studioCreateSampleProject,
    icon: Icons.auto_awesome_outlined,
    inPalette: _paletteStudio,
    run: (AppActionContext c) => createStudioSampleProject(c.context, c.ref),
  ),

  // ===== 编辑 =====
  comingSoon(
    AppActionIds.undo,
    AppActionGroup.edit,
    (AppLocalizations l) => l.commonUndo,
    macKey: PlannedKeys.undoMac,
    otherKey: PlannedKeys.undoOther,
  ),
  comingSoon(
    AppActionIds.redo,
    AppActionGroup.edit,
    (AppLocalizations l) => l.appActionRedo,
    macKey: PlannedKeys.redoMac,
    otherKey: PlannedKeys.redoOther,
  ),
  comingSoon(
    AppActionIds.cut,
    AppActionGroup.edit,
    (AppLocalizations l) => l.appActionCut,
    macKey: PlannedKeys.cutMac,
    otherKey: PlannedKeys.cutOther,
  ),
  comingSoon(
    AppActionIds.copy,
    AppActionGroup.edit,
    (AppLocalizations l) => l.appActionCopy,
    macKey: PlannedKeys.copyMac,
    otherKey: PlannedKeys.copyOther,
  ),
  comingSoon(
    AppActionIds.paste,
    AppActionGroup.edit,
    (AppLocalizations l) => l.appActionPaste,
    macKey: PlannedKeys.pasteMac,
    otherKey: PlannedKeys.pasteOther,
  ),
  // 复制一份：选中的配置卡各一份（产物不复制，判据 duplicateSources）。
  _action(
    id: AppActionIds.duplicate,
    group: AppActionGroup.edit,
    label: (AppLocalizations l) => l.canvasNodeMenuDuplicate,
    macKey: _mac('canvasDuplicate'),
    otherKey: _other('canvasDuplicate'),
    blocker: _onCanvas(
      (AppActionContext c, String canvasId) =>
          duplicateSources(_selectedNodes(c, canvasId)).isEmpty
              ? _selectNodes
              : null,
    ),
    run: _withCanvas(
      (AppActionContext c, String canvasId) => duplicateNodes(
        c.context,
        c.ref,
        canvasId: canvasId,
        nodeIds: _selection(c, canvasId),
      ),
    ),
  ),
  // 删除：走带撤销卡的删除，与 Delete 键 / 节点右键菜单同一条路。
  _action(
    id: AppActionIds.delete,
    group: AppActionGroup.edit,
    label: (AppLocalizations l) => l.canvasNodeMenuDelete,
    macKey: _mac('canvasDelete'),
    otherKey: _other('canvasDelete'),
    blocker: _onCanvas(
      (AppActionContext c, String canvasId) =>
          _selection(c, canvasId).isEmpty ? _selectNodes : null,
    ),
    run: _withCanvas(
      (AppActionContext c, String canvasId) => deleteNodesWithUndo(
        c.context,
        c.ref,
        canvasId: canvasId,
        nodeIds: _selection(c, canvasId),
      ),
    ),
  ),
  _action(
    id: AppActionIds.selectAll,
    group: AppActionGroup.edit,
    label: (AppLocalizations l) => l.canvasBlankMenuSelectAll,
    macKey: _mac('canvasSelectAll'),
    otherKey: _other('canvasSelectAll'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          selectAllNodes(c.ref, canvasId: canvasId),
    ),
  ),
  comingSoon(
    AppActionIds.find,
    AppActionGroup.edit,
    (AppLocalizations l) => l.appActionFind,
    macKey: PlannedKeys.findMac,
    otherKey: PlannedKeys.findOther,
  ),
  _action(
    id: AppActionIds.commandPalette,
    group: AppActionGroup.edit,
    label: (AppLocalizations l) => l.appActionCommandPalette,
    macKey: kCommandPaletteActivators[0],
    otherKey: kCommandPaletteActivators[1],
    run: (AppActionContext c) => showCommandPalette(c.context, c.ref),
  ),

  // ===== 画布 =====
  // 新建…：与 Tab 同一个菜单，开在视口中心（照 core_canvas_keys.dart 的 openCanvasCreateMenu；那份要 CanvasKeyContext，
  // 不能直接调）。视口还没上报尺寸时不知道中心在哪，不开。
  _action(
    id: AppActionIds.openCreateMenu,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.canvasBlankMenuNew,
    macKey: _mac('canvasOpenCreateMenu'),
    otherKey: _other('canvasOpenCreateMenu'),
    blocker: _onCanvas(),
    run: _withCanvas((AppActionContext c, String canvasId) {
      final Size viewport = c.ref.read(canvasViewportSizeProvider(canvasId));
      if (!viewport.isEmpty) {
        c.ref
            .read(canvasMenuRequestProvider(canvasId).notifier)
            .openCreate(viewport.center(Offset.zero), viewportCentered: true);
      }
    }),
  ),
  // 建节点与工具条、I / G / T 同一条路（addNodeAtViewportCenter）：视口中心 + 散布、判泳道、新节点只单选不挪相机，
  // 失败弹错误卡「添加节点失败」。
  _addNodeAction(
    id: AppActionIds.addImageNode,
    type: CanvasNodeType.image,
    label: (AppLocalizations l) => l.canvasAddImageNode,
    icon: Icons.add_photo_alternate_outlined,
    bindingId: 'canvasAddImageNode',
    inPalette: true,
  ),
  _addNodeAction(
    id: AppActionIds.addVideoNode,
    type: CanvasNodeType.video,
    label: (AppLocalizations l) => l.canvasAddVideoNode,
    icon: Icons.videocam_outlined,
    bindingId: 'canvasAddVideoNode',
    inPalette: true,
  ),
  _addNodeAction(
    id: AppActionIds.addTextNode,
    type: CanvasNodeType.text,
    label: (AppLocalizations l) => l.canvasToolTextNode,
    bindingId: 'canvasAddTextNode',
  ),
  // 镜头节点没有单键（稿未分配）。
  _addNodeAction(
    id: AppActionIds.addShotNode,
    type: CanvasNodeType.shot,
    label: (AppLocalizations l) => l.canvasAddShotNode,
    icon: Icons.movie_outlined,
    inPalette: true,
  ),
  comingSoon(
    AppActionIds.newNote,
    AppActionGroup.canvas,
    (AppLocalizations l) => l.appActionNewNote,
    macKey: PlannedKeys.newNote,
    otherKey: PlannedKeys.newNote,
  ),
  _action(
    id: AppActionIds.addLane,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.settingsShortcutCanvasAddLane,
    macKey: _mac('canvasAddLane'),
    otherKey: _other('canvasAddLane'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          addLaneViaDialog(c.context, c.ref, canvasId: canvasId),
    ),
  ),
  // 连线开关：可按的判据与工具条连线键同一个（canToggleLink：已在连线模式，或恰好选中一个节点）。
  _action(
    id: AppActionIds.toggleLink,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.canvasToolLink,
    macKey: _mac('canvasToggleLink'),
    otherKey: _other('canvasToggleLink'),
    blocker: _onCanvas(
      (AppActionContext c, String canvasId) => canToggleLink(
        linking: c.ref.read(linkModeControllerProvider(canvasId)) != null,
        selectedCount: _selection(c, canvasId).length,
      )
          ? null
          : _selectOneNode,
    ),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          toggleLinkMode(c.ref, canvasId: canvasId),
    ),
  ),
  // 导入剧本：整条链从视口中心起铺——第一镜正对着用户，后续沿 x 轴排开。
  _action(
    id: AppActionIds.importScript,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.canvasAddImportScript,
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) => showScriptImportDialog(
        c.context,
        canvasId: canvasId,
        origin: viewportCenteredNodeOrigin(
          c.ref,
          canvasId: canvasId,
          type: CanvasNodeType.shot,
        ),
      ),
    ),
  ),
  comingSoon(
    AppActionIds.importMedia,
    AppActionGroup.canvas,
    (AppLocalizations l) => l.appActionImportMedia,
    macKey: PlannedKeys.importMediaMac,
    otherKey: PlannedKeys.importMediaOther,
  ),
  _action(
    id: AppActionIds.selectTool,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.canvasToolSelect,
    macKey: _mac('canvasSelectTool'),
    otherKey: _other('canvasSelectTool'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          activateSelectTool(c.ref, canvasId: canvasId),
    ),
  ),
  // 平移工具：与 H 键同义（来回切）。
  _action(
    id: AppActionIds.panTool,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.canvasToolPan,
    macKey: _mac('canvasPanTool'),
    otherKey: _other('canvasPanTool'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          c.ref.read(canvasToolModeProvider(canvasId).notifier).togglePan(),
    ),
  ),
  _action(
    id: AppActionIds.zoomIn,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.settingsShortcutCanvasZoomIn,
    macKey: _mac('canvasZoomIn'),
    otherKey: _other('canvasZoomIn'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          zoomCanvasBy(c.ref, canvasId: canvasId, factor: kCanvasZoomStep),
    ),
  ),
  _action(
    id: AppActionIds.zoomOut,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.settingsShortcutCanvasZoomOut,
    macKey: _mac('canvasZoomOut'),
    otherKey: _other('canvasZoomOut'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          zoomCanvasBy(c.ref, canvasId: canvasId, factor: 1 / kCanvasZoomStep),
    ),
  ),
  // ⌘0 / Ctrl+0：缩放到 100%、视口中心对着的内容不动。
  _action(
    id: AppActionIds.zoomReset,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.settingsShortcutCanvasZoomReset,
    macKey: _mac('canvasZoomReset'),
    otherKey: _other('canvasZoomReset'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          resetCanvasZoom(c.ref, canvasId: canvasId),
    ),
  ),
  _action(
    id: AppActionIds.fitAll,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.settingsShortcutCanvasFitAll,
    macKey: _mac('canvasFitAll'),
    otherKey: _other('canvasFitAll'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          fitAllNodes(c.ref, canvasId: canvasId),
    ),
  ),
  _action(
    id: AppActionIds.fitSelection,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.settingsShortcutCanvasFitSelection,
    macKey: _mac('canvasFitSelection'),
    otherKey: _other('canvasFitSelection'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          fitSelectedNodes(c.ref, canvasId: canvasId),
    ),
  ),
  // 左栏开合：leftRailProvider 不按画布分族，但左栏只在打开了画布时才画——同样只在画布上可用。
  _action(
    id: AppActionIds.toggleLeftRail,
    group: AppActionGroup.canvas,
    label: (AppLocalizations l) => l.settingsShortcutCanvasToggleLeftRail,
    macKey: _mac('canvasToggleLeftRail'),
    otherKey: _other('canvasToggleLeftRail'),
    blocker: _onCanvas(),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          c.ref.read(leftRailProvider.notifier).toggle(),
    ),
  ),

  // ===== 文件（导出视频：排在画布组之后，⌘K 里紧跟三种新建节点） =====
  // 启用 = 画布上有可导出的视频产物、且外壳有项目上下文（BOARD 210：projectId 看外壳，与导出对话框同源）。
  // 执行与导出标签、序列标签同一条路（openExportVideoDialogForCanvas：按叙事链排序）；面板关闭到执行之间节点变了
  // （链序首个为空）静默不弹。
  _action(
    id: AppActionIds.exportVideo,
    group: AppActionGroup.file,
    label: (AppLocalizations l) => l.exportVideoLabel,
    icon: Icons.file_download_outlined,
    inPalette: _paletteOnCanvas,
    blocker: _onCanvas((AppActionContext c, String canvasId) {
      if (exportableVideoNodes(_nodes(c, canvasId)).isEmpty) return _noVideo;
      if (c.shell.project == null) return _noProject;
      return null;
    }),
    run: _withCanvas(
      (AppActionContext c, String canvasId) =>
          openExportVideoDialogForCanvas(c.context, c.ref, canvasId),
    ),
  ),

  // ===== 节点（对象 = 当前选中集，判据与节点右键菜单同一组函数） =====
  // 生成：恰好选中一张能生成的配置卡（generationTarget）；在不在忙由 generateNode 自己挡。
  _action(
    id: AppActionIds.generate,
    group: AppActionGroup.node,
    label: (AppLocalizations l) => l.canvasNodeMenuGenerate,
    macKey: _mac('canvasGenerate'),
    otherKey: _other('canvasGenerate'),
    blocker: _onCanvas(
      (AppActionContext c, String canvasId) =>
          generationTarget(_selectedNodes(c, canvasId)) == null
              ? _selectOneConfig
              : null,
    ),
    run: _withCanvas((AppActionContext c, String canvasId) {
      final CanvasNode? target = generationTarget(_selectedNodes(c, canvasId));
      if (target != null) generateNode(c.ref, nodeId: target.id);
    }),
  ),
  // 存为角色：恰好选中一张带图的产物（characterSource），且外壳有项目（角色是项目级的）。
  _action(
    id: AppActionIds.saveAsCharacter,
    group: AppActionGroup.node,
    label: (AppLocalizations l) => l.canvasNodeMenuSaveAsCharacter,
    blocker: _onCanvas((AppActionContext c, String canvasId) {
      if (characterSource(_selectedNodes(c, canvasId)) == null) {
        return _selectOneImage;
      }
      if (c.shell.project == null) return _noProject;
      return null;
    }),
    run: _withCanvas((AppActionContext c, String canvasId) async {
      final ProjectRef? project = c.shell.project;
      final CanvasNode? node = characterSource(_selectedNodes(c, canvasId));
      if (project == null || node == null) return;
      await saveNodeAsCharacter(
        c.context,
        c.ref,
        projectId: project.id,
        canvasId: canvasId,
        node: node,
      );
    }),
  ),
  comingSoon(
    AppActionIds.wrapInLane,
    AppActionGroup.node,
    (AppLocalizations l) => l.appActionWrapInLane,
    macKey: PlannedKeys.wrapInLaneMac,
    otherKey: PlannedKeys.wrapInLaneOther,
  ),
  // 移出泳道：选中里至少一张在（还存在的）泳道里（canRemoveFromLane）。整批走 moveNodesToLane(laneId: null)。
  _action(
    id: AppActionIds.removeFromLane,
    group: AppActionGroup.node,
    label: (AppLocalizations l) => l.canvasNodeMenuRemoveFromLane,
    blocker: _onCanvas((AppActionContext c, String canvasId) {
      final List<CanvasNode> targets = _selectedNodes(c, canvasId);
      if (targets.isEmpty) return _selectNodes;
      final List<StyleLane> lanes =
          c.ref.read(canvasLanesControllerProvider(canvasId)).valueOrNull ??
              const <StyleLane>[];
      return canRemoveFromLane(lanes: lanes, targets: targets)
          ? null
          : _notInLane;
    }),
    run: _withCanvas(
      (AppActionContext c, String canvasId) => moveNodesToLane(
        c.context,
        c.ref,
        canvasId: canvasId,
        nodeIds: _selection(c, canvasId),
        laneId: null,
      ),
    ),
  ),
  // 在序列中定位：选中里有节点在序列的某一镜（shotIndexForSelection，与标签栏「在序列中查看」同一判据）。
  _action(
    id: AppActionIds.locateInSequence,
    group: AppActionGroup.node,
    label: (AppLocalizations l) => l.canvasNodeMenuLocateInSequence,
    blocker: _onCanvas((AppActionContext c, String canvasId) {
      final Set<String> selection = _selection(c, canvasId);
      if (selection.isEmpty) return _selectNodes;
      final int index = shotIndexForSelection(
        c.ref.read(sequenceLensProvider(canvasId)),
        selection: selection,
        nodes: _nodes(c, canvasId),
      );
      return index >= 0 ? null : _notInSequence;
    }),
    run: _withCanvas(
      (AppActionContext c, String canvasId) => viewInSequence(
        c.ref,
        canvasId: canvasId,
        nodeIds: _selection(c, canvasId),
      ),
    ),
  ),

  // ===== 窗口 =====
  // 返回工作室：标签模型下切到 Studio 标签不等于关闭画布（画布还在保活宿主里），所以不清「上次画布」记录——
  // 下次启动是否回到上次画布的唯一真相源是 shellKeepLastCanvas 偏好开关（T11）。
  _action(
    id: AppActionIds.backToStudio,
    group: AppActionGroup.window,
    label: (AppLocalizations l) => l.commandBackToStudio,
    icon: Icons.arrow_back,
    inPalette: _paletteBackToStudio,
    run: (AppActionContext c) =>
        c.ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio),
  ),
  comingSoon(
    AppActionIds.focusNotifications,
    AppActionGroup.window,
    (AppLocalizations l) => l.appActionFocusNotifications,
    macKey: PlannedKeys.focusNotifications,
    otherKey: PlannedKeys.focusNotifications,
  ),

  // ===== 文件（设置：⌘K 里排在最后） =====
  _action(
    id: AppActionIds.openSettings,
    group: AppActionGroup.file,
    label: (AppLocalizations l) => l.studioOpenSettings,
    icon: Icons.settings_outlined,
    inPalette: _paletteOpenSettings,
    run: (AppActionContext c) => c.ref
        .read(shellControllerProvider.notifier)
        .openOverlay(ShellOverlay.settings),
  ),
];

final Map<String, AppAction> _byId = <String, AppAction>{
  for (final AppAction a in kAppActions) a.id: a,
};

/// 按 id 取动作表里的一行；没有这一行 ⇒ null。
AppAction? appActionById(String id) => _byId[id];

// ===== 建行的小工具 =====

/// 一行可执行的动作：启用判据与禁用原因都从 [blocker] 来（缺省 = 恒可用）；恒可见。
AppAction _action({
  required String id,
  required AppActionGroup group,
  required String Function(AppLocalizations l) label,
  required FutureOr<void> Function(AppActionContext c) run,
  _Blocker? blocker,
  IconData? icon,
  ShortcutActivator? macKey,
  ShortcutActivator? otherKey,
  bool Function(AppActionContext c)? inPalette,
}) {
  final _Blocker b = blocker ?? _unblocked;
  return AppAction(
    id: id,
    group: group,
    label: label,
    macKey: macKey,
    otherKey: otherKey,
    icon: icon,
    isAvailable: _always,
    isEnabled: (AppActionContext c) => b(c) == null,
    disabledReason: (AppActionContext c, AppLocalizations l) => b(c)?.call(l),
    run: run,
    inPalette: inPalette,
  );
}

/// 在视口中心建一个 [type] 节点的那一行（[bindingId] = 快捷键注册表里的绑定 id，没有键传 null）。
AppAction _addNodeAction({
  required String id,
  required CanvasNodeType type,
  required String Function(AppLocalizations l) label,
  IconData? icon,
  String? bindingId,
  bool inPalette = false,
}) =>
    _action(
      id: id,
      group: AppActionGroup.canvas,
      label: label,
      icon: icon,
      macKey: bindingId == null ? null : _mac(bindingId),
      otherKey: bindingId == null ? null : _other(bindingId),
      inPalette: inPalette ? _paletteOnCanvas : null,
      blocker: _onCanvas(),
      run: _withCanvas(
        (AppActionContext c, String canvasId) => addNodeAtViewportCenter(
          c.context,
          c.ref,
          canvasId: canvasId,
          type: type,
        ),
      ),
    );

/// 画布动作的判据：看不见画布 ⇒「先打开一个画布」；画布在场时再问 [extra]（缺省 = 可用）。
_Blocker _onCanvas([
  _Reason? Function(AppActionContext c, String canvasId)? extra,
]) =>
    (AppActionContext c) {
      final String? canvasId = c.canvasId;
      if (canvasId == null) return _openCanvas;
      return extra?.call(c, canvasId);
    };

/// 画布动作的执行：此刻看不见画布（菜单打开到执行之间外壳变了）⇒ 什么都不做。
FutureOr<void> Function(AppActionContext c) _withCanvas(
  FutureOr<void> Function(AppActionContext c, String canvasId) body,
) =>
    (AppActionContext c) async {
      final String? canvasId = c.canvasId;
      if (canvasId == null) return;
      await body(c, canvasId);
    };

/// 画布键位：快捷键注册表里 [bindingId] 那一条在 macOS / 其他平台的主键。
ShortcutActivator? _mac(String bindingId) =>
    canvasBindingActivator(bindingId, isMac: true);
ShortcutActivator? _other(String bindingId) =>
    canvasBindingActivator(bindingId, isMac: false);

Set<String> _selection(AppActionContext c, String canvasId) =>
    c.ref.read(canvasSelectionControllerProvider(canvasId));

List<CanvasNode> _nodes(AppActionContext c, String canvasId) =>
    c.ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasNode>[];

/// 选中集里此刻还在的节点（节点菜单的「目标」）。
List<CanvasNode> _selectedNodes(AppActionContext c, String canvasId) {
  final Set<String> selection = _selection(c, canvasId);
  return <CanvasNode>[
    for (final CanvasNode n in _nodes(c, canvasId))
      if (selection.contains(n.id)) n,
  ];
}

String _openCanvas(AppLocalizations l) => l.appActionReasonOpenCanvas;
String _selectNodes(AppLocalizations l) => l.appActionReasonSelectNodes;
String _noProject(AppLocalizations l) => l.appActionReasonNoProject;
String _noVideo(AppLocalizations l) => l.appActionReasonNoVideo;
String _selectOneNode(AppLocalizations l) => l.appActionReasonSelectOneNode;
String _selectOneConfig(AppLocalizations l) => l.appActionReasonSelectOneConfig;
String _selectOneImage(AppLocalizations l) => l.appActionReasonSelectOneImage;
String _notInLane(AppLocalizations l) => l.appActionReasonNotInLane;
String _notInSequence(AppLocalizations l) => l.appActionReasonNotInSequence;

_Reason? _unblocked(AppActionContext c) => null;
bool _always(AppActionContext c) => true;
void _noop(AppActionContext c) {}

// ===== ⌘K 的上下文（原 command_actions.dart 的四个分支，判序照旧：浮层优先） =====

/// 画布标签在前台（且没有浮层）：三种新建节点、导出视频。
bool _paletteOnCanvas(AppActionContext c) => c.canvasId != null;

bool _galleryWithProject(AppActionContext c) =>
    c.shell.overlay == null &&
    c.shell.tab == ShellTab.gallery &&
    c.shell.project != null;

/// 其余（工作室首页、还没打开画布的画布标签、序列 / 导出标签……）：导入项目、短剧示例。
bool _paletteStudio(AppActionContext c) =>
    c.shell.overlay == null && c.canvasId == null && !_galleryWithProject(c);

/// 浮层开着、画布、有项目的画廊：返回工作室。
bool _paletteBackToStudio(AppActionContext c) =>
    c.shell.overlay != null || c.canvasId != null || _galleryWithProject(c);

/// 没有浮层时都有「设置」。
bool _paletteOpenSettings(AppActionContext c) => c.shell.overlay == null;
