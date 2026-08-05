// GalleryTile 视频二切片（GA-1/2）：缩略图渲染/回退、时长与播放角标、
// 点击缺失视频 → broken 态。播放成功路径只验接线（media_kit 不进单测环境）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/widgets/gallery_tile.dart';

import '../../../_harness/test_app.dart';

/// 指向真实临时目录的 resolver（canvas 双参根）。
class _TempResolver implements FileResolverService {
  _TempResolver(this.root);
  final String root;

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('$root/$projectId/canvases/$canvasId/$relativePath');

  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      throw UnimplementedError();
}

// 1x1 透明 PNG（真图字节,Image.file 可解码）。
const List<int> _kPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

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

Future<void> _pumpTile(
  WidgetTester tester, {
  required GalleryItem item,
  required String root,
}) =>
    pumpInkApp(
      tester,
      Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: GalleryTile(projectId: 'p1', item: item),
        ),
      ),
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_TempResolver(root)),
      ],
    );

void main() {
  testWidgets('有缩略图且文件存在 → Image.file 渲染 + 播放角标 + mm:ss 时长角标',
      (tester) async {
    final root = await _root(tester);
    File('${root.path}/p1/canvases/c1/thumbnails/v.jpg')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(_kPngBytes);

    await _pumpTile(
      tester,
      item: _video(thumb: 'thumbnails/v.jpg'),
      root: root.path,
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
  });

  testWidgets('缩略图路径在但文件缺失 → errorBuilder 回退图标占位', (tester) async {
    final root = await _root(tester);

    await _pumpTile(
      tester,
      item: _video(thumb: 'thumbnails/gone.jpg'),
      root: root.path,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
  });

  testWidgets('无缩略图 → 原图标+时长占位（首切片回退不变）', (tester) async {
    final root = await _root(tester);

    await _pumpTile(tester, item: _video(), root: root.path);

    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
  });

  testWidgets('点击视频但文件缺失 → broken 态,不开 lightbox', (tester) async {
    final root = await _root(tester);
    File('${root.path}/p1/canvases/c1/thumbnails/v.jpg')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(_kPngBytes);

    await _pumpTile(
      tester,
      item: _video(thumb: 'thumbnails/v.jpg'),
      root: root.path,
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget,
        reason: '视频文件缺失 → broken 态');
    expect(find.byType(Dialog), findsNothing);
  });
}
