// 空白处右键菜单的宽度（W2 验收 #16）：最上面一组是「撤销 / 重做〈步名〉」+ 行尾键位，196 宽时标签只剩约 98px，
// 「Undo Delete 3 nodes」被省略号截断。空白处菜单改与新建菜单同宽（InkMenuPanel.blankMenuWidth = createWidth）；
// 节点菜单与子菜单仍是 blankWidth 196。
//
// 开菜单照 canvas_undo_menu_test：1200×800，(700, 500) 处右键（空白）。标签是 maxLines 1 + ellipsis，
// 截没截断读 RenderParagraph.didExceedMaxLines。
//
// 变异对照：
// - canvas_menu_host.dart 空白处分支的 width 改回 InkMenuPanel.blankWidth ⇒ 本文件两条都红；
// - ink_menu_panel.dart 的 blankMenuWidth 改成 196 ⇒ 本文件两条都红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
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

import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/fake_canvas_command.dart';
import '../../../../_harness/fake_toast_service.dart';
import '../../../../_harness/test_app.dart';

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

Finder _inMenu(String text) => find.descendant(
      of: find.byKey(CanvasMenuKeys.blankMenu),
      matching: find.text(text),
    );

void main() {
  testWidgets('空白处菜单与新建菜单同宽', (tester) async {
    await _pump(tester);
    await _openBlankMenu(tester);

    expect(
      tester
          .widget<InkMenuPanel<String>>(find.byKey(CanvasMenuKeys.blankMenu))
          .width,
      InkMenuPanel.createWidth,
    );
  });

  testWidgets('撤销行带步名：「Undo Delete 3 nodes」完整显示、不出省略号，行尾 Ctrl+Z 在', (tester) async {
    final ProviderContainer container = await _pump(tester);
    container
        .read(canvasHistoryControllerProvider(_c1).notifier)
        .record(ScriptedCanvasCommand('Delete 3 nodes', affectedNodeIds: <String>{'b'}));
    await _openBlankMenu(tester);

    expect(_inMenu('Undo Delete 3 nodes'), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(_inMenu('Undo Delete 3 nodes'))
          .didExceedMaxLines,
      isFalse,
      reason: '196 宽时标签只剩约 98px，这一行会被省略号截断',
    );
    expect(_inMenu('Ctrl+Z'), findsOneWidget);
  });
}
