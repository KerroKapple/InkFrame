// EX-1′ 首建、SB-6 消费的 artifacts util 用例集。
//
// 核心风险点（卡面点名）：`nodes.listByCanvas` 的 ORDER BY 是
// `z_index ASC, created_at ASC`，**不是**按 created_at 单排——所以「同一个
// config 节点重跑多次、取最新那张产物」绝不能取列表序末位，必须在候选里按
// created_at 比。z_index 由用户拖动层级决定，跟生成时间毫无关系。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/node_artifacts.dart';

CanvasNode _result(
  String id, {
  required String source,
  required String url,
  DateTime? createdAt,
  CanvasNodeType type = CanvasNodeType.video,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: type,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      createdAt: createdAt,
      typeConfig: <String, Object?>{
        type == CanvasNodeType.video ? 'video_url' : 'image_url': url,
      },
    );

CanvasNode _config(String id) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
    );

void main() {
  group('latestResultFor', () {
    test('无候选 → null', () {
      expect(latestResultFor(sourceNodeId: 'x', nodes: const []), isNull);
    });

    test('单个候选直接返回', () {
      final r = _result('r1', source: 'cfg', url: 'a.mp4');
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: [_config('cfg'), r])?.id,
          'r1');
    });

    test('多候选按 created_at 取最新——不是列表序末位', () {
      // 列表序刻意让「最旧」排在最后（模拟 z_index 主序把新节点排到前面）。
      final nodes = [
        _result('new', source: 'cfg', url: 'new.mp4',
            createdAt: DateTime.utc(2026, 8, 7, 12)),
        _result('old', source: 'cfg', url: 'old.mp4',
            createdAt: DateTime.utc(2026, 8, 1)),
      ];
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'new');
    });

    test('created_at 全缺失时退回列表序末位（保持确定性,不返回 null）', () {
      final nodes = [
        _result('first', source: 'cfg', url: 'a.mp4'),
        _result('last', source: 'cfg', url: 'b.mp4'),
      ];
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'last');
    });

    test('部分缺 created_at：有时间戳的优先,缺的当最旧', () {
      final nodes = [
        _result('stamped', source: 'cfg', url: 'a.mp4',
            createdAt: DateTime.utc(2026, 1, 1)),
        _result('nostamp', source: 'cfg', url: 'b.mp4'),
      ];
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'stamped');
    });

    test('只认 role==result——config 节点即便 sourceNodeId 匹配也不算产物', () {
      const impostor = CanvasNode(
        id: 'cfg2',
        label: 'cfg2',
        type: CanvasNodeType.video,
        canvasId: 'c1',
        sourceNodeId: 'cfg',
        typeConfig: <String, Object?>{'video_url': 'x.mp4'},
      );
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: [impostor]), isNull);
    });

    test('url 为空的 result 不算产物（生成中/失败的占位节点）', () {
      const empty = CanvasNode(
        id: 'r1',
        label: 'r1',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        canvasId: 'c1',
        sourceNodeId: 'cfg',
        typeConfig: <String, Object?>{},
      );
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: [empty]), isNull);
    });

    test('sourceNodeId 不匹配的 result 不算', () {
      final other = _result('r1', source: 'someone-else', url: 'a.mp4');
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: [other]), isNull);
    });

    test('image 产物同样识别（url 键不同,SB-6 图片镜要用）', () {
      final img = _result('r1',
          source: 'cfg', url: 'a.png', type: CanvasNodeType.image);
      expect(latestResultFor(sourceNodeId: 'cfg', nodes: [img])?.id, 'r1');
    });

    test('accept 可收窄产物类型（EX-1′ 只要 video）', () {
      final img = _result('img',
          source: 'cfg', url: 'a.png', type: CanvasNodeType.image);
      final vid = _result('vid', source: 'cfg', url: 'a.mp4');
      expect(
        latestResultFor(
          sourceNodeId: 'cfg',
          nodes: [img, vid],
          accept: (n) => n.type == CanvasNodeType.video,
        )?.id,
        'vid',
      );
      expect(
        latestResultFor(
          sourceNodeId: 'cfg',
          nodes: [img],
          accept: (n) => n.type == CanvasNodeType.video,
        ),
        isNull,
      );
    });
  });
}
