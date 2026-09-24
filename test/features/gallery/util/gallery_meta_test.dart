// gallery_meta 纯函数：产物 → meta（名称 / providerId / 当前线 / 序列序号 / 关键帧）与血缘行。
//
// 图：shot ──narrative──> imgB ──data(last_frame)──> video
//                          imgA ──data(first_frame)──┘
//     imgA 有 4 个批量 slot（#2 promoted）；imgB 有 1 个 result；video 有 1 个 result。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/gallery/models/gallery_graph.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';
import 'package:inkframe/features/gallery/util/gallery_meta.dart';

CanvasNode _node(String id, String label, CanvasNodeType type,
        {NodeRole role = NodeRole.config, String? source, Map<String, Object?> cfg = const <String, Object?>{}, double x = 0}) =>
    CanvasNode(
      id: id,
      label: label,
      type: type,
      role: role,
      canvasId: 'c1',
      sourceNodeId: source,
      typeConfig: cfg,
      position: Offset(x, 0),
      createdAt: DateTime.utc(2026, 9, 1),
    );

CanvasEdge _edge(String id, String from, String to, EdgeType type, {EdgeRole role = EdgeRole.reference}) =>
    CanvasEdge(id: id, canvasId: 'c1', sourceNodeId: from, targetNodeId: to, edgeType: type, role: role);

GalleryBatchSlot _slot(int i, {bool promoted = false}) => GalleryBatchSlot(
      nodeId: 'imgA',
      canvasId: 'c1',
      slotIndex: i,
      outputUrl: 'images/a$i.png',
      createdAt: DateTime.utc(2026, 9, 1, i),
      promoted: promoted,
    );

final GalleryGraph _graph = GalleryGraph(
  canvases: const <GalleryCanvasInfo>[GalleryCanvasInfo(id: 'c1', name: '画布 02 · 主线', baseStylePrefix: '水墨')],
  nodesByCanvas: <String, List<CanvasNode>>{
    'c1': <CanvasNode>[
      _node('shot', '镜头 01 · 分镜描述', CanvasNodeType.shot, cfg: <String, Object?>{'shot_notes': '晨雾'}),
      _node('imgA', '镜头 01 · 图像', CanvasNodeType.image, x: 100, cfg: <String, Object?>{'provider_id': 'gemini-image'}),
      _node('imgB', '镜头 02 · 图像', CanvasNodeType.image, x: 100, cfg: <String, Object?>{'provider_id': 'gemini-image'}),
      _node('imgBr', '', CanvasNodeType.image, role: NodeRole.result, source: 'imgB',
          cfg: <String, Object?>{'image_url': 'images/b.png'}),
      _node('video', '镜头 03 · 图转视频', CanvasNodeType.video, x: 200, cfg: <String, Object?>{
        'provider_id': 'kling-v3',
        'prompt': '晨雾中的山径',
        'camera': 'pushIn',
      }),
      _node('videoR', '', CanvasNodeType.video, role: NodeRole.result, source: 'video',
          cfg: <String, Object?>{'video_url': 'videos/v.mp4', 'duration_ms': 5000, 'thumbnail_url': 'thumbs/v.png'}),
    ],
  },
  edgesByCanvas: <String, List<CanvasEdge>>{
    'c1': <CanvasEdge>[
      _edge('e1', 'shot', 'imgB', EdgeType.narrative),
      _edge('e2', 'imgA', 'video', EdgeType.data, role: EdgeRole.firstFrame),
      _edge('e3', 'imgB', 'video', EdgeType.data, role: EdgeRole.lastFrame),
    ],
  },
  slotsByNode: <String, List<GalleryBatchSlot>>{
    'imgA': <GalleryBatchSlot>[_slot(0), _slot(1, promoted: true), _slot(2), _slot(3)],
  },
);

