// 用户点名的三条（#234 持久标签外壳在真实使用里最可能翻的地方）：
//   A 项目设筛选 → 切画布标签 → 切 B 项目的画廊 → 切回 A：
//   1. 筛选是否还在（provider 值）
//   2. 控件显示与实际生效是否一致（筛选行高亮 + 网格按它过滤）
//   3. 滚动位置是否保持（GridView 的 ScrollPosition.pixels）
// 顺带：缩略图尺寸档、选中集也要留着。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';
import 'package:inkframe/features/gallery/providers/gallery_selection.dart';
import 'package:inkframe/features/gallery/widgets/gallery_filter_panel.dart';
import 'package:inkframe/features/gallery/widgets/gallery_grid.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/gallery/widgets/gallery_tile.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_canvas.dart';
import '../../_harness/fake_repositories.dart';
import '../../_harness/shell_app.dart';

ScrollPosition _gridPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)),
    )
    .position;

Color? _rowColor(WidgetTester tester, Key key) => tester
    .widget<Container>(find.descendant(of: find.byKey(key), matching: find.byType(Container)).first)
    .color;

void main() {
  const ProjectRef alpha = ProjectRef(id: 'pA', name: 'Alpha');
  const ProjectRef beta = ProjectRef(id: 'pB', name: 'Beta');

  testWidgets('A 设筛选 → 切画布 → 切 B 画廊 → 切回 A：筛选还在、控件一致、滚动位置保持', (tester) async {
    final canvases = InMemoryCanvasRepository();
    final nodes = InMemoryNodeRepository();
    final batch = FakeBatchResultRepo();
    // A：30 个视频（可滚）+ 5 张图；B：3 个视频。
    final String ca = await canvases.create(projectId: 'pA', name: 'A-canvas');
    for (int i = 0; i < 30; i++) {
      await nodes.create(
        canvasId: ca,
        type: 'video',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'video_url': 'videos/a$i.mp4', 'duration_ms': 1000},
      );
    }
    for (int i = 0; i < 5; i++) {
      await nodes.create(
        canvasId: ca,
        type: 'image',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'image_url': 'images/a$i.png'},
      );
    }
    final String cb = await canvases.create(projectId: 'pB', name: 'B-canvas');
    for (int i = 0; i < 3; i++) {
      await nodes.create(
        canvasId: cb,
        type: 'video',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'video_url': 'videos/b$i.mp4', 'duration_ms': 1000},
      );
    }

    final paths = await setupTempPaths(tester, 'ink_shell_gallery_keep_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.gallery, project: alpha),
      surfaceSize: const Size(1600, 1000),
      extraOverrides: <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
        fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
        canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
        canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
        canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      ],
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    final ProviderContainer c = readShellContainer(tester);
    expect(find.byType(GalleryTile), findsWidgets);

    // 1) A 设筛选：视频；选中一项；换特大档；滚一段。
    final Key videoRow = GalleryFilterPanel.rowKey('type', GalleryItemKind.video.name);
    await tester.tap(find.byKey(videoRow));
    await tester.pump();
    expect(c.read(galleryFilterProvider('pA')).kind, GalleryItemKind.video);
    await tester.tap(find.byType(GalleryTile).first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(GalleryGrid.sizeKey(GalleryThumbSize.xlarge)));
    await tester.pump();
    await tester.drag(find.byType(GridView), const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final double scrolled = _gridPosition(tester).pixels;
    expect(scrolled, greaterThan(0), reason: '前置条件：真的滚到了非零位置');
    final int tilesBefore = tester.widgetList(find.byType(GalleryTile)).length;

    // 2) 切画布标签。
    await tapShellTab(tester, ShellTab.canvas);
    expect(find.byType(GalleryScreen), findsNothing, reason: '画廊离屏（保活但不在台上）');

    // 3) 切 B 项目的画廊（换项目 = GalleryScreen(pB)）。
    c.read(shellControllerProvider.notifier).openGallery(beta);
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(c.read(shellControllerProvider).project?.id, 'pB');
    expect(c.read(galleryFilterProvider('pB')).isActive, isFalse, reason: 'B 不能继承 A 的筛选');
    expect(_rowColor(tester, videoRow), isNull, reason: 'B 的筛选行不能显示为选中');
    expect(find.byType(GalleryTile), findsNWidgets(3));

    // 4) 切回 A。
    c.read(shellControllerProvider.notifier).openGallery(alpha);
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    // ① 筛选还在。
    expect(c.read(galleryFilterProvider('pA')).kind, GalleryItemKind.video, reason: '① 筛选还在');
    // ② 控件显示与实际生效一致：行高亮 + 网格只有视频 + 尺寸档仍是特大。
    expect(_rowColor(tester, videoRow), isNotNull, reason: '② 筛选行高亮');
    expect(find.byType(Image), findsNothing, reason: '② 网格按视频过滤（图片没出现）');
    expect(tester.widgetList(find.byType(GalleryTile)).length, tilesBefore, reason: '② 可见 tile 数一致');
    expect(c.read(galleryThumbSizeProvider), GalleryThumbSize.xlarge, reason: '② 尺寸档保留');
    expect(c.read(gallerySelectionProvider('pA')).count, 1, reason: '选中集保留');
    // ③ 滚动位置保持。
    expect(_gridPosition(tester).pixels, scrolled, reason: '③ 滚动位置一格不差');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
