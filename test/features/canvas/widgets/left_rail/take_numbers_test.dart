// take 号（left_rail/assets_model.dart 的 takeNumbersOn）：素材页格子与检查器历史页共用的那一个编号函数，
// 以及 assetCaptions 跟着它变的两件事：批量 slot 写 slot 号；当前画布的号在实时节点表上数。
// 两处界面上的号对得上，由 assets_panel_test.dart 的外壳级用例（素材页 + 历史页同屏）钉。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_model.dart';
import 'package:inkframe/features/gallery/models/gallery_graph.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/util/gallery_meta.dart';

CanvasNode _config(String id) => CanvasNode(id: id, label: id, type: CanvasNodeType.image);

/// result 节点；[url] 为 null = 没有产物（生成中 / 失败的占位，或没转正的批量容器）。
CanvasNode _result(String id, {String? source, String? url, DateTime? at}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      sourceNodeId: source,
      createdAt: at,
      typeConfig: <String, Object?>{'image_url': ?url},
    );

GalleryItem _item(String canvasId, String nodeId, String path, {int? slot}) => GalleryItem(
      kind: GalleryItemKind.image,
      relativePath: path,
      canvasId: canvasId,
      canvasName: canvasId,
      nodeId: nodeId,
      createdAt: DateTime.utc(2026, 1, 1),
      slotIndex: slot,
    );

void main() {
  group('takeNumbersOn', () {
    test('每个来源名下有产物的 result 节点按时间正序编号（最早的是 take 1），与节点列表顺序无关', () {
      final Map<String, int> numbers = takeNumbersOn(<CanvasNode>[
        _config('cfg1'),
        _result('a', source: 'cfg1', url: 'images/a.png', at: DateTime.utc(2026, 1, 2)),
        _result('b', source: 'cfg1', url: 'images/b.png', at: DateTime.utc(2026, 1, 1)),
        _result('c', source: 'cfg1', url: 'images/c.png', at: DateTime.utc(2026, 1, 3)),
        _config('cfg2'),
        _result('d', source: 'cfg2', url: 'images/d.png', at: DateTime.utc(2026, 1, 1)),
        _result('e', source: 'cfg2', url: 'images/e.png', at: DateTime.utc(2026, 1, 5)),
      ]);
      expect(numbers, <String, int>{'b': 1, 'a': 2, 'c': 3, 'd': 1, 'e': 2});
    });

    test('名下只有一个的（成片）、没有来源的孤儿、没有产物 url 的（占位 / 没转正的批量容器）：都不在表里', () {
      final Map<String, int> numbers = takeNumbersOn(<CanvasNode>[
        _config('solo'),
        _result('only', source: 'solo', url: 'images/only.png', at: DateTime.utc(2026, 1, 1)),
        _result('orphan', url: 'images/orphan.png', at: DateTime.utc(2026, 1, 1)),
        _config('cfg'),
        _result('t1', source: 'cfg', url: 'images/t1.png', at: DateTime.utc(2026, 1, 1)),
        _result('container', source: 'cfg', at: DateTime.utc(2026, 1, 2)),
        _result('t2', source: 'cfg', url: 'images/t2.png', at: DateTime.utc(2026, 1, 3)),
      ]);
      expect(numbers, <String, int>{'t1': 1, 't2': 2});
    });

    test('都没有时间戳（乐观新增、还没落库）：按节点列表原序，越靠后越新（resultsFor 口径）', () {
      final Map<String, int> numbers = takeNumbersOn(<CanvasNode>[
        _config('cfg'),
        _result('first', source: 'cfg', url: 'images/first.png'),
        _result('second', source: 'cfg', url: 'images/second.png'),
      ]);
      expect(numbers, <String, int>{'first': 1, 'second': 2});
    });
  });

  group('assetCaptions', () {
    // cvA：cfg1 名下 r1 / r2 / r3 三个 take，r2 上还挂着批量容器 rb 的两格 slot；cvB：cfg2 名下 s1 / s2。
    final GalleryGraph graph = GalleryGraph(
      canvases: const <GalleryCanvasInfo>[
        GalleryCanvasInfo(id: 'cvA', name: 'A'),
        GalleryCanvasInfo(id: 'cvB', name: 'B'),
      ],
      nodesByCanvas: <String, List<CanvasNode>>{
        'cvA': <CanvasNode>[
          _config('cfg1'),
          _result('r1', source: 'cfg1', url: 'images/r1.png', at: DateTime.utc(2026, 1, 1)),
          _result('r2', source: 'cfg1', url: 'images/r2.png', at: DateTime.utc(2026, 1, 2)),
          _result('r3', source: 'cfg1', url: 'images/r3.png', at: DateTime.utc(2026, 1, 3)),
          _result('rb', source: 'cfg1', at: DateTime.utc(2026, 1, 4)),
        ],
        'cvB': <CanvasNode>[
          _config('cfg2'),
          _result('s1', source: 'cfg2', url: 'images/s1.png', at: DateTime.utc(2026, 1, 1)),
          _result('s2', source: 'cfg2', url: 'images/s2.png', at: DateTime.utc(2026, 1, 2)),
        ],
      },
      edgesByCanvas: const <String, List<Never>>{},
      slotsByNode: const <String, List<Never>>{},
    );
    final GalleryItem r2 = _item('cvA', 'r2', 'images/r2.png');
    final GalleryItem r3 = _item('cvA', 'r3', 'images/r3.png');
    final GalleryItem slot0 = _item('cvA', 'rb', 'images/rb0.png', slot: 0);
    final GalleryItem slot1 = _item('cvA', 'rb', 'images/rb1.png', slot: 1);
    final GalleryItem s2 = _item('cvB', 's2', 'images/s2.png');
    final List<GalleryItem> items = <GalleryItem>[r2, r3, slot0, slot1, s2];

    test('批量 slot 写 slot 号（1 起）、不写 take 号；节点主产物没有 slot 号', () {
      final Map<String, AssetCaption> captions = assetCaptions(graph, items);
      expect(captions[galleryItemKey(slot0)]!.slot, 1);
      expect(captions[galleryItemKey(slot1)]!.slot, 2);
      expect(captions[galleryItemKey(slot1)]!.take, isNull);
      expect(captions[galleryItemKey(slot1)]!.config?.id, 'cfg1');
      expect(captions[galleryItemKey(r2)]!.slot, isNull);
      expect(captions[galleryItemKey(r2)]!.take, 2);
      expect(captions[galleryItemKey(r3)]!.take, 3);
    });

    test('当前画布的号在实时节点表上数：删掉 r1，r2 / r3 跟着变成 take 1 / 2；别的画布照画廊图', () {
      final Map<String, AssetCaption> captions = assetCaptions(
        graph,
        items,
        canvasId: 'cvA',
        canvasNodes: <CanvasNode>[
          _config('cfg1'),
          _result('r2', source: 'cfg1', url: 'images/r2.png', at: DateTime.utc(2026, 1, 2)),
          _result('r3', source: 'cfg1', url: 'images/r3.png', at: DateTime.utc(2026, 1, 3)),
          _result('rb', source: 'cfg1', at: DateTime.utc(2026, 1, 4)),
        ],
      );
      expect(captions[galleryItemKey(r2)]!.take, 1);
      expect(captions[galleryItemKey(r3)]!.take, 2);
      expect(captions[galleryItemKey(s2)]!.take, 2, reason: 'cvB 没有实时节点表，照画廊图数');
    });
  });
}
