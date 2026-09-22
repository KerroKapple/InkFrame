// T9：把 `when` 的 skipLoadingOnRefresh 默认值钉死在一条真断言上。
//
// riverpod 2.6.1：ref.invalidate 走 refresh 而非 reload，AsyncValue.when 默认
// skipLoadingOnRefresh: true ⇒ 刷新期间不走 loading 分支 ⇒ _GalleryContent
// 不卸载 ⇒ GridView 的 ScrollPosition 原地不动。
//
// 【实测变异】给 gallery_screen.dart 的 when 加上 skipLoadingOnRefresh: false：
//   Expected: <400.0>  Actual: <0.0>
// 断言的是"等于刷新前记下的那个数"，不是"不为零"——退化成 0 与退化成别的值
// 都得红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_repositories.dart';

/// GridView 自己那条 Scrollable 的位置——收窄到 GridView 子树，别撞上
/// 搜索框 TextField 内部的 Scrollable。
ScrollPosition _gridPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

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

  // 视频 result 节点：tile 只画图标+时长，不碰文件系统。
  Future<void> seedVideos(int n) async {
    final String ca = await canvases.create(projectId: 'p1', name: 'Alpha');
    for (int i = 0; i < n; i++) {
      await nodes.create(
        canvasId: ca,
        type: 'video',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'video_url': 'videos/v$i.mp4'},
      );
    }
  }

  testWidgets('invalidate 后 GridView 的 ScrollPosition.pixels 不变', (tester) async {
    await seedVideos(60);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer container =
        ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final double before = _gridPosition(tester).pixels;
    // 前置条件（不是被证明的那条）：真的滚到了非零位置。
    expect(before, greaterThan(0));

    container.invalidate(galleryControllerProvider('p1'));
    await tester.pumpAndSettle();

    expect(
      _gridPosition(tester).pixels,
      before,
      reason: 'skipLoadingOnRefresh 默认 true ⇒ 刷新不卸载 _GalleryContent '
          '⇒ 滚动位置必须一格不差地留着',
    );
  });
}
