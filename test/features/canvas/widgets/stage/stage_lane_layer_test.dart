// 泳道标题栏的删 / 改接线（stage/stage_lane_layer.dart 的 StageLaneLayer）：标题栏删除键 → 确认框 → deleteLane，
// 编辑键 → 编辑框 → updateLane，失败出 laneDeleteFailed 卡。这几条接线原来挂在 canvas_view.dart 的舞台层里，
// 一条测试都没有；拆文件时补上。
//
// 「删最后一条道失败」那条专钉搬家后的 context：真控制器先乐观移除、写库失败再回滚。删的是最后一条道时，
// 乐观移除那一帧舞台骨架把整个泳道层拆掉（它只在有泳道时挂着），等写库失败回来，泳道层的 context 早已失效——
// 失败提示要是还按「context.mounted 才提示」写，这张卡就悄悄没了（原来挂在舞台层上时舞台一直在，没有这个问题）。
//
// 变异对照：拿掉 `if (confirmed != true) return;` ⇒「点取消」红；失败卡改回 await 之后再取 context ⇒
// 「删最后一条道失败」红；onDelete / onEdit 接线断开 ⇒ 删 / 改两条红。
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

// ===== 假控制器 =====

typedef _Updated = ({String id, String? label, String? stylePrompt});

/// 泳道：记下 deleteLane / updateLane 收到了什么。删除与真控制器同一个形状——先乐观移除；
/// [deleteError] 非空时「写库」慢于下一帧（等 50ms），然后回滚、上抛。
class _Lanes extends CanvasLanesController {
  _Lanes(this._seed, {this.deleteError});

  final List<StyleLane> _seed;
  final InkError? deleteError;
  final List<String> deleted = <String>[];
  final List<_Updated> updated = <_Updated>[];

  @override
  Future<List<StyleLane>> build(String canvasId) async => _seed;

  @override
  Future<void> deleteLane(String id) async {
    deleted.add(id);
    final List<StyleLane> previous = state.valueOrNull ?? const <StyleLane>[];
    state = AsyncData<List<StyleLane>>(<StyleLane>[
      for (final StyleLane l in previous)
        if (l.id != id) l,
    ]);
    final InkError? error = deleteError;
    if (error == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = AsyncData<List<StyleLane>>(previous);
    throw error;
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

Finder _dialogButton(String label) => find.widgetWithText(TextButton, label);

void main() {
  testWidgets('标题栏删除键 → 确认框；点删除 ⇒ deleteLane 收到这条道的 id', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(const <StyleLane>[_rain, _dusk]);
    final ProviderContainer c = await _pump(tester, lanes);

    await _tapTitleBarKey(tester, 'Delete lane');
    expect(find.text('Delete this lane?'), findsOneWidget);
    expect(lanes.deleted, isEmpty, reason: '确认之前不删');

    await tester.tap(_dialogButton('Delete lane'));
    await tester.pumpAndSettle();

    expect(lanes.deleted, <String>['lane-1']);
    expect(find.text('Delete this lane?'), findsNothing);
    expect(find.byType(LaneTitleBar), findsOneWidget, reason: '删掉的那条道的标题栏不再画');
    expect(_toastOf(c).shown, isEmpty);
  });

  testWidgets('确认框点取消 ⇒ 不调 deleteLane', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(const <StyleLane>[_rain, _dusk]);
    final ProviderContainer c = await _pump(tester, lanes);

    await _tapTitleBarKey(tester, 'Delete lane');
    expect(find.text('Delete this lane?'), findsOneWidget);

    await tester.tap(_dialogButton('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this lane?'), findsNothing);
    expect(lanes.deleted, isEmpty);
    expect(find.byType(LaneTitleBar), findsNWidgets(2));
    expect(_toastOf(c).shown, isEmpty);
  });

  testWidgets('deleteLane 抛 InkError ⇒ 出 laneDeleteFailed 卡', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(
      const <StyleLane>[_rain, _dusk],
      deleteError: const LocalIOError(extra: <String, Object?>{'op': 'softDelete'}),
    );
    final ProviderContainer c = await _pump(tester, lanes);

    await _tapTitleBarKey(tester, 'Delete lane');
    await tester.tap(_dialogButton('Delete lane'));
    await tester.pumpAndSettle();

    expect(lanes.deleted, <String>['lane-1']);
    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Failed to delete lane']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(find.byType(LaneTitleBar), findsNWidgets(2), reason: '回滚后两条道都还在');
  });

  testWidgets('删最后一条道失败（乐观移除那一帧泳道层被拆掉）⇒ 仍出 laneDeleteFailed 卡', (WidgetTester tester) async {
    final _Lanes lanes = _Lanes(
      const <StyleLane>[_rain],
      deleteError: const LocalIOError(extra: <String, Object?>{'op': 'softDelete'}),
    );
    final ProviderContainer c = await _pump(tester, lanes);

    await _tapTitleBarKey(tester, 'Delete lane');
    await tester.tap(_dialogButton('Delete lane'));
    // 乐观移除后先出一帧：没有泳道了，泳道层整个卸掉。
    await tester.pump();
    expect(find.byType(LaneTitleBar), findsNothing, reason: '前置：乐观移除那一帧泳道层确实被拆了');

    // 写库失败回来：回滚、上抛。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(lanes.deleted, <String>['lane-1']);
    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Failed to delete lane'], reason: '泳道层被拆过，失败卡也不能丢');
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(find.byType(LaneTitleBar), findsOneWidget, reason: '回滚后道回来了');
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
