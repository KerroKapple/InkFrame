// VideoNodeBody widget tests：
//   - 无 videoUrl → hourglass 占位
//   - 有 thumbnail_url 但文件缺失 → broken_image 占位
//   - 有 video_url 无 thumbnail_url → play_circle_outline
//
// 直接 override fileResolverServiceProvider 为 FakeResolver，避开 real fs I/O
// 与 testWidgets fake-async zone 的死锁（TD-003 旧方案 await Directory.createTemp
// 让 pump 永不收敛）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/video_node_body.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_resolver_service.dart';

class _FakeResolver implements FileResolverService {
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

Widget _host(Widget child, {FileResolverService? resolver}) => ProviderScope(
      overrides: [
        if (resolver != null)
          fileResolverServiceProvider.overrideWithValue(resolver),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('VideoNodeBody', () {
    testWidgets('无 videoUrl → hourglass 占位', (tester) async {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        sourceNodeId: 'c1',
      );
      await tester.pumpWidget(_host(const VideoNodeBody(node: node)));
      expect(find.byIcon(Icons.hourglass_empty_outlined), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    });

    testWidgets('有 thumbnail_url 但文件缺失 → broken_image 占位', (tester) async {
      final resolver = _FakeResolver(
        Directory('/tmp/inkframe-video-node-body-nonexistent'),
      );

      const node = CanvasNode(
        id: 'n2',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        sourceNodeId: 'c1',
        projectId: 'proj-1',
        canvasId: 'canvas-1',
        typeConfig: <String, Object?>{
          'video_url': 'videos/job-2.mp4',
          'thumbnail_url': 'videos/job-2.jpg',
        },
      );

      await tester.pumpWidget(
        _host(const VideoNodeBody(node: node), resolver: resolver),
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('有 video_url 无 thumbnail_url → play_circle_outline',
        (tester) async {
      final resolver = _FakeResolver(Directory.systemTemp);

      const node = CanvasNode(
        id: 'n3',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        sourceNodeId: 'c1',
        projectId: 'proj-1',
        canvasId: 'canvas-1',
        typeConfig: <String, Object?>{
          'video_url': 'videos/job-3.mp4',
        },
      );

      await tester.pumpWidget(
        _host(const VideoNodeBody(node: node), resolver: resolver),
      );
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_outlined), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });
  });
}
