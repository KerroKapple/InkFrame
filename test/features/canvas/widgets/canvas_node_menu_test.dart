// 节点右键菜单（PR-8b）接到画布上：卡片插槽（stage/node_card_slot.dart）的右键 → canvas_view 开节点菜单 →
// canvas_menu/node_menu_entries.dart 的各项 → canvas_tool_actions / view_in_sequence / canvas_node_delete 的动作。
//
//   - 右键一张没选中的卡：先单选它，菜单开在按下点；右键已在多选里的卡：保持多选。
//   - 右键在抬起时开；在卡片上按住右键拖动不开菜单、不改选中（B4）。
//   - 菜单开着时右键的卡被删：一项都不出。
//   - 菜单里按一次 Esc 只关菜单、选中保留，再按一次才清选中；按住 Esc 也只关菜单。
//   - 各项的可用 / 置灰（不隐藏）条件。
//   - 生成：走 submitWithPending——还没发射的防抖 patch 并进终稿一并 submit，不借退出路径的 flush（B8）。
//   - 复制一份：类型 / typeConfig / 泳道 / 偏移 / 标签后缀，新节点单选、不挪相机，不复制边；多选每张配置卡各一份。
//   - 存为角色：起名框 → createFromImage 收到解析出来的绝对路径；没有活动项目时置灰。
//   - 加入泳道 ›：子菜单列出泳道 + 移出泳道，当前那条打勾不可点，moveNode 的参数，多选整批。
//   - 在序列中定位：切到序列标签，播放头跳到那一镜。
//   - 删除：走撤销卡；多选一次 removeNodes 整批（失败一张不删、只出失败卡、没有撤销卡），撤销一次 restoreAll。
//     变异：canvas_node_delete.dart 多选分支改回逐个 removeNode ⇒「多选：整批删除」红（batchRemoved 为空）。
//   - 存为角色的起名框一打开就持焦（B1）：不点输入框直接按 Backspace / L / Esc，按键不穿到框后面的画布上。
//   - 失败分支（B10）：复制一份中途写库失败（已复制出来的照样选中 + 错误卡）；存为角色的四种失败（产物路径解析
//     被拒 / 仓储 InkError / 资产服务 CharacterAssetError / 文件系统 FileSystemException）各出对应的错误卡。
//
// 变异对照：拿掉任一可用条件 ⇒「可用 / 置灰」组对应的那一条红；canvas_menu/node_menu_entries.dart 的
// _runDuplicate / _runLaneSubmenu / _runDelete 把 c.targets 换成 {c.request.nodeId!}（只对右键的那张、不看选中集）
// ⇒ 三条「多选」用例红；删掉 buildNodeMenuGroups 里「卡已经不在 ⇒ 空表」那个判断 ⇒「右键的卡被删」红。
// 菜单里 Esc 的两条变异见「菜单里的 Esc」组头注。
import 'dart:io' show File, FileSystemException;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/character_asset_service.dart' show CharacterAssetError;
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/character.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/characters_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/sequence/providers/sequence_playhead.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/components/ink_name_dialog.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/primitives/ink_activatable.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

// ===== 夹具 =====

/// 叙事链 img → vid：第 0 镜是 img（放它的产物 take），第 1 镜是 vid（无产物，按提示词占位）。
const CanvasNode _img = CanvasNode(
  id: 'img',
  label: 'Shot 01',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  position: Offset(40, 40),
  typeConfig: <String, Object?>{'prompt': 'boat at dawn'},
);
const CanvasNode _vid = CanvasNode(
  id: 'vid',
  label: 'Shot 02',
  type: CanvasNodeType.video,
  canvasId: 'c1',
  position: Offset(400, 40),
  typeConfig: <String, Object?>{'prompt': 'pan across the bay'},
);

/// 提示词只有空白的图像配置：不能生成。
const CanvasNode _blank = CanvasNode(
  id: 'blank',
  label: 'Draft',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  position: Offset(760, 40),
  typeConfig: <String, Object?>{'prompt': '   '},
);
const CanvasNode _take = CanvasNode(
  id: 'take',
  label: 'Shot 01 take',
  type: CanvasNodeType.image,
  role: NodeRole.result,
  sourceNodeId: 'img',
  canvasId: 'c1',
  position: Offset(40, 320),
  typeConfig: <String, Object?>{'image_url': 'images/take.png'},
);

/// 不在叙事链上的文本节点。
const CanvasNode _note = CanvasNode(
  id: 'note',
  label: 'Loose note',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(400, 320),
  typeConfig: <String, Object?>{'text': 'not on the chain'},
);

const List<CanvasNode> _nodes = <CanvasNode>[_img, _vid, _blank, _take, _note];

const List<CanvasEdge> _chain = <CanvasEdge>[
  CanvasEdge(
    id: 'n1',
    canvasId: 'c1',
    sourceNodeId: 'img',
    targetNodeId: 'vid',
    edgeType: EdgeType.narrative,
  ),
];

