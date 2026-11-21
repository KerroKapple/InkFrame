// 参考库格子的三个动作（reference_item_actions.dart）：当〈类别〉参考（同类替换）/ 只放进画布 / 存为角色。
//
// 导入、节点、边、角色控制器都换成只记账的假实现：导入不碰磁盘，直接往假节点表里插一张导入的 result 节点；
// applySplice 记下收到的 plan 并按它改内存边集。服务商能力用真实的 kAllProviderCapabilities（wanx-image 上限 1、
// wanx-r2v 上限 3、默认 gemini-image 不收参考图）。
//
// 钉：
//   - 当参考：导入一次（原图绝对路径、落在目标左侧同一行、同一条泳道），两个标记键写进新节点，applySplice 收到
//     1 条新边（新节点 → 目标，data / reference）、0 条删除。
//   - 已挂一张 pose ⇒ removeEdgeIds 恰好是旧那条，旧节点留在画布上；costume 不替换 pose。
//   - 同一张 ⇒ 不导入、不连线，出胶囊「已经是这张」。
//   - 点之前目标被删了 ⇒ 不导入，出「目标已不在」卡（Review Focus 3）；点之前服务商换成不收参考图的（检查器挂起
//     补丁）⇒ 不导入，出原因卡。
//   - applySplice 抛 InkError ⇒ 错误卡，导入的节点还在；导入被跳过 ⇒ 错误卡，不连线。
//   - 只放进画布：导入一次、写标记键、不连线。
//   - 存为角色：取消 ⇒ 不调 createFromImage；确认 ⇒ 用原图绝对路径调。
//
// 变异对照：applySplice 的 removeEdgeIds 换成空集 ⇒「已挂一张 pose」红；去掉动作开头的重新判（改用调用方传进来的
// 旧判据 / 不判）⇒「目标被删了」「挂起补丁」红；删掉 _markReference ⇒「当参考」「只放进画布」红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/import_keys.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/providers.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/reference_item.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/character.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/characters_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_pending_config.dart';
import 'package:inkframe/features/canvas/providers/media_import_controller.dart';
import 'package:inkframe/features/canvas/util/narrative_splice.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/reference_item_actions.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/components/ink_name_dialog.dart';

import '../../../../_harness/fake_toast_service.dart';
import '../../../../_harness/test_app.dart';

// ===== 夹具 =====

ReferenceItem _item(
  String id, {
  ReferenceCategory category = ReferenceCategory.pose,
}) =>
    ReferenceItem(
      id: id,
      category: category,
      name: 'Name $id',
      group: 'g',
      thumbPath: 'D:/lib/thumbs/$id.webp',
      originalPath: 'D:/lib/img/$id.webp',
      searchText: id,
    );

final ReferenceItem _pose1 = _item('pose-1');
final ReferenceItem _pose2 = _item('pose-2');
final ReferenceItem _portrait = _item('por-1', category: ReferenceCategory.portrait);

/// 选中的目标：wanx-image（收 1 张参考图），在泳道 lane-1 里。
const CanvasNode _cfg = CanvasNode(
  id: 'cfg',
  label: 'Shot 01',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  laneId: 'lane-1',
  position: Offset(600, 200),
  typeConfig: <String, Object?>{'provider_id': 'wanx-image'},
);

/// 已经从参考库挂上去的一张导入图。
CanvasNode _imported(String id, {required String refId, required ReferenceCategory category}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      typeConfig: <String, Object?>{
        ImportKeys.origin: ImportKeys.originImport,
        'image_url': 'imports/$id.webp',
        ImportKeys.referenceItemId: refId,
        ImportKeys.referenceCategory: category.name,
      },
    );

CanvasEdge _refEdge(String id, String source, String target) => CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: source,
      targetNodeId: target,
      edgeType: EdgeType.data,
      role: EdgeRole.reference,
    );

// ===== 假控制器 =====

