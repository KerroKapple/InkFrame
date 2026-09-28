// GalleryTile：稿的网格单元——图区 / ▶ 时长 / 选中勾 / 当前线徽标 / 序号 + 名称，
// 交互全部回调给上层（onTap 带 ⌘/Ctrl 切换位、onPreview 双击）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/util/gallery_meta.dart';
import 'package:inkframe/features/gallery/widgets/gallery_tile.dart';

import '../../../_harness/test_app.dart';

class _TempResolver implements FileResolverService {
  _TempResolver(this.root);
  final String root;

  @override
  File resolve({required String projectId, required String canvasId, required String relativePath}) =>
      File('$root/$projectId/canvases/$canvasId/$relativePath');

  @override
  File resolveInProject({required String projectId, required String relativePath}) =>
      throw UnimplementedError();

  @override
  String toRelative({required String projectId, required String canvasId, required File source}) =>
      throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) => throw UnimplementedError();
}

const List<int> _kPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

GalleryItem _image() => GalleryItem(
      kind: GalleryItemKind.image,
      relativePath: 'images/a.png',
      canvasId: 'c1',
      canvasName: 'Alpha',
      nodeId: 'n-img',
      createdAt: DateTime.utc(2026, 8, 1),
    );

GalleryItem _video({String? thumb, int? durationMs = 65000}) => GalleryItem(
      kind: GalleryItemKind.video,
      relativePath: 'videos/v.mp4',
      canvasId: 'c1',
      canvasName: 'Alpha',
      nodeId: 'n1',
      createdAt: DateTime.utc(2026, 8, 1),
      durationMs: durationMs,
      thumbnailRelativePath: thumb,
    );

Future<Directory> _root(WidgetTester tester) async {
  final root = Directory.systemTemp.createTempSync('gal_tile_');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return root;
}

class _Calls {
  final List<bool> taps = <bool>[];
  int previews = 0;
}

Future<_Calls> _pumpTile(
  WidgetTester tester, {
  required GalleryItem item,
  required String root,
  GalleryItemMeta meta = const GalleryItemMeta(label: '镜头 01 · 图像'),
  bool selected = false,
}) async {
  final _Calls calls = _Calls();
  await pumpInkApp(
    tester,
    Scaffold(
      body: Center(
        child: SizedBox(
          width: 220,
          child: GalleryTile(
            projectId: 'p1',
            item: item,
            meta: meta,
            index: 3,
            selected: selected,
            onTap: calls.taps.add,
            onPreview: () => calls.previews++,
          ),
        ),
      ),
    ),
    overrides: <Override>[fileResolverServiceProvider.overrideWithValue(_TempResolver(root))],
  );
  return calls;
}

void main() {
  testWidgets('图片：Image.file 缩略解码（ResizeImage）+ 序号 003 + 名称', (tester) async {
    final root = await _root(tester);
    File('${root.path}/p1/canvases/c1/images/a.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(_kPngBytes);
    await _pumpTile(tester, item: _image(), root: root.path);
    await tester.pump();

    final Image img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<ResizeImage>(), reason: 'LB-23：按 tile 上限缩略解码');
    expect(find.text('003'), findsOneWidget);
    expect(find.text('镜头 01 · 图像'), findsOneWidget);
  });

  testWidgets('视频：有缩略图 → Image + ▶ + 00:01:05；无缩略图 → 占位图标', (tester) async {
    final root = await _root(tester);
    File('${root.path}/p1/canvases/c1/thumbs/v.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(_kPngBytes);
    await _pumpTile(tester, item: _video(thumb: 'thumbs/v.png'), root: root.path);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('▶'), findsOneWidget);
    expect(find.text('00:01:05'), findsOneWidget);

    await _pumpTile(tester, item: _video(), root: root.path);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.text('00:01:05'), findsOneWidget);
  });

  testWidgets('缩略图路径在但文件缺失 → errorBuilder 回退 broken 图标', (tester) async {
    final root = await _root(tester);
    await _pumpTile(tester, item: _video(thumb: 'thumbs/missing.png'), root: root.path);
    // 文件读取在真实异步里失败，pumpAndSettle 等不到；runAsync 放一小段真实时间再 pump。
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('选中 → 右上 ✓；在当前线上 → 「当前线」徽标；名称为空回落到类型名', (tester) async {
    final root = await _root(tester);
    await _pumpTile(tester, item: _image(), root: root.path, selected: true,
        meta: const GalleryItemMeta(label: '', onNarrativeChain: true));
    await tester.pump();
    expect(find.text('✓'), findsOneWidget);
    expect(find.text('Current line'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget, reason: 'label 空 → 类型名');

    await _pumpTile(tester, item: _image(), root: root.path);
    await tester.pump();
    expect(find.text('✓'), findsNothing);
    expect(find.text('Current line'), findsNothing);
  });

  testWidgets('单击 → onTap(false)；Ctrl+单击 → onTap(true)；双击 → onPreview', (tester) async {
    final root = await _root(tester);
    final _Calls calls = await _pumpTile(tester, item: _image(), root: root.path);
    await tester.pump();

    await tester.tap(find.byType(GalleryTile));
    await tester.pump(const Duration(milliseconds: 400)); // 越过双击等待
    expect(calls.taps, <bool>[false]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byType(GalleryTile));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(calls.taps, <bool>[false, true]);

    await tester.tap(find.byType(GalleryTile));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(GalleryTile));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls.previews, 1);
  });
}