/// 两条横向泳道，各 400 厚：Rain 在上（世界 y 0..400），Dusk 在下。
const List<StyleLane> _twoLanes = <StyleLane>[
  StyleLane(id: 'lane-1', canvasId: 'c1', label: 'Rain', size: 400),
  StyleLane(id: 'lane-2', canvasId: 'c1', label: 'Dusk', size: 400, sortOrder: 1),
];

// ===== 假控制器 =====

typedef _Added = ({
  String label,
  CanvasNodeType type,
  Offset position,
  String? laneId,
  Map<String, Object?> typeConfig,
});

typedef _Moved = ({String id, Offset delta, String? laneId});

/// 节点：增 / 挪 / 删都落在内存态里，并记下收到了什么。新节点 id 依次是 new-1、new-2……
class _Nodes extends CanvasNodesController {
  _Nodes(this._seed, {this.failAddAt, this.failRemoveNodes = false});
  final List<CanvasNode> _seed;

  /// 第几次 addNode（1 起）写库失败、抛 InkError（这一次照样记进 [added]，但不建节点）；null = 不失败。
  final int? failAddAt;

  /// 为真时 removeNodes 整批失败：照样记进 [batchRemoved]，但不改内存、抛 InkError（整批回滚）。
  final bool failRemoveNodes;

  final List<_Added> added = <_Added>[];
  final List<_Moved> moved = <_Moved>[];

  /// 单删（removeNode）收到的 id。
  final List<String> removed = <String>[];

  /// 整批删（removeNodes）每次收到的 id 集合。
  final List<Set<String>> batchRemoved = <Set<String>>[];

  /// restoreAll 被调了几次。
  int restoreAllCalls = 0;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;

  @override
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    String? laneId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    added.add((
      label: label,
      type: type,
      position: position,
      laneId: laneId,
      typeConfig: typeConfig,
    ));
    if (added.length == failAddAt) {
      throw const LocalIOError(extra: <String, Object?>{'op': 'createNode'});
    }
    final CanvasNode node = CanvasNode(
      id: 'new-${added.length}',
      label: label,
      type: type,
      role: role,
      canvasId: arg,
      laneId: laneId,
      position: position,
      typeConfig: typeConfig,
    );
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      ...state.valueOrNull ?? const <CanvasNode>[],
      node,
    ]);
    return node;
  }

  @override
  Future<void> moveNode(String id, Offset delta, {required String? laneId}) async {
    moved.add((id: id, delta: delta, laneId: laneId));
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in state.valueOrNull ?? const <CanvasNode>[])
        if (n.id == id)
          n.copyWith(position: n.position + delta, laneId: laneId, clearLaneId: laneId == null)
        else
          n,
    ]);
  }

  @override
  Future<NodeDeletion?> removeNode(String id) async {
    removed.add(id);
    final List<CanvasNode> previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? gone;
    for (final CanvasNode n in previous) {
      if (n.id == id) gone = n;
    }
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in previous)
        if (n.id != id) n,
    ]);
    final CanvasNode? node = gone;
    return node == null ? null : (node: node, edgeIds: const <String>[]);
  }

  @override
  Future<void> restore(NodeDeletion deletion) async {
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      ...state.valueOrNull ?? const <CanvasNode>[],
      deletion.node,
    ]);
  }

  @override
  Future<List<NodeDeletion>> removeNodes(Set<String> ids) async {
    batchRemoved.add(Set<String>.of(ids));
    if (failRemoveNodes) {
      throw const LocalIOError(extra: <String, Object?>{'op': 'removeNodes'});
    }
    final List<CanvasNode> previous = state.valueOrNull ?? const <CanvasNode>[];
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[
      for (final CanvasNode n in previous)
        if (!ids.contains(n.id)) n,
    ]);
    return <NodeDeletion>[
      for (final String id in ids)
        for (final CanvasNode n in previous)
          if (n.id == id) (node: n, edgeIds: const <String>[]),
    ];
  }

  @override
  Future<int> restoreAll(List<NodeDeletion> deletions) async {
    restoreAllCalls++;
    final List<CanvasNode> previous = state.valueOrNull ?? const <CanvasNode>[];
    final Set<String> present = <String>{for (final CanvasNode n in previous) n.id};
    final List<CanvasNode> back = <CanvasNode>[
      for (final NodeDeletion d in deletions)
        if (present.add(d.node.id)) d.node,
    ];
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[...previous, ...back]);
    return back.length;
  }
}

/// 连线：起始边集由夹具给；记下新建的边（复制一份不该建任何边）。
class _Edges extends CanvasEdgesController {
  _Edges(this._seed);
  final List<CanvasEdge> _seed;
  final List<CanvasEdge> added = <CanvasEdge>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => _seed;

  @override
  Future<CanvasEdge> addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    EdgeType edgeType = EdgeType.data,
    EdgeRole role = EdgeRole.reference,
    EdgeRole Function(List<CanvasEdge> current)? roleResolver,
    int sortOrder = 0,
  }) async {
    final CanvasEdge edge = CanvasEdge(
      id: 'e${added.length + 1}',
      canvasId: arg,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      edgeType: edgeType,
      role: role,
      sortOrder: sortOrder,
    );
    added.add(edge);
    state = AsyncData<List<CanvasEdge>>(<CanvasEdge>[
      ...state.valueOrNull ?? const <CanvasEdge>[],
      edge,
    ]);
    return edge;
  }
}

