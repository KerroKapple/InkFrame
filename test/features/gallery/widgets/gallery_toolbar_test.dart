// T9 复评 R68/R69：工具条标题（项目名 + 产物计数）的断言。
//
// R68 的由来：这是 T9 唯一用户可见的改动，落地时**一条断言都没有**——复评做
// 全量变异（itemCount 恒 null / projectName 置空）两次都 2038 全绿，唯一会
// 察觉的是一张正处于红窗口、要到 T13 才重铸的 golden。重铸会把回归一起烤进
// 新基线，从此无人发现。所以这里必须有非 golden 的护栏。
//
// R69 的由来：计数原本取全量 length，而网格渲染的是筛选后的列表 ⇒ 工具条同屏
// 显示「筛选生效中」+「4 assets」，底下网格只有 1 个 tile。现在数的是可见条数。
//
// 两条取材纪律：
//   1. 项目名与画布名取不同字面（Alpha / Beta / Gamma）——同字面会让 find.text
//      分不清标题与 tile caption，断言就成了假绿。
//   2. 只播种视频节点：图片 tile 会走真实 Image.file，缺文件就是一个与本文件
//      无关的失败源。筛选用画布名搜索来触发，不需要图片。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/theme/components/ink_tool_bar.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

/// 收窄到工具条子树——标题的断言绝不能在全树上做。
Finder _inToolBar(Finder matching) => find.descendant(
      of: find.byType(InkToolBar),
      matching: matching,
    );

void main() {
  late InMemoryCanvasRepository canvases;
  late InMemoryNodeRepository nodes;
  late FakeBatchResultRepo batch;

  setUp(() {
    canvases = InMemoryCanvasRepository();
    nodes = InMemoryNodeRepository();
    batch = FakeBatchResultRepo();
  });

  List<Override> overrides() => <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
      ];

  /// 在名为 [canvasName] 的画布上播种 [count] 个视频 result 节点。
  Future<void> seedVideos(int count, {String canvasName = 'Beta'}) async {
    final String ca = await canvases.create(projectId: 'p1', name: canvasName);
    for (int i = 0; i < count; i++) {
      await nodes.create(
        canvasId: ca,
        type: 'video',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'video_url': 'videos/$canvasName$i.mp4'},
      );
    }
  }

  Future<void> pumpGallery(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
      surfaceSize: const Size(1280, 800),
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpAndSettle();
  }

  // 【实测变异】_GalleryToolBar 的 Text(projectName) → Text('')
  // ⇒ Expected: exactly one matching candidate / Actual: Found 0 widgets
  testWidgets('标题显示项目名（不是画布名，也不是退役的面包屑）', (tester) async {
    await seedVideos(1);
    await pumpGallery(tester);

    expect(_inToolBar(find.text('Alpha')), findsOneWidget);
    expect(
      find.text('Alpha / Gallery'),
      findsNothing,
      reason: 'galleryBreadcrumb 已退役，标题里不该再有 "/ Gallery" 那截',
    );
  });

  // 三条各自独立一例，变异 `itemCount: visibleCount` → `itemCount: null`
  // 时三条同时转红。
  group('计数：en 复数三分支各有覆盖', () {
    testWidgets('=0 分支：无产物 → No assets', (tester) async {
      await pumpGallery(tester);

      expect(_inToolBar(find.text('No assets')), findsOneWidget);
    });

    testWidgets('=1 分支：1 个产物 → 1 asset（不是 "1 assets"）', (tester) async {
      await seedVideos(1);
      await pumpGallery(tester);

      expect(_inToolBar(find.text('1 asset')), findsOneWidget);
    });

    testWidgets('other 分支：3 个产物 → 3 assets', (tester) async {
      await seedVideos(3);
      await pumpGallery(tester);

      expect(_inToolBar(find.text('3 assets')), findsOneWidget);
    });
  });

  // zh 一侧：zh ARB 只有 =0 / other 两支（中文无单复数），1 也走 other。
  group('计数：zh 两分支', () {
    testWidgets('=0 分支 → 没有产物', (tester) async {
      await pumpGallery(tester, locale: const Locale('zh'));

      expect(_inToolBar(find.text('没有产物')), findsOneWidget);
    });

    testWidgets('other 分支：1 个产物也走 other → 1 个产物', (tester) async {
      await seedVideos(1);
      await pumpGallery(tester, locale: const Locale('zh'));

      expect(_inToolBar(find.text('1 个产物')), findsOneWidget);
    });
  });

  // R69：标题、它正下方的网格、它正旁边的 chip，三者必须说同一件事。
  //
  // 【实测变异】visibleCount 改回全量（`itemCount: items?.length`）
  // ⇒ Expected: exactly one matching candidate / Actual: Found 0 widgets
  //   （工具条上仍写着 "4 assets"）
  testWidgets('R69：筛选后计数跟着网格走，不是全量', (tester) async {
    await seedVideos(3);
    await seedVideos(1, canvasName: 'Gamma');
    await pumpGallery(tester);
    expect(
      _inToolBar(find.text('4 assets')),
      findsOneWidget,
      reason: '前置：未筛选时是全部 4 个',
    );

    // 按画布名搜索 ⇒ 网格只剩 Gamma 那 1 个 tile。
    await tester.enterText(find.byType(TextField), 'Gamma');
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.videocam_outlined),
      findsOneWidget,
      reason: '前置：网格确实只剩 1 个 tile',
    );
    expect(
      _inToolBar(find.text('1 asset')),
      findsOneWidget,
      reason: '网格里只剩 1 个 tile，标题不能还写着 4——同屏自相矛盾',
    );
    expect(
      _inToolBar(find.text('Filters active')),
      findsOneWidget,
      reason: '前置：筛选 chip 在场，正是它让"标题说 4"显得荒谬',
    );
  });
}
