// GalleryScreen widget 测试：空态 / 网格渲染（图+视频 tile）/ 返回 / 图片预览 Dialog。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/gallery/providers/current_gallery_project.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

// 1x1 透明 PNG——让 image tile 走真实 Image.file 路径。
const String _kPng1x1B64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _FakeResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

  _FakeResolver(this.dir);
  final Directory dir;

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      dir;

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) {
    if (relativePath.contains('..')) {
      throw PathSecurityError('parent traversal');
    }
    return File('${dir.path}/$relativePath');
  }

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;
}

void main() {
  late Directory tempDir;
  late InMemoryCanvasRepository canvases;
  late InMemoryNodeRepository nodes;
  late FakeBatchResultRepo batch;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ink_gallery_');
    canvases = InMemoryCanvasRepository();
    nodes = InMemoryNodeRepository();
    batch = FakeBatchResultRepo();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  List<Override> overrides() => <Override>[
        canvasRepositoryProvider.overrideWith((_) async => canvases),
        nodeRepositoryProvider.overrideWith((_) async => nodes),
        batchResultRepositoryProvider.overrideWith((_) async => batch),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver(tempDir)),
      ];

  Future<void> seedAssets() async {
    final ca = await canvases.create(projectId: 'p1', name: 'Alpha');
    await nodes.create(
      canvasId: ca,
      type: 'image',
      nodeRole: 'result',
      typeConfig: <String, Object?>{'image_url': 'images/a.png'},
    );
    await nodes.create(
      canvasId: ca,
      type: 'video',
      nodeRole: 'result',
      typeConfig: <String, Object?>{
        'video_url': 'videos/v.mp4',
        'duration_ms': 65000,
      },
    );
    Directory('${tempDir.path}/images').createSync(recursive: true);
    File('${tempDir.path}/images/a.png')
        .writeAsBytesSync(base64Decode(_kPng1x1B64));
  }

  testWidgets('空态：无产物 → empty 文案', (tester) async {
    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
      surfaceSize: const Size(1280, 800),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(find.text('No generated assets yet'), findsOneWidget);
    expect(
      find.text(
        "Images and videos generated on this project's canvases will appear here.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('数据态：image tile 渲染 Image，video tile 图标+时长，caption 带类型/画布名',
      (tester) async {
    await seedAssets();
    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
      surfaceSize: const Size(1280, 800),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    // 两个 tile 的 caption 都带画布名
    expect(find.text('Alpha'), findsNWidgets(2));
  });

  testWidgets('返回按钮：清空 currentGalleryProjectProvider', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    container.read(currentGalleryProjectProvider.notifier).state =
        (id: 'p1', name: 'Alpha');

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

    await tester.tap(find.byIcon(Icons.arrow_back));
    // DragToMoveArea 带 onDoubleTap 竞争手势：单击需过 300ms 仲裁超时才落地
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(currentGalleryProjectProvider), isNull);
  });

  testWidgets('点击 image tile → 打开预览 Dialog，可关闭', (tester) async {
    await seedAssets();
    await pumpInkApp(
      tester,
      const GalleryScreen(projectId: 'p1', projectName: 'Alpha'),
      surfaceSize: const Size(1280, 800),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
