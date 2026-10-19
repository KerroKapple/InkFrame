// 泳道标题栏的解散 / 改接线（stage/stage_lane_layer.dart 的 StageLaneLayer）：标题栏解散键 → 不确认、直接
// dissolveLane → 撤销卡；编辑键 → 编辑框 → updateLane；解散失败出 laneDissolveFailed 卡。这几条接线原来挂在
// canvas_view.dart 的舞台层里，一条测试都没有；拆文件时补上。
//
// 「解散最后一条道成功」那条专钉搬家后的 context：道一从泳道 state 里拿掉，舞台骨架就把整个泳道层拆掉（它只在
// 有泳道时挂着），等解散的 future 回来，标题栏的 context / WidgetRef 早已失效——撤销卡要是在 await 之后才按
// context 取通知服务（showCanvasUndoSnack(context, …)），就会在失效的 context 上查祖先而抛错，卡也丢了。
// 假控制器在拿掉道之后停在 [_Lanes.gate] 上，测试先推一帧让泳道层真的卸掉，再放行。
//
// 变异对照：stage_lane_layer 仍走旧确认框 ⇒「点解散键 ⇒ 不弹框」「不弹任何对话框」红；dissolveLaneWithUndo 改成
// await 之后按 context 取通知服务 ⇒「解散最后一条道成功 ⇒ 仍出撤销卡」红；失败不出卡 ⇒「抛 InkError」红；
// onDissolve / onEdit 接线断开 ⇒ 解散 / 改两条红。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/util/lane_dissolve.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/lane_title_bar.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';

import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/fake_toast_service.dart';
import '../../../../_harness/test_app.dart';

// ===== 夹具 =====

/// 两条横向泳道，各 400 厚：Rain 在上，Dusk 在下。
const StyleLane _rain = StyleLane(id: 'lane-1', canvasId: 'c1', label: 'Rain', size: 400);
const StyleLane _dusk = StyleLane(id: 'lane-2', canvasId: 'c1', label: 'Dusk', size: 400, sortOrder: 1);

/// 舞台要有节点才画（没节点是空态画布）：一张无道的文本卡，放在标题栏右边，不压着标题栏的键。
final CanvasNode _free = textNode('t', 'Text', 600);

const String _dissolveTooltip = 'Dissolve lane (keep nodes)';

// ===== 假控制器 =====

typedef _Updated = ({String id, String? label, String? stylePrompt});

/// 泳道：记下 dissolveLane / updateLane 收到了什么。解散与真控制器同一个形状——不是乐观移除：
/// [dissolveError] 非空时 state 不动、抛错；成功时从 state 里拿掉该道，（[gate] 非空时）停在 gate 上，再返回令牌。
class _Lanes extends CanvasLanesController {
  _Lanes(this._seed, {this.dissolveError, this.gate});

  final List<StyleLane> _seed;
  final InkError? dissolveError;
  final Completer<void>? gate;
  final List<String> dissolved = <String>[];
  final List<_Updated> updated = <_Updated>[];

  @override
  Future<List<StyleLane>> build(String canvasId) async => _seed;

  @override
  Future<LaneDissolution?> dissolveLane(
    String laneId, {
    required Map<String, Offset> positions,
  }) async {
    dissolved.add(laneId);
    final InkError? error = dissolveError;
    if (error != null) throw error;
    final List<StyleLane> previous = state.valueOrNull ?? const <StyleLane>[];
    StyleLane? lane;
    for (final StyleLane l in previous) {
      if (l.id == laneId) lane = l;
    }
    if (lane == null) return null;
    state = AsyncData<List<StyleLane>>(<StyleLane>[
      for (final StyleLane l in previous)
        if (l.id != laneId) l,
    ]);
    final Completer<void>? g = gate;
    if (g != null) await g.future;
    return LaneDissolution(lane: lane, nodes: const <LaneNodeSnapshot>[]);
  }

  @override
  Future<void> updateLane(
    String id, {
    String? label,
    String? stylePrompt,
    String? tintColor,
    bool clearTint = false,
    double? size,
  }) async {
    updated.add((id: id, label: label, stylePrompt: stylePrompt));
  }
}

// ===== 装配 =====

Future<ProviderContainer> _pump(WidgetTester tester, _Lanes lanes) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasView()),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(<CanvasNode>[_free])),
      canvasEdgesControllerProvider.overrideWith(FakeEdgesController.new),
      canvasLanesControllerProvider.overrideWith(() => lanes),
      canvasLaneDirectionProvider('c1').overrideWith((_) async => LaneDirection.horizontal),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
    surfaceSize: const Size(1200, 900),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

