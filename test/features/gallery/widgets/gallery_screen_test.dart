// GalleryScreen（稿接线版）：空态 / 数据态 / 筛选行 / 选中与信息面板 / 双击预览 / 键盘。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';
import 'package:inkframe/features/gallery/providers/gallery_selection.dart';
import 'package:inkframe/features/gallery/providers/gallery_view.dart';
import 'package:inkframe/features/gallery/util/gallery_meta.dart';
import 'package:inkframe/features/gallery/widgets/gallery_filter_panel.dart';
import 'package:inkframe/features/gallery/widgets/gallery_grid.dart';
import 'package:inkframe/features/gallery/widgets/gallery_info_panel.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/gallery/widgets/gallery_tile.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _kPng1x1B64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _FakeResolver implements FileResolverService {
  _FakeResolver(this.dir);
  final Directory dir;

  @override
  File resolveInProject({required String projectId, required String relativePath}) => throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) => dir;

  @override
  File resolve({required String projectId, required String canvasId, required String relativePath}) {
    if (relativePath.contains('..')) throw PathSecurityError('parent traversal');
    return File('${dir.path}/$relativePath');
  }

  @override
  String toRelative({required String projectId, required String canvasId, required File source}) => source.path;
}

T _read<T>(WidgetTester tester, ProviderListenable<T> p) =>
    ProviderScope.containerOf(tester.element(find.byType(GalleryScreen))).read(p);

