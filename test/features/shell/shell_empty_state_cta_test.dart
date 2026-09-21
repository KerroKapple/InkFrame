// 四处「去 Studio」空态 CTA 的整支覆盖（fix round 18 / R85）。
//
// 评审用 coverage/lcov.info 逐行证明：`canvas_tab.dart` 的空态分支（:30-37）
// 与 `gallery_tab.dart` 的空态分支（:77-83）**整支零命中**，而四个标签的
// `onCta` 闭包（canvas:36-37 / gallery:82-83 / sequence:46-47 / export:36-37）
// **一次都没被点过**——「去 Studio」这个按钮在整个分支里从未被执行。
//
// 要紧在于 spec §8.1 亲口说：该空态在今天的生产代码里**根本不可达**
// （`app.dart` 从不以 null canvasId 构建 `CanvasScreen`），本 PR 让它**第一次
// 真正可达**。第一次可达的分支必须有护栏。
//
// D12 的原话是「这个空态必须是**可行动的引导**，用户不能觉得卡死」——在本
// 文件之前，这条决定只写在注释里。失败场景：用户 `shellKeepLastCanvas=false`
// 或上次画布被软删 → 启动后点「画布」标签 → 正文可能是别的标签的文案、
// 「Go to Studio」可能是哑键，用户只能靠标签条自救。
//
// 【每条用例断两件事】文案键（防"正文串标签"）+ 点 CTA 后 tab 真的变成
// studio（防哑键 / 自跳）。只断其中一件的话，评审那条变异（把正文换成导出
// 标签的键、CTA 改成 goTab(canvas) 自跳）在全量测试下零红——那正是本文件
// 存在的理由。
//
// 【实跑的变异证明】两轮，**刻意分开跑**：文案变异会打断 CTA 断言的前置条件，
// 合在一起跑只证明得了前者。
//
// M1a 文案互换（canvas→shellExportEmptyBody、sequence→shellCanvasEmptyBody、
// export→shellSequenceEmptyBody，四个 onCta 同时自跳）：
//   3 条正文断言红（"Found 0 widgets with text ..."，:59 / :79 / :98），
//   画廊无正文、红在 CTA（:129 Expected studio, Actual gallery）。
//
// M1b **只**把四处 onCta 改成自跳（正文原样还原）：四条全红，且全部红在 CTA
//   那一行——Expected ShellTab.studio，Actual 依次为 canvas(:66) / sequence(:85)
//   / export(:104) / gallery(:129)。四个 onCta 闭包的鉴别力由此逐一独立证明，
//   而不是"其中某一条顺带带红了别人"。
//
// 【为什么走 pumpInkShell 而不是单 pump 标签体】CTA 的效果是「外壳 tab 变了」，
// 只有整壳在场才能断到；顺带覆盖「空态标签能被标签条切进去」这条路径。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/shell_empty_state.dart';

import '../../_harness/shell_app.dart';

ShellTab _tabOf(WidgetTester tester) =>
    readShellContainer(tester).read(shellControllerProvider).tab;

/// 点空态里那唯一一个「Go to Studio」按钮。
Future<void> _tapGoToStudio(WidgetTester tester) async {
  expect(
    find.byType(ShellEmptyState),
    findsOneWidget,
    reason: '前置条件：当前标签得真的处在空态，否则下面那条 CTA 断言测的是别的东西',
  );
  await tester.tap(find.text('Go to Studio'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('画布标签空态：文案是画布的，且「Go to Studio」真的回 Studio 标签',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_cta_canvas_');
    await pumpInkShell(
      tester,
      paths: paths,
      // canvasId == null 是合法态（spec §8.1 / D12）：keepLastCanvas 关掉、
      // 或上次画布被软删时，用户点画布标签看到的就是这一支。
      initial: const ShellState(tab: ShellTab.canvas),
    );

    expect(find.text('No canvas open'), findsOneWidget);
    expect(
      find.text('Pick a canvas in Studio and it opens right here.'),
      findsOneWidget,
      reason: '正文串成别的标签的键时这里红——四个空态共用标题、正文各不相同',
    );

    await _tapGoToStudio(tester);
    expect(_tabOf(tester), ShellTab.studio);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('序列标签空态：文案是序列的，且「Go to Studio」真的回 Studio 标签',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_cta_sequence_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.sequence),
    );

    expect(find.text('No canvas open'), findsOneWidget);
    expect(
      find.text('Open a canvas first, then preview its narrative chain here.'),
      findsOneWidget,
    );

    await _tapGoToStudio(tester);
    expect(_tabOf(tester), ShellTab.studio);
  }, timeout: const Timeout(Duration(seconds: 10)));

  testWidgets('导出标签空态：文案是导出的，且「Go to Studio」真的回 Studio 标签',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_cta_export_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.export),
    );

    expect(find.text('No canvas open'), findsOneWidget);
    expect(
      find.text('Open a canvas first, then export its video results here.'),
      findsOneWidget,
    );

    await _tapGoToStudio(tester);
    expect(_tabOf(tester), ShellTab.studio);
  }, timeout: const Timeout(Duration(seconds: 10)));

  // 【这一条否掉了"需要真仓储所以测不了"的说法】project == null 这一支在
  // GalleryScreen 之前就 return 了，根本不碰任何仓储——harness 的封印足够。
  testWidgets('画廊标签空态：出「No project」，且「Go to Studio」真的回 Studio 标签',
      (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_cta_gallery_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.gallery),
    );

    // 必须限定在空态子树里：`shellBreadcrumbNoProject` 是复用键，外壳面包屑
    // 此刻也在渲染同一句「No project」——不限定就是 findsNWidgets(2) 直接红。
    expect(
      find.descendant(
        of: find.byType(ShellEmptyState),
        matching: find.text('No project'),
      ),
      findsOneWidget,
    );

    await _tapGoToStudio(tester);
    expect(_tabOf(tester), ShellTab.studio);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
