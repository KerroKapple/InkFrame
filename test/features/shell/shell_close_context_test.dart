// 上下文失效的【效果】那一半（BOARD「删掉正在打开的画布 / 项目后外壳上下文悬空」）。
//
// 接线那一半（Studio 的两个删除入口真的调了这两个迁移）在
// test/features/studio/studio_delete_clears_shell_context_test.dart。
//
// 为什么效果必须在外壳级断言：标签 chip 恒可点（只有交付锁会禁用），所以
// 「删完之后点回画布标签会看到什么」是保活宿主的性质，画布级 pump 测不到。
// #251 关卡的入场条件点名要一条"调用后画布保活槽真被销毁"的显式断言——
// 下面第一条就是它：CanvasScreen 必须从树里消失，而不是"离台但还活着"。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_screen.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/shell_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

void main() {
  testWidgets('closeCanvas 后点回画布标签：拿到的不是那张已删画布（保活槽真被销毁）',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_close_canvas_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(
          tab: ShellTab.canvas, canvasId: 'cv-1', project: _alpha),
    );
    final ProviderContainer container = readShellContainer(tester);

    expect(find.byType(CanvasScreen, skipOffstage: false), findsOneWidget,
        reason: '前置：画布槽已物化，CanvasScreen 在树里');

    container.read(shellControllerProvider.notifier).closeCanvas();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CanvasScreen, skipOffstage: false), findsNothing,
        reason: '保活槽必须真被销毁——"离台但还活着"等于用户切回去还在编辑已删画布');
    expect(find.text('No canvas open'), findsOneWidget);

    // 标签 chip 恒可点，所以"点回去"这一步必须真的走一遍。
    await tapShellTab(tester, ShellTab.studio);
    await tapShellTab(tester, ShellTab.canvas);

    expect(find.byType(CanvasScreen, skipOffstage: false), findsNothing,
        reason: '点回画布标签拿到的是空态，不是那张已删画布');
    expect(container.read(shellControllerProvider).canvasId, isNull);
    expect(container.read(shellControllerProvider).project, _alpha,
        reason: '画布失效不牵连项目上下文');
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('closeProject 后：画廊 / 序列 / 导出 / 面包屑都不再指着它',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_close_project_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(
          tab: ShellTab.gallery, canvasId: 'cv-1', project: _alpha),
    );
    final ProviderContainer container = readShellContainer(tester);

    expect(find.byType(GalleryScreen, skipOffstage: false), findsOneWidget,
        reason: '前置：画廊槽已物化并挂着 Alpha');
    expect(find.text('Alpha'), findsWidgets, reason: '前置：面包屑中段是项目名');

    container.read(shellControllerProvider.notifier).closeProject();
    await tester.pump();
    await tester.pump();

    final ShellState s = container.read(shellControllerProvider);
    expect(s.project, isNull);
    expect(s.canvasId, isNull);

    expect(find.byType(GalleryScreen, skipOffstage: false), findsNothing,
        reason: 'GalleryScreen 还在 = 它仍捧着已删项目的 projectId 在查库');
    expect(find.text('Alpha'), findsNothing,
        reason: '面包屑不能继续显示一个已经不在库里的项目名');
    expect(find.text('No project'), findsWidgets);

    // 序列 / 导出两个标签走的是 canvasId 判据，closeProject 连带清了它。
    await tapShellTab(tester, ShellTab.sequence);
    expect(find.text('No canvas open'), findsOneWidget);
    await tapShellTab(tester, ShellTab.export);
    expect(find.text('No canvas open'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 15)));
}