void main() {
  late Directory tempDir;
  late InMemoryCanvasRepository canvases;
  late InMemoryNodeRepository nodes;
  late InMemoryEdgeRepository edges;
  late FakeBatchResultRepo batch;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ink_gallery_');
    canvases = InMemoryCanvasRepository();
    nodes = InMemoryNodeRepository();
    edges = InMemoryEdgeRepository();
    batch = FakeBatchResultRepo();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  List<Override> overrides() => <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        edgeRepositoryProvider.overrideWith((_) async => edges),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver(tempDir)),
      ];

  /// 画布 Alpha：config「镜头 01 · 图像」→ result a.png；config「镜头 03 · 图转视频」→ result v.mp4。
  Future<void> seedAssets() async {
    final ca = await canvases.create(projectId: 'p1', name: 'Alpha');
    final imgCfg = await nodes.create(
      canvasId: ca,
      type: 'image',
      nodeRole: 'config',
      label: '镜头 01 · 图像',
      typeConfig: <String, Object?>{'provider_id': 'gemini-image', 'prompt': 'a cat'},
    );
    await nodes.create(
      canvasId: ca,
      type: 'image',
      nodeRole: 'result',
      sourceNodeId: imgCfg,
      typeConfig: <String, Object?>{'image_url': 'images/a.png'},
    );
    final vidCfg = await nodes.create(
      canvasId: ca,
      type: 'video',
      nodeRole: 'config',
      label: '镜头 03 · 图转视频',
      typeConfig: <String, Object?>{'provider_id': 'kling-v3'},
    );
    await nodes.create(
      canvasId: ca,
      type: 'video',
      nodeRole: 'result',
      sourceNodeId: vidCfg,
      typeConfig: <String, Object?>{'video_url': 'videos/v.mp4', 'duration_ms': 65000},
    );
    Directory('${tempDir.path}/images').createSync(recursive: true);
    File('${tempDir.path}/images/a.png').writeAsBytesSync(base64Decode(_kPng1x1B64));
  }

  Future<void> pump(WidgetTester tester) async {
    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
      surfaceSize: const Size(1400, 900),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
  }

  Finder tileNamed(String name) => find.ancestor(of: find.text(name), matching: find.byType(GalleryTile));

  testWidgets('空态：无产物 → empty 文案', (tester) async {
    await pump(tester);
    expect(find.text('No generated assets yet'), findsOneWidget);
    expect(find.text("Images and videos generated on this project's canvases will appear here."), findsOneWidget);
  });

  testWidgets('数据态：图片 tile 渲染 Image，视频 tile ▶ + 00:01:05，说明行是「序号 源节点名」', (tester) async {
    await seedAssets();
    await pump(tester);

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('00:01:05'), findsOneWidget);
    expect(find.descendant(of: find.byType(GalleryTile), matching: find.text('镜头 01 · 图像')), findsOneWidget);
    expect(find.descendant(of: find.byType(GalleryTile), matching: find.text('镜头 03 · 图转视频')), findsOneWidget);
    expect(find.text('001'), findsOneWidget);
    expect(find.text('002'), findsOneWidget);
    // 左栏四组的标题与计数。
    expect(find.text('Scope'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Marks'), findsOneWidget);
    expect(find.text('All in project'), findsWidgets);
    // 工具行「2 items」；右栏未选中时提示。
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Select an asset to see its details'), findsOneWidget);
  });

  testWidgets('筛选行：点「Video」只留视频；再点取消；画布行按画布过滤', (tester) async {
    await seedAssets();
    final cb = await canvases.create(projectId: 'p1', name: 'Beta');
    await nodes.create(
      canvasId: cb,
      type: 'video',
      nodeRole: 'result',
      typeConfig: <String, Object?>{'video_url': 'videos/b.mp4', 'duration_ms': 1000},
    );
    await pump(tester);
    expect(find.byType(GalleryTile), findsNWidgets(3));

    await tester.tap(find.byKey(GalleryFilterPanel.rowKey('type', 'video')));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTile), findsNWidgets(2));
    expect(find.byType(Image), findsNothing);
    expect(_read(tester, galleryFilterProvider('p1')).kind, GalleryItemKind.video);

    await tester.tap(find.byKey(GalleryFilterPanel.rowKey('type', 'video')));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTile), findsNWidgets(3), reason: '再点已选中的行 = 取消');

    await tester.tap(find.byKey(GalleryFilterPanel.rowKey('scope', cb)));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTile), findsOneWidget);
    expect(find.text('Beta'), findsWidgets, reason: '工具行范围名跟着变');
  });

  testWidgets('筛选零命中 → no-match 态 + 清除筛选恢复', (tester) async {
    await seedAssets();
    await pump(tester);
    // 「模型」组只有 gemini / kling；先选 kling（只剩视频），再叠加「Image」类型 → 零命中。
    await tester.tap(find.byKey(GalleryFilterPanel.rowKey('model', 'kling-v3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(GalleryFilterPanel.rowKey('type', 'image')));
    await tester.pumpAndSettle();
    expect(find.text('No results match the current filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryTile), findsNWidgets(2));
    expect(_read(tester, galleryFilterProvider('p1')).isActive, isFalse);
  });

  testWidgets('单击 tile → 选中 + 右栏显示名称 / 服务商 / 血缘；Ctrl+单击追加', (tester) async {
    await seedAssets();
    await pump(tester);

    await tester.tap(tileNamed('镜头 03 · 图转视频'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(_read(tester, gallerySelectionProvider('p1')).count, 1);
    expect(find.text('✓'), findsOneWidget);
    // 右栏：名称、服务商行、片长行、血缘标题 + 当前项行。
    // 名称出现在标题行 + 血缘「当前项」行。
    expect(find.descendant(of: find.byType(GalleryInfoPanel), matching: find.text('镜头 03 · 图转视频')), findsNWidgets(2));
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.descendant(of: find.byType(GalleryInfoPanel), matching: find.text('00:01:05')), findsOneWidget);
    expect(find.text('Lineage · current line'), findsOneWidget);
    expect(find.textContaining('Current item'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(tileNamed('镜头 01 · 图像'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_read(tester, gallerySelectionProvider('p1')).count, 2);
    expect(find.text('✓'), findsNWidgets(2));

    // 「血缘」标签只剩血缘块。
    await tester.tap(find.byKey(GalleryInfoPanel.lineageTabKey));
    await tester.pumpAndSettle();
    expect(find.text('Provider'), findsNothing);
    expect(find.text('Lineage · current line'), findsOneWidget);
  });

  testWidgets('双击图片 tile → 打开预览 Dialog，可关闭', (tester) async {
    await seedAssets();
    await pump(tester);

    await tester.tap(tileNamed('镜头 01 · 图像'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tileNamed('镜头 01 · 图像'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('键盘：→ 移锚点，空格预览锚点', (tester) async {
    await seedAssets();
    await pump(tester);
    // 两条产物 createdAt 可能同刻（Windows 毫秒钟）也可能不同（Linux 微秒钟），排序随之变——
    // 按网格里的实际顺序取第一 / 第二项，不写死是哪个。
    final List<GalleryItem> items = _read(tester, galleryFilteredItemsProvider('p1'));
    final Map<String, GalleryItemMeta> meta = _read(tester, galleryMetaProvider('p1'));
    String nameOf(int i) => meta[galleryItemKey(items[i])]!.label;
    await tester.tap(tileNamed(nameOf(0)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_read(tester, gallerySelectionProvider('p1')).anchor, galleryItemKey(items[1]));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_read(tester, gallerySelectionProvider('p1')).anchor, galleryItemKey(items[0]));

    // 空格预览：把锚点挪到图片项（视频预览要真 media_kit，测试环境进不去）。
    final int imageAt = items.indexWhere((GalleryItem i) => i.kind == GalleryItemKind.image);
    await tester.tap(tileNamed(nameOf(imageAt)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('缩略图尺寸档：特大 → 3 列', (tester) async {
    await seedAssets();
    await pump(tester);
    await tester.tap(find.byKey(GalleryGrid.sizeKey(GalleryThumbSize.xlarge)));
    await tester.pumpAndSettle();
    final GridView grid = tester.widget<GridView>(find.byType(GridView));
    expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 3);
  });

  testWidgets('「在画布中定位」→ 打开画布并选中节点', (tester) async {
    await seedAssets();
    await pump(tester);
    await tester.tap(tileNamed('镜头 01 · 图像'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(GalleryInfoPanel.locateKey));
    await tester.pumpAndSettle();
    final ShellState s = _read(tester, shellControllerProvider);
    expect(s.tab, ShellTab.canvas);
    expect(s.canvasId, isNotNull);
    expect(s.project?.id, 'p1');
  });
}
