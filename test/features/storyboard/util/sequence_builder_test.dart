// SB-6 播放清单构建。
//
// 最要紧的一条是「折叠」：`_generateImageFromNotes` 建出来的真实拓扑是
// shot ──narrative──> image config ──sourceNodeId──> image result，
// 即 config 节点也在链上。不折叠的话一条 3 镜分镜会播成 6 条（每镜先占位
// 再出图）。这是当前把图接进分镜链的唯一入口，所以它不是边角情况。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/storyboard/models/sequence_shot.dart';
import 'package:inkframe/features/storyboard/util/sequence_builder.dart';

CanvasNode _shot(
  String id, {
  String? notes,
  int? durationMs,
  double x = 0,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.shot,
      canvasId: 'c1',
      position: Offset(x, 0),
      typeConfig: <String, Object?>{
        'shot_notes': ?notes,
        'duration_ms': ?durationMs,
      },
    );

CanvasNode _imageConfig(String id, {String? prompt}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'prompt': ?prompt},
    );

CanvasNode _imageResult(String id, {required String source, String? url}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      typeConfig: <String, Object?>{'image_url': url ?? '$id.png'},
    );

CanvasNode _videoResult(
  String id, {
  required String source,
  int? durationMs,
  DateTime? createdAt,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      createdAt: createdAt,
      typeConfig: <String, Object?>{
        'video_url': '$id.mp4',
        'duration_ms': ?durationMs,
      },
    );

CanvasEdge _narr(String id, String s, String t, {int sortOrder = 0}) =>
    CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: s,
      targetNodeId: t,
      edgeType: EdgeType.narrative,
      sortOrder: sortOrder,
    );

List<String> _ids(List<SequenceShot> s) => s.map((e) => e.nodeId).toList();

