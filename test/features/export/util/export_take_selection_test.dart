// 导出默认勾选 = 一镜一条（BOARD 194）。
//
// 这张卡的核心知识是「同一镜的多个 take 默认选哪一个」，所以用例按那条规则的
// 分支铺开：①同镜多 take 只勾最新，判据是 created_at **而不是列表序**
// （`listByCanvas` 主序是 z_index，用户拖层级就能改列表序）②源节点为空的孤儿
// 产物彼此之间没有「同一镜」的依据，各自成镜、全勾 ③缺时间戳时的退路
// ④配置节点固定了某个 take（pinnedBySource）→ 勾固定的；固定的不在候选里 → 回落最新。
//
// promoted 为什么一条用例都没有：批量在 `generation_controller` 被收口成「仅图片
// 节点」，promote 写的也只有 `image_url`——video result 节点在数据上不可能有 slot，
// 「promoted take」在导出这条路径上不是优先级低，而是无定义。完整理由见
// `lib/features/export/util/export_take_selection.dart` 文件头。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/export/util/export_take_selection.dart';

CanvasNode _take(
  String id, {
  String? source = 'cfg',
  DateTime? createdAt,
  double x = 0,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      projectId: 'p1',
      sourceNodeId: source,
      createdAt: createdAt,
      position: Offset(x, 0),
      typeConfig: <String, Object?>{'video_url': '$id.mp4'},
    );

void main() {
  group('currentTakeNodeIds', () {
    test('同一镜两个 take → 只勾最新那个（本卡的核心用例）', () {
      final nodes = <CanvasNode>[
        _take('old', createdAt: DateTime.utc(2026, 1, 1)),
        _take('new', createdAt: DateTime.utc(2026, 8, 7)),
      ];
      expect(currentTakeNodeIds(nodes), <String>{'new'});
    });

    test('列表序与时间序相反时仍按 created_at（z_index 陷阱）', () {
      // 候选列表里最新的那个排在最前——取"末位"的实现会在这条上翻车。
      final nodes = <CanvasNode>[
        _take('new', createdAt: DateTime.utc(2026, 8, 7)),
        _take('mid', createdAt: DateTime.utc(2026, 5, 5)),
        _take('old', createdAt: DateTime.utc(2026, 1, 1)),
      ];
      expect(currentTakeNodeIds(nodes), <String>{'new'});
    });

    test('多镜各自勾一个,互不影响', () {
      final nodes = <CanvasNode>[
        _take('a-old', source: 'cfgA', createdAt: DateTime.utc(2026, 1, 1)),
        _take('b-new', source: 'cfgB', createdAt: DateTime.utc(2026, 3, 3)),
        _take('a-new', source: 'cfgA', createdAt: DateTime.utc(2026, 2, 2)),
        _take('b-old', source: 'cfgB', createdAt: DateTime.utc(2026, 1, 2)),
      ];
      expect(currentTakeNodeIds(nodes), <String>{'a-new', 'b-new'});
    });

    test('一镜只有一个 take → 照旧勾上（单 take 画布的默认全选不变）', () {
      final nodes = <CanvasNode>[
        _take('a', source: 'cfgA'),
        _take('b', source: 'cfgB'),
        _take('c', source: 'cfgC'),
      ];
      expect(currentTakeNodeIds(nodes), <String>{'a', 'b', 'c'});
    });

    test('源节点为空的孤儿产物：各自成镜,全部勾上（不塌成一个）', () {
      // sourceNodeId 为 null 意味着"不知道属于哪一镜"，按同一镜处理会静默少导出。
      final nodes = <CanvasNode>[
        _take('loose1', source: null),
        _take('loose2', source: null),
        _take('owned', source: 'cfgA'),
      ];
      expect(currentTakeNodeIds(nodes), <String>{'loose1', 'loose2', 'owned'});
    });

    test('同镜全缺时间戳 → 仍只勾一个,取候选列表序末位（与 resultsFor 同口径）', () {
      final nodes = <CanvasNode>[
        _take('first'),
        _take('second'),
        _take('third'),
      ];
      expect(currentTakeNodeIds(nodes), <String>{'third'});
    });

    test('同镜混合有无时间戳 → 有时间戳的胜（未落库的本地节点不算"更新"）', () {
      final nodes = <CanvasNode>[
        _take('local', createdAt: null),
        _take('stored', createdAt: DateTime.utc(2026, 1, 1)),
      ];
      expect(currentTakeNodeIds(nodes), <String>{'stored'});
    });

    test('空输入 → 空集', () {
      expect(currentTakeNodeIds(const <CanvasNode>[]), isEmpty);
    });

    test('只回传候选里的 id——不发明、不丢镜', () {
      final nodes = <CanvasNode>[
        _take('a1', source: 'cfgA', createdAt: DateTime.utc(2026, 1, 1)),
        _take('a2', source: 'cfgA', createdAt: DateTime.utc(2026, 2, 1)),
        _take('b1', source: 'cfgB', createdAt: DateTime.utc(2026, 1, 1)),
      ];
      final ids = currentTakeNodeIds(nodes);
      expect(ids.length, 2, reason: '两镜 → 两条');
      expect(
        ids.every((id) => nodes.any((n) => n.id == id)),
        isTrue,
        reason: '返回的 id 必须都来自候选集',
      );
    });

    test('固定旧 take → 默认勾旧的', () {
      final nodes = <CanvasNode>[
        _take('old', createdAt: DateTime.utc(2026, 1, 1)),
        _take('new', createdAt: DateTime.utc(2026, 8, 7)),
        _take('b', source: 'cfgB', createdAt: DateTime.utc(2026, 3, 3)),
      ];
      expect(
        currentTakeNodeIds(nodes, pinnedBySource: const <String, String>{'cfg': 'old'}),
        <String>{'old', 'b'},
      );
    });

    test('固定的不在候选 → 勾最新', () {
      // 固定的是一张图（不在 video 候选里）或已被删：候选里找不到它，回落最新。
      final nodes = <CanvasNode>[
        _take('old', createdAt: DateTime.utc(2026, 1, 1)),
        _take('new', createdAt: DateTime.utc(2026, 8, 7)),
      ];
      expect(
        currentTakeNodeIds(nodes, pinnedBySource: const <String, String>{'cfg': 'gone'}),
        <String>{'new'},
      );
    });

    test('固定表不影响孤儿产物：各自勾上', () {
      final nodes = <CanvasNode>[
        _take('loose1', source: null),
        _take('loose2', source: null),
      ];
      expect(
        currentTakeNodeIds(nodes, pinnedBySource: const <String, String>{'cfg': 'loose1'}),
        <String>{'loose1', 'loose2'},
      );
    });
  });
}
