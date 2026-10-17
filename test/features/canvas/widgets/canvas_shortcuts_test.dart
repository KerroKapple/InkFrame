// CanvasShortcuts widget 测试（PL-2）：五组键位（Delete / Esc / ⌘A / ⌘± / ⌘0）
// 驱动真实画布 + 焦点链陷阱（Inspector 文本框聚焦时不误伤画布）。
// 浮动工具条之后多了工具单键（V / H / I / G / T / F / L）与按住空格临时平移，
// 同样要过焦点链陷阱：在文本框里打这些字母 / 空格，画布一概不动。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_empty_state.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_shortcuts.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

List<Override> _canvasOverrides(List<CanvasNode> nodes) => <Override>[
  // currentCanvasIdProvider 现是 shellControllerProvider 的派生投影，
  // 本文件要在测试内切换 canvasId（D3/D3+ 用例），因此播种真相源而非
  // override 投影本身——否则 nav.openCanvas('c2') 不会反映到派生值上。
  shellControllerProvider
      .overrideWith(() => ShellNavigator(initial: const ShellState(canvasId: 'c1'))),
  // 记录型：I / G / T 建节点只记类型、不碰仓储（删除 / 撤销沿用 FakeNodesController）。
  canvasNodesControllerProvider.overrideWith(() => RecordingNodesController(nodes)),
  canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
  canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
  fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
  // 删除走通知卡（撤销卡）：记录下来断言，不真起 ToastCenter 的计时器。
  toastServiceProvider.overrideWithValue(RecordingToastService()),
];

/// 画布单独包在 CanvasShortcuts 下，外层再套 CommandPaletteShortcuts——
/// 对齐 app.dart 的生产嵌套（PL-1 全路由外层 ⌘K + canvas_screen 的包裹方式），
/// 这样 isActive:false 场景下才能断言"画布让出的焦点冒泡到了 ⌘K，而非整个键盘失灵"。
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
  Size? surfaceSize,
  bool isActive = true,
}) async {
  await pumpInkApp(
    tester,
    Scaffold(
      body: CommandPaletteShortcuts(
        child: CanvasShortcuts(isActive: isActive, child: const CanvasView()),
      ),
    ),
    overrides: _canvasOverrides(nodes),
    surfaceSize: surfaceSize,
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

/// _pumpToggleable 的返回句柄：container 供断言/驱动 provider，setActive 供翻转 isActive。
/// 不用跨用例共享的 late 全局——避免忘记先 pump 就调用 setter 时抛出难读的
/// LateInitializationError，也避免第二个 toggle 用例互相串味。
typedef _ToggleableHandle =
    ({ProviderContainer container, void Function(bool) setActive});

/// 用 [handle.setActive] 翻转 isActive 并 pump 一帧（不 settle——调用方按需自己 pumpAndSettle）。
Future<void> _setActive(
  WidgetTester tester,
  void Function(bool) setActive,
  bool v,
) async {
  setActive(v);
  await tester.pump();
}

/// 与 _pump 同构（同样走 pumpInkApp + ProviderScope.containerOf，不手写 MaterialApp），
/// 唯一区别：CanvasShortcuts 包进 StatefulBuilder，isActive 可在测试中翻转。
Future<_ToggleableHandle> _pumpToggleable(
  WidgetTester tester, {
  required List<CanvasNode> nodes,
  bool initialActive = false,
}) async {
  bool active = initialActive;
  late void Function(bool) setActiveFn;
  await pumpInkApp(
    tester,
    Scaffold(
      body: CommandPaletteShortcuts(
        child: StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setState) {
            setActiveFn = (bool v) => setState(() => active = v);
            return CanvasShortcuts(isActive: active, child: const CanvasView());
          },
        ),
      ),
    ),
    overrides: _canvasOverrides(nodes),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CanvasView)),
  );
  return (container: container, setActive: setActiveFn);
}

/// 通过 InteractiveViewer widget 读当前变换——与 transform provider 是否 family 无关。
Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

