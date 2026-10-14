// 左栏素材页的纯函数（PR-4）：分段过滤、删掉的不显示、类型计数、网格标签（源配置名 + take 序号）。
// take 号在节点上数（与检查器历史页同一个函数）：result 节点按时间正序编号，批量 slot 不参与。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_model.dart';
import 'package:inkframe/features/gallery/models/gallery_graph.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/util/gallery_meta.dart';

GalleryItem _item(
  String canvasId,
  String nodeId,
  String path, {
  GalleryItemKind kind = GalleryItemKind.image,
  required DateTime at,
}) =>
    GalleryItem(
      kind: kind,
      relativePath: path,
      canvasId: canvasId,
      canvasName: canvasId,
      nodeId: nodeId,
      createdAt: at,
    );

CanvasNode _config(String id, String label) =>
    CanvasNode(id: id, label: label, type: CanvasNodeType.image);

/// result 节点；[url] 是它的产物（videos/ 开头记成 video_url），没有 = 生成中 / 失败的占位或没转正的批量容器。
CanvasNode _result(String id, String source, {String? url, DateTime? at}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: source,
      createdAt: at,
      typeConfig: <String, Object?>{
        if (url != null) (url.startsWith('videos/') ? 'video_url' : 'image_url'): url,
      },
    );

