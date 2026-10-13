// 自动保存失败面的上屏回归（BOARD 第 197 行）。
//
// 三件事各一条：
//   ① 失败态真的在屏上，而且带「重试」——不是只在控制台 log
//   ② 点「重试」真的再写一次库
//   ③ 失败不清用户输入（与 #248「Key 被拒保留输入框」同一个道理）
// 另有一条存在性断言：检查器面板真的挂了这一行（否则上面三条测的是孤岛）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_inspector_panel.dart';
import 'package:inkframe/features/canvas/widgets/inspector_auto_save_row.dart';
import 'package:inkframe/features/canvas/widgets/shot_config_inspector.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';
import '../../../helpers/recording_logger.dart';

/// 写 type_config 必失败的 nodes 仓储（其余走内存实现）。
class _WriteFailingNodeRepository implements NodeRepository {
  _WriteFailingNodeRepository(this._inner);

  final InMemoryNodeRepository _inner;
  int attempts = 0;

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    attempts++;
    throw const LocalIOError(extra: <String, Object?>{'op': 'patchTypeConfig'});
  }

  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) =>
      _inner.listByCanvas(canvasId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const String canvasId = 'cv1';
  const String shotNodeId = 's1';
  const CanvasNode shotNode = CanvasNode(
    id: shotNodeId,
    label: '',
    canvasId: canvasId,
    type: CanvasNodeType.shot,
    role: NodeRole.config,
  );

  /// 两件单品拼起来测：ShotConfigInspector 负责输入与落盘，
  /// InspectorAutoSaveRow 负责把失败上屏。生产里由检查器面板把二者放在一起
  /// （最后一条用例断言的就是那条接线）。
  ///
  /// 宽度钉在检查器面板的真实宽度：失败行是「图标 + 原因 + 重试按钮」一行，
  /// 在 800 的默认画布上测不出它在 301 里会不会溢出（溢出在 debug 下直接抛）。
  const Widget composed = Scaffold(
    body: SizedBox(
      width: CanvasInspectorPanel.width,
      child: Column(
        children: <Widget>[
          ShotConfigInspector(node: shotNode),
          InspectorAutoSaveRow(nodeId: shotNodeId),
        ],
      ),
    ),
  );

  late _WriteFailingNodeRepository repo;
  late RecordingLogger logger;

  setUp(() {
    repo = _WriteFailingNodeRepository(InMemoryNodeRepository());
    logger = RecordingLogger();
  });

  List<Override> overrides() => <Override>[
        nodeRepositoryProvider.overrideWith((ref) async => repo),
        loggerProvider.overrideWithValue(logger),
      ];

  /// 等到自动重试全部用尽（Failed 态才带「重试」按钮）。
  Future<void> pumpUntilGaveUp(WidgetTester tester) async {
    for (final Duration d in InspectorSubmitController.retryBackoff) {
      await tester.pump(d + const Duration(milliseconds: 50));
    }
    await tester.pump();
  }

  testWidgets('自动保存失败 → 失败行上屏（带原因），输入不被清掉，可点重试', (tester) async {
    await pumpInkApp(tester, composed, overrides: overrides());
    await tester.pumpAndSettle();
    expect(find.byKey(InspectorAutoSaveRow.retryKey), findsNothing,
        reason: '一切正常时这一行不占位');

    await tester.enterText(find.byType(TextField).first, 'my last edit');
    // 防抖窗口 + 首次尝试（落盘链路有若干 await，多泵几拍把微任务走完）
    await tester.pump(
      InspectorSubmitController.debounceDuration +
          const Duration(milliseconds: 50),
    );
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(find.textContaining('retrying'), findsOneWidget,
        reason: '首次失败先如实说「正在重试」');

    await pumpUntilGaveUp(tester);

    expect(repo.attempts, InspectorSubmitController.maxAutoRetries + 1);
    expect(find.textContaining('Changes not saved:'), findsOneWidget,
        reason: '重试用尽必须上屏，不能只在控制台 log');
    expect(find.byKey(InspectorAutoSaveRow.retryKey), findsOneWidget);
    expect(find.text('my last edit'), findsOneWidget,
        reason: '失败不许清掉用户输入（#248 同款口径）');
  });

  testWidgets('点「重试」 → 真的再写一次库', (tester) async {
    await pumpInkApp(tester, composed, overrides: overrides());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'retry me');
    await tester.pump(
      InspectorSubmitController.debounceDuration +
          const Duration(milliseconds: 50),
    );
    await pumpUntilGaveUp(tester);
    final int before = repo.attempts;

    await tester.tap(find.byKey(InspectorAutoSaveRow.retryKey));
    await tester.pump();
    await tester.pump();

    expect(repo.attempts, greaterThan(before),
        reason: '「重试」必须是真动作，不是装饰');
  });

  testWidgets('检查器面板挂了自动保存失败行（选中节点时）', (tester) async {
    final InMemoryNodeRepository nodes = InMemoryNodeRepository();
    final String id = await nodes.create(
      canvasId: canvasId,
      type: CanvasNodeType.shot.name,
      nodeRole: NodeRole.config.name,
    );
    await pumpInkApp(
      tester,
      const Scaffold(body: CanvasInspectorPanel(canvasId: canvasId)),
      overrides: <Override>[
        nodeRepositoryProvider.overrideWith((ref) async => nodes),
        loggerProvider.overrideWithValue(logger),
      ],
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(CanvasInspectorPanel)),
    );
    await container.read(canvasNodesControllerProvider(canvasId).future);
    container
        .read(canvasSelectionControllerProvider(canvasId).notifier)
        .select(id);
    await tester.pumpAndSettle();

    expect(find.byType(InspectorAutoSaveRow), findsOneWidget,
        reason: '失败面必须真的接在用户看得见的那一层上');
  });
}