/// 发送带 Ctrl 修饰的按键（跨平台注册了 meta+control 双变体）。
Future<void> _sendCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// 发送不带修饰的按键（Delete / Backspace / Esc 等）。
Future<void> _sendKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// 发送带 ⌘/Ctrl 修饰的按键——快捷键表跨平台同时注册了 meta+control 双变体，
/// 测试环境用 Ctrl 变体驱动即可（与 _sendCtrl 一致）。
Future<void> _sendMeta(WidgetTester tester, LogicalKeyboardKey key) =>
    _sendCtrl(tester, key);

/// 当前画布（c1）的记录型节点控制器——I / G / T 建了什么节点从这里读。
RecordingNodesController _recorder(ProviderContainer container) =>
    container.read(canvasNodesControllerProvider('c1').notifier)
        as RecordingNodesController;

void main() {
  testWidgets('Delete 键删除选中节点（复用 PL-4a 删除路径）', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.text('Node A'), findsNothing);
    expect(find.byType(NodeCard), findsOneWidget); // 仅剩 B
    final toast = container.read(toastServiceProvider) as RecordingToastService;
    expect(toast.titles, <String>['Node deleted']);
    expect(toast.kinds, <ToastKind>[ToastKind.undo]); // 撤销入口保留
    expect(toast.shown.single.primary?.label, 'Undo');
  });

  testWidgets('Backspace 键同样删除选中节点', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider('c1').notifier).select('b');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(find.text('Node B'), findsNothing);
  });

  testWidgets('多选 Delete → 批量删除 + 一条批量撤销', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider('c1').notifier).selectAll(
      <String>['a', 'b'],
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byType(NodeCard), findsNothing);
    final toast = container.read(toastServiceProvider) as RecordingToastService;
    expect(toast.titles, <String>['2 nodes deleted']);
    expect(toast.kinds, <ToastKind>[ToastKind.undo]);
    expect(toast.shown.single.primary?.label, 'Undo');
  });

  testWidgets('Esc 清空节点 + 边选择', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    container.read(selectedEdgeControllerProvider('c1').notifier).select('e1');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(canvasSelectionControllerProvider('c1')), isEmpty);
    expect(container.read(selectedEdgeControllerProvider('c1')), isNull);
  });

  testWidgets('Esc 优先退出连线模式，不清空选择', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(linkModeControllerProvider('c1').notifier).start('a');
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(container.read(linkModeControllerProvider('c1')), isNull); // 退出连线
    expect(container.read(canvasSelectionControllerProvider('c1')), {'a'}); // 选择保留
  });

  testWidgets('Ctrl+A 全选当前画布所有节点', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await _sendCtrl(tester, LogicalKeyboardKey.keyA);

    expect(container.read(canvasSelectionControllerProvider('c1')), {'a', 'b'});
  });

  testWidgets('⌘±（Ctrl+= / Ctrl+-）改变缩放变换', (tester) async {
    await _pump(tester, nodes: twoNodes);
    expect(_ivTransform(tester), initialCanvasTransform());

    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    expect(scaleOf(_ivTransform(tester)), greaterThan(1.0));

    final zoomedIn = scaleOf(_ivTransform(tester));
    await _sendCtrl(tester, LogicalKeyboardKey.minus);
    expect(scaleOf(_ivTransform(tester)), lessThan(zoomedIn));
  });

  // KeyMap Q5-B：⌘0 是「缩放到 100%、保持视口中心」，不再跳回初始相机（初始相机常落在空处）。
  // 变异对照：resetCanvasZoom 改回 initialCanvasTransform() ⇒ 中心点断言与 isNot(初始相机) 红。
  testWidgets('⌘0（Ctrl+0）缩放到 100%、保持视口中心', (tester) async {
    final container = await _pump(
      tester,
      nodes: twoNodes,
      surfaceSize: const Size(800, 600),
    );

    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    // 再手动平移一段：保证 100% 之后的相机与初始相机不同（单靠缩放，中心点不动也可能巧合回到原处）。
    final controller = container.read(canvasTransformControllerProvider('c1'));
    controller.value = Matrix4.translationValues(-90, 70, 0)
      ..multiply(controller.value);
    await tester.pump();
    expect(scaleOf(_ivTransform(tester)), greaterThan(1.0));

    final size = container.read(canvasViewportSizeProvider('c1'));
    expect(size, isNot(Size.zero), reason: '前提：视口尺寸已上报');
    final center = Offset(size.width / 2, size.height / 2);
    final sceneAtCenter = MatrixUtils.transformPoint(
      Matrix4.inverted(_ivTransform(tester)),
      center,
    );

    await _sendCtrl(tester, LogicalKeyboardKey.digit0);

    final m = _ivTransform(tester);
    expect(scaleOf(m), 1.0);
    final mapped = MatrixUtils.transformPoint(m, sceneAtCenter);
    expect(mapped.dx, closeTo(center.dx, 1e-6));
    expect(mapped.dy, closeTo(center.dy, 1e-6));
    expect(m, isNot(initialCanvasTransform()));
  });

  // ===== D2：缩放围绕视口中心（viewport size 存活，不自毁复位 Size.zero）=====
  testWidgets('⌘+ 围绕视口中心而非 (0,0)：viewport size 存活', (tester) async {
    final container = await _pump(
      tester,
      nodes: twoNodes,
      surfaceSize: const Size(800, 600),
    );
    // viewport size 已上报且未被 autoDispose 复位。
    final size = container.read(canvasViewportSizeProvider('c1'));
    expect(size, isNot(Size.zero));
    expect(size.width, greaterThan(0));

    await _sendCtrl(tester, LogicalKeyboardKey.equal); // ⌘+
    final m = _ivTransform(tester);
    final scale = scaleOf(m);
    // 围绕视口中心：初始相机 t=-kStageHalf、s=1 → 中心场景点 = cx + kStageHalf，
    // 新平移 tx = cx(1-scale) - kStageHalf*scale；若支点落 (0,0) 则 tx==-kStageHalf*scale。
    final cx = size.width / 2;
    final expectedTx = cx * (1 - scale) - kStageHalf * scale;
    expect(m.storage[12], closeTo(expectedTx, 1e-3));
    expect(
      (m.storage[12] + kStageHalf * scale).abs(),
      greaterThan(1.0), // 不是 (0,0) 支点
    );
  });

  // ===== 视口尺寸 provider 的生命周期：订阅锚在本层，不再 keepAlive =====
  //
  // 旧实现靠 ref.keepAlive() 挡住"没人 watch ⇒ setSize 后随即自毁复位 Size.zero"，
  // 代价是 family + keepAlive ⇒ **每个开过的 canvasId 永久留一个 entry**（进程级
  // 泄漏，BOARD 债）。现在订阅锚挪到 CanvasShortcuts.build 的那条 watch 上：
  // 它与画布标签同生共死，换画布时旧 canvasId 的 watcher 当场断开 ⇒ entry 随之回收。
  //
  // 上面那条 D2 用例是另一半护栏：锚掉了 ⇒ 尺寸被复位 ⇒ 缩放围绕 (0,0) 当场红。
  // 本用例咬的是反方向——锚在、但范围过大（keepAlive 回来）就永不回收。
  //
  // 【实测变异】把 CanvasViewportSize.build 里的 ref.keepAlive() 加回来
  //   ⇒ Expected: Size(0.0, 0.0)  Actual: Size(800.0, 600.0)
  testWidgets('切换画布 → 旧画布的视口尺寸 entry 被回收，不再常驻', (tester) async {
    final container = await _pump(
      tester,
      nodes: twoNodes,
      surfaceSize: const Size(800, 600),
    );
    // 预热并保活 c2 的节点：理由同 D3——切换瞬间若出现 loading 空档，
    // pumpAndSettle 会卡在 CircularProgressIndicator 上。
    final sub = container.listen(
      canvasNodesControllerProvider('c2'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await tester.pumpAndSettle();

    expect(
      container.read(canvasViewportSizeProvider('c1')),
      isNot(Size.zero),
      reason: '前置：c1 在台上，视口已上报',
    );

    container.read(shellControllerProvider.notifier).openCanvas('c2');
    await tester.pumpAndSettle();

    expect(
      container.read(canvasViewportSizeProvider('c1')),
      Size.zero,
      reason: 'c1 已无人订阅 ⇒ entry 必须随之回收；再读是全新实例（Size.zero）。'
          '读回旧尺寸说明 entry 还在，即每开一张画布就永久多留一份视口尺寸',
    );
  });

  // ===== D3：切换画布不继承旧画布的 pan/zoom（transform 按 canvasId 隔离）=====
  testWidgets('切换画布 → InteractiveViewer 变换复位为初始相机', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    // 预热并保活 c2 的节点：否则切换瞬间出现 loading 空档，InteractiveViewer 短暂卸载，
    // autoDispose 顺带把（非 family 的）共享 transform 复位，反而掩盖了串味 bug。
    // 保活后切换无空档、舞台持续挂载，才能真实暴露"新画布继承旧变换"。
    final sub = container.listen(
      canvasNodesControllerProvider('c2'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await tester.pumpAndSettle();

    // 缩放当前画布 c1。
    await _sendCtrl(tester, LogicalKeyboardKey.equal);
    expect(_ivTransform(tester), isNot(initialCanvasTransform()));

    // 切到 c2（同一 CanvasScreen 常驻，仅换 canvasId；c2 已 AsyncData，无 loading 空档）。
    container.read(shellControllerProvider.notifier).openCanvas('c2');
    await tester.pumpAndSettle();

    expect(
      _ivTransform(tester),
      initialCanvasTransform(),
      reason: '新画布不得继承旧画布的 pan/zoom',
    );
  });

  // ===== D3+：切画布后选中态不跟随（Task 2 评审 Important #1 补测；
  // 原四条 isolation 用例在同一 container 里读两个 family key，Notifier.build()
  // 全是常量返回，family 一旦不坏就恒真——不咬「某调用点传错 canvasId」这唯一的
  // 静默失效模式。本用例驱动真实消费方：c1 选中 → 切 c2 → 按 Delete，
  // 断言 c1 的选中不会在 c2 上把节点删掉。=====
  testWidgets('切换画布 → 旧画布的选中不会跟到新画布，Delete 不误删', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    // 预热并保活 c2 的节点：理由同 D3——切换瞬间若出现 loading 空档，舞台会
    // 短暂卸载，反而掩盖串味 bug（本用例要测的正是"接错线"，不能被空档遮住）。
    final sub = container.listen(
      canvasNodesControllerProvider('c2'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await tester.pumpAndSettle();

    // c1 选中节点 'a'。同时保活 c1 的选中态：不保活的话，autoDispose 会在
    // 没人 watch 它之后把这个 family entry 连同选中值一起清空,即便读错线
    // （改读死 'c1'）也只会读到"刚清空的空集",把本该咬住的 bug 自愈掉——
    // 这正是本用例第一版失败的原因（见 fix report 里的变异验证记录）。
    // 保活模拟 Task 5/6/7 保活宿主落地后的真实世界：c1、c2 会真的同时存活。
    final selectionSub = container.listen(
      canvasSelectionControllerProvider('c1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(selectionSub.close);
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    // 切到 c2（同一 CanvasScreen 常驻，仅换 canvasId；c2 已 AsyncData，无 loading 空档）。
    container.read(shellControllerProvider.notifier).openCanvas('c2');
    await tester.pumpAndSettle();

    expect(
      container.read(canvasSelectionControllerProvider('c2')),
      isEmpty,
      reason: 'c2 是全新画布，不应继承 c1 的选中集',
    );

    // 不点击任何东西，直接按 Delete：c2 上没有真实选中，理应 no-op。
    // 若 deleteCanvasSelection（shortcuts/core_canvas_keys.dart）某处把 canvasId 接错线（例如误读了
    // c1 的选中集，同时仍对当前渲染的 c2 节点表执行删除），'Node A' 会从
    // 屏幕上消失——这是本用例唯一要咬住的静默串味模式。
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(
      find.text('Node A'),
      findsOneWidget,
      reason: 'c2 上没有真实选中，Delete 必须是 no-op；若节点被删，'
          '说明某处误读了 c1 的选中集',
    );
  });

  // ===== D1：生产嵌套下画布仍拿到焦点（PL-1 ⌘K 层在外层）=====
  testWidgets('生产嵌套：CommandPaletteShortcuts 外层时画布仍持焦（Delete 生效 + ⌘K 仍开面板）', (
    tester,
  ) async {
    // 复现 app.dart 的嵌套：命令面板层(autofocus) 包 画布快捷键层。
    await pumpInkApp(
      tester,
      const Scaffold(
        body: CommandPaletteShortcuts(
          child: CanvasShortcuts(isActive: true, child: CanvasView()),
        ),
      ),
      overrides: _canvasOverrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    // 不点击任何东西：Delete 应删除节点（证明画布抢回了焦点，未被 PL-1 autofocus 独占）。
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Node A'), findsNothing);

    // ⌘K 仍冒泡到祖先命令面板层 → 打开面板（证明没弄坏 ⌘K）。
    await _sendCtrl(tester, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
  });

  // ===== 焦点链陷阱（MANDATORY）=====
  testWidgets('焦点在 Inspector 文本框时：Backspace/⌘A 交给文本编辑，不误伤画布', (tester) async {
    final fieldController = TextEditingController(text: 'hello');
    addTearDown(fieldController.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          isActive: true,
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              // Inspector 文本框替身：同处于 CanvasShortcuts 子树内的 EditableText。
              TextField(controller: fieldController),
            ],
          ),
        ),
      ),
      overrides: _canvasOverrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );

    // 选中一个节点（若快捷键误命中会被删/被全选覆盖）。
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    // 焦点移入文本框。
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue); // 主焦点确在 EditableText 内

    // Backspace：应编辑文本，而非删除节点。
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.text('Node A'), findsOneWidget); // 节点未被删
    expect(container.read(canvasSelectionControllerProvider('c1')), {'a'}); // 选择未变

    // ⌘A：应选中框内文本，而非全选画布节点。
    await _sendCtrl(tester, LogicalKeyboardKey.keyA);
    expect(
      container.read(canvasSelectionControllerProvider('c1')),
      {'a'},
      reason: '文本框聚焦时 ⌘A 不得触发画布全选',
    );
  });

  // ===== 保活安全：不可见的画布不得吞 Delete（V2 前半）=====
  testWidgets('isActive:false → Delete 不删节点，且 ⌘K 仍能开命令面板', (tester) async {
    final container = await _pump(tester, nodes: twoNodes, isActive: false);
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pumpAndSettle();

    await _sendKey(tester, LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byType(NodeCard), findsNWidgets(2), reason: '不可见画布不得响应 Delete');

    // 同一帧里 ⌘K 必须仍然可用——证明我们让出的是画布焦点，不是把键盘整个掐死。
    await _sendMeta(tester, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsOneWidget);
  });

  // ===== 保活安全：重新可见时必须自己拿回焦点（V2 后半）=====
  testWidgets('isActive false→true → 不点任何东西，Delete 直接恢复生效', (tester) async {
    final handle = await _pumpToggleable(tester, nodes: twoNodes);
    handle.container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pumpAndSettle();

    await _setActive(tester, handle.setActive, true); // 由 StatefulBuilder 翻转
    await tester.pumpAndSettle(); // 等 post-frame 复焦跑完

    await _sendKey(tester, LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(
      find.byType(NodeCard),
      findsNWidgets(1),
      reason: 'ExcludeFocus 文档明说重新可见不会自动复焦，必须由 didUpdateWidget 的 post-frame 补上',
    );
  });

  // ===== 保活安全：正在用的画布切走不可见后，必须立刻交出焦点（V2 补漏，Important #1）=====
  testWidgets('isActive true→false → Delete 不再删节点', (tester) async {
    final handle = await _pumpToggleable(
      tester,
      nodes: twoNodes,
      initialActive: true,
    );
    handle.container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pumpAndSettle();

    // 先证明画布此刻确实持焦：Delete 应该能删掉节点，否则这条用例什么都没测。
    await _sendKey(tester, LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(
      find.byType(NodeCard),
      findsNWidgets(1),
      reason: '先证明 isActive:true 时画布确实持焦，Delete 有效',
    );

    // 用户正在用画布 → 切到别的标签（isActive 变 false）→ 画布必须交出焦点。
    handle.container.read(canvasSelectionControllerProvider('c1').notifier).select('b');
    await tester.pumpAndSettle();
    await _setActive(tester, handle.setActive, false);
    await tester.pumpAndSettle();

    await _sendKey(tester, LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(
      find.byType(NodeCard),
      findsNWidgets(1),
      reason: '切到不可见标签后，画布必须让出焦点，Delete 不得再生效',
    );
  });

  // ===== 保活安全：不可见时子树内的输入框也不得被聚焦（V2 补漏，Important #1）=====
  // descendantsAreFocusable:false 唯一能被打靶的用例——Inspector 的 TextField 就在
  // CanvasShortcuts 子树内（canvas_screen.dart 把整个 Row 包在 CanvasShortcuts 里）。
  testWidgets('isActive:false 时子树内的 TextField 不得被聚焦', (tester) async {
    final fieldController = TextEditingController(text: 'hello');
    addTearDown(fieldController.dispose);
    final fieldFocusNode = FocusNode(debugLabel: 'inspector-field-stub');
    addTearDown(fieldFocusNode.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          isActive: false,
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              // Inspector 文本框替身：同处于 CanvasShortcuts 子树内的 EditableText。
              TextField(controller: fieldController, focusNode: fieldFocusNode),
            ],
          ),
        ),
      ),
      overrides: _canvasOverrides(twoNodes),
    );
    await tester.pumpAndSettle();

    fieldFocusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(
      fieldFocusNode.hasFocus,
      isFalse,
      reason: 'isActive:false 的 CanvasShortcuts 子树必须整体拒绝聚焦（含 Inspector 输入框），'
          '否则用户正在框里打字时切走标签，焦点会滞留在看不见的界面上',
    );
  });

  // ===== 工具单键（浮动工具条）=====
  testWidgets('H 开 / 关平移工具；V 回到选择工具并退出连线', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await _sendKey(tester, LogicalKeyboardKey.keyH);
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.pan);
    await _sendKey(tester, LogicalKeyboardKey.keyH);
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);

    // 平移中 + 连线中按 V：两样都退掉（选择 = 不在平移、也不在连线）。
    await _sendKey(tester, LogicalKeyboardKey.keyH);
    container.read(linkModeControllerProvider('c1').notifier).start('a');
    await tester.pump();
    await _sendKey(tester, LogicalKeyboardKey.keyV);
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);
    expect(container.read(linkModeControllerProvider('c1')), isNull);
  });

  testWidgets('I / G / T：各建一个 image / video / text 节点（与工具条同一条路径）',
      (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await _sendKey(tester, LogicalKeyboardKey.keyI);
    await _sendKey(tester, LogicalKeyboardKey.keyG);
    await _sendKey(tester, LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();

    expect(_recorder(container).added, <CanvasNodeType>[
      CanvasNodeType.image,
      CanvasNodeType.video,
      CanvasNodeType.text,
    ]);
  });

  testWidgets('F：开「新建泳道」框', (tester) async {
    await _pump(tester, nodes: twoNodes);

    await _sendKey(tester, LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(find.text('New lane'), findsOneWidget);
  });

  testWidgets('L：恰好选中一个节点 → 以它为源进连线；再按退出；没选中时不动', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await _sendKey(tester, LogicalKeyboardKey.keyL);
    expect(
      container.read(linkModeControllerProvider('c1')),
      isNull,
      reason: '没选中节点：不知道从哪个节点连出去',
    );

    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();
    await _sendKey(tester, LogicalKeyboardKey.keyL);
    expect(container.read(linkModeControllerProvider('c1')), 'a');

    await _sendKey(tester, LogicalKeyboardKey.keyL);
    expect(container.read(linkModeControllerProvider('c1')), isNull);
  });

  testWidgets('Esc 在平移工具里 → 回到选择；一次只剥一层，不动选中', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await _sendKey(tester, LogicalKeyboardKey.keyH);
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.pan);

    await _sendKey(tester, LogicalKeyboardKey.escape);

    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);
    expect(container.read(canvasSelectionControllerProvider('c1')), {'a'});
  });

  testWidgets('按住空格 → 实际平移；松开 → 回到原来的工具（工具态始终没变）', (tester) async {
    final container = await _pump(tester, nodes: twoNodes);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(container.read(canvasPanActiveProvider('c1')), isTrue);
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(container.read(canvasPanActiveProvider('c1')), isFalse);
  });

  // ===== 焦点链陷阱：工具单键与空格在文本框里打字时一概让位 =====
  testWidgets('焦点在文本框里：V / H / I / G / T / F / L 与空格都交给打字，画布不动',
      (tester) async {
    final fieldController = TextEditingController();
    addTearDown(fieldController.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          isActive: true,
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              // 提示词条 / 检查器文本框替身：同处于 CanvasShortcuts 子树内的 EditableText。
              TextField(controller: fieldController),
            ],
          ),
        ),
      ),
      overrides: _canvasOverrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );

    // 先切到平移、选中 a：V / H 误命中会把工具切走，L 误命中会以 a 为源进连线。
    container.read(canvasToolModeProvider('c1').notifier).pan();
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue); // 主焦点确在 EditableText 内

    for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.keyI,
      LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyL,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      container.read(canvasSpacePanProvider('c1')),
      isFalse,
      reason: '打字时空格就是空格，不是临时平移',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      container.read(canvasToolModeProvider('c1')),
      CanvasToolMode.pan,
      reason: 'V / H 不得被画布吃掉',
    );
    expect(_recorder(container).added, isEmpty, reason: 'I / G / T 不得建节点');
    expect(find.text('New lane'), findsNothing, reason: 'F 不得开泳道框');
    expect(
      container.read(linkModeControllerProvider('c1')),
      isNull,
      reason: 'L 不得进连线模式',
    );
  });

  testWidgets('打完字再点画布空白：键盘焦点回到画布，单键工具立刻生效', (tester) async {
    final fieldController = TextEditingController();
    addTearDown(fieldController.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          isActive: true,
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              TextField(controller: fieldController),
            ],
          ),
        ),
      ),
      overrides: _canvasOverrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue);

    // 点画布右下角的空白（节点都在左上一带）：文本框失焦，画布要回焦点。
    final Rect stage = tester.getRect(find.byType(CanvasView));
    await tester.tapAt(stage.bottomRight - const Offset(40, 40));
    await tester.pumpAndSettle();
    expect(isEditingText(), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(
      container.read(canvasToolModeProvider('c1')),
      CanvasToolMode.pan,
      reason: '点回画布后 H 应立即切到平移，不该要等切一次标签',
    );
  });


  // B6：没有节点时整块画布换成空态，空态的点击原来只清选中、不把焦点要回来。
  testWidgets('空画布：在输入框里打完字再点空画布，按 I 照样建出节点（焦点回到画布）', (tester) async {
    final fieldController = TextEditingController();
    addTearDown(fieldController.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          isActive: true,
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              // 画布之外的输入框（检查器 / 提示词条替身）。
              TextField(controller: fieldController),
            ],
          ),
        ),
      ),
      overrides: _canvasOverrides(const <CanvasNode>[]),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );
    expect(find.byType(CanvasEmptyState), findsOneWidget, reason: '前提：没有节点，画的是空态');

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue);

    // 点空态左上角的空白（CTA 在正中，横幅从工具条那一条往下才有）。
    final Rect stage = tester.getRect(find.byType(CanvasView));
    await tester.tapAt(stage.topLeft + const Offset(40, 40));
    await tester.pumpAndSettle();
    expect(isEditingText(), isFalse, reason: '点空画布：焦点回到画布');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pumpAndSettle();
    expect(_recorder(container).added, <CanvasNodeType>[CanvasNodeType.image]);
  });

  // B6 延伸：CTA 自己的点击赢了手势竞技场，外层「点空白」收不到——焦点得在按下时就要回来。
  testWidgets('空画布：在输入框里打完字再点 CTA「添加视频节点」，按 I 照样建出节点（焦点回到画布）', (tester) async {
    final fieldController = TextEditingController();
    addTearDown(fieldController.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          isActive: true,
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              TextField(controller: fieldController),
            ],
          ),
        ),
      ),
      overrides: _canvasOverrides(const <CanvasNode>[]),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();
    expect(isEditingText(), isTrue);

    await tester.tap(find.text('Add video node'));
    await tester.pumpAndSettle();
    expect(isEditingText(), isFalse, reason: '按在 CTA 上：焦点回到画布');

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pumpAndSettle();
    expect(
      _recorder(container).added,
      <CanvasNodeType>[CanvasNodeType.video, CanvasNodeType.image],
    );
  });

  testWidgets('焦点在画布里的按钮上：空格是按钮的「激活」，不起临时平移', (tester) async {
    final FocusNode buttonFocus = FocusNode(debugLabel: 'inspector-button');
    addTearDown(buttonFocus.dispose);
    int pressed = 0;

    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasShortcuts(
          isActive: true,
          child: Column(
            children: <Widget>[
              const Expanded(child: CanvasView()),
              // 检查器里的按钮 / 下拉框替身：同处于 CanvasShortcuts 子树内、但不是文本框的可聚焦控件。
              // 空格 → 激活 绑在 WidgetsApp 那层（本层的祖先），画布先拿到事件，不让就截走了。
              TextButton(
                focusNode: buttonFocus,
                onPressed: () => pressed++,
                child: const Text('btn'),
              ),
            ],
          ),
        ),
      ),
      overrides: _canvasOverrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );

    buttonFocus.requestFocus();
    await tester.pump();
    expect(buttonFocus.hasPrimaryFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      container.read(canvasSpacePanProvider('c1')),
      isFalse,
      reason: '按钮持焦时空格不是临时平移',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(pressed, 1, reason: '空格要落到按钮上');
  });

  testWidgets('按住空格时焦点离开画布：临时平移随之收掉，不会卡在平移里', (tester) async {
    final FocusNode outside = FocusNode(debugLabel: 'outside-canvas');
    addTearDown(outside.dispose);

    await pumpInkApp(
      tester,
      Scaffold(
        body: Column(
          children: <Widget>[
            const Expanded(
              child: CanvasShortcuts(isActive: true, child: CanvasView()),
            ),
            // 画布之外的可聚焦控件（外壳标签栏之类）：松开空格的事件冒泡不经过画布层。
            Focus(focusNode: outside, child: const SizedBox(width: 10, height: 10)),
          ],
        ),
      ),
      overrides: _canvasOverrides(twoNodes),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasView)),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(container.read(canvasSpacePanProvider('c1')), isTrue);

    outside.requestFocus();
    await tester.pump();
    expect(
      container.read(canvasSpacePanProvider('c1')),
      isFalse,
      reason: '焦点离开画布后松开事件到不了画布层，只能在失焦时收',
    );

    // 收尾：松开空格，键盘状态归零。
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
  });

}
