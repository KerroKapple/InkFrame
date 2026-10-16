// CanvasEmptyState 渲染测试：标题/副文/四个动作 + 背景点击触发回调。
//
// P7 起外形走共用的 ShellEmptyState（中性灰语汇：72 圆底 + 标题 + 副文 + 动作行），
// 动作按钮是设计系统的 InkAmberButton / InkGhostButton，不再是 Material 的
// FilledButton / OutlinedButton——那两个带 Material 自己的涟漪、圆角和主色，
// 在中性灰界面里是唯一一处「别人家的按钮」。
//
// 建节点与工具条、I / G / T 同一条路（canvas_tool_actions.addNodeAtViewportCenter）：新节点挂一条只单选、不挪相机
// 的定位请求；失败走 toastServiceProvider（错误卡），这里覆盖成 RecordingToastService 断言记下的卡。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_focus_request.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_empty_state.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/widgets/shell_empty_state.dart';
import 'package:inkframe/features/storyboard/widgets/script_import_dialog.dart';
import 'package:inkframe/theme/primitives/ink_amber_button.dart';
import 'package:inkframe/theme/primitives/ink_ghost_button.dart';

import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

/// addNode 一律抛 InkError 的节点控制器：走到「添加节点失败」那条提示。
class _FailingNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async =>
      const <CanvasNode>[];

  @override
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    String? laneId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async =>
      throw const LocalIOError();
}

/// addNode 照常成功、新节点 id 固定的节点控制器。
class _RecordingNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async =>
      const <CanvasNode>[];

  @override
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    String? laneId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    final CanvasNode node = CanvasNode(id: 'new', label: label, type: type, canvasId: 'c1');
    state = AsyncData<List<CanvasNode>>(<CanvasNode>[node]);
    return node;
  }
}

void main() {
  testWidgets('渲染共用空态壳 + 标题 + 副文 + 四个动作', (tester) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasEmptyState(canvasId: 'c1', onBackgroundTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShellEmptyState), findsOneWidget);
    expect(find.text('This canvas is empty'), findsOneWidget);
    expect(find.text('Add your first node to start storyboarding.'),
        findsOneWidget);
    expect(find.text('Add image node'), findsOneWidget);
    expect(find.text('Add video node'), findsOneWidget);
    expect(find.text('Add shot node'), findsOneWidget);
    expect(find.text('Import script'), findsOneWidget);
    // 主动作一颗琥珀，其余三颗幽灵按钮；Material 按钮一个都不许剩。
    expect(find.byType(InkAmberButton), findsOneWidget);
    expect(find.byType(InkGhostButton), findsNWidgets(3));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  // SB-2：空画布是「粘脚本」最自然的落点——手上有本子的人不该被逼着一个个建节点。
  testWidgets('「导入脚本」CTA 打开脚本导入对话框', (tester) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasEmptyState(canvasId: 'c1', onBackgroundTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import script'), findsOneWidget);
    await tester.tap(find.text('Import script'));
    await tester.pumpAndSettle();

    expect(find.byType(ScriptImportDialog), findsOneWidget);
  });

  testWidgets('点击空白触发 onBackgroundTap', (tester) async {
    var taps = 0;
    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasEmptyState(canvasId: 'c1', onBackgroundTap: () => taps++),
      ),
    );
    await tester.pumpAndSettle();
    // 点击屏幕左上角的空白处（远离 CTA 按钮和卡片）。
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('CTA 建节点与 I 同一条路：新节点被单选（挂定位请求）、相机不动', (tester) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasEmptyState(canvasId: 'c1', onBackgroundTap: () {}),
      ),
      overrides: <Override>[
        canvasNodesControllerProvider.overrideWith(_RecordingNodesController.new),
      ],
    );
    await tester.pumpAndSettle();
    final ProviderContainer c = ProviderScope.containerOf(tester.element(find.byType(CanvasEmptyState)));

    await tester.tap(find.text('Add image node'));
    await tester.pumpAndSettle();

    expect(
      c.read(canvasFocusRequestProvider),
      const CanvasFocusRequest(canvasId: 'c1', nodeId: 'new', center: false),
    );
  });

  // 建节点失败要说一声：空画布上什么都没多出来，不说 = 用户以为按钮坏了。
  testWidgets('建节点失败 → 错误卡「Failed to add node」', (tester) async {
    final toast = RecordingToastService();
    await pumpInkApp(
      tester,
      Scaffold(
        body: CanvasEmptyState(canvasId: 'c1', onBackgroundTap: () {}),
      ),
      overrides: <Override>[
        canvasNodesControllerProvider.overrideWith(_FailingNodesController.new),
        toastServiceProvider.overrideWithValue(toast),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add image node'));
    await tester.pumpAndSettle();

    expect(toast.titles, <String>['Failed to add node']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
  });
}