void main() {
  // cvA：cfg1 名下三个产物（三个 take）、cfg2 名下一个（成片）、一个源配置已删的孤儿；cvB：cfg3 一个。
  final GalleryItem a1 = _item('cvA', 'r1a', 'images/1a.png', at: DateTime.utc(2026, 1, 2));
  final GalleryItem a2 = _item('cvA', 'r1b', 'images/1b.png', at: DateTime.utc(2026, 1, 1));
  final GalleryItem a3 = _item('cvA', 'r1c', 'images/1c.png', at: DateTime.utc(2026, 1, 3));
  final GalleryItem v1 = _item('cvA', 'r2', 'videos/2.mp4', kind: GalleryItemKind.video, at: DateTime.utc(2026, 2, 1));
  final GalleryItem orphan = _item('cvA', 'rOrphan', 'images/o.png', at: DateTime.utc(2026, 3, 1));
  final GalleryItem b1 = _item('cvB', 'r3', 'images/3.png', at: DateTime.utc(2026, 4, 1));
  final List<GalleryItem> all = <GalleryItem>[b1, orphan, v1, a3, a1, a2];

  final GalleryGraph graph = GalleryGraph(
    canvases: const <GalleryCanvasInfo>[
      GalleryCanvasInfo(id: 'cvA', name: 'A'),
      GalleryCanvasInfo(id: 'cvB', name: 'B'),
    ],
    nodesByCanvas: <String, List<CanvasNode>>{
      'cvA': <CanvasNode>[
        _config('cfg1', 'Harbor'),
        _config('cfg2', 'Boat'),
        _result('r1a', 'cfg1', url: 'images/1a.png', at: DateTime.utc(2026, 1, 2)),
        _result('r1b', 'cfg1', url: 'images/1b.png', at: DateTime.utc(2026, 1, 1)),
        _result('r1c', 'cfg1', url: 'images/1c.png', at: DateTime.utc(2026, 1, 3)),
        _result('r2', 'cfg2', url: 'videos/2.mp4', at: DateTime.utc(2026, 2, 1)),
        _result('rOrphan', 'deleted', url: 'images/o.png', at: DateTime.utc(2026, 3, 1)),
      ],
      'cvB': <CanvasNode>[
        _config('cfg3', 'Peaks'),
        _result('r3', 'cfg3', url: 'images/3.png', at: DateTime.utc(2026, 4, 1)),
      ],
    },
    edgesByCanvas: const <String, List<Never>>{},
    slotsByNode: const <String, List<Never>>{},
  );

  test('分段：本画布只留当前画布的产物，项目全部原样（保持聚合序）', () {
    expect(assetsInScope(all, scope: AssetScope.canvas, canvasId: 'cvA'), <GalleryItem>[orphan, v1, a3, a1, a2]);
    expect(assetsInScope(all, scope: AssetScope.project, canvasId: 'cvA'), all);
  });

  test('删掉的不显示：本画布节点已不在实时节点表里的去掉（批量 slot 跟着容器走），别的画布原样；节点表没载入不过滤',
      () {
    // 挂在 r1a 这个 result 容器上的批量 slot。
    final GalleryItem slot = GalleryItem(
      kind: GalleryItemKind.image,
      relativePath: 'images/s0.png',
      canvasId: 'cvA',
      canvasName: 'cvA',
      nodeId: 'r1a',
      createdAt: DateTime.utc(2026, 1, 4),
      slotIndex: 0,
    );
    final List<GalleryItem> items = <GalleryItem>[b1, orphan, v1, a3, a1, a2, slot];
    // cvA 上 r1a、rOrphan 删了；cvB 的 r3 不在这份节点表里，但它在别的画布，原样留着。
    final List<CanvasNode> live = <CanvasNode>[
      _config('cfg1', 'Harbor'),
      _config('cfg2', 'Boat'),
      _result('r1b', 'cfg1'),
      _result('r1c', 'cfg1'),
      _result('r2', 'cfg2'),
    ];
    expect(
      assetsWithoutDeleted(items, canvasId: 'cvA', liveNodes: live),
      <GalleryItem>[b1, v1, a3, a2],
    );
    expect(assetsWithoutDeleted(items, canvasId: 'cvA', liveNodes: null), items, reason: '节点表还没载入');
  });

  test('类型计数随分段变', () {
    expect(countAssets(assetsInScope(all, scope: AssetScope.canvas, canvasId: 'cvA')), (all: 5, image: 4, video: 1));
    expect(countAssets(all), (all: 6, image: 5, video: 1));
    expect(countAssets(const <GalleryItem>[]), (all: 0, image: 0, video: 0));
  });

  test('类型过滤', () {
    expect(assetsOfKind(all, AssetKindFilter.video), <GalleryItem>[v1]);
    expect(assetsOfKind(all, AssetKindFilter.image), <GalleryItem>[b1, orphan, a3, a1, a2]);
    expect(assetsOfKind(all, AssetKindFilter.all), all);
  });

  group('网格标签', () {
    final Map<String, AssetCaption> captions = assetCaptions(graph, all);
    AssetCaption of(GalleryItem i) => captions[galleryItemKey(i)]!;

    test('同一配置名下多个产物：按生成时间从早到晚编 take 1..N', () {
      expect(of(a2).config?.label, 'Harbor');
      expect(of(a2).take, 1, reason: '最早的');
      expect(of(a1).take, 2);
      expect(of(a3).take, 3, reason: '最新的');
    });

    test('只有一个产物 → take 为 null（界面写「成片」）；源配置名跟着 config 走', () {
      expect(of(v1).config?.label, 'Boat');
      expect(of(v1).take, isNull);
      expect(of(b1).config?.label, 'Peaks');
      expect(of(b1).take, isNull);
    });

    test('源配置已删的孤儿：config 为 null、不参与编号', () {
      expect(of(orphan).config, isNull);
      expect(of(orphan).take, isNull);
    });

    test('批量 slot 不参与 take 编号：名下的 result 节点按时间正序编 take 1..N，slot 没有 take 号', () {
      // cfgG 名下：rg1（1 月 1 日）、批量容器 rgB（1 月 2 日，没转正 ⇒ 没有产物 url）挂三格 slot、rg2（1 月 3 日）。
      final GalleryGraph batchGraph = GalleryGraph(
        canvases: const <GalleryCanvasInfo>[GalleryCanvasInfo(id: 'cvC', name: 'C')],
        nodesByCanvas: <String, List<CanvasNode>>{
          'cvC': <CanvasNode>[
            _config('cfgG', 'Gull'),
            _result('rg1', 'cfgG', url: 'images/g1.png', at: DateTime.utc(2026, 1, 1)),
            _result('rgB', 'cfgG', at: DateTime.utc(2026, 1, 2)),
            _result('rg2', 'cfgG', url: 'images/g2.png', at: DateTime.utc(2026, 1, 3)),
          ],
        },
        edgesByCanvas: const <String, List<Never>>{},
        slotsByNode: const <String, List<Never>>{},
      );
      GalleryItem slot(int i) => GalleryItem(
            kind: GalleryItemKind.image,
            relativePath: 'images/gb$i.png',
            canvasId: 'cvC',
            canvasName: 'C',
            nodeId: 'rgB',
            createdAt: DateTime.utc(2026, 1, 2),
            slotIndex: i,
          );
      final GalleryItem g1 = _item('cvC', 'rg1', 'images/g1.png', at: DateTime.utc(2026, 1, 1));
      final GalleryItem g2 = _item('cvC', 'rg2', 'images/g2.png', at: DateTime.utc(2026, 1, 3));
      final Map<String, AssetCaption> batch =
          assetCaptions(batchGraph, <GalleryItem>[g2, slot(0), slot(1), slot(2), g1]);

      expect(batch[galleryItemKey(g1)]!.take, 1);
      expect(batch[galleryItemKey(g2)]!.take, 2, reason: '检查器历史页只数 result 节点：它是 take 2，不是 take 5');
      for (int i = 0; i < 3; i++) {
        expect(batch[galleryItemKey(slot(i))]!.take, isNull, reason: 'slot 不参与 take 编号');
        expect(batch[galleryItemKey(slot(i))]!.config?.label, 'Gull', reason: 'slot 经它挂的 result 容器找到源配置');
      }
    });

    test('take 按整个项目编号：只传本画布的产物算出来的号与全量一致（切分段不换号）', () {
      final Map<String, AssetCaption> canvasOnly = assetCaptions(
        graph,
        assetsInScope(all, scope: AssetScope.canvas, canvasId: 'cvA'),
      );
      expect(canvasOnly[galleryItemKey(a3)]!.take, of(a3).take);
    });
  });
}
