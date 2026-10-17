// ⌘K 镜头组一行的缩略：取配置节点的当前 take（固定的 ?? 最新的），与序列 / 导出 / 画廊同一个判官。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/command_palette/palette_search.dart';

CanvasNode _config({String? pinned}) => CanvasNode(
      id: 'cfg',
      label: 'cfg',
      type: CanvasNodeType.video,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'pinned_result_id': ?pinned},
    );

CanvasNode _take(String id, DateTime at) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: 'cfg',
      createdAt: at,
      typeConfig: <String, Object?>{
        'video_url': 'videos/$id.mp4',
        'thumbnail_url': 'thumbs/$id.png',
      },
    );

void main() {
  final List<CanvasNode> takes = <CanvasNode>[
    _take('new', DateTime.utc(2026, 8, 7)),
    _take('old', DateTime.utc(2026, 8, 1)),
  ];

  test('镜头组缩略取当前 take', () {
    final CanvasNode unpinned = _config();
    expect(shotThumbRelativePath(unpinned, <CanvasNode>[unpinned, ...takes]), 'thumbs/new.png');

    final CanvasNode pinned = _config(pinned: 'old');
    expect(shotThumbRelativePath(pinned, <CanvasNode>[pinned, ...takes]), 'thumbs/old.png');
  });

  test('图片产物没有缩略 → 用图本身；没有产物 → null', () {
    final CanvasNode config = _config();
    final CanvasNode image = CanvasNode(
      id: 'img',
      label: 'img',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: 'cfg',
      createdAt: DateTime.utc(2026, 8, 1),
      typeConfig: const <String, Object?>{'image_url': 'images/img.png'},
    );
    expect(shotThumbRelativePath(config, <CanvasNode>[config, image]), 'images/img.png');
    expect(shotThumbRelativePath(config, <CanvasNode>[config]), isNull);
  });
}
