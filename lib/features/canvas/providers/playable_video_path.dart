// playableVideoPathProvider — 可播放视频路径判定（HI-18 下沉自 CanvasView）。
//
// video result 节点且文件存在 → 绝对路径；其余（类型不符 / 字段缺失 / 文件缺失 /
// 路径非法）→ null。IO 判定不进 widget build。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../models/canvas_node.dart';

final playableVideoPathProvider =
    Provider.autoDispose.family<String?, CanvasNode>(
  (ref, node) {
    if (node.type != CanvasNodeType.video ||
        node.role != NodeRole.result ||
        node.videoUrl == null ||
        node.projectId == null ||
        node.canvasId == null) {
      return null;
    }
    final resolver = ref.watch(fileResolverServiceProvider);
    try {
      final file = resolver.resolve(
        projectId: node.projectId!,
        canvasId: node.canvasId!,
        relativePath: node.videoUrl!,
      );
      return file.existsSync() ? file.path : null;
    } on PathSecurityError {
      return null;
    }
  },
  name: 'playableVideoPathProvider',
);