void main() {
  group('buildSequence', () {
    test('空输入 → 空清单', () {
      expect(buildSequence(nodes: const [], edges: const []), isEmpty);
    });

    test('真实拓扑折叠：shot→config→result 每镜只出一条,产物挂在 shot 上', () {
      // 这正是「用本镜备注生成图像」建出来的形状。
      final nodes = [
        _shot('s1', notes: 'dawn ridge'),
        _shot('s2', notes: 'rope bridge', x: 300),
        _imageConfig('cfg1', prompt: 'dawn ridge'),
        _imageConfig('cfg2', prompt: 'rope bridge'),
        _imageResult('r1', source: 'cfg1'),
        _imageResult('r2', source: 'cfg2'),
      ];
      final edges = [
        _narr('e1', 's1', 's2', sortOrder: 0),
        _narr('e2', 's1', 'cfg1', sortOrder: 1),
        _narr('e3', 's2', 'cfg2', sortOrder: 1),
      ];

      final seq = buildSequence(nodes: nodes, edges: edges);

      expect(_ids(seq), ['s1', 's2'], reason: 'config 节点被折叠,不单独成镜');
      expect(seq[0].kind, SequenceArtifactKind.image);
      expect(seq[0].relativePath, 'r1.png');
      expect(seq[1].relativePath, 'r2.png');
    });

    test('直接挂在 shot 上的产物同样识别（无中间 config 节点）', () {
      final nodes = [
        _shot('s1', notes: 'x'),
        _imageResult('r1', source: 's1'),
      ];
      final seq = buildSequence(nodes: nodes, edges: const []);
      expect(_ids(seq), ['s1']);
      expect(seq.single.relativePath, 'r1.png');
    });

    test('无产物的镜显 notes 占位,并照样计时', () {
      final nodes = [_shot('s1', notes: 'not generated yet')];
      final seq = buildSequence(nodes: nodes, edges: const []);

      expect(seq.single.kind, SequenceArtifactKind.none);
      expect(seq.single.notes, 'not generated yet');
      expect(seq.single.durationMs, kDefaultShotDurationMs);
    });

    test('既无产物也无 notes 的节点被跳过', () {
      final nodes = [_shot('s1'), _shot('s2', notes: 'has notes', x: 300)];
      expect(_ids(buildSequence(nodes: nodes, edges: const [])), ['s2']);
    });

    test('result 节点不独立成镜', () {
      // 孤儿 result（source 指向已删节点）也不该冒出来当一镜。
      final nodes = [
        _shot('s1', notes: 'x'),
        _imageResult('orphan', source: 'gone'),
      ];
      expect(_ids(buildSequence(nodes: nodes, edges: const [])), ['s1']);
    });

    test('时长：shot 的 duration_ms 优先于默认值', () {
      final nodes = [_shot('s1', notes: 'x', durationMs: 5000)];
      expect(buildSequence(nodes: nodes, edges: const []).single.durationMs,
          5000);
    });

    test('时长：视频产物的真实时长压过 shot 的预期时长', () {
      final nodes = [
        _shot('s1', notes: 'x', durationMs: 5000),
        _videoResult('v1', source: 's1', durationMs: 8123),
      ];
      final shot = buildSequence(nodes: nodes, edges: const []).single;
      expect(shot.kind, SequenceArtifactKind.video);
      expect(shot.durationMs, 8123);
    });

    test('时长：视频缺真实时长 → 退回 shot 预期 → 再退默认', () {
      final withShot = buildSequence(
        nodes: [
          _shot('s1', notes: 'x', durationMs: 5000),
          _videoResult('v1', source: 's1'),
        ],
        edges: const [],
      ).single;
      expect(withShot.durationMs, 5000);

      final bare = buildSequence(
        nodes: [_shot('s2', notes: 'x'), _videoResult('v2', source: 's2')],
        edges: const [],
      ).single;
      expect(bare.durationMs, kDefaultShotDurationMs);
    });

    test('时长：0 / 负数 / 非 int 一律当缺失——否则那一镜永远停不下来', () {
      for (final bad in <Object?>[0, -1, '5000', null]) {
        final node = CanvasNode(
          id: 's1',
          label: 's1',
          type: CanvasNodeType.shot,
          canvasId: 'c1',
          typeConfig: <String, Object?>{
            'shot_notes': 'x',
            'duration_ms': bad,
          },
        );
        expect(
          buildSequence(nodes: [node], edges: const []).single.durationMs,
          kDefaultShotDurationMs,
          reason: 'duration_ms=$bad 应回退默认值',
        );
      }
    });

    test('同一镜多次重跑 → 取最新产物（按 created_at,不是列表序末位）', () {
      final nodes = [
        _shot('s1', notes: 'x'),
        _videoResult('newer',
            source: 's1', createdAt: DateTime.utc(2026, 8, 7)),
        _videoResult('older',
            source: 's1', createdAt: DateTime.utc(2026, 1, 1)),
      ];
      expect(
        buildSequence(nodes: nodes, edges: const []).single.relativePath,
        'newer.mp4',
      );
    });

    test('顺序跟随 narrative 链,与 position.x 无关', () {
      final nodes = [
        _shot('s1', notes: 'a', x: 900),
        _shot('s2', notes: 'b', x: 500),
        _shot('s3', notes: 'c', x: 100),
      ];
      final edges = [_narr('e1', 's1', 's2'), _narr('e2', 's2', 's3')];
      expect(_ids(buildSequence(nodes: nodes, edges: edges)),
          ['s1', 's2', 's3']);
    });

    test('借用只发生一次：两个 shot 不会抢同一个 config 的产物', () {
      final nodes = [
        _shot('s1', notes: 'a'),
        _shot('s2', notes: 'b', x: 300),
        _imageConfig('cfg', prompt: 'shared'),
        _imageResult('r', source: 'cfg'),
      ];
      // 两个 shot 都连向同一个 config。
      final edges = [
        _narr('e1', 's1', 'cfg'),
        _narr('e2', 's2', 'cfg'),
        _narr('e3', 's1', 's2', sortOrder: 5),
      ];

      final seq = buildSequence(nodes: nodes, edges: edges);
      final withArtifact =
          seq.where((s) => s.relativePath != null).toList();
      expect(withArtifact, hasLength(1), reason: '产物只能归一镜');
      expect(seq.every((s) => s.nodeId != 'cfg'), isTrue,
          reason: 'config 被消费后不该再单独成镜');
    });

    test('canvasId 跟着产物走（解析绝对路径要用）', () {
      final nodes = [
        _shot('s1', notes: 'x'),
        _imageResult('r1', source: 's1'),
      ];
      expect(buildSequence(nodes: nodes, edges: const []).single.canvasId,
          'c1');
    });
  });
}
