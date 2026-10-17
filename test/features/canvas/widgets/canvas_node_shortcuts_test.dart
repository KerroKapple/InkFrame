// PR-8b 画布四个新键（shortcuts/core_canvas_keys.dart）：Ctrl+D 复制一份、Ctrl+↵ 生成选中、Shift+1 适应全部、Shift+2 适应选中。
//
//   - 每个键各一条正向用例；
//   - 适应全部：所有卡片都落进视口扣掉留白的那一块；适应选中只框选中的卡（且只缩小、不放大）；
//   - 打字时让位：焦点在文本框里，四个键一概不动画布；
//   - 提示词条里按 Ctrl+↵：只提交一次（提示词条自己那一下），画布这层不跟着再提交。
//   - Ctrl+↵ 走 submitWithPending：还没发射的防抖 patch 并进终稿，不借退出路径的 flushPendingWrites（B8）。
//
// 变异对照：把 shortcuts/core_canvas_keys.dart 里这四条绑定（canvasDuplicate / canvasGenerate / canvasFitAll /
// canvasFitSelection）的 gate 从 CanvasKeyGate.notEditingText 改成 CanvasKeyGate.always ⇒「打字时让位」红；
// generateCanvasSelection 不要求「恰好一张」⇒「选中两张」红；fitSelectedNodes 改框全部 ⇒「适应选中」红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/default_providers.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_tool_actions.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

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

/// 远在初始视口之外的两张文本卡：适应全部之后它们也得在视口里。
const CanvasNode _far = CanvasNode(
  id: 'far',
  label: 'Far',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(3000, 1800),
);
const CanvasNode _west = CanvasNode(
  id: 'west',
  label: 'West',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(-1500, -900),
);

const List<CanvasNode> _nodes = <CanvasNode>[_img, _vid, _far, _west];

/// 视口 1200 × 800 扣掉 kCanvasFitInsets（左右 24、顶 64、底 48）之后的那一块。
const Rect _fitArea = Rect.fromLTRB(24, 64, 1176, 752);

/// 记下 addNode 收到的标签与类型；新节点进内存态（定位请求才落得了地）。
class _Nodes extends CanvasNodesController {
  _Nodes(this._seed);
  final List<CanvasNode> _seed;
  final List<({String label, CanvasNodeType type})> added =
      <({String label, CanvasNodeType type})>[];

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
    added.add((label: label, type: type));
    final CanvasNode node = CanvasNode(
      id: 'new-${added.length}',
      label: label,
      type: type,
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
}

/// 提交：只记调用顺序与终稿。
class _RecordingSubmit extends InspectorSubmitController {
  static final List<String> log = <String>[];
  static final List<Map<String, Object?>> configs = <Map<String, Object?>>[];

  @override
  InspectorSubmitState build(String configNodeId) => const InspectorSubmitIdle();

  @override
  Future<void> flushPendingWrites() async => log.add('flush:$arg');

  @override
  Future<void> submit(Map<String, Object?> finalConfig) async {
    log.add('submit:$arg');
    configs.add(finalConfig);
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<CanvasNode> nodes = _nodes,
  Widget Function(Widget canvas)? around,
}) async {
  const Widget canvas = CanvasView();
  await pumpInkApp(
    tester,
    Scaffold(
      body: CanvasShortcuts(
        isActive: true,
        child: around == null ? canvas : around(canvas),
      ),
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(tab: ShellTab.canvas, canvasId: 'c1')),
      ),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(nodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
      inspectorSubmitControllerProvider.overrideWith(_RecordingSubmit.new),
      // 提示词条的 ⌘↵ 过「配了 Key」这道闸（util/generate_gate.dart）：本文件不看这道闸，一律当已配。
      inspectorHasApiKeyProvider.overrideWith((ref, String providerId) async => true),
    ],
    surfaceSize: const Size(1200, 800),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

_Nodes _nodesOf(ProviderContainer c) =>
    c.read(canvasNodesControllerProvider('c1').notifier) as _Nodes;

void _select(ProviderContainer c, List<String> ids) =>
    c.read(canvasSelectionControllerProvider('c1').notifier).selectAll(ids);

Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

Finder _card(String id) => find.byKey(ValueKey<String>('node-card-$id'));

Future<void> _sendCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> _sendShift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// [r] 整个落在 [area] 里（容差 0.5px）。
bool _inside(Rect r, Rect area) =>
    r.left >= area.left - 0.5 &&
    r.top >= area.top - 0.5 &&
    r.right <= area.right + 0.5 &&
    r.bottom <= area.bottom + 0.5;

void main() {
  setUp(() {
    _RecordingSubmit.log.clear();
    _RecordingSubmit.configs.clear();
  });

  test('前提：画布适应视口的留白就是这一块（顶部让出工具条、底部让出缩放条、左右各一个 lg）', () {
    expect(kCanvasFitInsets.deflateRect(Offset.zero & const Size(1200, 800)), _fitArea);
  });

  group('Ctrl+D 复制一份', () {
    testWidgets('选中一张配置卡：复制一份，新节点被单选', (tester) async {
      final ProviderContainer c = await _pump(tester);
      _select(c, <String>['img']);
      await tester.pump();

      await _sendCtrl(tester, LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();

      expect(_nodesOf(c).added, <({String label, CanvasNodeType type})>[
        (label: 'Shot 01 copy', type: CanvasNodeType.image),
      ]);
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'new-1'});
    });

    testWidgets('没选中：什么都不建', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _sendCtrl(tester, LogicalKeyboardKey.keyD);
      await tester.pumpAndSettle();
      expect(_nodesOf(c).added, isEmpty);
    });
  });