/// 节点：内存态 + 记下收到的 patch。[failPatch] ⇒ patchTypeConfigMany 抛 InkError。
class _Nodes extends CanvasNodesController {
  _Nodes(this._seed);
  final List<CanvasNode> _seed;
  final List<Map<String, Map<String, Object?>>> patches =
      <Map<String, Map<String, Object?>>>[];

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  /// 假导入用：插一张导入的 result 节点。
  String insertImported(MediaImportRequest r) {
    final List<CanvasNode> current = state.valueOrNull ?? const <CanvasNode>[];
    final String id = 'imp-${current.length + 1}';
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      ...current,
      CanvasNode(
        id: id,
        label: id,
        type: CanvasNodeType.image,
        role: NodeRole.result,
        canvasId: arg,
        laneId: r.placement.laneId,
        position: r.placement.world,
        typeConfig: <String, Object?>{
          ImportKeys.origin: ImportKeys.originImport,
          'image_url': 'imports/$id.webp',
        },
      ),
    ]);
    return id;
  }

  /// 测试里删掉一张（模拟点菜单前目标被删）。
  void drop(String id) {
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in state.valueOrNull ?? const <CanvasNode>[])
        if (n.id != id) n,
    ]);
  }

  @override
  Future<void> patchTypeConfigMany(Map<String, Map<String, Object?>> patches) async {
    this.patches.add(patches);
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in state.valueOrNull ?? const <CanvasNode>[])
        if (patches.containsKey(n.id))
          n.copyWith(typeConfig: <String, Object?>{...n.typeConfig, ...patches[n.id]!})
        else
          n,
    ]);
  }
}

/// 边：记下 applySplice 收到的 plan，并按它改内存；[fail] ⇒ 抛 InkError、内存不动。
class _Edges extends CanvasEdgesController {
  _Edges(this._seed, {this.fail = false});
  final List<CanvasEdge> _seed;
  final bool fail;
  final List<SplicePlan> plans = <SplicePlan>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => _seed;

  @override
  Future<SpliceApplied> applySplice(SplicePlan plan) async {
    plans.add(plan);
    if (fail) throw const LocalIOError(extra: <String, Object?>{'op': 'applySplice'});
    final List<CanvasEdge> added = <CanvasEdge>[
      for (int i = 0; i < plan.addEdges.length; i++)
        CanvasEdge(
          id: 'new-e${i + 1}',
          canvasId: arg,
          sourceNodeId: plan.addEdges[i].sourceNodeId,
          targetNodeId: plan.addEdges[i].targetNodeId,
          edgeType: plan.addEdges[i].edgeType,
          role: plan.addEdges[i].role,
          sortOrder: plan.addEdges[i].sortOrder,
        ),
    ];
    state = AsyncData<List<CanvasEdge>>(<CanvasEdge>[
      for (final CanvasEdge e in state.valueOrNull ?? const <CanvasEdge>[])
        if (!plan.removeEdgeIds.contains(e.id)) e,
      ...added,
    ]);
    return (removed: const <CanvasEdge>[], added: added, token: const SpliceUndoToken());
  }
}

class _Lanes extends CanvasLanesController {
  @override
  Future<List<StyleLane>> build(String canvasId) async => const <StyleLane>[];
}

/// 导入：不碰磁盘，记下请求，直接往假节点表里插节点。[skip] ⇒ 全部跳过（原图读不出来）。
class _Import extends MediaImportController {
  _Import({this.skip = false});
  final bool skip;
  final List<MediaImportRequest> requests = <MediaImportRequest>[];

  @override
  Future<MediaImportBatchResult> importFiles({
    required String projectId,
    required List<MediaImportRequest> requests,
  }) async {
    this.requests.addAll(requests);
    if (skip) {
      return (
        nodeIds: const <String>[],
        skipped: <MediaImportSkip>[
          for (final MediaImportRequest r in requests)
            (fileName: r.path, reason: MediaImportSkipReason.unreadable),
        ],
      );
    }
    final _Nodes nodes = ref.read(canvasNodesControllerProvider(arg).notifier) as _Nodes;
    return (
      nodeIds: <String>[for (final MediaImportRequest r in requests) nodes.insertImported(r)],
      skipped: const <MediaImportSkip>[],
    );
  }
}

/// 角色：只记 createFromImage 收到了什么。
class _Characters extends CharactersController {
  final List<({String name, String path})> created = <({String name, String path})>[];

  @override
  Future<List<Character>> build(String projectId) async => const <Character>[];

  @override
  Future<String> createFromImage({
    required String name,
    required String sourceAbsolutePath,
  }) async {
    created.add((name: name, path: sourceAbsolutePath));
    return 'char-1';
  }
}

// ===== 装配 =====

/// 宿主：挂住几个 autoDispose provider（与画布开着时一样），并交出 context / ref 给测试直接调动作。
class _Handle {
  late BuildContext context;
  late WidgetRef ref;
}

class _Host extends ConsumerWidget {
  const _Host(this.handle);
  final _Handle handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(canvasSelectionControllerProvider('c1'));
    ref.watch(canvasNodesControllerProvider('c1'));
    ref.watch(canvasEdgesControllerProvider('c1'));
    ref.watch(canvasCapsuleProvider('c1'));
    handle
      ..context = context
      ..ref = ref;
    return const SizedBox.shrink();
  }
}

