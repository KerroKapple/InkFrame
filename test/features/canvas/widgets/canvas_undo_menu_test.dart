// 空白处右键菜单的撤销 / 重做两行（canvas_menu/undo_menu_items.dart）。
//
// 开菜单照 canvas_create_menu_test「空白处右键 → 空白处右键菜单」：1200×800，(700, 500) 处右键（空白）。
// 置灰的行在面板里是 Opacity(0.5) + 点不动；这里直接读 InkMenuPanel 收到的 InkMenuEntry.enabled，比量透明度稳。
// flutter_test 缺省平台不是 macOS：行尾键位是 Ctrl+Z / Ctrl+Y。
//
// 变异对照：
// - undo_menu_items.dart 的 enabled 改成恒 true ⇒「栈空：两行都在且置灰」「撤销在途：两行都置灰」红；
// - 行名改成恒 commonUndo ⇒「有一步：撤销行写 Undo <步名>」红；
// - menu_registry.dart 里删掉 ...undoBlankMenuItems ⇒ 本文件全红（菜单里没有这两行）。
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_canvas_command.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const String _c1 = 'c1';
const Offset _blank = Offset(700, 500);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: CanvasShortcuts(isActive: true, child: CanvasView()),
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(canvasId: _c1)),
      ),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
    surfaceSize: const Size(1200, 800),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

/// 空白处右键，开空白处右键菜单。
Future<void> _openBlankMenu(WidgetTester tester) async {
  await tester.tapAt(
    _blank,
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  expect(find.byKey(CanvasMenuKeys.blankMenu), findsOneWidget);
}

/// 菜单面板收到的分组。
List<List<InkMenuEntry<String>>> _groups(WidgetTester tester) => tester
    .widget<InkMenuPanel<String>>(find.byKey(CanvasMenuKeys.blankMenu))
    .groups;

/// 菜单里值为 [value] 的那一行。
InkMenuEntry<String> _entry(WidgetTester tester, String value) => _groups(tester)
    .expand((List<InkMenuEntry<String>> g) => g)
    .firstWhere((InkMenuEntry<String> e) => e.value == value);

Finder _inMenu(String text) => find.descendant(
      of: find.byKey(CanvasMenuKeys.blankMenu),
      matching: find.text(text),
    );

void main() {
  testWidgets('栈空：撤销 / 重做两行都在（最上面一组）且置灰', (tester) async {
    await _pump(tester);
    await _openBlankMenu(tester);

    expect(
      _groups(tester).first.map((InkMenuEntry<String> e) => e.value).toList(),
      <String>['blank.undo', 'blank.redo'],
      reason: '组 0 排在最上面',
    );
    expect(_inMenu('Undo'), findsOneWidget);
    expect(_inMenu('Redo'), findsOneWidget);
    expect(_entry(tester, 'blank.undo').enabled, isFalse);
    expect(_entry(tester, 'blank.redo').enabled, isFalse);
    expect(_entry(tester, 'blank.undo').glyph, InkGlyph.undo);
    expect(_entry(tester, 'blank.redo').glyph, isNull, reason: '重做没有镜像图标，留空位');
  });

  testWidgets('有一步：撤销行写「Undo <步名>」、行尾 Ctrl+Z，可点；重做仍灰', (tester) async {
    final ProviderContainer container = await _pump(tester);
    container
        .read(canvasHistoryControllerProvider(_c1).notifier)
        .record(ScriptedCanvasCommand('B', affectedNodeIds: <String>{'b'}));
    await _openBlankMenu(tester);

    expect(_inMenu('Undo B'), findsOneWidget);
    expect(_inMenu('Ctrl+Z'), findsOneWidget);
    expect(_inMenu('Ctrl+Y'), findsOneWidget);
    expect(_entry(tester, 'blank.undo').label, 'Undo B');
    expect(_entry(tester, 'blank.undo').keyHint, 'Ctrl+Z');
    expect(_entry(tester, 'blank.undo').enabled, isTrue);
    expect(_entry(tester, 'blank.redo').label, 'Redo');
    expect(_entry(tester, 'blank.redo').enabled, isFalse);
  });

  testWidgets('点撤销行 ⇒ 菜单关、revert 调一次，之后重做行写「Redo <步名>」', (tester) async {
    final ProviderContainer container = await _pump(tester);
    final ScriptedCanvasCommand cmd =
        ScriptedCanvasCommand('B', affectedNodeIds: <String>{'b'});
    container.read(canvasHistoryControllerProvider(_c1).notifier).record(cmd);
    await _openBlankMenu(tester);

    await tester.tap(_inMenu('Undo B'));
    await tester.pumpAndSettle();

    expect(find.byKey(CanvasMenuKeys.blankMenu), findsNothing);
    expect(cmd.revertCalls, 1);
    expect(cmd.applyCalls, 0);

    await _openBlankMenu(tester);
    expect(_entry(tester, 'blank.undo').enabled, isFalse);
    expect(_entry(tester, 'blank.redo').label, 'Redo B');
    expect(_entry(tester, 'blank.redo').enabled, isTrue);
  });

  testWidgets('撤销在途：栈顶有步，撤销行照样置灰；做完后菜单跟着栈变', (tester) async {
    final ProviderContainer container = await _pump(tester);
    final Completer<CanvasCommandOutcome> pending =
        Completer<CanvasCommandOutcome>();
    final CanvasHistoryController history =
        container.read(canvasHistoryControllerProvider(_c1).notifier);
    history.record(ScriptedCanvasCommand('A'));
    history.record(
      ScriptedCanvasCommand('C', revertScript: <Object>[pending]),
    );
    // 撤 C 并让它悬着 ⇒ busy，undo 栈顶 C 还在。
    final Future<CanvasUndoResult> inFlight = history.undo();
    await tester.pump();
    expect(container.read(canvasHistoryControllerProvider(_c1)).busy, isTrue);

    await _openBlankMenu(tester);
    expect(_entry(tester, 'blank.undo').enabled, isFalse, reason: '栈顶有步，但撤销在途');

    pending.complete(CanvasCommandOutcome.done);
    await inFlight;
    await tester.pumpAndSettle();
    expect(_entry(tester, 'blank.undo').enabled, isTrue, reason: '菜单跟着栈变：A 还在');
    expect(_entry(tester, 'blank.redo').enabled, isTrue, reason: 'C 进了 redo');
  });
}
