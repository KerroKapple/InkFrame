// 画廊筛选器的存活性（T4a）：筛选态不得因为列表进入 loading/error/空态而被回收。
//
// 纯 ProviderContainer 层面无法稳定复现——autoDispose 的销毁经
// scheduleMicrotask/Timer 调度，测试同步 read 抢在调度落地前完成，
// 因此改走 widget 层：真实驱动 GalleryScreen 的 data(非空)→data(空)→
// data(非空) 三态切换，断言筛选条状态（SegmentedButton 选中值）
// 不因 `_GalleryContent` 卸载/重挂载而被 autoDispose 静默复位。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../_harness/fake_batch_result.dart';
import '../../_harness/fake_repositories.dart';

void main() {
  testWidgets(
    'error/空态抖动不得静默复位用户已选的筛选（T4a：GalleryScreen 层 watch 锚定存活性）',
    (tester) async {
      final canvases = InMemoryCanvasRepository();
      final nodes = InMemoryNodeRepository();
      final batch = FakeBatchResultRepo();
      final container = ProviderContainer(
        overrides: <Override>[
          canvasRepositoryProvider.overrideWith((_) async => canvases),
          nodeRepositoryProvider.overrideWith((_) async => nodes),
          batchResultRepositoryProvider.overrideWith((_) async => batch),
        ],
      );
      addTearDown(container.dispose);

      final canvasId = await canvases.create(projectId: 'p1', name: 'Alpha');
      final nodeId = await nodes.create(
        canvasId: canvasId,
        type: 'video',
        nodeRole: 'result',
        typeConfig: <String, Object?>{'video_url': 'videos/v.mp4'},
      );

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
}
