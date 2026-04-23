import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  group('CanvasNode video getters', () {
    test('videoUrl 返回 type_config.video_url', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        typeConfig: {'video_url': 'videos/job-1.mp4'},
      );
      expect(node.videoUrl, 'videos/job-1.mp4');
    });

    test('videoUrl 缺失返回 null', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
      );
      expect(node.videoUrl, isNull);
    });

    test('thumbnailUrl 返回 type_config.thumbnail_url', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        typeConfig: {'thumbnail_url': 'videos/job-1.jpg'},
      );
      expect(node.thumbnailUrl, 'videos/job-1.jpg');
    });

    test('durationMs / camera / mode 读 type_config', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.config,
        typeConfig: {
          'duration_ms': 5000,
          'camera': 'pushIn',
          'mode': 't2v',
        },
      );
      expect(node.durationMs, 5000);
      expect(node.cameraName, 'pushIn');
      expect(node.videoMode, 't2v');
    });

    test('videoMode 缺失返回 null', () {
      const node = CanvasNode(
        id: 'n1',
        label: '',
        type: CanvasNodeType.video,
        role: NodeRole.config,
      );
      expect(node.videoMode, isNull);
    });
  });
}