class _Lanes extends CanvasLanesController {
  _Lanes(this._seed);
  final List<StyleLane> _seed;

  @override
  Future<List<StyleLane>> build(String canvasId) async => _seed;
}

/// 提交：只记调用顺序与终稿，不写库不生成。[busy] 里的节点一建出来就是「生成中」。
class _RecordingSubmit extends InspectorSubmitController {
  static final List<String> log = <String>[];
  static final List<Map<String, Object?>> configs = <Map<String, Object?>>[];
  static Set<String> busy = <String>{};

  @override
  InspectorSubmitState build(String configNodeId) => busy.contains(configNodeId)
      ? const InspectorSubmitRunning()
      : const InspectorSubmitIdle();

  @override
  Future<void> flushPendingWrites() async => log.add('flush:$arg');

  @override
  Future<void> submit(Map<String, Object?> finalConfig) async {
    log.add('submit:$arg');
    configs.add(finalConfig);
  }
}

/// 角色：只记 createFromImage 收到了什么。[failWith] 非空 ⇒ createFromImage 抛它（什么都不建）。
class _RecordingCharacters extends CharactersController {
  static final List<({String projectId, String name, String path})> created =
      <({String projectId, String name, String path})>[];
  static Object? failWith;

  @override
  Future<List<Character>> build(String projectId) async => const <Character>[];

  @override
  Future<String> createFromImage({
    required String name,
    required String sourceAbsolutePath,
  }) async {
    final Object? failure = failWith;
    if (failure != null) throw failure;
    created.add((projectId: arg, name: name, path: sourceAbsolutePath));
    return 'char-1';
  }
}

/// 产物路径解析被拒（越出项目根之类）：resolve 抛 PathSecurityError。
class _RejectingResolver extends StubFileResolver {
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      throw PathSecurityError('outside the project root');
}

// ===== 装配 =====

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CanvasNode> nodes = _nodes,
  List<CanvasEdge> edges = _chain,
  List<StyleLane> lanes = const <StyleLane>[],
  bool withProject = true,
  int? failAddAt,
  bool failRemoveNodes = false,
  FileResolverService? resolver,
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasShortcuts(isActive: true, child: CanvasView())),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: ShellState(
            tab: ShellTab.canvas,
            canvasId: 'c1',
            project: withProject ? const ProjectRef(id: 'p1', name: 'Alpha') : null,
          ),
        ),
      ),
      canvasNodesControllerProvider.overrideWith(
        () => _Nodes(nodes, failAddAt: failAddAt, failRemoveNodes: failRemoveNodes),
      ),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(edges)),
      canvasLanesControllerProvider.overrideWith(() => _Lanes(lanes)),
      canvasLaneDirectionProvider('c1').overrideWith((_) async => LaneDirection.horizontal),
      fileResolverServiceProvider.overrideWithValue(resolver ?? StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
      inspectorSubmitControllerProvider.overrideWith(_RecordingSubmit.new),
      charactersControllerProvider.overrideWith(_RecordingCharacters.new),
    ],
    surfaceSize: const Size(1200, 800),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

_Nodes _nodesOf(ProviderContainer c) =>
    c.read(canvasNodesControllerProvider('c1').notifier) as _Nodes;

_Edges _edgesOf(ProviderContainer c) =>
    c.read(canvasEdgesControllerProvider('c1').notifier) as _Edges;

RecordingToastService _toastOf(ProviderContainer c) =>
    c.read(toastServiceProvider) as RecordingToastService;

Set<String> _selection(ProviderContainer c) =>
    c.read(canvasSelectionControllerProvider('c1'));

Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

Finder _card(String id) => find.byKey(ValueKey<String>('node-card-$id'));

