// canvas_history_actions：撤销 / 重做执行口的后效（选中、平移、胶囊、失败卡）与纯函数 revealAffectedTransform。
//
// 装置：ProviderContainer；外壳停在画布 c1；节点 = twoNodes（'a' / 'b'，在初始视口里）+ 'far'（远在视口外）；
// 命令用 ScriptedCanvasCommand（label 直接返回名字）。read 传 container.read，l 用 en。
// 节点 / 选中 / 胶囊 / 相机 / 视口尺寸先挂订阅：它们都是 autoDispose，没订阅者时胶囊读不回来、节点只拿得到 AsyncLoading。
//
// 变异对照：
// - revealAffectedTransform 删掉相交判断（恒平移）⇒「与视口相交 ⇒ null」红；
// - 后效里 replace(still) 改成 replace(affected) ⇒「受影响节点有一个已不在 ⇒ 只选还在的」红；
// - 一个都不在时改成 replace(still)（清空选中）⇒「都不在 ⇒ 从原选中里移除、其余不动」红；
// - 删掉 done 分支的胶囊 ⇒「撤销 done：选中受影响节点、出 Undone · <步名> 胶囊」红；
// - failed 分支改成出胶囊 ⇒「failed ⇒ 出 Couldn't undo 错误卡」红；
// - 胶囊不带 dedupeKey ⇒「连按两次 ⇒ 胶囊只留最新一条」红（serial 变了）。
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_history_actions.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/viewport_focus.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_canvas_command.dart';
import '../../../_harness/fake_toast_service.dart';

const String _c1 = 'c1';
const ProjectRef _p1 = ProjectRef(id: 'p1', name: 'P1');

final AppLocalizations _en = lookupAppLocalizations(const Locale('en'));

/// 'a' / 'b' 在初始视口里；'far' 远在视口外。
final List<CanvasNode> _nodes = <CanvasNode>[
  ...twoNodes,
  textNode('far', 'Far', 4000),
];