void main() {
  final List<GalleryItem> items = galleryItemsFromGraph(_graph);
  final GalleryIndex index = GalleryIndex.build(_graph);
  GalleryItem byPath(String p) => items.firstWhere((i) => i.relativePath == p);

  test('galleryItemsFromGraph：result 主产物 + 批量 slot，去重，createdAt 倒序', () {
    expect(items.map((i) => i.relativePath),
        containsAll(<String>['videos/v.mp4', 'images/b.png', 'images/a0.png', 'images/a1.png']));
    expect(items.length, 6);
    expect(byPath('images/a1.png').slotIndex, 1);
  });

  test('meta：名称 / providerId / 关键帧来源 / 提示词 / 运镜 / 基底风格', () {
    final GalleryItemMeta m = galleryMetaFor(_graph, index, byPath('videos/v.mp4'));
    expect(m.label, '镜头 03 · 图转视频');
    expect(m.providerId, 'kling-v3');
    expect(m.prompt, '晨雾中的山径');
    expect(m.cameraName, 'pushIn');
    expect(m.baseStylePrefix, '水墨');
    expect(m.keyframes.map((k) => (k.role, k.sourceLabel)),
        <(EdgeRole, String)>[(EdgeRole.firstFrame, '镜头 01 · 图像'), (EdgeRole.lastFrame, '镜头 02 · 图像')]);
    // 批量 slot 的名称带 #n（1 起）。
    expect(galleryMetaFor(_graph, index, byPath('images/a1.png')).label, '镜头 01 · 图像 #2');
  });

  test('当前线 = config 参与 narrative 边；已入序列 = 在播放清单里', () {
    expect(galleryMetaFor(_graph, index, byPath('images/b.png')).onNarrativeChain, isTrue);
    expect(galleryMetaFor(_graph, index, byPath('images/a1.png')).onNarrativeChain, isFalse);
    // imgB 是 shot 的 narrative 后继：清单里 shot 借 imgB 的产物成镜 ⇒ b.png 在序列第 1 位。
    expect(galleryMetaFor(_graph, index, byPath('images/b.png')).sequenceIndex, 1);
    // video 不在 narrative 边上：buildSequence 虽把它追加在链尾，「已入序列」不认链外的镜。
    expect(galleryMetaFor(_graph, index, byPath('videos/v.mp4')).sequenceIndex, isNull);
  });

  test('血缘：关键帧来源 → 当前项；从 4 个结果中选定 #2，其余折成 +3 分支', () {
    final List<GalleryLineageRow> rows = galleryLineageFor(_graph, index, byPath('videos/v.mp4'));
    expect(rows.map((r) => r.kind), <GalleryLineageKind>[
      GalleryLineageKind.input,
      GalleryLineageKind.input,
      GalleryLineageKind.current,
    ]);
    expect(rows[0].role, EdgeRole.firstFrame);
    expect(rows[0].name, '镜头 01 · 图像 #2', reason: 'promoted 的 slot 是被选定的那份');
    expect(rows[0].resultCount, 4);
    expect(rows[0].branches, 3);
    expect(rows[0].thumbRelativePath, 'images/a1.png');
    expect(rows[1].role, EdgeRole.lastFrame);
    expect(rows[1].name, '镜头 02 · 图像');
    expect(rows[1].branches, 0);
    expect(rows[1].thumbRelativePath, 'images/b.png');
    expect(rows[2].name, '镜头 03 · 图转视频');
    expect(rows[2].thumbRelativePath, 'thumbs/v.png');
    expect(rows[2].branches, 0);
  });

  test('血缘：图像产物的前驱是分镜文本；批量 slot 的当前项折出其余分支', () {
    final List<GalleryLineageRow> b = galleryLineageFor(_graph, index, byPath('images/b.png'));
    expect(b.first.kind, GalleryLineageKind.shotText);
    expect(b.first.name, '镜头 01 · 分镜描述');
    expect(b.last.kind, GalleryLineageKind.current);
    expect(b.last.sequenceIndex, 1);
    final List<GalleryLineageRow> a = galleryLineageFor(_graph, index, byPath('images/a1.png'));
    expect(a.map((r) => r.kind), <GalleryLineageKind>[GalleryLineageKind.current]);
    expect(a.last.branches, 3, reason: '同 config 的其余 3 个 slot 折成分支');
  });

  test('图里找不到节点 → meta 空、血缘空，不抛', () {
    final GalleryItem ghost = GalleryItem(
      kind: GalleryItemKind.image,
      relativePath: 'x.png',
      canvasId: 'c1',
      canvasName: '',
      nodeId: 'nope',
      createdAt: DateTime.utc(2026),
    );
    expect(galleryMetaFor(_graph, index, ghost).label, '');
    expect(galleryLineageFor(_graph, index, ghost), isEmpty);
  });
}
