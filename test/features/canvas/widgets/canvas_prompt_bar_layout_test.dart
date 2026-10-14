// 提示词条的版式（提示词条与节点文字稿）：
//   - 宽度跟着舞台走（不再钉死 668）：舞台宽 × 0.6，夹在 480–880；舞台窄于 512 取舞台宽减两侧 16；
//   - 提示词框 prompt 档 13 / 行高 1.6，1 行起、随内容长到 8 行，再多就在框内滚动；
//   - 条子底边贴舞台底，内容变多只往上长。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const CanvasNode _node = CanvasNode(
  id: 'n1',
  label: 'Shot',
  type: CanvasNodeType.image,
  canvasId: 'cv1',
  typeConfig: <String, Object?>{'prompt': 'a cat'},
);

class _Nodes extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => const <CanvasNode>[_node];
}

class _Selected extends CanvasSelectionController {
  @override
  Set<String> build(String canvasId) => <String>{'n1'};
}

/// 打字不落库：本文件只看版式，防抖保存的计时器与仓储都不该被碰到。
class _NoSave extends InspectorSubmitController {
  @override
  void savePromptDebounced(String prompt) {}
}

List<Override> _overrides() => <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'cv1'),
      canvasRepositoryProvider.overrideWith((_) async => InMemoryCanvasRepository()),
      canvasNodesControllerProvider.overrideWith(_Nodes.new),
      canvasSelectionControllerProvider.overrideWith(_Selected.new),
      inspectorSubmitControllerProvider.overrideWith(_NoSave.new),
    ];

/// 条子本体（带底色 / 边框的那只盒子）。外层对齐壳会撑满父级，量它量不出条子多宽。
Finder get _surface => find.byKey(CanvasPromptBar.surfaceKey);

Finder get _field => find.descendant(
      of: find.byType(CanvasPromptBar),
      matching: find.byType(TextField),
    );

/// 把条子塞进一个定宽「舞台」里。面要比舞台宽，否则 Center 给的上限会先把舞台压窄。
Future<void> _pumpInStage(WidgetTester tester, double stageWidth) async {
  await pumpInkApp(
    tester,
    Scaffold(
      body: Center(
        child: SizedBox(
          width: stageWidth,
          child: const CanvasPromptBar(canvasId: 'cv1'),
        ),
      ),
    ),
    surfaceSize: Size(stageWidth + 100, 600),
    overrides: _overrides(),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('提示词占满整条宽度；字数与「生成」在下面一行', (tester) async {
    await _pumpInStage(tester, 1014);
    final Rect bar = tester.getRect(_surface);
    final Rect field = tester.getRect(_field);
    final Rect generate = tester.getRect(find.byKey(CanvasPromptBar.generateKey));
    // 条子内边距左 14、右 12，外加 1px 描边两侧：提示词框应吃满剩下的宽度。
    expect(field.width, greaterThan(bar.width - 14 - 12 - 2 - 1),
        reason: '提示词不该再和按钮挤一行');
    expect(generate.top, greaterThanOrEqualTo(field.bottom),
        reason: '生成按钮在提示词下面');
    expect(generate.right, closeTo(bar.right - 12 - 1, 1.5), reason: '按钮贴右');
    final Rect baseStyle = tester.getRect(find.byKey(CanvasPromptBar.baseStyleKey));
    expect(baseStyle.right, closeTo(bar.right - 12 - 1, 1.5), reason: '基础风格贴右，不被平分到中间');
  });

  group('宽度跟着舞台走；居中压不到左下缩放条时照常居中', () {
    for (final (double stage, double expected) in const <(double, double)>[
      (1014.0, 608.4), // 60%
      (1977.0, 880.0), // 0.6 倍 1186 → 上限
    ]) {
      testWidgets('舞台 $stage → 条宽 $expected，居中', (tester) async {
        await _pumpInStage(tester, stage);
        expect(tester.getSize(_surface).width, closeTo(expected, 0.01));
        // 对齐壳居中：条子两侧到舞台边的距离相等。
        final Rect bar = tester.getRect(_surface);
        final Rect stageRect = tester.getRect(find.byType(CanvasPromptBar));
        expect(bar.left - stageRect.left, closeTo(stageRect.right - bar.right, 0.01));
      });
    }
  });

  group('居中会压到左下缩放条 / 泳道工具栏时：在右边那段里居中，放不下再收窄', () {
    for (final (double stage, double width, double left) in const <(double, double, double)>[
      // 窗宽 1280、左右栏都开：舞台 697，居中左沿只有 108.5——「适应」「+」整格被盖住。
      (697.0, 480.0, 188.5), // 右边那段 697 − 176 − 16 = 505，480 放得下，在里面居中
      (500.0, 308.0, 176.0), // 右边那段只剩 308：收窄到 308，贴着预留区右沿
    ]) {
      testWidgets('舞台 $stage → 条宽 $width、左沿 $left', (tester) async {
        await _pumpInStage(tester, stage);
        final Rect bar = tester.getRect(_surface);
        final Rect stageRect = tester.getRect(find.byType(CanvasPromptBar));
        expect(bar.width, closeTo(width, 0.01));
        expect(bar.left - stageRect.left, closeTo(left, 0.01));
        expect(bar.left - stageRect.left, greaterThanOrEqualTo(InkToolbarSize.stageBottomLeftReserve));
      });
    }
  });

  testWidgets('提示词框：prompt 档 13 / 行高 1.6，1 行起、最多 8 行', (tester) async {
    await _pumpInStage(tester, 1014);
    final TextField field = tester.widget<TextField>(_field);
    expect(field.style?.fontSize, 13);
    expect(field.style?.height, 1.6);
    expect(field.minLines, 1);
    expect(field.maxLines, 8);
  });

  testWidgets('内容多了往上长：长到第 8 行为止、底边不动；第 9 行起在框内滚动', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(
        body: Stack(
          children: <Widget>[
            // 与 canvas_screen 同一种挂法：贴舞台底 16、水平居中。
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(child: CanvasPromptBar(canvasId: 'cv1')),
            ),
          ],
        ),
      ),
      surfaceSize: const Size(1014, 700),
      overrides: _overrides(),
    );
    await tester.pumpAndSettle();

    Future<Rect> barWith(int lines) async {
      await tester.enterText(
        _field,
        List<String>.generate(lines, (int i) => 'line ${i + 1}').join('\n'),
      );
      await tester.pump();
      return tester.getRect(_surface);
    }

    final Rect one = await barWith(1);
    final Rect three = await barWith(3);
    final Rect seven = await barWith(7);
    final Rect eight = await barWith(8);
    final Rect nine = await barWith(9);
    final Rect twenty = await barWith(20);

    expect(three.height, greaterThan(one.height));
    expect(eight.height, greaterThan(seven.height), reason: '第 8 行还在长');
    expect(nine.height, closeTo(eight.height, 0.5), reason: '8 行封顶，再多在框内滚动');
    expect(twenty.height, closeTo(eight.height, 0.5));
    for (final Rect r in <Rect>[three, seven, eight, nine, twenty]) {
      expect(r.bottom, closeTo(one.bottom, 0.01), reason: '底边锚在舞台底上，内容变多只往上长');
    }
  });
}
