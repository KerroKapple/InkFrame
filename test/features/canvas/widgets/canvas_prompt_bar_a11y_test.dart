// 提示词条「生成」按钮的可达性（BOARD 214）。
//
// 这是整个画布唯一的生成入口，此前点击壳是手搓的
// `Semantics + MouseRegion + GestureDetector`——⌘↵ 之外键盘到不了它。换成 theme
// 层的 InkActivatable 后钉三件：能 Tab 到、Enter 走的是同一条 submit、
// 提示词为空（禁用）时连焦点都到不了。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';

import '../../../_harness/a11y.dart';
import '../../../_harness/test_app.dart';

/// 「生成」只在提示词非空（且供应商配了 Key，见 _pump）时可点，所以两种节点各一个。
/// 供应商写死在节点上：终稿就只有提示词一项（没存过供应商的节点另见 canvas_prompt_bar_generate_gate_test）。
const CanvasNode _withPrompt = CanvasNode(
  id: 'n1',
  label: 'Shot',
  type: CanvasNodeType.image,
  canvasId: 'cv1',
  typeConfig: <String, Object?>{'prompt': 'a cat', 'provider_id': 'gemini-image'},
);
const CanvasNode _emptyPrompt = CanvasNode(
  id: 'n1',
  label: 'Shot',
  type: CanvasNodeType.image,
  canvasId: 'cv1',
);

class _Nodes extends CanvasNodesController {
  _Nodes(this.node);
  final CanvasNode node;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[node];
}

class _Selected extends CanvasSelectionController {
  @override
  Set<String> build(String canvasId) => <String>{'n1'};
}

/// 记录 submit 的提交控制器：本文件要证的是"回车走的是同一条 submit"，
/// 不是 submit 自己怎么写库。
class _RecordingSubmit extends InspectorSubmitController {
  static final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<void> submit(Map<String, Object?> finalConfig) async =>
      calls.add(finalConfig);
}

Future<void> _pump(WidgetTester tester, CanvasNode node) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasPromptBar(canvasId: 'cv1')),
    surfaceSize: const Size(900, 500),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(node)),
      canvasSelectionControllerProvider.overrideWith(_Selected.new),
      inspectorSubmitControllerProvider.overrideWith(_RecordingSubmit.new),
      // 本文件只看可达性：Key 一律当已配（没配 Key 的置灰见 canvas_prompt_bar_generate_gate_test）。
      inspectorHasApiKeyProvider.overrideWith((ref, String providerId) async => true),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(_RecordingSubmit.calls.clear);

  testWidgets('提示词非空 →「生成」Tab 到得了', (tester) async {
    await _pump(tester, _withPrompt);

    expect(
      await tabUntilFocused(
        tester,
        activatableFocus(tester, CanvasPromptBar.generateKey),
      ),
      isTrue,
      reason: '画布唯一的生成入口不可聚焦 ⇒ 键盘用户只剩 ⌘↵ 一条路',
    );
  });

  testWidgets('Enter 激活 → 走的是同一条 submit', (tester) async {
    await _pump(tester, _withPrompt);

    await activateByKey(
      tester,
      activatableFocus(tester, CanvasPromptBar.generateKey),
    );
    await tester.pumpAndSettle();

    expect(
      _RecordingSubmit.calls,
      <Map<String, Object?>>[
        <String, Object?>{'prompt': 'a cat'},
      ],
      reason: '回车必须和鼠标点击走同一条 InspectorSubmitController.submit',
    );
  });

  testWidgets('提示词为空（禁用）→ 不可聚焦', (tester) async {
    await _pump(tester, _emptyPrompt);

    expect(
      activatableFocus(tester, CanvasPromptBar.generateKey).canRequestFocus,
      isFalse,
      reason: '此刻点不动的按钮不该能被聚焦——聚焦上去按回车什么都不会发生',
    );
    expect(_RecordingSubmit.calls, isEmpty);
  });
}
