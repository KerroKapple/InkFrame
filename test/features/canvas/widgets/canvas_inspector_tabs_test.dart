// 检查器页签（PR-6）：「属性 / 状态 / 历史」改成「属性 / 历史」。
//
// - 只有两格，原来那个只画不挂交互的「状态」不在了；
// - 两格都能点（InkActivatable），切过去内容跟着换：属性 = 摘要 + NodeInspectorRouter，
//   历史 = InspectorHistoryPanel；
// - 停在哪一页记在 inspectorTabProvider：换选中节点不重置；
// - 页签条：surface4 底，选中那格 surface3 底 + fg1 字。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_tab.dart';
import 'package:inkframe/features/canvas/widgets/canvas_inspector_panel.dart';
import 'package:inkframe/features/canvas/widgets/inspector_history_panel.dart';
import 'package:inkframe/features/canvas/widgets/node_inspector_router.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/primitives/ink_activatable.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/test_app.dart';

const String _canvasId = 'c1';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Align(
        alignment: Alignment.topRight,
        child: SizedBox(height: 700, child: CanvasInspectorPanel(canvasId: _canvasId)),
      ),
    ),
    overrides: <Override>[
      // 两个文本节点：文本节点的属性检查器是空的，不牵扯检查器自己的依赖。
      canvasNodesControllerProvider.overrideWith(
        () => FakeNodesController(<CanvasNode>[
          textNode('n1', 'Node One', 40),
          textNode('n2', 'Node Two', 320),
        ]),
      ),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
    surfaceSize: const Size(800, 800),
  );
  await tester.pump();
  final ProviderContainer c =
      ProviderScope.containerOf(tester.element(find.byType(CanvasInspectorPanel)));
  await c.read(canvasNodesControllerProvider(_canvasId).future);
  await tester.pump();
  return c;
}

AppLocalizations _l(WidgetTester tester) => tester.element(find.byType(CanvasInspectorPanel)).l10n;

Finder _tab(InspectorTab tab) => find.byKey(CanvasInspectorPanel.tabKey(tab));

Future<void> _select(WidgetTester tester, ProviderContainer c, String id) async {
  c.read(canvasSelectionControllerProvider(_canvasId).notifier).select(id);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('页签只有「属性 / 历史」两格，「状态」不在了', (tester) async {
    await _pump(tester);
    final AppLocalizations l = _l(tester);

    expect(_tab(InspectorTab.properties), findsOneWidget);
    expect(_tab(InspectorTab.history), findsOneWidget);
    expect(find.text(l.inspectorTabProperties), findsOneWidget);
    expect(find.text(l.inspectorTabHistory), findsOneWidget);
    expect(find.text('Status'), findsNothing);
    // 没选中节点时整个面板里能点的只有这两格。
    expect(find.byType(InkActivatable), findsNWidgets(2));
    expect(InspectorTab.values, <InspectorTab>[InspectorTab.properties, InspectorTab.history]);
  });

  testWidgets('两格都能点：属性 = 摘要 + NodeInspectorRouter；历史 = InspectorHistoryPanel', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _select(tester, c, 'n1');

    expect(find.byType(NodeInspectorRouter), findsOneWidget, reason: '默认停在属性页');
    expect(find.byType(InspectorHistoryPanel), findsNothing);
    expect(find.text('Node One'), findsOneWidget, reason: '属性页顶上是节点摘要');

    await tester.tap(_tab(InspectorTab.history));
    await tester.pump();
    expect(c.read(inspectorTabProvider), InspectorTab.history);
    expect(find.byType(InspectorHistoryPanel), findsOneWidget);
    expect(find.byType(NodeInspectorRouter), findsNothing);
    expect(find.text(_l(tester).inspectorHistoryEmpty), findsOneWidget, reason: '文本节点名下没有 take');

    await tester.tap(_tab(InspectorTab.properties));
    await tester.pump();
    expect(c.read(inspectorTabProvider), InspectorTab.properties);
    expect(find.byType(NodeInspectorRouter), findsOneWidget);
    expect(find.byType(InspectorHistoryPanel), findsNothing);
  });

  testWidgets('换选中节点不重置页签', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _select(tester, c, 'n1');
    await tester.tap(_tab(InspectorTab.history));
    await tester.pump();

    await _select(tester, c, 'n2');
    expect(c.read(inspectorTabProvider), InspectorTab.history);
    expect(find.byType(InspectorHistoryPanel), findsOneWidget);
    expect(tester.widget<InspectorHistoryPanel>(find.byType(InspectorHistoryPanel)).node.id, 'n2');
  });

  testWidgets('没选中节点：两页都是同一句空态', (tester) async {
    await _pump(tester);
    final AppLocalizations l = _l(tester);
    expect(find.text(l.inspectorNoSelection), findsOneWidget);

    await tester.tap(_tab(InspectorTab.history));
    await tester.pump();
    expect(find.text(l.inspectorNoSelection), findsOneWidget);
    expect(find.byType(InspectorHistoryPanel), findsNothing);
  });

  testWidgets('页签条 surface4 底；选中那格 surface3 底 + fg1 字，另一格 fg4 字', (tester) async {
    await _pump(tester);
    final InkColors c = InkColors.dark();

    final Container bar = tester.widget<Container>(
      find.ancestor(of: _tab(InspectorTab.properties), matching: find.byType(Container)).first,
    );
    expect((bar.decoration! as BoxDecoration).color, c.surface4);
    expect(tester.getSize(find.byWidget(bar)).height, CanvasInspectorPanel.tabBarHeight);

    Container cell(InspectorTab tab) =>
        tester.widget<Container>(find.descendant(of: _tab(tab), matching: find.byType(Container)).first);
    Text label(InspectorTab tab) =>
        tester.widget<Text>(find.descendant(of: _tab(tab), matching: find.byType(Text)));

    expect(cell(InspectorTab.properties).color, c.surface3);
    expect(cell(InspectorTab.history).color, isNull);
    expect(label(InspectorTab.properties).style!.color, c.fg1);
    expect(label(InspectorTab.history).style!.color, c.fg4);
    expect(tester.widget<InkActivatable>(_tab(InspectorTab.properties)).selected, isTrue);
    expect(tester.widget<InkActivatable>(_tab(InspectorTab.history)).selected, isFalse);
  });
}
