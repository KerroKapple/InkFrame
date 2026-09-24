// 浮层形态（Screens 稿第 3 屏）后，外层 IndexedStack 换成了 Stack——它以前替外壳做的两件事
// 现在由显式代码承担，本文件是这两处代码各自的靶子（2026-09-25 变异实测，两条都是单点靶）：
//   ① 点不穿：ShellOverlayLayer 的 ModalBarrier。变异成 IgnorePointer(ColoredBox) 后，
//      app_routing_test 的 hittable:false 三处【仍绿】——它们在标签体中心点命中，而对话框
//      恰好也在中心，挡住它的是对话框不是遮罩。所以这里在对话框【之外】的点上验：
//      画廊筛选行在左侧 220 列，对话框左沿在 (1440-1122)/2 ≈ 159 之右。
//   ② 不持焦：ShellContentStack 的 ExcludeFocus(excluding: overlay != null)。变异成 excluding: false
//      后 shell / settings / routing 全绿——画布自己有 isActive 守卫，测不出；空态 CTA 的 InkWell
//      本身就不可聚焦，也测不出。有鉴别力的是画廊网格的键盘导航焦点节点（'gallery-grid'）：
//      浮层开着时它 canRequestFocus 必须为 false、requestFocus 必须落空。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';
import 'package:inkframe/features/gallery/widgets/gallery_filter_panel.dart';
import 'package:inkframe/features/settings/settings_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';

const ProjectRef _alpha = ProjectRef(id: 'p1', name: 'Alpha');

/// 一个产物就够让画廊网格挂上它的焦点节点。
class _OneItemGallery extends GalleryController {
  @override
  Future<List<GalleryItem>> build(String projectId) async => <GalleryItem>[
        GalleryItem(
          kind: GalleryItemKind.image,
          relativePath: 'images/one.png',
          canvasId: 'c1',
          canvasName: 'Alpha',
          nodeId: 'n1',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
}

Future<void> _pumpFrames(WidgetTester tester, [int n = 4]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('浮层打开时，遮罩之外的点也点不到底下的标签体（画廊筛选行不生效）', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_overlay_barrier_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.gallery, project: _alpha, overlay: ShellOverlay.settings),
    );
    await _pumpFrames(tester);
    final ProviderContainer c = readShellContainer(tester);
    final Finder imageRow = find.byKey(GalleryFilterPanel.rowKey('type', GalleryItemKind.image.name), skipOffstage: false);
    expect(imageRow, findsOneWidget, reason: '前置：画廊标签体在浮层底下仍在树里');
    // 前置：这个点确实在对话框之外，否则挡住它的是对话框而不是遮罩。
    final Rect dialog = tester.getRect(find.byKey(SettingsScreen.titleBarKey));
    expect(tester.getCenter(imageRow).dx, lessThan(dialog.left));

    await tester.tap(imageRow, warnIfMissed: false);
    await _pumpFrames(tester);

    expect(c.read(galleryFilterProvider('p1')).kind, isNull, reason: '遮罩必须吃掉指针：筛选不能被点穿改掉');
    expect(c.read(shellControllerProvider).overlay, ShellOverlay.settings, reason: '点遮罩也不关浮层');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('浮层打开时，底下标签体里的可聚焦控件拿不到焦点（画廊网格的键盘焦点节点）', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_overlay_focus_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.gallery, project: _alpha, overlay: ShellOverlay.settings),
      extraOverrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
        galleryControllerProvider.overrideWith(() => _OneItemGallery()),
      ],
    );
    await _pumpFrames(tester);
    // 画廊网格自带一个键盘导航焦点节点（gallery_grid.dart 的 'gallery-grid'），只有有产物时才挂。
    final Finder gridFocus = find.byWidgetPredicate(
      (Widget w) => w is Focus && w.focusNode?.debugLabel == 'gallery-grid',
      skipOffstage: false,
    );
    expect(gridFocus, findsOneWidget, reason: '前置：画廊网格在浮层底下仍在树里');
    final FocusNode node = tester.widget<Focus>(gridFocus).focusNode!;

    expect(node.canRequestFocus, isFalse, reason: '标签宿主整体在 ExcludeFocus 之下');
    node.requestFocus();
    await tester.pump();
    expect(primaryFocus, isNot(same(node)), reason: 'requestFocus 必须落空');
    expect(primaryFocus?.debugLabel, 'SettingsOverlay', reason: '焦点仍在浮层');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