RecordingToastService _toastOf(ProviderContainer c) =>
    c.read(toastServiceProvider) as RecordingToastService;

/// 点第一条道（Rain）标题栏上的某个键。标题栏挂着 onDoubleTap：单击要等 kDoubleTapTimeout（300ms）
/// 才落地，pumpAndSettle 不推计时器。
Future<void> _tapTitleBarKey(WidgetTester tester, String tooltip) async {
  final Finder key = find.descendant(
    of: find.byType(LaneTitleBar).first,
    matching: find.byTooltip(tooltip),
  );
  expect(key, findsOneWidget);
  await tester.tap(key);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('点解散键 ⇒ 不弹框、dissolveLane 收到 lane-1、出撤销卡', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(const <StyleLane>[_rain, _dusk]);
    final ProviderContainer c = await _pump(tester, lanes);

    await _tapTitleBarKey(tester, _dissolveTooltip);

    expect(find.byType(AlertDialog), findsNothing, reason: '解散不确认');
    expect(lanes.dissolved, <String>['lane-1']);
    expect(find.byType(LaneTitleBar), findsOneWidget, reason: '解散掉的那条道的标题栏不再画');
    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Lane “Rain” dissolved']);
    expect(toast.kinds, <ToastKind>[ToastKind.undo]);
    expect(toast.shown.single.primary?.label, 'Undo');
  });

  testWidgets('点解散键不弹任何对话框（键落地那一刻就已调 dissolveLane）', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(const <StyleLane>[_rain, _dusk]);
    await _pump(tester, lanes);

    final Finder key = find.descendant(
      of: find.byType(LaneTitleBar).first,
      matching: find.byTooltip(_dissolveTooltip),
    );
    await tester.tap(key);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(lanes.dissolved, <String>['lane-1'], reason: '不经任何确认直接解散');
  });

  testWidgets('dissolveLane 抛 InkError ⇒ 出 laneDissolveFailed（error）卡、两条道都在', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(
      const <StyleLane>[_rain, _dusk],
      dissolveError: const LocalIOError(extra: <String, Object?>{'op': 'softDelete'}),
    );
    final ProviderContainer c = await _pump(tester, lanes);

    await _tapTitleBarKey(tester, _dissolveTooltip);

    expect(lanes.dissolved, <String>['lane-1']);
    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Failed to dissolve lane']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(find.byType(LaneTitleBar), findsNWidgets(2), reason: '解散不是乐观移除，失败时两条道都在');
  });

  testWidgets('解散最后一条道成功（泳道层随之卸掉）⇒ 仍出撤销卡', (WidgetTester tester) async {
    final Completer<void> gate = Completer<void>();
    final _Lanes lanes = _Lanes(const <StyleLane>[_rain], gate: gate);
    final ProviderContainer c = await _pump(tester, lanes);

    final Finder key = find.descendant(
      of: find.byType(LaneTitleBar).first,
      matching: find.byTooltip(_dissolveTooltip),
    );
    await tester.tap(key);
    await tester.pump(const Duration(milliseconds: 400)); // 单击落地：道已拿掉，解散停在 gate 上
    await tester.pump(); // 出一帧：没有泳道了，泳道层整个卸掉
    expect(lanes.dissolved, <String>['lane-1']);
    expect(find.byType(LaneTitleBar), findsNothing, reason: '前置：await 回来之前泳道层确实被拆了');

    gate.complete();
    await tester.pumpAndSettle();

    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Lane “Rain” dissolved'], reason: '泳道层被拆过，撤销卡也不能丢');
    expect(toast.kinds, <ToastKind>[ToastKind.undo]);
  });

  testWidgets('标题栏编辑键 → 编辑框；确认 ⇒ updateLane 收到 label / stylePrompt', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(const <StyleLane>[_rain, _dusk]);
    await _pump(tester, lanes);

    await _tapTitleBarKey(tester, 'Edit lane');
    expect(find.text('Edit lane'), findsOneWidget, reason: '编辑框标题');

    final Finder fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(2));
    await tester.enterText(fields.first, 'Day Scene');
    await tester.enterText(fields.at(1), 'warm sunset lighting');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(lanes.updated, hasLength(1));
    expect(lanes.updated.single.id, 'lane-1');
    expect(lanes.updated.single.label, 'Day Scene');
    expect(lanes.updated.single.stylePrompt, 'warm sunset lighting');
  });
}
