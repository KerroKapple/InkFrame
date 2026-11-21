// 参考库格子的三个动作：只放进画布 / 当〈类别〉参考（同类替换）/ 存为角色。
//
// 三个动作都只调现成的接口，不另写一套：
//   - 导入：mediaImportControllerProvider(canvasId).importFiles——与「导入本地图片」同一条路，原图复制进项目
//     imports/，建一个导入的图像产物节点；导出项目包时这张图跟着走。导入成功后在新节点的 type_config 里补两个
//     标记键（ImportKeys.referenceItemId / referenceCategory），「当参考」靠它们认出同类别的旧图与「已经是这张」。
//   - 连线：canvasEdgesController.applySplice——删旧边、建新边在一个事务里，旧导入节点留在画布上不删。
//   - 存为角色：charactersController.createFromImage，与角色库「新建角色」、节点右键「存为角色」同一条路。
// 三个都不进撤销栈：导入与建角色本来就不进栈（W3 的撤销范围不含它们），连线进栈归 TOPO-7。
//
// 「当参考」开头**重新**读选中集 / 节点 / 边再判一次（planReferenceAttach）：菜单是点开那一刻画的，点下去之前
// 目标可能被删了、换了服务商、或画布换了（Review Focus 3）。判不过 ⇒ 出说明卡，什么也不导入。
//
// 文案、通知出口与 ProviderContainer 一律在第一次 await 之前取好：之后发起动作的那块界面可能已卸载（收了左栏、
// 切了分段），WidgetRef 不能再用；容器活得和应用一样长。节点 / 边控制器都是 autoDispose，操作期间经容器挂住。
import 'dart:io' show FileSystemException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/import_keys.dart';
import '../../../../core/di/logger.dart';
import '../../../../core/di/preferences.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/errors/ink_error.dart';
import '../../../../core/interfaces/character_asset_service.dart'
    show CharacterAssetError;
import '../../../../core/interfaces/toast_service.dart';
import '../../../../core/models/app_preferences.dart';
import '../../../../core/models/reference_item.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/components/ink_name_dialog.dart';
import '../../../notifications/providers/toast_service_provider.dart';
import '../../models/canvas_edge.dart';
import '../../models/canvas_node.dart';
import '../../models/character.dart';
import '../../providers/canvas_capsule.dart';
import '../../providers/canvas_edges_controller.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/characters_controller.dart';
import '../../providers/inspector_pending_config.dart';
import '../../providers/media_import_controller.dart';
import '../../util/canvas_extent.dart';
import '../../util/canvas_history_actions.dart' show ProviderReader;
import '../../util/canvas_tool_actions.dart';
import '../../util/drop_placement.dart';
import '../../util/narrative_splice.dart';
import 'reference_library_model.dart';

/// 日志 module 名（内部标识，English-only）。
const String kReferenceActionsLogModule = 'canvas.reference_library';

/// 「当参考」导入的节点落在目标左侧：与成片落点（result_placement.dart：config 右侧一列）同一套间距、方向相反；
/// 同一行（与目标顶对齐）。
Offset referenceNodePosition(Offset targetPosition) => clampIntoWorldReach(
      Offset(
        targetPosition.dx - kNodeCardSize.width - kResultColumnGap,
        targetPosition.dy,
      ),
    );