  group('Ctrl+↵ 生成选中', () {
    testWidgets('恰好选中一张可生成的配置卡：提交一次，不走退出路径的 flush', (tester) async {
      final ProviderContainer c = await _pump(tester);
      _select(c, <String>['img']);
      await tester.pump();

      await _sendCtrl(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_RecordingSubmit.log, <String>['submit:img']);
      expect(_RecordingSubmit.configs, <Map<String, Object?>>[<String, Object?>{}],
          reason: '没有挂起的编辑：终稿是空补丁，生成读库里那一行');
    });

    // B8：原来先借退出路径的 flushPendingWrites 冲一笔、再交空补丁——那一笔写失败就按「已用尽」记账、不再重试，
    // 接着 submit 读到库里的旧提示词，白生成一次。现在还没发射的防抖 patch 直接并进终稿一并提交。
    testWidgets('防抖还没发射时按 Ctrl+↵：终稿里带着最新提示词，不调 flushPendingWrites', (tester) async {
      final ProviderContainer c = await _pump(tester);
      _select(c, <String>['img']);
      await tester.pump();
      // 提示词条刚敲完字：防抖窗口还没过，这一笔还没落库。
      c.read(inspectorSubmitControllerProvider('img').notifier).savePromptDebounced('boat at dusk');

      await _sendCtrl(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_RecordingSubmit.log, <String>['submit:img'], reason: '不借退出路径的 flushPendingWrites');
      expect(_RecordingSubmit.configs, <Map<String, Object?>>[
        <String, Object?>{'prompt': 'boat at dusk'},
      ]);
      // 收尾：替身的 submit 不落库，也就没收掉防抖计时器——让它到点走完（替身没跑真 build，那一笔写入是空操作）。
      await tester.pump(InspectorSubmitController.debounceDuration);
    });

    testWidgets('选中两张 / 选中的不能生成：不提交', (tester) async {
      final ProviderContainer c = await _pump(tester);
      _select(c, <String>['img', 'vid']);
      await tester.pump();
      await _sendCtrl(tester, LogicalKeyboardKey.enter);
      _select(c, <String>['far']);
      await tester.pump();
      await _sendCtrl(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_RecordingSubmit.log, isEmpty);
    });
  });

