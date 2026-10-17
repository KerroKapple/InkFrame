// Esc 阶梯在 CanvasShortcuts 上的接线（KeyMap ›「Esc 阶梯」）。
//
// 钉四件事：
//   ① 焦点在子树里的文本框（提示词条 / 检查器 / 左栏筛选框）按 Esc：只失焦，选中与选中的边都不动——
//      改动前 CanvasEscapeIntent 不对文字让位，这一下会把选中清空。
//   ② 失焦后焦点回到画布本身：紧接着按 H 立刻生效（光 unfocus 只会把焦点交给路由作用域）。
//   ③ 无事可剥时 Esc 不被消费，冒泡给祖先；有东西可剥时消费、祖先收不到。
//   ④ 后续切片登记的层（这里用查找条）按层序参与判序，排在选中之前；注销后不再参与。
//
// 变异对照：canvas_shortcuts.dart 里把传给 handle(local:) 的 textField 一项删掉 ⇒ ① 红；
// textField 层 dismiss 里删掉 requestFocus ⇒ ② 红；Esc 绑定的 enabledWhen 改成恒 true ⇒ ③ 红。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_escape_ladder.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/util/escape_ladder.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

List<Override> _canvasOverrides() => <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(canvasId: 'c1')),
      ),
      canvasNodesControllerProvider
          .overrideWith(() => RecordingNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ];

/// 与 canvas_shortcuts_test.dart 的焦点链用例同构：CanvasShortcuts 包 Column[CanvasView, TextField]，
/// TextField 是提示词条 / 检查器文本框的替身（同处于 CanvasShortcuts 子树内的 EditableText）。
/// [onOuterEscape] 非空时外面再套一层 CallbackShortcuts 接 Esc——祖先收没收到冒泡上来的 Esc。
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required TextEditingController field,
  VoidCallback? onOuterEscape,
}) async {
  Widget body = CanvasShortcuts(
    isActive: true,
    child: Column(
      children: <Widget>[
        const Expanded(child: CanvasView()),
        TextField(controller: field),
      ],
    ),
  );
  if (onOuterEscape != null) {
    body = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): onOuterEscape,
      },
      child: body,
    );
  }
  await pumpInkApp(
    tester,
    Scaffold(body: body),
    overrides: _canvasOverrides(),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

/// 选中节点 a + 边 e1，再把焦点放进文本框。
Future<void> _selectThenFocusField(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
  container.read(selectedEdgeControllerProvider('c1').notifier).select('e1');
  await tester.pump();
  await tester.tap(find.byType(TextField));
  await tester.pumpAndSettle();
  expect(isEditingText(), isTrue, reason: '前提：主焦点在文本框里');
}

void main() {
  testWidgets('焦点在输入框里按 Esc：只失焦，选中还在', (tester) async {
    final TextEditingController field = TextEditingController(text: 'hello');
    addTearDown(field.dispose);
    final ProviderContainer container = await _pump(tester, field: field);
    await _selectThenFocusField(tester, container);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(isEditingText(), isFalse, reason: 'Esc 让文本框失焦');
    expect(
      container.read(canvasSelectionControllerProvider('c1')),
      <String>{'a'},
      reason: '这一下只剥输入框这一层，不清选中',
    );
    expect(container.read(selectedEdgeControllerProvider('c1')), 'e1');
    expect(field.text, 'hello', reason: 'Esc 不改文本');
  });

  testWidgets('失焦后焦点回到画布：紧接着按 H 生效；再按 Esc 才清空选中', (tester) async {
    final TextEditingController field = TextEditingController();
    addTearDown(field.dispose);
    final ProviderContainer container = await _pump(tester, field: field);
    await _selectThenFocusField(tester, container);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();

    expect(
      container.read(canvasToolModeProvider('c1')),
      CanvasToolMode.pan,
      reason: '焦点回到画布本身，单键工具立刻生效',
    );
    expect(field.text, isEmpty, reason: 'H 没有打进文本框');

    // 往下按层序继续剥：平移 → 回选择（不动选中）→ 清空选中。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);
    expect(container.read(canvasSelectionControllerProvider('c1')), <String>{'a'});

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(container.read(canvasSelectionControllerProvider('c1')), isEmpty);
    expect(container.read(selectedEdgeControllerProvider('c1')), isNull);
  });

  testWidgets('无事可剥时 Esc 不被消费，冒泡给祖先；有选中时被消费、选中清空', (tester) async {
    final TextEditingController field = TextEditingController();
    addTearDown(field.dispose);
    int outer = 0;
    final ProviderContainer container = await _pump(
      tester,
      field: field,
      onOuterEscape: () => outer++,
    );

    // 无选中、无工具态、无菜单、无拖线、不在打字。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(outer, 1, reason: '画布无事可剥：Esc 冒泡给祖先');

    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(outer, 1, reason: '剥了一层：Esc 被画布消费，祖先收不到');
    expect(container.read(canvasSelectionControllerProvider('c1')), isEmpty);
  });

  testWidgets('登记的外部层优先于选中；注销后不再参与', (tester) async {
    final TextEditingController field = TextEditingController();
    addTearDown(field.dispose);
    final ProviderContainer container = await _pump(tester, field: field);
    container.read(canvasSelectionControllerProvider('c1').notifier).select('a');
    await tester.pump();

    int findBarDismissed = 0;
    final CanvasEscapeLadder ladder =
        container.read(canvasEscapeLadderProvider('c1'));
    ladder.register(EscapeRungId.findBar, (
      isActive: () => true,
      dismiss: () => findBarDismissed++,
    ));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(findBarDismissed, 1, reason: '查找条在层序上排在选中之前');
    expect(container.read(canvasSelectionControllerProvider('c1')), <String>{'a'});

    ladder.unregister(EscapeRungId.findBar);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(findBarDismissed, 1, reason: '注销后不再参与判序');
    expect(container.read(canvasSelectionControllerProvider('c1')), isEmpty);
  });
}
