// take 号（canvas/util/take_numbers.dart 的 takeNumbersOn）：素材页格子与检查器历史页共用的那一个编号函数。
// 素材页标签怎么跟着它变见 left_rail/asset_captions_test.dart；两处界面上的号对得上，由
// assets_panel_test.dart 的外壳级用例（素材页 + 历史页同屏）钉。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/take_numbers.dart';

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
}
