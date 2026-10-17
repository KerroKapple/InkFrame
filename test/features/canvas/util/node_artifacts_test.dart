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

CanvasNode _config(String id, {String? pinned}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      typeConfig: <String, Object?>{
        'pinned_result_id': ?pinned,
      },
    );

void main() {
  group('currentResultFor · 没固定时 = 最新', () {
    test('无候选 → null', () {
      expect(currentResultFor(sourceNodeId: 'x', nodes: const []), isNull);
    });

    test('单个候选直接返回', () {
      final r = _result('r1', source: 'cfg', url: 'a.mp4');
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: [_config('cfg'), r])?.id,
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
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'new');
    });

    test('created_at 全缺失时退回列表序末位（保持确定性,不返回 null）', () {
      final nodes = [
        _result('first', source: 'cfg', url: 'a.mp4'),
        _result('last', source: 'cfg', url: 'b.mp4'),
      ];
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'last');
    });

    test('部分缺 created_at：有时间戳的优先,缺的当最旧', () {
      final nodes = [
        _result('stamped', source: 'cfg', url: 'a.mp4',
            createdAt: DateTime.utc(2026, 1, 1)),
        _result('nostamp', source: 'cfg', url: 'b.mp4'),
      ];
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'stamped');
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
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: [impostor]), isNull);
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
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: [empty]), isNull);
    });

    test('sourceNodeId 不匹配的 result 不算', () {
      final other = _result('r1', source: 'someone-else', url: 'a.mp4');
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: [other]), isNull);
    });

    test('image 产物同样识别（url 键不同,SB-6 图片镜要用）', () {
      final img = _result('r1',
          source: 'cfg', url: 'a.png', type: CanvasNodeType.image);
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: [img])?.id, 'r1');
    });

    test('accept 可收窄产物类型（EX-1′ 只要 video）', () {
      final img = _result('img',
          source: 'cfg', url: 'a.png', type: CanvasNodeType.image);
      final vid = _result('vid', source: 'cfg', url: 'a.mp4');
      expect(
        currentResultFor(
          sourceNodeId: 'cfg',
          nodes: [img, vid],
          accept: (n) => n.type == CanvasNodeType.video,
        )?.id,
        'vid',
      );
      expect(
        currentResultFor(
          sourceNodeId: 'cfg',
          nodes: [img],
          accept: (n) => n.type == CanvasNodeType.video,
        ),
        isNull,
      );
    });
  });

  group('currentResultFor · 固定的 ?? 最新的', () {
    // 两个 take：old 旧、new 新；列表序刻意把新的放前面（z_index 陷阱照旧）。
    List<CanvasNode> takes() => <CanvasNode>[
          _result('new', source: 'cfg', url: 'new.mp4', createdAt: DateTime.utc(2026, 8, 7)),
          _result('old', source: 'cfg', url: 'old.mp4', createdAt: DateTime.utc(2026, 8, 1)),
        ];

    test('没固定 → 与最新同', () {
      final nodes = <CanvasNode>[_config('cfg'), ...takes()];
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'new');
    });

    test('固定的 take 活着 → 取固定的', () {
      final nodes = <CanvasNode>[_config('cfg', pinned: 'old'), ...takes()];
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'old');
    });

    test('固定的被软删（不在 nodes 里）→ 回落最新；放回后又是它', () {
      final config = _config('cfg', pinned: 'old');
      final newTake = _result('new', source: 'cfg', url: 'new.mp4', createdAt: DateTime.utc(2026, 8, 7));
      final oldTake = _result('old', source: 'cfg', url: 'old.mp4', createdAt: DateTime.utc(2026, 8, 1));
      // listByCanvas 不返回软删行：固定 id 在候选里找不到。
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: <CanvasNode>[config, newTake])?.id, 'new');
      // restore 后又在列表里：固定自然回来（删产物时不清 pinned_result_id）。
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: <CanvasNode>[config, newTake, oldTake])?.id, 'old');
    });

    test('固定 id 指向别的配置的产物 → 回落最新', () {
      final nodes = <CanvasNode>[
        _config('cfg', pinned: 'foreign'),
        ...takes(),
        _result('foreign', source: 'other', url: 'f.mp4', createdAt: DateTime.utc(2026, 1, 1)),
      ];
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'new');
    });

    test('固定的是 url 为空的占位 → 回落最新', () {
      final nodes = <CanvasNode>[
        _config('cfg', pinned: 'pending'),
        ...takes(),
        CanvasNode(
          id: 'pending',
          label: 'pending',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          canvasId: 'c1',
          sourceNodeId: 'cfg',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'new');
    });

    test('accept 刷掉固定的 → 回落', () {
      final nodes = <CanvasNode>[
        _config('cfg', pinned: 'img'),
        _result('img', source: 'cfg', url: 'a.png', type: CanvasNodeType.image, createdAt: DateTime.utc(2026, 1, 1)),
        _result('vid', source: 'cfg', url: 'a.mp4', createdAt: DateTime.utc(2026, 1, 2)),
        _result('vid-old', source: 'cfg', url: 'b.mp4', createdAt: DateTime.utc(2025, 12, 1)),
      ];
      // 不带 accept 时固定的 img 是当前——证明下面的回落是 accept 造成的。
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: nodes)?.id, 'img');
      expect(
        currentResultFor(
          sourceNodeId: 'cfg',
          nodes: nodes,
          accept: (n) => n.type == CanvasNodeType.video,
        )?.id,
        'vid',
      );
    });

    test('显式 pinnedResultId 优先，nodes 里没有配置节点也生效', () {
      // 大纲分桶 / 导出候选：手里只有产物，没有配置节点。
      expect(currentResultFor(sourceNodeId: 'cfg', nodes: takes())?.id, 'new');
      expect(
        currentResultFor(sourceNodeId: 'cfg', nodes: takes(), pinnedResultId: 'old')?.id,
        'old',
      );
      // 显式给了就以它为准，不再去读配置节点上的固定。
      expect(
        currentResultFor(
          sourceNodeId: 'cfg',
          nodes: <CanvasNode>[_config('cfg', pinned: 'new'), ...takes()],
          pinnedResultId: 'old',
        )?.id,
        'old',
      );
    });
  });
}
