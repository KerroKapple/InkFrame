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

import 'package:inkframe/core/di/character_assets.dart';
import 'package:inkframe/core/di/repositories.dart';

import '../../../_harness/fake_character.dart';
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

Future<void> _pumpTile(
  WidgetTester tester, {
  required GalleryItem item,
  required String root,
  List<Override> extraOverrides = const <Override>[],
}) =>
    pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: GalleryTile(projectId: 'p1', item: item),
          ),
        ),
      ),
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_TempResolver(root)),
        ...extraOverrides,
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
    // 评审 F1/F5 钉死：errorBuilder 整体接管,播放角标不残留、时长只显一份。
    expect(find.byIcon(Icons.play_circle_outline), findsNothing,
        reason: '缩略图失败时播放角标不得叠在占位图上');
    expect(find.text('01:05'), findsOneWidget,
        reason: '时长只显占位图内一份,不得双份');
  });

  testWidgets('item 变更复位 broken 态（GridView Element 复用防串位,评审 F2）',
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
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    // 同位置换 item（无 key 的 Element 复用路径）→ didUpdateWidget 复位。
    await _pumpTile(
      tester,
      item: _video(thumb: 'thumbnails/v.jpg').copyWith(
        relativePath: 'videos/other.mp4',
        nodeId: 'n2',
      ),
      root: root.path,
    );
    await tester.pump();

    expect(find.byIcon(Icons.broken_image_outlined), findsNothing,
        reason: '换 item 后 broken 态不得串位残留');
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });

  testWidgets('无缩略图 → 原图标+时长占位（首切片回退不变）', (tester) async {
    final root = await _root(tester);

    await _pumpTile(tester, item: _video(), root: root.path);

    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
  });

  testWidgets('GA-4 存为角色：菜单仅 image 项;命名确认 → createFromImage + 成功提示',
      (tester) async {
    final root = await _root(tester);
    File('${root.path}/p1/canvases/c1/images/a.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(_kPngBytes);
    final repo = FakeCharacterRepo();
    final assets = FakeCharacterAssetService();

    await _pumpTile(
      tester,
      item: _image(),
      root: root.path,
      extraOverrides: <Override>[
        characterRepositoryProvider.overrideWith((_) async => repo),
        characterAssetServiceProvider.overrideWithValue(assets),
      ],
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as character'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hero');
    await tester.pump();
    await tester.tap(find.text('Save')); // 对话框确认键（inspectorCharactersSave）
    await tester.pumpAndSettle();

    expect(repo.rows, hasLength(1), reason: '角色记录已建');
    expect(assets.imported, hasLength(1), reason: '参考图已导入');
    expect(find.text('Character saved'), findsOneWidget);
  });

  testWidgets('GA-4 视频项无「存为角色」菜单', (tester) async {
    final root = await _root(tester);

    await _pumpTile(tester, item: _video(), root: root.path);

    expect(find.byIcon(Icons.more_vert), findsNothing);
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
