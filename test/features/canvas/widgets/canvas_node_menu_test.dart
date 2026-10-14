// 节点右键菜单（PR-8b）接到画布上：canvas_view 的卡片右键 → create_node_menu 的节点菜单 →
// canvas_tool_actions / view_in_sequence / canvas_node_delete 的动作。
//
//   - 右键一张没选中的卡：先单选它，菜单开在按下点；右键已在多选里的卡：保持多选。
//   - 各项的可用 / 置灰（不隐藏）条件。
//   - 生成：先冲挂起的写入，再交空补丁走 submit。
//   - 复制一份：类型 / typeConfig / 泳道 / 偏移 / 标签后缀，新节点单选、不挪相机，不复制边；多选每张配置卡各一份。
//   - 存为角色：起名框 → createFromImage 收到解析出来的绝对路径；没有活动项目时置灰。
//   - 加入泳道 ›：子菜单列出泳道 + 移出泳道，当前那条打勾不可点，moveNode 的参数，多选整批。
//   - 在序列中定位：切到序列标签，播放头跳到那一镜。
//   - 删除：走撤销卡；多选整批。
//
// 变异对照：拿掉任一可用条件 ⇒「可用 / 置灰」组对应的那一条红；_pickNode 只对右键的那张做复制 / 移道 / 删除
// （不看选中集）⇒ 三条「多选」用例红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
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
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/sequence/providers/sequence_playhead.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
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
  _Nodes(this._seed);
  final List<CanvasNode> _seed;

  final List<_Added> added = <_Added>[];
  final List<_Moved> moved = <_Moved>[];
  final List<String> removed = <String>[];

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

/// 角色：只记 createFromImage 收到了什么。
class _RecordingCharacters extends CharactersController {
  static final List<({String projectId, String name, String path})> created =
      <({String projectId, String name, String path})>[];

  @override
  Future<List<Character>> build(String projectId) async => const <Character>[];

  @override
  Future<String> createFromImage({
    required String name,
    required String sourceAbsolutePath,
  }) async {
    created.add((projectId: arg, name: name, path: sourceAbsolutePath));
    return 'char-1';
  }
}

// ===== 装配 =====

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CanvasNode> nodes = _nodes,
  List<CanvasEdge> edges = _chain,
  List<StyleLane> lanes = const <StyleLane>[],
  bool withProject = true,
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
      canvasNodesControllerProvider.overrideWith(() => _Nodes(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => _Edges(edges)),
      canvasLanesControllerProvider.overrideWith(() => _Lanes(lanes)),
      canvasLaneDirectionProvider('c1').overrideWith((_) async => LaneDirection.horizontal),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
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

    testWidgets('右键卡片不开空白处右键菜单；点菜单外面关掉', (tester) async {
      await _pump(tester);
      await _openMenuOn(tester, 'img');
      expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);

      await tester.tapAt(const Offset(1100, 700));
      await tester.pumpAndSettle();
      expect(_menu, findsNothing);
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

  testWidgets('生成：走提示词条那一条 submit——先冲挂起的写入，再交空补丁（提示词以库里那一行为准）', (tester) async {
    await _pump(tester);
    await _openMenuOn(tester, 'img');

    await _pick(tester, 'Generate');

    expect(_RecordingSubmit.log, <String>['flush:img', 'submit:img']);
    expect(_RecordingSubmit.configs, <Map<String, Object?>>[<String, Object?>{}]);
    expect(_menu, findsNothing, reason: '执行之后菜单收起');
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

      expect(_nodesOf(c).removed.toSet(), <String>{'img', 'vid'});
      expect(_toastOf(c).titles, <String>['2 nodes deleted']);
      expect(_toastOf(c).kinds, <ToastKind>[ToastKind.undo]);
    });
  });
}
