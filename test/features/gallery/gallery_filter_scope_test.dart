// 画廊筛选的存活性与分键：
//   1. error / 空态抖动不得静默复位用户已选的筛选（筛选 provider 是 keepAlive，
//      不再依赖某个 watcher 锚定）——数据转空再转回非空，筛选行仍选中、网格仍按它过滤。
//   2. 按 projectId 分键：A 的筛选不影响 B。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';
import 'package:inkframe/features/gallery/providers/gallery_graph_provider.dart';
import 'package:inkframe/features/gallery/widgets/gallery_filter_panel.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/gallery/widgets/gallery_tile.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_repositories.dart';
import '../../_harness/test_app.dart';

Container _rowBox(WidgetTester tester, Key key) => tester.widget<Container>(
      find.descendant(of: find.byKey(key), matching: find.byType(Container)).first,
    );

void main() {
  testWidgets('error/空态抖动不得静默复位用户已选的筛选', (tester) async {
    final canvases = InMemoryCanvasRepository();
    final nodes = InMemoryNodeRepository();
    final batch = FakeBatchResultRepo();

    final canvasId = await canvases.create(projectId: 'p1', name: 'Alpha');
    final nodeId = await nodes.create(
      canvasId: canvasId,
      type: 'video',
      nodeRole: 'result',
      typeConfig: <String, Object?>{'video_url': 'videos/v.mp4'},
    );

    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
      overrides: <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        edgeRepositoryProvider.overrideWith((_) async => InMemoryEdgeRepository()),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
      ],
      surfaceSize: const Size(1280, 800),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(GalleryScreen)));

    // 点「视频」筛选行——建立用户的筛选态。
    final Key videoRow = GalleryFilterPanel.rowKey('type', GalleryItemKind.video.name);
    await tester.tap(find.byKey(videoRow));
    await tester.pumpAndSettle();
    expect(container.read(galleryFilterProvider('p1')).kind, GalleryItemKind.video);
    expect(_rowBox(tester, videoRow).color, isNotNull, reason: '选中行有底色');

    // 抖动：唯一的产物被软删 → 列表转空态，网格整体从树上卸载。
    await nodes.softDelete(nodeId);
    container.invalidate(galleryGraphProvider('p1'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTile), findsNothing);

    // 恢复：新增一条视频 + 一条图片 → 列表转回非空。
    await nodes.create(
      canvasId: canvasId,
      type: 'video',
      nodeRole: 'result',
      typeConfig: <String, Object?>{'video_url': 'videos/v2.mp4'},
    );
    await nodes.create(
      canvasId: canvasId,
      type: 'image',
      nodeRole: 'result',
      typeConfig: <String, Object?>{'image_url': 'images/i.png'},
    );
    container.invalidate(galleryGraphProvider('p1'));
    await tester.pumpAndSettle();

    expect(container.read(galleryFilterProvider('p1')).kind, GalleryItemKind.video,
        reason: 'error 重试或 data→空 的抖动不得静默复位用户的筛选');
    expect(_rowBox(tester, videoRow).color, isNotNull, reason: '控件显示与实际生效一致');
    expect(find.byType(GalleryTile), findsOneWidget, reason: '网格仍按「视频」过滤');
  });

  test('筛选按 projectId 分键：A 的画布筛选不得清空 B 的网格', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(galleryFilterProvider('pA').notifier).state = const GalleryFilter(canvasId: 'canvas-in-A');

    expect(container.read(galleryFilterProvider('pA')).canvasId, 'canvas-in-A');
    expect(container.read(galleryFilterProvider('pB')).canvasId, isNull,
        reason: 'A 的 canvasId 比 B 的项必然零命中，而筛选控件会回落显示"未筛选"——界面撒谎');
  });

  test('筛选 provider 是 keepAlive：没有 watcher 也不回收', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(galleryFilterProvider('pA'), (_, _) {});
    container.read(galleryFilterProvider('pA').notifier).state = const GalleryFilter(kind: GalleryItemKind.video);
    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(galleryFilterProvider('pA')).kind, GalleryItemKind.video,
        reason: '切走画廊后唯一的 watcher 消失，筛选也必须留着');
  });
}