typedef _Rig = ({_Handle handle, ProviderContainer container});

Future<_Rig> _pump(
  WidgetTester tester, {
  List<CanvasNode> nodes = const <CanvasNode>[_cfg],
  List<CanvasEdge> edges = const <CanvasEdge>[],
  Set<String> selected = const <String>{'cfg'},
  bool failSplice = false,
  bool skipImport = false,
}) async {
  final _Handle handle = _Handle();
  await pumpInkApp(
    tester,
    Scaffold(body: _Host(handle)),
    overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => _Nodes(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(edges, fail: failSplice)),
      canvasLanesControllerProvider.overrideWith(_Lanes.new),
      mediaImportControllerProvider.overrideWith(() => _Import(skip: skipImport)),
      charactersControllerProvider.overrideWith(_Characters.new),
      preferencesServiceProvider.overrideWithValue(
        InMemoryPreferencesService(const AppPreferences()),
      ),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
  );
  await tester.pumpAndSettle();
  final ProviderContainer c = ProviderScope.containerOf(handle.context, listen: false);
  for (final String id in selected) {
    c.read(canvasSelectionControllerProvider('c1').notifier).select(id, toggle: true);
  }
  await tester.pump();
  return (handle: handle, container: c);
}

_Nodes _nodesOf(ProviderContainer c) =>
    c.read(canvasNodesControllerProvider('c1').notifier) as _Nodes;
_Edges _edgesOf(ProviderContainer c) =>
    c.read(canvasEdgesControllerProvider('c1').notifier) as _Edges;
_Import _importOf(ProviderContainer c) =>
    c.read(mediaImportControllerProvider('c1').notifier) as _Import;
RecordingToastService _toastOf(ProviderContainer c) =>
    c.read(toastServiceProvider) as RecordingToastService;
AppLocalizations _l(_Rig rig) => AppLocalizations.of(rig.handle.context);

Future<void> _attach(_Rig rig, ReferenceItem item) => attachReferenceToSelected(
      rig.handle.context,
      rig.handle.ref,
      canvasId: 'c1',
      projectId: 'p1',
      item: item,
    );