/// 此刻（现读）的「当参考」判据：选中集、节点、边、能力表、上次使用的服务商都现取。
///
/// 选中节点在检查器里有还没落盘的服务商改动（inspectorPendingConfigProvider）时按改动后的判——与提示词条同一份
/// 「已存 + 补丁」，检查器刚换成不收参考图的服务商，这里也立刻置灰。
/// 菜单（画的时候）与 [attachReferenceToSelected]（点下去的时候）共用这一个。[read] 传 WidgetRef.read 或
/// ProviderContainer.read 都行。
ReferenceAttachDecision currentReferenceAttachDecision(
  ProviderReader read, {
  required String canvasId,
  required ReferenceItem item,
}) {
  final Set<String> selected = read(canvasSelectionControllerProvider(canvasId));
  final List<CanvasNode> nodes =
      read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[];
  final List<CanvasEdge> edges =
      read(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasEdge>[];
  final AppPreferences prefs = read(preferencesServiceProvider).current;
  return planReferenceAttach(
    item: item,
    selectedIds: selected,
    nodes: _withPendingProvider(read, nodes, selected),
    edges: edges,
    capabilities: read(providerCapabilitiesListProvider),
    lastUsedImageProviderId: prefs.lastImageProviderId,
    lastUsedVideoProviderId: prefs.lastVideoProviderId,
  );
}

/// 恰好选中一个节点、且检查器里它的 provider_id 有挂起补丁 ⇒ 把补丁盖到那一张的 type_config 上；否则原样。
List<CanvasNode> _withPendingProvider(
  ProviderReader read,
  List<CanvasNode> nodes,
  Set<String> selected,
) {
  if (selected.length != 1) return nodes;
  final String id = selected.single;
  if (!nodes.any((CanvasNode n) => n.id == id)) return nodes;
  final Map<String, Object?> pending = read(inspectorPendingConfigProvider(id));
  if (!pending.containsKey('provider_id')) return nodes;
  return <CanvasNode>[
    for (final CanvasNode n in nodes)
      if (n.id == id)
        n.copyWith(
          typeConfig: <String, Object?>{
            ...n.typeConfig,
            'provider_id': pending['provider_id'],
          },
        )
      else
        n,
  ];
}

/// [decision] 点不动时的那句原因；可以点 ⇒ null。菜单副标题与动作的说明卡共用。
///
/// [targetGone]：选中集里恰好一个 id、却已不在画布上（点菜单这一刻被删了）——说「目标已不在」，不说「先选中」。
String? referenceAttachBlockText(
  AppLocalizations l,
  ReferenceAttachDecision decision, {
  required Map<String, String> providerNames,
  bool targetGone = false,
}) {
  final ReferenceAttachBlock? block = decision.block;
  if (block == null) return null;
  return switch (block) {
    ReferenceAttachBlock.noSelection =>
      targetGone ? l.referenceTargetGone : l.referenceBlockNoSelection,
    ReferenceAttachBlock.notConfig => l.referenceBlockNotConfig,
    ReferenceAttachBlock.providerNoRefs => l.referenceBlockProviderNoRefs(
        providerNames[decision.providerId] ?? decision.providerId ?? '',
      ),
    ReferenceAttachBlock.budgetFull =>
      l.referenceBlockBudgetFull(decision.maxRefImages),
  };
}

/// 只放进画布：导入 [item] 的原图，落在视口中心（与工具条建节点同一套落点：「视口中心 + 散布」，并按那一点判
/// 泳道），再写两个标记键。被跳过（原图不存在 / 读不出来）或节点控制器载入失败 ⇒ 错误卡「这张参考图导入失败」。
Future<void> placeReferenceOnCanvas(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required String projectId,
  required ReferenceItem item,
}) async {
  final String failed = context.l10n.referenceImportFailed;
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final ToastService toast = container.read(toastServiceProvider);
  final NodePlacement placement = menuNodePlacement(
    ref,
    canvasId: canvasId,
    viewportPoint: viewportCenteredNodePoint(
      ref,
      canvasId: canvasId,
      type: CanvasNodeType.image,
    ),
  );
  final ProviderSubscription<AsyncValue<List<CanvasNode>>> keepNodes =
      container.listen(canvasNodesControllerProvider(canvasId), (_, _) {});
  try {
    final String? nodeId = await _importReference(
      container,
      canvasId: canvasId,
      projectId: projectId,
      item: item,
      placement: placement,
    );
    if (nodeId == null) {
      toast.show(failed, kind: ToastKind.error);
      return;
    }
    try {
      await _markReference(container, canvasId: canvasId, nodeId: nodeId, item: item);
    } on InkError catch (e) {
      // 图已经进了画布，只是没记上「来自参考库」：之后当参考时它不参与同类替换。不算导入失败，只记 warn。
      container.read(loggerProvider).warn(
        kReferenceActionsLogModule,
        'reference.mark_failed',
        extra: <String, Object?>{'node_id': nodeId, 'code': e.code.name},
      );
    }
  } on InkError catch (_) {
    toast.show(failed, kind: ToastKind.error);
  } finally {
    keepNodes.close();
  }
}