/// 在 [id] 那张卡的中心按右键，返回按下的那一点。
Future<Offset> _openMenuOn(WidgetTester tester, String id) async {
  final Offset at = tester.getCenter(_card(id));
  await tester.tapAt(at, buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  return at;
}

Finder get _menu => find.byKey(CanvasMenuKeys.nodeMenu);
Finder get _submenu => find.byKey(CanvasMenuKeys.submenu);

/// 菜单里文案为 [label] 的那一行（取文案那个 Text：「删除」行尾的键位提示也写着 Delete）。
Finder _item(String label, {Finder? within}) =>
    find.descendant(of: within ?? _menu, matching: find.text(label)).first;

/// 那一行能不能点（置灰的行 onTap 为 null）。
bool _enabled(WidgetTester tester, String label, {Finder? within}) => tester
        .widget<InkActivatable>(
          find.ancestor(of: _item(label, within: within), matching: find.byType(InkActivatable)),
        )
        .onTap !=
    null;

Future<void> _pick(WidgetTester tester, String label, {Finder? within}) async {
  await tester.tap(_item(label, within: within));
  await tester.pumpAndSettle();
}

const List<String> _labels = <String>[
  'Generate',
  'Duplicate',
  'Save as character',
  'Add to lane',
  'Locate in sequence',
  'Delete',
];

void main() {
  setUp(() {
    _RecordingSubmit.log.clear();
    _RecordingSubmit.configs.clear();
    _RecordingSubmit.busy = <String>{};
    _RecordingCharacters.created.clear();
    _RecordingCharacters.failWith = null;
  });

  group('右键开菜单', () {
    testWidgets('右键一张没被选中的卡：先把选中换成它，节点菜单开在按下的那一点，六项按稿的顺序都在', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).select('vid');
      await tester.pump();

      final Offset at = await _openMenuOn(tester, 'img');

      expect(_selection(c), <String>{'img'});
      expect(_menu, findsOneWidget);
      final Offset topLeft = tester.getTopLeft(_menu);
      expect(topLeft.dx, closeTo(at.dx, 0.5));
      expect(topLeft.dy, closeTo(at.dy, 0.5));
      double lastY = -1;
      for (final String label in _labels) {
        final double y = tester.getCenter(_item(label)).dy;
        expect(y, greaterThan(lastY), reason: '$label 的位置不对');
        lastY = y;
      }
      // 键位提示从快捷键表取（测试平台不是 macOS ⇒ Ctrl 变体）。
      expect(find.descendant(of: _menu, matching: find.text('Ctrl+Enter')), findsOneWidget);
      expect(find.descendant(of: _menu, matching: find.text('Ctrl+D')), findsOneWidget);
    });

    testWidgets('右键一张已在多选里的卡：保持多选', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid']);
      await tester.pump();

      await _openMenuOn(tester, 'img');

      expect(_selection(c), <String>{'img', 'vid'});
      expect(_menu, findsOneWidget);
    });

    // B4：原来右键一按下就开菜单——按住右键拖会把画布拖走，菜单还钉在原处。
    testWidgets('在卡片上按住右键拖动：不开节点菜单，选中不变', (tester) async {
      final ProviderContainer c = await _pump(tester);
      final TestGesture drag = await tester.startGesture(
        tester.getCenter(_card('img')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();
      await drag.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(_menu, findsNothing, reason: '按下 / 拖动时都不开');

      await drag.up();
      await tester.pumpAndSettle();
      expect(_menu, findsNothing, reason: '挪出了点击容差：抬起也不开');
      expect(_selection(c), isEmpty, reason: '不是右键单击：不改选中');
    });

    testWidgets('右键卡片不开空白处右键菜单；点菜单外面关掉', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'img');
      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);

      await tester.tapAt(const Offset(1100, 700));
      await tester.pumpAndSettle();
      expect(_menu, findsNothing);
    });

    // 规则 2：菜单开着时右键的那张卡被删（Delete 键 / 撤销 / 别处删掉）⇒ 一项都不出——不能对已删的 id
    // 照常出六项、「删除」还能点。
    testWidgets('菜单开着时右键的卡被删：一项都不出，只剩空行', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _openMenuOn(tester, 'img');
      expect(_item('Delete'), findsOneWidget, reason: '前提：菜单照常出项');

      await _nodesOf(c).removeNode('img');
      await tester.pumpAndSettle();

      expect(_menu, findsOneWidget, reason: '菜单还开着（请求没变）');
      for (final String label in _labels) {
        expect(
          find.descendant(of: _menu, matching: find.text(label)),
          findsNothing,
          reason: '卡已经不在了：$label 不出',
        );
      }
      expect(
        find.descendant(of: _menu, matching: find.text('No matching actions')),
        findsOneWidget,
      );
    });
  });

  // 菜单里的 Esc 只关菜单：面板自己接住 Esc（关菜单、焦点交回画布），不再冒泡给画布的 Esc 阶梯——
  // 右键时设好的选中留着，再按一次 Esc 才清。
  // 变异对照：ink_menu_panel.dart 的 _onKey 里 Esc 那一支改成 dismiss 之后 return KeyEventResult.ignored ⇒
  // 「按一次 Esc 只关菜单」红（Esc 冒泡到画布，阶梯此刻菜单已关、不在打字，落到选中那一层把选中清掉）；
  // shortcuts/core_canvas_keys.dart 的 Esc 激活器去掉 includeRepeats: false ⇒「按住 Esc」红。
  group('菜单里的 Esc', () {
    testWidgets('按一次 Esc 只关菜单、选中保留；再按一次才清选中', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _openMenuOn(tester, 'img');
      expect(_selection(c), <String>{'img'}, reason: '前提：右键先单选了它');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_menu, findsNothing, reason: '第一下关菜单');
      expect(_selection(c), <String>{'img'}, reason: '一次 Esc 只剥菜单这一层');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_selection(c), isEmpty, reason: '焦点回到了画布：第二下清选中');
    });

    testWidgets('按住 Esc（按下 + 若干自动重复）：只关菜单，选中还在', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _openMenuOn(tester, 'img');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_menu, findsNothing);
      for (int i = 0; i < 3; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
        await tester.pump();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_selection(c), <String>{'img'}, reason: '自动重复不接着剥：关菜单之后选中还在');
    });
  });

  group('可用 / 置灰（不隐藏）', () {
    testWidgets('图像配置、提示词不空：生成 / 复制一份 / 在序列中定位 / 删除可点；存为角色置灰；没有泳道 ⇒ 加入泳道置灰',
        (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'img');

      expect(_enabled(tester, 'Generate'), isTrue);
      expect(_enabled(tester, 'Duplicate'), isTrue);
      expect(_enabled(tester, 'Save as character'), isFalse, reason: '不是带图的产物');
      expect(_enabled(tester, 'Add to lane'), isFalse, reason: '画布上没有泳道');
      expect(_enabled(tester, 'Locate in sequence'), isTrue, reason: 'img 是第 0 镜');
      expect(_enabled(tester, 'Delete'), isTrue);
      for (final String label in _labels) {
        expect(_item(label), findsOneWidget, reason: '置灰的项也在（不隐藏）：$label');
      }
    });

    testWidgets('提示词只有空白：生成置灰', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'blank');
      expect(_enabled(tester, 'Generate'), isFalse);
      expect(_enabled(tester, 'Duplicate'), isTrue);
    });

    testWidgets('文本节点：生成置灰；不在叙事链上 ⇒ 在序列中定位置灰', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'note');
      expect(_enabled(tester, 'Generate'), isFalse);
      expect(_enabled(tester, 'Duplicate'), isTrue, reason: '文本卡也是配置节点');
      expect(_enabled(tester, 'Locate in sequence'), isFalse);
    });

    testWidgets('带图的产物：存为角色可点；生成 / 复制一份置灰；产物归到来源那一镜 ⇒ 在序列中定位可点', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'take');
      expect(_enabled(tester, 'Save as character'), isTrue);
      expect(_enabled(tester, 'Generate'), isFalse);
      expect(_enabled(tester, 'Duplicate'), isFalse, reason: '产物不复制');
      expect(_enabled(tester, 'Locate in sequence'), isTrue);
    });

    testWidgets('没有活动项目：存为角色置灰', (tester) async {
      await _pump(tester, withProject: false);
      await _openMenuOn(tester, 'take');
      expect(_enabled(tester, 'Save as character'), isFalse);
    });

    testWidgets('多选两张配置卡：生成置灰（只对恰好一张）', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid']);
      await tester.pump();
      await _openMenuOn(tester, 'img');
      expect(_enabled(tester, 'Generate'), isFalse);
      expect(_enabled(tester, 'Duplicate'), isTrue);
    });

    testWidgets('在忙（生成中）：生成置灰', (tester) async {
      _RecordingSubmit.busy = <String>{'img'};
      await _pump(tester);
      await _openMenuOn(tester, 'img');
      expect(_enabled(tester, 'Generate'), isFalse);
    });

    testWidgets('置灰的项点了不执行、菜单不关', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'note');
      await _pick(tester, 'Generate');
      expect(_RecordingSubmit.log, isEmpty);
      expect(_menu, findsOneWidget);
    });

    testWidgets('删除是危险色', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'img');
      final InkColors colors = tester.element(find.byType(CanvasView)).inkColors;
      expect(tester.widget<Text>(_item('Delete')).style?.color, colors.danger);
    });
  });

  testWidgets('生成：走提示词条那一条 submit——没有挂起的编辑时交空补丁（提示词以库里那一行为准），不调 flush',
      (tester) async {
    await _pump(tester);
    await _openMenuOn(tester, 'img');

    await _pick(tester, 'Generate');

    expect(_RecordingSubmit.log, <String>['submit:img']);
    expect(_RecordingSubmit.configs, <Map<String, Object?>>[<String, Object?>{}]);
    expect(_menu, findsNothing, reason: '执行之后菜单收起');
  });

  // B8：原来先借退出路径的 flushPendingWrites 冲一笔、再交空补丁——那一笔写失败就按「已用尽」记账，接着 submit
  // 读到库里的旧提示词，白生成一次。
  testWidgets('生成：防抖还没发射时，终稿里带着最新提示词', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _openMenuOn(tester, 'img');
    // 提示词条刚敲完字：防抖窗口还没过（开菜单的那几帧已经走过去了，所以放在开菜单之后、点「生成」之前）。
    c.read(inspectorSubmitControllerProvider('img').notifier).savePromptDebounced('boat at dusk');

    await _pick(tester, 'Generate');

    expect(_RecordingSubmit.log, <String>['submit:img'], reason: '不借退出路径的 flushPendingWrites');
    expect(_RecordingSubmit.configs, <Map<String, Object?>>[
      <String, Object?>{'prompt': 'boat at dusk'},
    ]);
    // 收尾：替身的 submit 不落库，也就没收掉防抖计时器——让它到点走完（替身没跑真 build，那一笔写入是空操作）。
    await tester.pump(InspectorSubmitController.debounceDuration);
  });

  group('复制一份', () {
    testWidgets('同类型 / 同 typeConfig / 同泳道、标签加后缀、右下各偏一个 lg；新节点单选、不挪相机，不复制边',
        (tester) async {
      const CanvasNode inLane = CanvasNode(
        id: 'img',
        label: 'Shot 01',
        type: CanvasNodeType.image,
        canvasId: 'c1',
        laneId: 'lane-1',
        position: Offset(40, 40),
        typeConfig: <String, Object?>{'prompt': 'boat at dawn', 'provider_id': 'gemini'},
      );
      final ProviderContainer c = await _pump(
        tester,
        nodes: const <CanvasNode>[inLane, _vid, _take],
        lanes: _twoLanes,
      );
      final Matrix4 cameraBefore = _ivTransform(tester).clone();
      await _openMenuOn(tester, 'img');

      await _pick(tester, 'Duplicate');

      final _Added added = _nodesOf(c).added.single;
      expect(added.type, CanvasNodeType.image);
      expect(added.typeConfig, <String, Object?>{'prompt': 'boat at dawn', 'provider_id': 'gemini'});
      expect(added.laneId, 'lane-1');
      expect(added.label, 'Shot 01 copy');
      expect(added.position, inLane.position + const Offset(InkSpacing.lg, InkSpacing.lg));
      expect(_selection(c), <String>{'new-1'}, reason: '新节点被单选');
      expect(_ivTransform(tester), cameraBefore, reason: '不挪相机');
      expect(_edgesOf(c).added, isEmpty, reason: '不复制边');
    });

    testWidgets('多选：每一张配置卡各复制一份（产物跳过），新的这几张被选中', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid', 'take']);
      await tester.pump();
      await _openMenuOn(tester, 'img');

      await _pick(tester, 'Duplicate');

      expect(
        _nodesOf(c).added.map((_Added a) => a.label),
        <String>['Shot 01 copy', 'Shot 02 copy'],
      );
      expect(_selection(c), <String>{'new-1', 'new-2'});
    });

    // B10：中途写库失败——已经复制出来的照样选中（只出来一张 ⇒ 单选它），弹错误卡。
    testWidgets('多选复制中途写库失败：已经复制出来的那张被单选，弹错误卡「添加节点失败」', (tester) async {
      final ProviderContainer c = await _pump(tester, failAddAt: 2);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid']);
      await tester.pump();
      await _openMenuOn(tester, 'img');

      await _pick(tester, 'Duplicate');

      expect(
        _nodesOf(c).added.map((_Added a) => a.label),
        <String>['Shot 01 copy', 'Shot 02 copy'],
        reason: '第二张也试过，写库失败',
      );
      expect(_selection(c), <String>{'new-1'}, reason: '只复制出来一张：单选它');
      expect(_toastOf(c).titles, <String>['Failed to add node']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.error]);
    });
  });

  group('存为角色', () {
    testWidgets('先弹起名框；确认后 createFromImage 收到名字与产物图片解析出来的绝对路径，出成功卡', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _openMenuOn(tester, 'take');

      await _pick(tester, 'Save as character');
      expect(find.byType(InkNameDialog), findsOneWidget);
      expect(_RecordingCharacters.created, isEmpty, reason: '起名之前什么都不建');

      await tester.enterText(
        find.descendant(of: find.byType(InkNameDialog), matching: find.byType(TextField)),
        '  Hero  ',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final String expected = StubFileResolver()
          .resolve(projectId: 'p1', canvasId: 'c1', relativePath: 'images/take.png')
          .path;
      expect(
        _RecordingCharacters.created,
        <({String projectId, String name, String path})>[
          (projectId: 'p1', name: 'Hero', path: expected),
        ],
      );
      expect(_toastOf(c).titles, <String>['Character saved']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.success]);
    });

    testWidgets('起名框取消：什么都不建', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'take');
      await _pick(tester, 'Save as character');

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(_RecordingCharacters.created, isEmpty);
    });

    // B1：起名框弹出来时主焦点曾被画布要回去（关菜单时还焦点 + 框里没有 autofocus）——Backspace 删掉框后面
    // 选中的卡、L 在画布上进连线、Esc 关不掉框。不点输入框直接发键：enterText 会替我们把焦点给到输入框，
    // 正好把这个问题盖住，所以这里一律不用它。
    testWidgets('起名框一打开就持焦：不点输入框直接按 Backspace / L / Esc——卡还在、没进连线、Esc 关的是框',
        (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _openMenuOn(tester, 'take');
      expect(_selection(c), <String>{'take'}, reason: '前提：右键那张产物卡被单选');

      await _pick(tester, 'Save as character');
      final Finder dialog = find.byType(InkNameDialog);
      expect(dialog, findsOneWidget);
      final Iterable<EditableText> fields = tester.widgetList<EditableText>(
        find.descendant(of: dialog, matching: find.byType(EditableText)),
      );
      expect(
        fields.any((EditableText f) => f.focusNode.hasPrimaryFocus),
        isTrue,
        reason: '主焦点在起名框的输入框里，不在画布上',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(_nodesOf(c).removed, isEmpty, reason: 'Backspace 不得删掉框后面选中的卡');
      expect(_card('take'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pump();
      expect(c.read(linkModeControllerProvider('c1')), isNull, reason: 'L 不得在画布上进连线');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dialog, findsNothing, reason: 'Esc 关的是起名框');
      expect(_selection(c), <String>{'take'}, reason: 'Esc 没落到画布上：选中不变');
      expect(_RecordingCharacters.created, isEmpty);
    });
  });

  // B10：saveNodeAsCharacter 的捕获集 = createFromImage 的真实抛出集 + 产物路径解析；失败一律出错误卡，不建角色。
  group('存为角色：失败分支', () {
    /// 右键产物卡 →「存为角色」→ 起名 → 保存。
    Future<void> saveAs(WidgetTester tester, String name) async {
      await _openMenuOn(tester, 'take');
      await _pick(tester, 'Save as character');
      await tester.enterText(
        find.descendant(of: find.byType(InkNameDialog), matching: find.byType(TextField)),
        name,
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('产物路径解析被拒（PathSecurityError）：不建角色，出「导入角色失败」错误卡', (tester) async {
      final ProviderContainer c = await _pump(tester, resolver: _RejectingResolver());
      await saveAs(tester, 'Hero');

      expect(_RecordingCharacters.created, isEmpty);
      expect(_toastOf(c).titles, <String>['Failed to import character']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.error]);
    });

    testWidgets('createFromImage 抛 InkError：出该错误的本地化文案（错误卡）', (tester) async {
      _RecordingCharacters.failWith = const LocalIOError();
      final ProviderContainer c = await _pump(tester);
      await saveAs(tester, 'Hero');

      expect(_toastOf(c).titles, <String>[
        l10nError(tester.element(find.byType(CanvasView)), const LocalIOError()),
      ]);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.error]);
    });

    testWidgets('createFromImage 抛 CharacterAssetError：出「导入角色失败」错误卡', (tester) async {
      _RecordingCharacters.failWith = const CharacterAssetError('copy failed');
      final ProviderContainer c = await _pump(tester);
      await saveAs(tester, 'Hero');

      expect(_toastOf(c).titles, <String>['Failed to import character']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.error]);
    });

    testWidgets('createFromImage 抛 FileSystemException：出「导入角色失败」错误卡', (tester) async {
      _RecordingCharacters.failWith = const FileSystemException('source vanished');
      final ProviderContainer c = await _pump(tester);
      await saveAs(tester, 'Hero');

      expect(_toastOf(c).titles, <String>['Failed to import character']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.error]);
    });
  });

  group('加入泳道 ›', () {
    /// 第一条道（Rain）里的 img、不在道里的 vid、第二条道（Dusk）里的 d2。
    const CanvasNode inRain = CanvasNode(
      id: 'img',
      label: 'Shot 01',
      type: CanvasNodeType.image,
      canvasId: 'c1',
      laneId: 'lane-1',
      position: Offset(40, 40),
      typeConfig: <String, Object?>{'prompt': 'boat at dawn'},
    );
    const CanvasNode inDusk = CanvasNode(
      id: 'd2',
      label: 'Shot 03',
      type: CanvasNodeType.image,
      canvasId: 'c1',
      laneId: 'lane-2',
      position: Offset(700, 500),
      typeConfig: <String, Object?>{'prompt': 'dusk'},
    );
    const List<CanvasNode> laneNodes = <CanvasNode>[inRain, _vid, inDusk];

    Finder subRow(String label) =>
        find.ancestor(of: _item(label, within: _submenu), matching: find.byType(InkActivatable));

    testWidgets('子菜单列出本画布的泳道 + 移出泳道；当前所在的那条打勾、不可点；点另一条 ⇒ moveNode 带上目标泳道',
        (tester) async {
      final ProviderContainer c = await _pump(tester, nodes: laneNodes, lanes: _twoLanes);
      await _openMenuOn(tester, 'img');
      expect(_enabled(tester, 'Add to lane'), isTrue);

      await _pick(tester, 'Add to lane');

      expect(_submenu, findsOneWidget);
      final List<double> ys = <double>[
        for (final String label in <String>['Rain', 'Dusk', 'Remove from lane'])
          tester.getCenter(_item(label, within: _submenu)).dy,
      ];
      expect(ys, orderedEquals(<double>[...ys]..sort()), reason: '泳道按画布顺序，移出泳道在最后');
      expect(
        find.descendant(
          of: subRow('Rain'),
          matching: find.byWidgetPredicate((Widget w) => w is InkIcon && w.glyph == InkGlyph.success),
        ),
        findsOneWidget,
        reason: '当前所在的那条打勾',
      );
      expect(_enabled(tester, 'Rain', within: _submenu), isFalse);
      expect(_enabled(tester, 'Dusk', within: _submenu), isTrue);
      expect(_enabled(tester, 'Remove from lane', within: _submenu), isTrue);

      await _pick(tester, 'Dusk', within: _submenu);

      // 缩放 1 下 img 的中心画在 135.5，收进 Dusk [400, 800) 的上边内侧：往下挪 360。
      expect(_nodesOf(c).moved, <_Moved>[(id: 'img', delta: const Offset(0, 360), laneId: 'lane-2')]);
      expect(_menu, findsNothing);
      expect(_submenu, findsNothing);
    });

    testWidgets('多选：整批移进去，已经在目标道里的不动', (tester) async {
      final ProviderContainer c = await _pump(tester, nodes: laneNodes, lanes: _twoLanes);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid', 'd2']);
      await tester.pump();
      await _openMenuOn(tester, 'img');
      await _pick(tester, 'Add to lane');

      await _pick(tester, 'Dusk', within: _submenu);

      expect(_nodesOf(c).moved.map((_Moved m) => m.id), <String>['img', 'vid']);
      expect(_nodesOf(c).moved.map((_Moved m) => m.laneId), <String?>['lane-2', 'lane-2']);
    });

    testWidgets('移出泳道：laneId 为 null，屏幕上不挪', (tester) async {
      final ProviderContainer c = await _pump(tester, nodes: laneNodes, lanes: _twoLanes);
      await _openMenuOn(tester, 'img');
      await _pick(tester, 'Add to lane');

      await _pick(tester, 'Remove from lane', within: _submenu);

      expect(_nodesOf(c).moved, <_Moved>[(id: 'img', delta: Offset.zero, laneId: null)]);
    });

    testWidgets('不在任何道里：移出泳道置灰', (tester) async {
      await _pump(tester, nodes: laneNodes, lanes: _twoLanes);
      await _openMenuOn(tester, 'vid');
      await _pick(tester, 'Add to lane');
      expect(_enabled(tester, 'Remove from lane', within: _submenu), isFalse);
    });
  });

  testWidgets('在序列中定位：切到序列标签，播放头跳到那一镜（selectShot，seekToken +1）', (tester) async {
    final ProviderContainer c = await _pump(tester);
    // 画布级 pump 里没有序列屏订阅播放头：这里替它订着，跳转落下来的值才读得回来。
    final ProviderSubscription<SequencePlayhead> keep =
        c.listen(sequencePlayheadProvider('c1'), (_, _) {});
    addTearDown(keep.close);
    await _openMenuOn(tester, 'vid');

    await _pick(tester, 'Locate in sequence');

    expect(c.read(shellControllerProvider).tab, ShellTab.sequence);
    expect(
      c.read(sequencePlayheadProvider('c1')),
      const SequencePlayhead(index: 1, offsetMs: 0, seekToken: 1),
      reason: 'vid 是第 1 镜',
    );
  });

  group('删除', () {
    testWidgets('走带撤销的删除：节点删掉，出「已删除 · 撤销」卡', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _openMenuOn(tester, 'img');

      await _pick(tester, 'Delete');

      expect(_nodesOf(c).removed, <String>['img']);
      expect(_toastOf(c).titles, <String>['Node deleted']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.undo]);
    });

    testWidgets('多选：整批删除，一张批量撤销卡', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid']);
      await tester.pump();
      await _openMenuOn(tester, 'vid');

      await _pick(tester, 'Delete');

      // 一次 removeNodes 整批删（一个事务），不再逐个 removeNode。
      expect(_nodesOf(c).batchRemoved, <Set<String>>[<String>{'img', 'vid'}]);
      expect(_nodesOf(c).removed, isEmpty, reason: '多选不走单删');
      expect(_toastOf(c).titles, <String>['2 nodes deleted']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.undo]);
    });

    testWidgets('多选删除失败 ⇒ 一张不删、只出 Failed to delete node、没有撤销卡', (tester) async {
      final ProviderContainer c = await _pump(tester, failRemoveNodes: true);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid']);
      await tester.pump();
      await _openMenuOn(tester, 'vid');

      await _pick(tester, 'Delete');

      expect(_nodesOf(c).batchRemoved, <Set<String>>[<String>{'img', 'vid'}]);
      expect(_toastOf(c).titles, <String>['Failed to delete node']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.error]);
      expect(_card('img'), findsOneWidget, reason: '整批回滚：两张卡都还在');
      expect(_card('vid'), findsOneWidget, reason: '整批回滚：两张卡都还在');
    });

    testWidgets('多选删除后点撤销 ⇒ restoreAll 恰一次、两张都回来', (tester) async {
      final ProviderContainer c = await _pump(tester);
      c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(<String>['img', 'vid']);
      await tester.pump();
      await _openMenuOn(tester, 'vid');
      await _pick(tester, 'Delete');
      expect(_card('img'), findsNothing);
      expect(_card('vid'), findsNothing);

      // RecordingToastService 不画卡：直接按卡上的「撤销」。
      _toastOf(c).shown.single.primary!.onPressed();
      await tester.pumpAndSettle();

      expect(_nodesOf(c).restoreAllCalls, 1, reason: '多选撤销走一次 restoreAll，不逐个 restore');
      expect(_card('img'), findsOneWidget);
      expect(_card('vid'), findsOneWidget);
    });
  });
}
