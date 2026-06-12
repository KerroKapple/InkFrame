// playableVideoPathProvider：可播放性判定下沉 provider（HI-18 / FIX-009）。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/playable_video_path.dart';

class _StubResolver implements FileResolverService {
  _StubResolver(this.root);
  final Directory root;

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) {
    if (relativePath.contains('..')) {
      throw PathSecurityError('traversal');
    }
    final localized =
        relativePath.replaceAll('/', Platform.pathSeparator);
    return File('${root.path}${Platform.pathSeparator}$localized');
  }

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      root;
}

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('playable_video_');
    container = ProviderContainer(overrides: <Override>[
      fileResolverServiceProvider.overrideWithValue(_StubResolver(tempDir)),
    ]);
  });

  tearDown(() {
    container.dispose();
    tempDir.deleteSync(recursive: true);
  });

  CanvasNode node({
    CanvasNodeType type = CanvasNodeType.video,
    NodeRole role = NodeRole.result,
    String? videoUrl = 'videos/v1.mp4',
    String? projectId = 'p1',
    String? canvasId = 'c1',
  }) =>
      CanvasNode(
        id: 'n1',
        label: 'V',
        type: type,
        role: role,
        projectId: projectId,
        canvasId: canvasId,
        typeConfig: videoUrl == null
            ? const <String, Object?>{}
            : <String, Object?>{'video_url': videoUrl},
      );

  test('video result 节点且文件存在 → 返回绝对路径', () {
    final file = File('${tempDir.path}${Platform.pathSeparator}videos'
        '${Platform.pathSeparator}v1.mp4');
    file.createSync(recursive: true);

    final path = container.read(playableVideoPathProvider(node()));
    expect(path, file.path);
  });

  test('文件不存在 → null', () {
    expect(container.read(playableVideoPathProvider(node())), isNull);
  });

  test('非 video 类型 / 非 result / 缺字段 → null（不触 IO）', () {
    expect(
      container.read(
        playableVideoPathProvider(node(type: CanvasNodeType.image)),
      ),
      isNull,
    );
    expect(
      container.read(playableVideoPathProvider(node(role: NodeRole.config))),
      isNull,
    );
    expect(
      container.read(playableVideoPathProvider(node(videoUrl: null))),
      isNull,
    );
    expect(
      container.read(playableVideoPathProvider(node(projectId: null))),
      isNull,
    );
    expect(
      container.read(playableVideoPathProvider(node(canvasId: null))),
      isNull,
    );
  });

  test('PathSecurityError → null（不冒泡到 UI）', () {
    expect(
      container.read(
        playableVideoPathProvider(node(videoUrl: '../escape.mp4')),
      ),
      isNull,
    );
  });
}
