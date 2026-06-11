// VideoNodeBody widget tests：
//   - 无 videoUrl → hourglass 占位
//   - 有 thumbnail_url 但文件缺失 → broken_image 占位
//   - 有 video_url 无 thumbnail_url → play_circle_outline
//
// 用 temp 目录 + override appPathsProvider 让 FileResolverService 能指向 canvas 根。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/video_node_body.dart';
import 'package:path/path.dart' as p;

import '../../../_harness/test_app.dart';

List<Override> _overridesFor(AppPaths? paths) => [
      if (paths != null) appPathsProvider.overrideWithValue(paths),
    ];

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
      await pumpInkApp(
        tester,
        const Scaffold(body: VideoNodeBody(node: node)),
      );
      expect(find.byIcon(Icons.hourglass_empty_outlined), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    });

    testWidgets('有 thumbnail_url 但文件缺失 → broken_image 占位', (tester) async {
      // testWidgets body 内不能 await 真实 dart:io 异步 Future（binding zone 不
      // 抽水其完成回调，会永久挂起）——一律用 *Sync 文件 API。
      final tmp = Directory.systemTemp.createTempSync('video_node_body_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final paths = DefaultAppPaths.forRoot(tmp);

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

      await pumpInkApp(
        tester,
        const Scaffold(body: VideoNodeBody(node: node)),
        overrides: _overridesFor(paths),
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('有 video_url 无 thumbnail_url → play_circle_outline', (tester) async {
      // 同上：testWidgets body 内只用 *Sync 文件 API，避免真实异步 I/O 挂起。
      final tmp = Directory.systemTemp.createTempSync('video_node_body_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final paths = DefaultAppPaths.forRoot(tmp);
      // 视频占位文件可有可无，本分支不读 videoUrl 文件。
      final canvasDir = Directory(
        p.join(tmp.path, 'projects', 'proj-1', 'canvases', 'canvas-1', 'videos'),
      );
      canvasDir.createSync(recursive: true);

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

      await pumpInkApp(
        tester,
        const Scaffold(body: VideoNodeBody(node: node)),
        overrides: _overridesFor(paths),
      );
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty_outlined), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });
  });
}