void main() {
  group('revealAffectedTransform', () {
    test('与视口相交 ⇒ null（部分相交、只贴着视口边都算看得见）', () {
      final Matrix4 current = Matrix4.identity();
      const Size viewport = Size(800, 600);
      expect(
        revealAffectedTransform(
          current: current,
          viewportSize: viewport,
          stageBounds: const Rect.fromLTWH(700, 500, 300, 300),
        ),
        isNull,
        reason: '部分在视口里',
      );
      expect(
        revealAffectedTransform(
          current: current,
          viewportSize: viewport,
          stageBounds: const Rect.fromLTWH(800, 100, 100, 100),
        ),
        isNull,
        reason: '只贴着右边（闭区间）',
      );
    });

    test('完全在视口外 ⇒ 并集中心落到视口中心、缩放不变', () {
      final Matrix4 current = Matrix4.identity()..scaleByDouble(0.5, 0.5, 1.0, 1.0);
      const Size viewport = Size(800, 600);
      const Rect bounds = Rect.fromLTWH(4000, 3000, 200, 100);
      final Matrix4? next = revealAffectedTransform(
        current: current,
        viewportSize: viewport,
        stageBounds: bounds,
      );
      expect(next, isNotNull);
      expect(scaleOf(next!), closeTo(0.5, 1e-9));
      final Offset center = MatrixUtils.transformPoint(next, bounds.center);
      expect(center.dx, closeTo(400, 1e-6));
      expect(center.dy, closeTo(300, 1e-6));
    });

    test('视口尺寸为空 ⇒ null', () {
      expect(
        revealAffectedTransform(
          current: Matrix4.identity(),
          viewportSize: Size.zero,
          stageBounds: const Rect.fromLTWH(4000, 3000, 200, 100),
        ),
        isNull,
      );
    });
  });

  group('后效', () {
    late List<String> log;
    late RecordingToastService toasts;
    late ProviderContainer container;

    setUp(() async {
      log = <String>[];
      toasts = RecordingToastService();
      container = ProviderContainer(overrides: <Override>[
        shellControllerProvider.overrideWith(
          () => ShellNavigator(
            initial: const ShellState(
              tab: ShellTab.canvas,
              canvasId: _c1,
              project: _p1,
            ),
          ),
        ),
        canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_nodes)),
        canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
        toastServiceProvider.overrideWithValue(toasts),
      ]);
      addTearDown(container.dispose);
      container.listen(canvasNodesControllerProvider(_c1), (_, _) {});
      container.listen(canvasLanesControllerProvider(_c1), (_, _) {});
      container.listen(canvasSelectionControllerProvider(_c1), (_, _) {});
      container.listen(canvasCapsuleProvider(_c1), (_, _) {});
      container.listen(canvasTransformControllerProvider(_c1), (_, _) {});
      container.listen(canvasViewportSizeProvider(_c1), (_, _) {});
      await container.read(canvasNodesControllerProvider(_c1).future);
      await container.read(canvasLanesControllerProvider(_c1).future);
    });

    CanvasHistoryController history() =>
        container.read(canvasHistoryControllerProvider(_c1).notifier);

    String record(
      String name, {
      Set<String> affected = const <String>{},
      List<Object> revert = const <Object>[],
    }) =>
        history().record(
          ScriptedCanvasCommand(
            name,
            log: log,
            affectedNodeIds: affected,
            revertScript: revert,
          ),
        );

    Future<CanvasUndoResult> undo() =>
        runCanvasUndo(container.read, canvasId: _c1, l: _en, isMac: false);

    Set<String> selection() =>
        container.read(canvasSelectionControllerProvider(_c1));

    void select(Iterable<String> ids) => container
        .read(canvasSelectionControllerProvider(_c1).notifier)
        .replace(ids);

    CanvasCapsuleMessage? capsule() => container.read(canvasCapsuleProvider(_c1));

    TransformationController camera() =>
        container.read(canvasTransformControllerProvider(_c1));

    void setViewport(Size size) =>
        container.read(canvasViewportSizeProvider(_c1).notifier).setSize(size);

    test('撤销 done：选中受影响节点、出 Undone · <步名> 胶囊（带 Redo + Ctrl+Y）', () async {
      record('A', affected: <String>{'a'});
      record('B', affected: <String>{'b'});
      select(<String>['a']);

      final CanvasUndoResult r = await undo();

      expect(r.status, CanvasUndoStatus.done);
      expect(log, <String>['revert:B']);
      expect(selection(), <String>{'b'});
      final CanvasCapsuleMessage? m = capsule();
      expect(m, isNotNull);
      expect(m!.text, 'Undone · B');
      expect(m.kind, CanvasCapsuleKind.action);
      expect(m.dedupeKey, kCanvasHistoryCapsuleKey);
      expect(m.actionLabel, 'Redo');
      expect(m.actionHint, 'Ctrl+Y');
      expect(toasts.shown, isEmpty, reason: '反馈只走胶囊');
    });

    test('macOS：胶囊的键位提示是 ⇧⌘Z', () async {
      record('B', affected: <String>{'b'});
      await runCanvasUndo(container.read, canvasId: _c1, l: _en, isMac: true);
      expect(capsule()!.actionHint, '⇧⌘Z');
    });

    test('点胶囊上的 Redo ⇒ 重做那一步，胶囊换成 Redone · <步名>（带 Undo + Ctrl+Z）', () async {
      record('B', affected: <String>{'b'});
      await undo();

      capsule()!.onAction!();
      await pumpEventQueue();

      expect(log, <String>['revert:B', 'apply:B']);
      final CanvasCapsuleMessage m = capsule()!;
      expect(m.text, 'Redone · B');
      expect(m.actionLabel, 'Undo');
      expect(m.actionHint, 'Ctrl+Z');
      expect(history().nextUndo?.command.label(_en), 'B');
    });

    test('受影响节点有一个已不在 ⇒ 只选还在的', () async {
      record('Del', affected: <String>{'a', 'gone'});
      select(<String>['b']);

      await undo();

      expect(selection(), <String>{'a'});
    });

    test('受影响节点都不在 ⇒ 只把它们从原选中里移除，其余不动', () async {
      record('Del', affected: <String>{'x', 'y'});
      select(<String>['b', 'x']);

      await undo();

      expect(selection(), <String>{'b'});
    });

    test('受影响节点在视口里 ⇒ 不平移', () async {
      setViewport(const Size(1200, 800));
      final Matrix4 before = camera().value.clone();
      record('A', affected: <String>{'a'});

      await undo();

      expect(camera().value, before);
    });

    test('受影响节点完全在视口外 ⇒ 平移到视口中心、缩放不变', () async {
      setViewport(const Size(1200, 800));
      final double scaleBefore = scaleOf(camera().value);
      final Matrix4 before = camera().value.clone();
      record('Far', affected: <String>{'far'});

      await undo();

      final Matrix4 after = camera().value;
      expect(after, isNot(before), reason: '相机挪了');
      expect(scaleOf(after), closeTo(scaleBefore, 1e-9));
      // 'far' 卡（舞台坐标，与卡片画出来的位置同源）的中心落在视口中心。
      final Offset onScreen = MatrixUtils.transformPoint(
        after,
        _stageRectOf(container, 'far', before).center,
      );
      expect(onScreen.dx, closeTo(600, 1e-6));
      expect(onScreen.dy, closeTo(400, 1e-6));
    });

    test('视口还没上报尺寸 ⇒ 不平移', () async {
      final Matrix4 before = camera().value.clone();
      record('Far', affected: <String>{'far'});

      await undo();

      expect(camera().value, before);
    });

    test('连按两次 ⇒ 胶囊只留最新一条（同 dedupeKey，原地改字）', () async {
      record('A', affected: <String>{'a'});
      record('B', affected: <String>{'b'});

      await undo();
      final int serial =
          container.read(canvasCapsuleProvider(_c1).notifier).serial;
      await undo();

      expect(capsule()!.text, 'Undone · A');
      expect(
        container.read(canvasCapsuleProvider(_c1).notifier).serial,
        serial,
        reason: '同一个 dedupeKey：不换卡',
      );
    });

    test("revert 返回 failed ⇒ 出 Couldn't undo 错误卡、栈顶不变、不出胶囊", () async {
      record('A', affected: <String>{'a'});
      final String b = record(
        'B',
        affected: <String>{'b'},
        revert: <Object>[CanvasCommandOutcome.failed],
      );
      select(<String>['a']);

      final CanvasUndoResult r = await undo();

      expect(r.status, CanvasUndoStatus.failed);
      expect(toasts.titles, <String>["Couldn't undo"]);
      expect(toasts.kinds, <ToastKind>[ToastKind.error]);
      expect(capsule(), isNull);
      expect(history().nextUndo?.id, b, reason: '那一步仍在栈顶');
      expect(selection(), <String>{'a'}, reason: '没做成：选中不动');
    });

    test('gone ⇒ 胶囊 This step can no longer be undone（纯文字），不出卡', () async {
      record('A', affected: <String>{'a'});
      record(
        'B',
        affected: <String>{'b'},
        revert: <Object>[CanvasCommandOutcome.gone],
      );

      final CanvasUndoResult r = await undo();

      expect(r.status, CanvasUndoStatus.gone);
      final CanvasCapsuleMessage m = capsule()!;
      expect(m.text, 'This step can no longer be undone');
      expect(m.kind, CanvasCapsuleKind.text);
      expect(m.actionLabel, isNull);
      expect(toasts.shown, isEmpty);
      expect(log, <String>['revert:B'], reason: '不连带撤下一步');
    });

    test('栈空 ⇒ 静默：不出胶囊、不出卡', () async {
      final CanvasUndoResult r = await undo();

      expect(r.status, CanvasUndoStatus.empty);
      expect(capsule(), isNull);
      expect(toasts.shown, isEmpty);
    });

    test('撤销在途再按 ⇒ busy，静默', () async {
      final Completer<CanvasCommandOutcome> pending =
          Completer<CanvasCommandOutcome>();
      record('B', affected: <String>{'b'}, revert: <Object>[pending]);

      final Future<CanvasUndoResult> first = undo();
      final CanvasUndoResult second = await undo();

      expect(second.status, CanvasUndoStatus.busy);
      expect(capsule(), isNull);
      expect(toasts.shown, isEmpty);

      pending.complete(CanvasCommandOutcome.done);
      expect((await first).status, CanvasUndoStatus.done);
      expect(capsule()!.text, 'Undone · B');
    });

    test('按步撤销栈中间那一步 ⇒ 只撤那一步，胶囊不带 Redo（它没进 redo 栈）', () async {
      final String a = record('A', affected: <String>{'a'});
      record('B', affected: <String>{'b'});

      final CanvasUndoResult r = await runCanvasUndoStep(
        container.read,
        canvasId: _c1,
        stepId: a,
        l: _en,
        isMac: false,
      );

      expect(r.status, CanvasUndoStatus.done);
      expect(log, <String>['revert:A']);
      expect(selection(), <String>{'a'});
      final CanvasCapsuleMessage m = capsule()!;
      expect(m.text, 'Undone · A');
      expect(m.actionLabel, isNull);
      expect(m.onAction, isNull);
    });
  });

  test('canvasUndoMenuLabel / canvasRedoMenuLabel：无步 = Undo / Redo，有步带步名', () {
    expect(canvasUndoMenuLabel(_en, null), 'Undo');
    expect(canvasRedoMenuLabel(_en, null), 'Redo');
    final CanvasHistoryStep step = CanvasHistoryStep(
      id: 'c1#1',
      command: ScriptedCanvasCommand('Delete 3 nodes'),
    );
    expect(canvasUndoMenuLabel(_en, step), 'Undo Delete 3 nodes');
    expect(canvasRedoMenuLabel(_en, step), 'Redo Delete 3 nodes');
  });
}

/// [id] 那张卡在舞台坐标下的渲染矩形（无泳道；与卡片 Positioned 同源的 nodeStageRect）。
Rect _stageRectOf(ProviderContainer container, String id, Matrix4 transform) {
  final CanvasNode node = container
      .read(canvasNodesControllerProvider(_c1))
      .requireValue
      .firstWhere((CanvasNode n) => n.id == id);
  return nodeStageRect(
    node: node,
    lanes: const <({String id, double size})>[],
    direction: LaneDirection.horizontal,
    transform: transform,
  );
}