void main() {
  group('当参考', () {
    testWidgets('目标没有参考边：导入一次、写标记键、applySplice 收 1 条新边 0 条删除', (tester) async {
      final _Rig rig = await _pump(tester);
      await _attach(rig, _pose1);

      final _Import import = _importOf(rig.container);
      expect(import.requests, hasLength(1));
      expect(import.requests.single.path, _pose1.originalPath, reason: '导入的是原图');
      expect(
        import.requests.single.placement.world,
        Offset(_cfg.position.dx - kNodeCardSize.width - kResultColumnGap, _cfg.position.dy),
        reason: '落在目标左侧同一行（成片落点反过来）',
      );
      expect(import.requests.single.placement.laneId, 'lane-1', reason: '与目标同一条泳道');

      final CanvasNode created =
          rig.container.read(canvasNodesControllerProvider('c1')).value!.firstWhere((CanvasNode n) => n.id == 'imp-2');
      expect(created.typeConfig[ImportKeys.referenceItemId], 'pose-1');
      expect(created.typeConfig[ImportKeys.referenceCategory], 'pose');

      final List<SplicePlan> plans = _edgesOf(rig.container).plans;
      expect(plans, hasLength(1));
      expect(plans.single.removeEdgeIds, isEmpty);
      expect(plans.single.addEdges, <SpliceEdgeSpec>[
        (
          sourceNodeId: 'imp-2',
          targetNodeId: 'cfg',
          edgeType: EdgeType.data,
          role: EdgeRole.reference,
          sortOrder: 0,
        ),
      ]);
      expect(_toastOf(rig.container).shown, isEmpty, reason: '成功不出卡');
    });

    testWidgets('已挂一张 pose：换一张 ⇒ removeEdgeIds 恰好是旧那条，旧节点留在画布上', (tester) async {
      final _Rig rig = await _pump(
        tester,
        nodes: <CanvasNode>[
          _cfg,
          _imported('old', refId: 'pose-1', category: ReferenceCategory.pose),
        ],
        edges: <CanvasEdge>[_refEdge('e-old', 'old', 'cfg')],
      );
      await _attach(rig, _pose2);

      final SplicePlan plan = _edgesOf(rig.container).plans.single;
      expect(plan.removeEdgeIds, <String>{'e-old'});
      expect(plan.addEdges.single.targetNodeId, 'cfg');
      expect(plan.addEdges.single.sourceNodeId, isNot('old'));
      expect(
        rig.container.read(canvasNodesControllerProvider('c1')).value!.map((CanvasNode n) => n.id),
        contains('old'),
        reason: '旧导入节点不删',
      );
      expect(
        rig.container.read(canvasEdgesControllerProvider('c1')).value!.map((CanvasEdge e) => e.id),
        isNot(contains('e-old')),
      );
    });

    testWidgets('pose 与 costume 互不替换：已挂 costume，再当 pose 参考 ⇒ 不删 costume 那条', (tester) async {
      final _Rig rig = await _pump(
        tester,
        nodes: <CanvasNode>[
          const CanvasNode(
            id: 'cfg',
            label: 'Shot 01',
            type: CanvasNodeType.video,
            canvasId: 'c1',
            typeConfig: <String, Object?>{'provider_id': 'wanx-r2v'},
          ),
          _imported('coat', refId: 'cos-1', category: ReferenceCategory.costume),
        ],
        edges: <CanvasEdge>[_refEdge('e-coat', 'coat', 'cfg')],
      );
      await _attach(rig, _pose1);

      final SplicePlan plan = _edgesOf(rig.container).plans.single;
      expect(plan.removeEdgeIds, isEmpty);
      expect(plan.addEdges, hasLength(1));
    });

    testWidgets('同一张已经挂着 ⇒ 不导入、不连线，出胶囊「已经是这张」', (tester) async {
      final _Rig rig = await _pump(
        tester,
        nodes: <CanvasNode>[
          _cfg,
          _imported('old', refId: 'pose-1', category: ReferenceCategory.pose),
        ],
        edges: <CanvasEdge>[_refEdge('e-old', 'old', 'cfg')],
      );
      await _attach(rig, _pose1);

      expect(_importOf(rig.container).requests, isEmpty);
      expect(_edgesOf(rig.container).plans, isEmpty);
      expect(rig.container.read(canvasCapsuleProvider('c1'))?.text, _l(rig).referenceAlreadyAttached);
      expect(_toastOf(rig.container).shown, isEmpty);
      rig.container.read(canvasCapsuleProvider('c1').notifier).dismiss();
    });

    testWidgets('点之前目标被删了 ⇒ 不导入，出「目标已不在」卡（Review Focus 3）', (tester) async {
      final _Rig rig = await _pump(tester);
      // 菜单画出来那一刻目标还在：判据是可用的。
      expect(
        currentReferenceAttachDecision(rig.container.read, canvasId: 'c1', item: _pose1).plan,
        isNotNull,
      );
      _nodesOf(rig.container).drop('cfg');
      await tester.pump();
      await _attach(rig, _pose1);

      expect(_importOf(rig.container).requests, isEmpty);
      expect(_edgesOf(rig.container).plans, isEmpty);
      expect(_toastOf(rig.container).titles, <String>[_l(rig).referenceTargetGone]);
    });

    testWidgets('点之前检查器把服务商换成不收参考图的（挂起补丁）⇒ 不导入，出原因卡', (tester) async {
      final _Rig rig = await _pump(tester);
      // 检查器的补丁是 autoDispose：挂住它（检查器开着时它就活着）。
      final ProviderSubscription<Map<String, Object?>> keep =
          rig.container.listen(inspectorPendingConfigProvider('cfg'), (_, _) {});
      addTearDown(keep.close);
      rig.container
          .read(inspectorPendingConfigProvider('cfg').notifier)
          .merge(<String, Object?>{'provider_id': 'gemini-image'});
      await _attach(rig, _pose1);

      final String gemini = rig.container.read(providerDisplayNamesProvider)['gemini-image']!;
      expect(_importOf(rig.container).requests, isEmpty);
      expect(_toastOf(rig.container).titles, <String>[_l(rig).referenceBlockProviderNoRefs(gemini)]);
      expect(_toastOf(rig.container).kinds, <ToastKind>[ToastKind.info]);
    });

    testWidgets('参考图已满（wanx-image 已有一条普通参考边）⇒ 不导入，出「已满 1 / 1」卡', (tester) async {
      final _Rig rig = await _pump(
        tester,
        nodes: <CanvasNode>[
          _cfg,
          const CanvasNode(
            id: 'plain',
            label: 'plain',
            type: CanvasNodeType.image,
            role: NodeRole.result,
            canvasId: 'c1',
          ),
        ],
        edges: <CanvasEdge>[_refEdge('e-plain', 'plain', 'cfg')],
      );
      await _attach(rig, _pose1);

      expect(_importOf(rig.container).requests, isEmpty);
      expect(_toastOf(rig.container).titles, <String>[_l(rig).referenceBlockBudgetFull(1)]);
    });

    testWidgets('applySplice 抛 InkError ⇒ 错误卡，导入的节点还在', (tester) async {
      final _Rig rig = await _pump(tester, failSplice: true);
      await _attach(rig, _pose1);

      expect(_edgesOf(rig.container).plans, hasLength(1));
      expect(_toastOf(rig.container).titles, <String>[_l(rig).referenceAttachFailed]);
      expect(_toastOf(rig.container).kinds, <ToastKind>[ToastKind.error]);
      expect(
        rig.container.read(canvasNodesControllerProvider('c1')).value!.map((CanvasNode n) => n.id),
        contains('imp-2'),
        reason: '不回滚导入',
      );
    });

    testWidgets('导入被跳过（原图读不出来）⇒ 错误卡，不连线', (tester) async {
      final _Rig rig = await _pump(tester, skipImport: true);
      await _attach(rig, _pose1);

      expect(_importOf(rig.container).requests, hasLength(1));
      expect(_edgesOf(rig.container).plans, isEmpty);
      expect(_toastOf(rig.container).titles, <String>[_l(rig).referenceImportFailed]);
      expect(_toastOf(rig.container).kinds, <ToastKind>[ToastKind.error]);
    });
  });

  group('只放进画布', () {
    testWidgets('导入一次（原图）、写标记键、不连线；没有泳道 ⇒ 不归道', (tester) async {
      final _Rig rig = await _pump(tester, selected: const <String>{});
      await placeReferenceOnCanvas(
        rig.handle.context,
        rig.handle.ref,
        canvasId: 'c1',
        projectId: 'p1',
        item: _pose1,
      );

      final _Import import = _importOf(rig.container);
      expect(import.requests, hasLength(1));
      expect(import.requests.single.path, _pose1.originalPath);
      expect(import.requests.single.placement.laneId, isNull);
      final CanvasNode created =
          rig.container.read(canvasNodesControllerProvider('c1')).value!.firstWhere((CanvasNode n) => n.id == 'imp-2');
      expect(created.typeConfig[ImportKeys.referenceItemId], 'pose-1');
      expect(created.typeConfig[ImportKeys.referenceCategory], 'pose');
      expect(_edgesOf(rig.container).plans, isEmpty);
      expect(_toastOf(rig.container).shown, isEmpty);
    });

    testWidgets('导入被跳过 ⇒ 错误卡', (tester) async {
      final _Rig rig = await _pump(tester, skipImport: true);
      await placeReferenceOnCanvas(
        rig.handle.context,
        rig.handle.ref,
        canvasId: 'c1',
        projectId: 'p1',
        item: _pose1,
      );
      expect(_toastOf(rig.container).titles, <String>[_l(rig).referenceImportFailed]);
      expect(_nodesOf(rig.container).patches, isEmpty);
    });
  });

  group('存为角色', () {
    Future<void> start(_Rig rig) => saveReferenceAsCharacter(
          rig.handle.context,
          rig.handle.ref,
          projectId: 'p1',
          item: _portrait,
        );

    _Characters charactersOf(ProviderContainer c) =>
        c.read(charactersControllerProvider('p1').notifier) as _Characters;

    testWidgets('起名框取消 ⇒ 不调 createFromImage', (tester) async {
      final _Rig rig = await _pump(tester);
      // 角色控制器是 autoDispose：挂住它，测完才读得到记账。
      final ProviderSubscription<AsyncValue<List<Character>>> keep =
          rig.container.listen(charactersControllerProvider('p1'), (_, _) {});
      addTearDown(keep.close);

      final Future<void> done = start(rig);
      await tester.pumpAndSettle();
      expect(find.byType(InkNameDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, _l(rig).commonCancel));
      await tester.pumpAndSettle();
      await done;

      expect(charactersOf(rig.container).created, isEmpty);
      expect(_toastOf(rig.container).shown, isEmpty);
    });

    testWidgets('确认 ⇒ 用原图绝对路径调 createFromImage，出成功卡', (tester) async {
      final _Rig rig = await _pump(tester);
      final ProviderSubscription<AsyncValue<List<Character>>> keep =
          rig.container.listen(charactersControllerProvider('p1'), (_, _) {});
      addTearDown(keep.close);

      final Future<void> done = start(rig);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: find.byType(InkNameDialog), matching: find.byType(TextField)),
        '  Heroine  ',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, _l(rig).characterSave));
      await tester.pumpAndSettle();
      await done;

      expect(
        charactersOf(rig.container).created,
        <({String name, String path})>[(name: 'Heroine', path: _portrait.originalPath)],
      );
      expect(_toastOf(rig.container).kinds, <ToastKind>[ToastKind.success]);
    });
  });
}
