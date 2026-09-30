// indexCharacterUsages 纯函数测试（P4）：角色库「M 处引用」与编辑框「被引用」的口径。
//
// 靶子是口径本身，不是"函数跑得通"：result 节点必须不计数（它的 type_config 是
// 生成时从 config 整份拷来的，数进去每跑一次就翻一倍）、跨画布要累加、
// 同一节点里重复写同一个 id 只算一次。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/character_usage.dart';
import 'package:inkframe/features/gallery/models/gallery_graph.dart';

CanvasNode _node(
  String id, {
  required NodeRole role,
  List<Object?>? characterIds,
}) => CanvasNode(
  id: id,
  label: id,
  type: CanvasNodeType.image,
  role: role,
  typeConfig: <String, Object?>{'character_ids': ?characterIds},
);

GalleryGraph _graph(Map<String, List<CanvasNode>> byCanvas) => GalleryGraph(
  canvases: <GalleryCanvasInfo>[
    for (final String id in byCanvas.keys) GalleryCanvasInfo(id: id, name: id),
  ],
  nodesByCanvas: byCanvas,
  edgesByCanvas: const <String, List<Never>>{},
  slotsByNode: const <String, List<Never>>{},
);

void main() {
  test('只数 config 节点：result 节点拷来的 character_ids 不计数', () {
    final GalleryGraph g = _graph(<String, List<CanvasNode>>{
      'cv1': <CanvasNode>[
        _node('cfg', role: NodeRole.config, characterIds: <Object?>['c1']),
        _node('res', role: NodeRole.result, characterIds: <Object?>['c1']),
      ],
    });

    final Map<String, List<CanvasNode>> out = indexCharacterUsages(g);

    expect(out['c1']!.length, 1, reason: 'result 计进来就会随生成次数翻倍');
    expect(out['c1']!.single.id, 'cfg');
  });

  test('跨画布累加：同一角色挂在两个画布的 config 上算 2 处', () {
    final GalleryGraph g = _graph(<String, List<CanvasNode>>{
      'cv1': <CanvasNode>[
        _node('a', role: NodeRole.config, characterIds: <Object?>['c1']),
      ],
      'cv2': <CanvasNode>[
        _node('b', role: NodeRole.config, characterIds: <Object?>['c1', 'c2']),
      ],
    });

    final Map<String, List<CanvasNode>> out = indexCharacterUsages(g);

    expect(out['c1']!.map((CanvasNode n) => n.id), <String>['a', 'b']);
    expect(out['c2']!.map((CanvasNode n) => n.id), <String>['b']);
  });

  test('同一节点里重复写同一个 id 只算一次', () {
    final GalleryGraph g = _graph(<String, List<CanvasNode>>{
      'cv1': <CanvasNode>[
        _node('a', role: NodeRole.config, characterIds: <Object?>['c1', 'c1']),
      ],
    });

    expect(indexCharacterUsages(g)['c1']!.length, 1);
  });

  test('没被引用的角色不出现在索引里（调用方按 0 显示）', () {
    final GalleryGraph g = _graph(<String, List<CanvasNode>>{
      'cv1': <CanvasNode>[_node('a', role: NodeRole.config)],
    });

    final Map<String, List<CanvasNode>> out = indexCharacterUsages(g);

    expect(out.containsKey('c1'), isFalse);
    expect(out['c1']?.length ?? 0, 0);
  });

  test('character_ids 是脏值时按无引用处理，不抛', () {
    expect(
      characterIdsOf(
        _node('a', role: NodeRole.config, characterIds: <Object?>['', null]),
      ),
      isEmpty,
    );
    expect(
      characterIdsOf(
        const CanvasNode(
          id: 'a',
          label: 'a',
          type: CanvasNodeType.image,
          typeConfig: <String, Object?>{'character_ids': 'c1'},
        ),
      ),
      isEmpty,
      reason: '非 List 的 character_ids 不得被当成单个 id 吃下去',
    );
  });
}