/// 当〈类别〉参考：把 [item] 导入、放在选中配置节点的左侧，连一条 data/reference 边过去；这一镜已经挂着同类别的
/// 参考库图 ⇒ 同一个事务里断开旧边（旧节点留着）。同一张已经挂着 ⇒ 什么也不改，出胶囊「已经是这张」。
///
/// 顺序：重新判（判不过出说明卡，不导入）→ 导入（失败出「导入失败」卡）→ 写标记键 → applySplice（失败出
/// 「连线失败」卡，导入的节点保留，用户可以手动连）。标记没写上也按连线失败算、不连：没标记的参考图下次认不出
/// 同类别，「每类最多一张」就破了。
Future<void> attachReferenceToSelected(
  BuildContext context,
  WidgetRef ref, {
  required String canvasId,
  required String projectId,
  required ReferenceItem item,
}) async {
  final AppLocalizations l = context.l10n;
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final ToastService toast = container.read(toastServiceProvider);
  final Map<String, String> providerNames =
      container.read(providerDisplayNamesProvider);

  final ProviderSubscription<AsyncValue<List<CanvasNode>>> keepNodes =
      container.listen(canvasNodesControllerProvider(canvasId), (_, _) {});
  final ProviderSubscription<AsyncValue<List<CanvasEdge>>> keepEdges =
      container.listen(canvasEdgesControllerProvider(canvasId), (_, _) {});
  try {
    try {
      await container.read(canvasNodesControllerProvider(canvasId).future);
      await container.read(canvasEdgesControllerProvider(canvasId).future);
    } on InkError catch (_) {
      toast.show(l.referenceAttachFailed, kind: ToastKind.error);
      return;
    }

    // 1. 重新判（Review Focus 3）：用的是此刻的选中集 / 节点 / 边，不是菜单画出来那一刻的。
    final ReferenceAttachDecision decision = currentReferenceAttachDecision(
      container.read,
      canvasId: canvasId,
      item: item,
    );
    final List<CanvasNode> nodes =
        container.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final ReferenceAttachPlan? plan = decision.plan;
    final CanvasNode? target = plan == null
        ? null
        : nodes.where((CanvasNode n) => n.id == plan.targetNodeId).firstOrNull;
    if (plan == null || target == null) {
      final Set<String> selected =
          container.read(canvasSelectionControllerProvider(canvasId));
      final bool gone = selected.length == 1 &&
          !nodes.any((CanvasNode n) => n.id == selected.single);
      final String? reason = referenceAttachBlockText(
        l,
        decision,
        providerNames: providerNames,
        targetGone: gone,
      );
      toast.show(reason ?? l.referenceTargetGone, kind: ToastKind.info);
      return;
    }
    if (plan.alreadyAttached) {
      container
          .read(canvasCapsuleProvider(canvasId).notifier)
          .show(CanvasCapsuleMessage(text: l.referenceAlreadyAttached));
      return;
    }

    // 2. 导入到目标左侧、同一条泳道。
    final String? nodeId;
    try {
      nodeId = await _importReference(
        container,
        canvasId: canvasId,
        projectId: projectId,
        item: item,
        placement: (
          world: referenceNodePosition(target.position),
          laneId: target.laneId,
        ),
      );
    } on InkError catch (_) {
      toast.show(l.referenceImportFailed, kind: ToastKind.error);
      return;
    }
    if (nodeId == null) {
      toast.show(l.referenceImportFailed, kind: ToastKind.error);
      return;
    }

    // 3. 标记键 + 4. 一个事务里断旧边、连新边。
    try {
      await _markReference(container, canvasId: canvasId, nodeId: nodeId, item: item);
      await container
          .read(canvasEdgesControllerProvider(canvasId).notifier)
          .applySplice(
            SplicePlan(
              removeEdgeIds: plan.replaceEdgeIds,
              addEdges: <SpliceEdgeSpec>[
                (
                  sourceNodeId: nodeId,
                  targetNodeId: plan.targetNodeId,
                  edgeType: EdgeType.data,
                  role: EdgeRole.reference,
                  sortOrder: 0,
                ),
              ],
            ),
          );
    } on InkError catch (_) {
      // 不回滚导入：节点留在画布上，用户可以手动连。
      toast.show(l.referenceAttachFailed, kind: ToastKind.error);
    }
  } finally {
    keepNodes.close();
    keepEdges.close();
  }
}

