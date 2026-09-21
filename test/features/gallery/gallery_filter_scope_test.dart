// 画廊筛选器的存活性（T4a）+ 分键 + 搜索框播种/回灌（T4b + fix round）：
// - 筛选态不得因为列表进入 loading/error/空态而被回收；
// - 跨项目不共享；
// - 搜索框既要从 filter.query 播种，也要在 filter 从外部（如顶栏 chip）
//   被清空时把自己同步清空，不能停留在上一次输入的文本上。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/theme/primitives/ink_accent_chip.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_repositories.dart';
import '../../_harness/test_app.dart';

void main() {
  testWidgets(
    'error/空态抖动不得静默复位用户已选的筛选（T4a：GalleryScreen 层 watch 锚定存活性）',
    (tester) async {
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
          batchResultRepositoryProvider.overrideWith((_) async => batch),
        ],
        surfaceSize: const Size(1280, 800),
      );
      await tester.pumpAndSettle();

      // pump 之后从树上取 container——不手写 MaterialApp/UncontrolledProviderScope，
      // 仅为了后面 container.invalidate 这一步而借用 pumpInkApp 装配好的那份。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GalleryScreen)),
      );

      // 选中「Video」分段——建立用户的筛选态。
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<GalleryItemKind?>),
          matching: find.text('Video'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<GalleryItemKind?>>(
              find.byType(SegmentedButton<GalleryItemKind?>),
            )
            .selected,
        <GalleryItemKind?>{GalleryItemKind.video},
      );

      // 抖动：唯一的产物被软删 → 列表转空态,_GalleryContent(连同
      // SegmentedButton)整体从树上卸载。
      await nodes.softDelete(nodeId);
      container.invalidate(galleryControllerProvider('p1'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<GalleryItemKind?>), findsNothing);

      // 恢复：新增一条视频产物 → 列表转回非空,_GalleryContent 重挂载。
      await nodes.create(
        canvasId: canvasId,
        type: 'video',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'video_url': 'videos/v2.mp4'},
      );
      container.invalidate(galleryControllerProvider('p1'));
      await tester.pumpAndSettle();

      // 修复前：filter 的唯一 watcher 消失过,autoDispose 已把它复位为
      // 默认值,SegmentedButton 重挂载后选中值回到「All」（null）。
      // 修复后：GalleryScreen 层的 watch 全程锚定,这里仍是 video。
      expect(
        tester
            .widget<SegmentedButton<GalleryItemKind?>>(
              find.byType(SegmentedButton<GalleryItemKind?>),
            )
            .selected,
        <GalleryItemKind?>{GalleryItemKind.video},
        reason: 'error 重试或 data→空 的抖动不得静默复位用户的筛选',
      );
    },
  );

  test('筛选按 projectId 分键：A 的画布筛选不得清空 B 的网格', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subA =
        container.listen(galleryFilterProvider('pA'), (_, _) {}, fireImmediately: true);
    final subB =
        container.listen(galleryFilterProvider('pB'), (_, _) {}, fireImmediately: true);
    addTearDown(subA.close);
    addTearDown(subB.close);

    container.read(galleryFilterProvider('pA').notifier).state =
        const GalleryFilter(canvasId: 'canvas-in-A');

    expect(container.read(galleryFilterProvider('pA')).canvasId, 'canvas-in-A');
    expect(container.read(galleryFilterProvider('pB')).canvasId, isNull,
        reason: 'A 的 canvasId 比 B 的项必然零命中，而筛选控件会回落显示"未筛选"——界面撒谎');
  });

  testWidgets('搜索框从筛选态播种：切项目后输入框显示该项目自己的 query，不是空的或上一个项目的',
      (tester) async {
    final canvases = InMemoryCanvasRepository();
    final nodes = InMemoryNodeRepository();
    final batch = FakeBatchResultRepo();

    final ca = await canvases.create(projectId: 'pA', name: 'Alpha');
    await nodes.create(
      canvasId: ca,
      type: 'video',
      nodeRole: 'result',
      typeConfig: <String, Object?>{'video_url': 'videos/a.mp4'},
    );

    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'pA', projectName: 'Alpha'),
      overrides: <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
        // 项目 A 已经带着一条 query 筛选（模拟“回到画廊标签”这一保活场景）——
        // 用 family 实参的 overrideWith 直接播种初始状态,不再需要 pump 前
        // 手动拿 container 写 state,顺带让这条用例也能走 pumpInkApp。
        galleryFilterProvider('pA').overrideWith(
          (ref) => const GalleryFilter(query: 'alpha-scene'),
        ),
      ],
      surfaceSize: const Size(1280, 800),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'alpha-scene',
      reason: '_searchCtrl 是 onChanged 的唯一输入源，从不读回 filter.query；'
          '切项目/error 重试/data→空 都会重建 State 但不重建 filter，'
          '于是输入框显示空、筛选却仍生效——界面与真相脱同步',
    );
  });

  testWidgets('顶栏 chip 清除筛选：搜索框必须跟着清空，不能留着上一次输入的文本',
      (tester) async {
    final canvases = InMemoryCanvasRepository();
    final nodes = InMemoryNodeRepository();
    final batch = FakeBatchResultRepo();

    final ca = await canvases.create(projectId: 'pA', name: 'Alpha');
    await nodes.create(
      canvasId: ca,
      type: 'video',
      nodeRole: 'result',
      typeConfig: <String, Object?>{'video_url': 'videos/a.mp4'},
    );

    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'pA', projectName: 'Alpha'),
      overrides: <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
      ],
      surfaceSize: const Size(1280, 800),
    );
    await tester.pumpAndSettle();

    // 在搜索框里打字，建立筛选态——顶栏 chip 应该随之出现。
    await tester.enterText(find.byType(TextField), 'foo');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'foo',
    );
    expect(find.byType(InkAccentChip), findsOneWidget);

    // 点顶栏的「筛选生效中」chip 清除筛选。chip 被 InkWindowChrome 包在
    // DragToMoveArea（window_manager）里,它自带 onDoubleTap,导致同一
    // 指针的 tap 识别器要等 kDoubleTapTimeout 才能在手势竞技场胜出——
    // 额外 pump 500ms 把这段等待喂给 fake clock,否则 onTap 不会触发。
    await tester.tap(find.byType(InkAccentChip));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(
      tester.read(galleryFilterProvider('pA')).isActive,
      isFalse,
      reason: 'chip 点击必须把 provider 状态清空',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
      reason: 'chip 只改 provider、不碰 _searchCtrl 就会重新制造 4b 要消灭的'
          '「输入框与筛选态脱同步」——清除筛选必须同时清空搜索框',
    );
  });
}

extension on WidgetTester {
  T read<T>(ProviderListenable<T> provider) =>
      ProviderScope.containerOf(element(find.byType(GalleryScreen))).read(
        provider,
      );
}