  group('Shift+1 / Shift+2 适应', () {
    testWidgets('Shift+1 适应全部：所有卡片都落进视口扣掉留白的那一块（顶部不压工具条那一条）', (tester) async {
      await _pump(tester);
      expect(
        _inside(tester.getRect(_card('far')), _fitArea),
        isFalse,
        reason: '前提：远处那张一开始不在视口里',
      );

      await _sendShift(tester, LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();

      final double scale = scaleOf(_ivTransform(tester));
      expect(scale, lessThan(1.0));
      expect(scale, greaterThanOrEqualTo(kCanvasMinScale));
      for (final CanvasNode n in _nodes) {
        final Rect r = tester.getRect(_card(n.id));
        expect(_inside(r, _fitArea), isTrue, reason: '${n.id}：$r 应在 $_fitArea 里');
      }
    });

    testWidgets('Shift+2 适应选中：只框选中的那张，且只缩小不放大（一张卡放得下 ⇒ 保持 100%，居中）', (tester) async {
      final ProviderContainer c = await _pump(tester);
      _select(c, <String>['far']);
      await tester.pump();

      await _sendShift(tester, LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();

      expect(scaleOf(_ivTransform(tester)), 1.0, reason: '不放大');
      final Offset center = tester.getRect(_card('far')).center;
      expect(center.dx, closeTo(_fitArea.center.dx, 0.5));
      expect(center.dy, closeTo(_fitArea.center.dy, 0.5));
      expect(
        tester.getRect(_card('west')).overlaps(Offset.zero & const Size(1200, 800)),
        isFalse,
        reason: '没选中的卡不框进来',
      );
    });

    testWidgets('Shift+2 没有选中：相机不动', (tester) async {
      await _pump(tester);
      final Matrix4 before = _ivTransform(tester).clone();

      await _sendShift(tester, LogicalKeyboardKey.digit2);
      await tester.pumpAndSettle();

      expect(_ivTransform(tester), before);
    });

    // KeyMap Q5-B：⌘0 = 缩放到 100%、保持视口中心，不是适应，也不回初始相机。
    // 变异对照：resetCanvasZoom 改回 initialCanvasTransform() ⇒ 中心点断言红。
    testWidgets('⌘0 / Ctrl+0 是 100% 不是适应：适应全部之后按它，scale 回到 1、中心不动', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _sendShift(tester, LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      expect(scaleOf(_ivTransform(tester)), lessThan(1.0), reason: '前提：适应全部缩小了');

      final Size size = c.read(canvasViewportSizeProvider('c1'));
      final Offset center = Offset(size.width / 2, size.height / 2);
      final Offset sceneAtCenter = MatrixUtils.transformPoint(
        Matrix4.inverted(_ivTransform(tester)),
        center,
      );

      await _sendCtrl(tester, LogicalKeyboardKey.digit0);

      final Matrix4 m = _ivTransform(tester);
      expect(scaleOf(m), 1.0);
      final Offset mapped = MatrixUtils.transformPoint(m, sceneAtCenter);
      expect(mapped.dx, closeTo(center.dx, 1e-6));
      expect(mapped.dy, closeTo(center.dy, 1e-6));
      expect(m, isNot(initialCanvasTransform()));
    });

    testWidgets('空白处右键菜单「适应视图」= 适应全部：与 Shift+1 同一个结果，行尾的键位提示是 Shift+1', (tester) async {
      final ProviderContainer c = await _pump(tester);
      await _sendShift(tester, LogicalKeyboardKey.digit1);
      await tester.pumpAndSettle();
      final Matrix4 viaKey = _ivTransform(tester).clone();
      // 前提：相机先回初始相机（⌘0 已是 100% 而非回初始相机，这里直接写控制器）。
      c.read(canvasTransformControllerProvider('c1')).value = initialCanvasTransform();
      await tester.pump();
      expect(_ivTransform(tester), initialCanvasTransform(), reason: '前提：先复位');

      // 右下角是空白（卡片都在左上一带或视口外）。
      await tester.tapAt(
        const Offset(1000, 700),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final Finder blank = find.byKey(CanvasMenuKeys.blankMenu);
      expect(find.descendant(of: blank, matching: find.text('Shift+1')), findsOneWidget);
      await tester.tap(find.descendant(of: blank, matching: find.text('Fit view')));
      await tester.pumpAndSettle();

      expect(_ivTransform(tester), viaKey);
    });
  });

  testWidgets('焦点在文本框里：Ctrl+D / Ctrl+↵ / Shift+1 / Shift+2 一概让给打字，画布不动', (tester) async {
    final TextEditingController field = TextEditingController();
    addTearDown(field.dispose);
    final ProviderContainer c = await _pump(
      tester,
      around: (Widget canvas) => Column(
        children: <Widget>[
          Expanded(child: canvas),
          // 提示词条 / 检查器文本框替身：同处于 CanvasShortcuts 子树内的 EditableText。
          TextField(controller: field),
        ],
      ),
    );
    // 选中一张可生成的配置卡：四个键要是误触发，一定会建节点 / 提交 / 挪相机。
    _select(c, <String>['img']);
    await tester.pump();
    final Matrix4 before = _ivTransform(tester).clone();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue);

    // ↵ 放最后：单行文本框收到回车是它自己的事，别让它影响前面三个键的判定。
    await _sendShift(tester, LogicalKeyboardKey.digit1);
    await _sendShift(tester, LogicalKeyboardKey.digit2);
    await _sendCtrl(tester, LogicalKeyboardKey.keyD);
    await _sendCtrl(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_nodesOf(c).added, isEmpty, reason: 'Ctrl+D 不得复制');
    expect(_RecordingSubmit.log, isEmpty, reason: 'Ctrl+↵ 不得生成');
    expect(_ivTransform(tester), before, reason: 'Shift+1 / Shift+2 不得挪相机');
  });

  testWidgets('提示词条里按 Ctrl+↵：只提交一次——提示词条自己那一下，画布这层不再提交', (tester) async {
    final ProviderContainer c = await _pump(
      tester,
      // 与 canvas_screen 同一种摆法：提示词条浮在舞台底部，同处于 CanvasShortcuts 子树内。
      around: (Widget canvas) => Stack(
        children: <Widget>[
          Positioned.fill(child: canvas),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(child: CanvasPromptBar(canvasId: 'c1')),
          ),
        ],
      ),
    );
    _select(c, <String>['img']);
    await tester.pumpAndSettle();
    final Finder promptField =
        find.descendant(of: find.byType(CanvasPromptBar), matching: find.byType(TextField));
    expect(promptField, findsOneWidget, reason: '前提：选中一张图像配置，提示词条出现');

    await tester.tap(promptField);
    await tester.pumpAndSettle();
    await _sendCtrl(tester, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(_RecordingSubmit.log, <String>['submit:img'], reason: '只有提示词条那一次，画布的生成没跟着触发');
    expect(_RecordingSubmit.configs, <Map<String, Object?>>[
      // 节点没存过供应商：提示词条把判 Key 的那个（默认链落到能力表第一个）一并写进终稿。
      <String, Object?>{'prompt': 'boat at dawn', 'provider_id': kDefaultImageProviderId},
    ]);
  });
}