/// 存为角色（只对人像，调用方保证）：先弹起名框，再用原图绝对路径调 createFromImage。取消 / 空名 ⇒ 什么也不做。
///
/// 捕获集与 canvas_tool_actions.saveNodeAsCharacter 相同 = createFromImage 的真实抛出集（仓储 InkError / 资产服务
/// CharacterAssetError / dart:io FileSystemException），失败一律出错误卡；成功也出一张卡（画布上看不见角色库）。
/// 角色控制器是 autoDispose：操作期间挂住，先等它 build 完再建（与画廊同一做法）。
Future<void> saveReferenceAsCharacter(
  BuildContext context,
  WidgetRef ref, {
  required String projectId,
  required ReferenceItem item,
}) async {
  assert(
    item.category == ReferenceCategory.portrait,
    'saveReferenceAsCharacter: only portraits can become characters',
  );
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => InkNameDialog(
      title: ctx.l10n.characterNew,
      hint: ctx.l10n.characterFieldName,
      confirmLabel: ctx.l10n.characterSave,
      cancelLabel: ctx.l10n.commonCancel,
    ),
  );
  final String trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty || !context.mounted) return;
  final AppLocalizations l = context.l10n;
  final ToastService toast = container.read(toastServiceProvider);
  final ProviderSubscription<AsyncValue<List<Character>>> keep =
      container.listen(charactersControllerProvider(projectId), (_, _) {});
  try {
    await container.read(charactersControllerProvider(projectId).future);
    await container
        .read(charactersControllerProvider(projectId).notifier)
        .createFromImage(name: trimmed, sourceAbsolutePath: item.originalPath);
    toast.show(l.gallerySavedAsCharacter, kind: ToastKind.success);
  } on InkError catch (e) {
    toast.show(l10nErrorFor(l, e), kind: ToastKind.error);
  } on CharacterAssetError catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
  } on FileSystemException catch (_) {
    toast.show(l.inspectorCharactersImportFailed, kind: ToastKind.error);
  } finally {
    keep.close();
  }
}

/// 导入一张原图：建成 ⇒ 新节点 id；被跳过 ⇒ null。节点控制器载入失败的 InkError 原样上抛。
Future<String?> _importReference(
  ProviderContainer container, {
  required String canvasId,
  required String projectId,
  required ReferenceItem item,
  required NodePlacement placement,
}) async {
  final MediaImportBatchResult result = await container
      .read(mediaImportControllerProvider(canvasId).notifier)
      .importFiles(
    projectId: projectId,
    requests: <MediaImportRequest>[
      (path: item.originalPath, placement: placement),
    ],
  );
  return result.nodeIds.isEmpty ? null : result.nodeIds.first;
}

/// 在导入的节点上记下「来自参考库的哪一张、什么类别」。
Future<void> _markReference(
  ProviderContainer container, {
  required String canvasId,
  required String nodeId,
  required ReferenceItem item,
}) =>
    container
        .read(canvasNodesControllerProvider(canvasId).notifier)
        .patchTypeConfigMany(<String, Map<String, Object?>>{
      nodeId: <String, Object?>{
        ImportKeys.referenceItemId: item.id,
        ImportKeys.referenceCategory: item.category.name,
      },
    });
