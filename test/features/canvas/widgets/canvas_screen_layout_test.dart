// 画布页浮层布局（画布重设计稿「画布页 · 改后」）：
// - 左侧 37px 工具条与右下角加号撤了——它们的测试锚点在树里一个都找不到；
// - 浮动工具条在舞台顶部居中（top 12）；
// - 缩放条挪到舞台左下（left 12 / bottom 12），右下角留给通知卡。
//
// 走外壳级 pump：CanvasScreen 的项目面板 / 检查器 / 渲染队列都要真 provider，只有外壳搭得起来。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_header_bar.dart';
import 'package:inkframe/features/canvas/widgets/canvas_toolbar.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/lane_toolbar.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/l10n/l10n_x.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/shell_app.dart';

void main() {
  testWidgets('没有左侧工具条与右下加号；工具条在舞台顶部居中，缩放条在左下',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_canvas_layout_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );

    // 旧件的测试锚点：左侧工具条 canvasTool-<id>，右下加号 canvas.addNodeFab。
    for (final String id in <String>['select', 'pan', 'link', 'image', 'lane']) {
      expect(
        find.byKey(ValueKey<String>('canvasTool-$id')),
        findsNothing,
        reason: '左侧工具条的 $id 格不该还在',
      );
    }
    expect(find.byKey(const Key('canvas.addNodeFab')), findsNothing);

    final Rect stage = tester.getRect(find.byType(CanvasView));

    expect(find.byType(CanvasToolbar), findsOneWidget);
    final Rect toolbar = tester.getRect(find.byType(CanvasToolbar));
    expect(toolbar.top, closeTo(stage.top + InkSpacing.s12, 0.5));
    expect(toolbar.center.dx, closeTo(stage.center.dx, 0.5));

    final Rect zoom = tester.getRect(find.byType(CanvasZoomBar));
    expect(zoom.left, closeTo(stage.left + InkSpacing.s12, 0.5));
    expect(zoom.bottom, closeTo(stage.bottom - InkSpacing.s12, 0.5));
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('舞台浮层给工具条与缩放条让位：连线提示从工具条下沿以下开始，泳道工具栏叠在缩放条之上',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_canvas_layout_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.canvas, canvasId: 'cv-1'),
    );
    final BuildContext context = tester.element(find.byType(CanvasView));
    ProviderScope.containerOf(context)
        .read(linkModeControllerProvider('cv-1').notifier)
        .start('n-any');
    await tester.pump();

    final Rect toolbar = tester.getRect(find.byType(CanvasToolbar));
    final Rect hint = tester.getRect(find.text(context.l10n.linkModeHint));
    expect(hint.top, greaterThan(toolbar.bottom), reason: '连线提示的后半句不得被工具条盖住');

    final Rect zoom = tester.getRect(find.byType(CanvasZoomBar));
    final Rect lanes = tester.getRect(find.byType(LaneToolbar));
    expect(lanes.bottom, lessThanOrEqualTo(zoom.top), reason: '泳道工具栏不得压在缩放条上');
    expect(lanes.left, closeTo(zoom.left, 0.5), reason: '两条左沿对齐');
  }, timeout: const Timeout(Duration(seconds: 15)));

}
