// TextNodeInspector（演示 F1）：
//   - 水化：输入框显示 type_config.text；
//   - 输入走 InspectorSubmitController 的防抖写入链，落到 type_config.text——与生成链路
//     （GenerationController._resolveAssociatedTexts）和 CanvasNode.textContent 读的是同一个键；
//   - 失焦后画布节点控制器重载，内存节点表里的 textContent 跟上（卡片 / 提示词预览读的就是它）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/text_node_inspector.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _canvasId = 'cv1';

void main() {
  late InMemoryNodeRepository nodeRepo;
  late String nodeId;
  late CanvasNode node;

  setUp(() async {
    nodeRepo = InMemoryNodeRepository();
    nodeId = await nodeRepo.create(
      canvasId: _canvasId,
      type: 'text',
      nodeRole: 'config',
      typeConfig: const <String, Object?>{'text': 'old body'},
    );
    node = CanvasNode(
      id: nodeId,
      label: '',
      type: CanvasNodeType.text,
      canvasId: _canvasId,
      typeConfig: const <String, Object?>{'text': 'old body'},
    );
  });

  Finder field() => find.descendant(
        of: find.byKey(TextNodeInspector.contentFieldKey),
        matching: find.byType(TextField),
      );

  Object? storedText() =>
      (nodeRepo.rows[nodeId]!['type_config']! as Map<String, Object?>)['text'];

  Future<void> pump(WidgetTester tester) async {
    await pumpInkApp(
      tester,
      Scaffold(body: TextNodeInspector(node: node)),
      overrides: <Override>[
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('水化：输入框显示 type_config.text', (tester) async {
    await pump(tester);
    expect(field(), findsOneWidget);
    expect(find.text('old body'), findsOneWidget);
  });

  testWidgets('输入 → 防抖窗口内不落库，窗口过后写进 type_config.text', (tester) async {
    await pump(tester);

    await tester.enterText(field(), 'a lone lighthouse at dawn');
    await tester.pump(const Duration(milliseconds: 100));
    // 防抖：窗口没过不写。
    expect(storedText(), 'old body');

    await tester.pump(InspectorSubmitController.debounceDuration);
    await tester.pumpAndSettle();
    expect(storedText(), 'a lone lighthouse at dawn');
    expect(kTextNodeContentKey, 'text');
  });

  testWidgets('失焦 → 立即落库并让画布节点表重载，内存节点的 textContent 跟上', (tester) async {
    await pump(tester);
    final ProviderContainer container =
        ProviderScope.containerOf(tester.element(find.byType(TextNodeInspector)));
    // 订阅住节点控制器（画布在屏时本来就有人订阅）。
    final ProviderSubscription<AsyncValue<List<CanvasNode>>> sub =
        container.listen(canvasNodesControllerProvider(_canvasId), (_, _) {});
    addTearDown(sub.close);
    final List<CanvasNode> before =
        await container.read(canvasNodesControllerProvider(_canvasId).future);
    expect(before.single.textContent, 'old body');

    await tester.enterText(field(), 'storm rolls in');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    // 只冲微任务、不推进时钟：失焦那一笔不等防抖窗口。
    await tester.pump();
    await tester.pump();
    expect(storedText(), 'storm rolls in');
    await tester.pumpAndSettle();
    final List<CanvasNode> after =
        await container.read(canvasNodesControllerProvider(_canvasId).future);
    expect(after.single.textContent, 'storm rolls in');

    // 把仍挂着的防抖计时器走完（写的是同一个值）。
    await tester.pump(InspectorSubmitController.debounceDuration);
    await tester.pumpAndSettle();
    expect(storedText(), 'storm rolls in');
  });
}
