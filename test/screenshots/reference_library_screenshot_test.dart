// 素材页「参考库」段截图（PR 附图用）：网格、点格子后的菜单、没选文件夹的空态。
//
// 跑法：flutter test --tags screenshot test/screenshots/reference_library_screenshot_test.dart
// 产物落在 build/screenshots/（gitignored）。条目是写死的假数据，缩略图指向不存在的路径（格子画占位）——
// 截图要贴进公开的 PR，不能带真图库的图（版权归原作者）。
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/reference_library.dart';
import 'package:inkframe/core/interfaces/reference_library_reader.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/reference_item.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/reference_library_section.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../_harness/screenshot.dart';

const List<(String, String, String)> _poses = <(String, String, String)>[
  ('自然站立・双手垂放', '站姿', '正面'),
  ('侧身回眸', '站姿', '斜前'),
  ('单手插兜', '站姿', '正面'),
  ('抬手挡光', '站姿', '侧面'),
  ('交叉手臂', '站姿', '正面'),
  ('倚墙站立', '站姿', '背面'),
  ('坐姿・抱膝', '坐姿', '正面'),
  ('迈步向前', '行走', '侧面'),
];

final List<ReferenceItem> _items = <ReferenceItem>[
  for (int i = 0; i < _poses.length; i++)
    ReferenceItem(
      id: 'p$i',
      category: ReferenceCategory.pose,
      name: _poses[i].$1,
      group: _poses[i].$2,
      angle: _poses[i].$3,
      thumbPath: 'Z:/__shot__/thumbs/p$i.webp',
      originalPath: 'Z:/__shot__/img/p$i.webp',
      searchText: _poses[i].$1,
    ),
  for (int i = 0; i < 5; i++)
    ReferenceItem(
      id: 'r$i',
      category: ReferenceCategory.portrait,
      name: '短发・标准款 $i',
      group: '正脸参考',
      thumbPath: 'Z:/__shot__/thumbs/r$i.webp',
      originalPath: 'Z:/__shot__/img/r$i.webp',
      searchText: '短发',
    ),
  for (int i = 0; i < 3; i++)
    ReferenceItem(
      id: 'c$i',
      category: ReferenceCategory.costume,
      name: '春季针织衫・半身裙 $i',
      group: '春季穿搭',
      thumbPath: 'Z:/__shot__/thumbs/c$i.webp',
      originalPath: 'Z:/__shot__/img/c$i.webp',
      searchText: '春季',
    ),
];

class _Reader implements ReferenceLibraryReader {
  _Reader(this.result);
  final ReferenceLibraryLoad result;
  @override
  Future<ReferenceLibraryLoad> load(String rootPath) async => result;
}

class _Nodes extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => const <CanvasNode>[
        CanvasNode(
          id: 'cfg',
          label: '镜头 03 · 雨中回头',
          type: CanvasNodeType.image,
          canvasId: 'c1',
          typeConfig: <String, Object?>{'provider_id': 'wanx-image'},
        ),
      ];
}

class _Edges extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[];
}

List<Override> _overrides({String? root}) => <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: const ShellState(
            tab: ShellTab.canvas,
            canvasId: 'c1',
            project: ProjectRef(id: 'p1', name: '短剧示例'),
          ),
        ),
      ),
      preferencesServiceProvider.overrideWithValue(
        InMemoryPreferencesService(AppPreferences(referenceLibraryRoot: root)),
      ),
      referenceLibraryReaderProvider
          .overrideWithValue(_Reader(ReferenceLibraryLoaded(_items, const <String>[]))),
      referenceFolderPickerProvider.overrideWithValue(() async => null),
      canvasNodesControllerProvider.overrideWith(_Nodes.new),
      canvasEdgesControllerProvider.overrideWith(_Edges.new),
    ];

// Material 默认组件的字走 textTheme（Roboto 已被测试注册，塞不进中文）：整块换成 Noto Sans SC，截图里中文才不成方框。
final Widget _scene = Builder(
  builder: (BuildContext context) {
    final ThemeData t = Theme.of(context);
    return Theme(
      data: t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Noto Sans SC')),
      child: const Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 241, height: 640, child: ReferenceLibrarySection(canvasId: 'c1')),
      ),
    );
  },
);

void main() {
  String? font;
  setUpAll(() async {
    font = await loadRealCjkFont();
  });

  Future<void> shoot(WidgetTester tester, String name, {String? root = 'D:/参考库/ai-pose-gallery-zh', bool openMenu = false}) async {
    if (font == null) {
      markTestSkipped('本机没有可用的中文字体，跳过');
      return;
    }
    await pumpScreenshotScene(tester, _scene, size: const Size(560, 640), overrides: _overrides(root: root));
    await tester.pumpAndSettle();
    if (openMenu) {
      final ProviderContainer c = ProviderScope.containerOf(
        tester.element(find.byType(ReferenceLibrarySection)),
        listen: false,
      );
      final ProviderSubscription<Set<String>> keep =
          c.listen(canvasSelectionControllerProvider('c1'), (_, _) {});
      addTearDown(keep.close);
      c.read(canvasSelectionControllerProvider('c1').notifier).select('cfg');
      await tester.pump();
      await tester.tap(find.byKey(ReferenceLibrarySection.tileKey('p1')));
      await tester.pumpAndSettle();
    }
    await captureToPng(tester, kScreenshotBoundary, 'build/screenshots/reference_library_$name.png');
  }

  testWidgets('网格', (tester) => shoot(tester, 'grid'));
  testWidgets('菜单（选中了 wanx-image 的图像配置）', (tester) => shoot(tester, 'menu', openMenu: true));
  testWidgets('空态：没选文件夹', (tester) => shoot(tester, 'empty', root: null));
}
