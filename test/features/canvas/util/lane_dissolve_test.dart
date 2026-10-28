// 泳道解散的纯函数（util/lane_dissolve.dart）：解散后卡片屏幕不动的位置换算 + 道内活动任务判据。
//
// 「屏幕不动」的口径：卡片中心沿横截轴的屏幕坐标（泳道栈坐标，crossTranslation = 0）解散前按原道锚定、
// 解散后按道外全局变换，两者相等（±0.5px）；主轴不动。
//
// 变异对照：dissolvedPositions 返回原坐标（不调 laneMoveDelta）⇒「横向 b 道」「缩放」「竖向」红；
// activeJobsInLane 不排除终态 ⇒「succeeded 不算」红；不比 canvasId ⇒「别的画布不算」红；
// 只看 sourceNodeId ⇒「resultNodeId 命中也算」红。
//
// 「被解散的道折叠与否不改结果（回归钉）」：解散后的位置只取决于本道的**起始边**（前面各道的有效厚度之和），
// 本道自己的厚度不进公式——这条只是回归钉，钉「结果 == 未折叠时」；没有对应的变异点
// （把本道从折叠集合里剔除与否是等价变异，lane_dissolve.dart 已不做这一步）。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/util/lane_dissolve.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/lane_pin_geometry.dart';
import 'package:inkframe/features/generation/models/job_state.dart';

const StyleLane _a = StyleLane(id: 'a', canvasId: 'c1', label: 'A', size: 400);
const StyleLane _b = StyleLane(id: 'b', canvasId: 'c1', label: 'B', size: 300, sortOrder: 1);
const StyleLane _c = StyleLane(id: 'c', canvasId: 'c1', label: 'C', size: 250, sortOrder: 2);

CanvasNode _node(String id, Offset position, {String? laneId}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      laneId: laneId,
      position: position,
    );

/// 卡片中心的横截屏幕坐标（泳道栈坐标）：有道按本道起始边锚定，无道走全局变换。
double _crossScreen(
  CanvasNode n, {
  required List<StyleLane> lanes,
  required Set<String> collapsed,
  required LaneDirection direction,
  required double scale,
}) {
  final List<({String id, double size})> slices = collapseLaneSlices(
    <({String id, double size})>[for (final StyleLane l in lanes) (id: l.id, size: l.size)],
    collapsed,
  );
  final bool horizontal = direction == LaneDirection.horizontal;
  final double half = horizontal ? kNodeCardSize.height / 2 : kNodeCardSize.width / 2;
  return crossToScreen(
    laneStart: laneStartOf(n.laneId, slices),
    world: (horizontal ? n.position.dy : n.position.dx) + half,
    scale: scale,
    crossTranslation: 0,
  );
}

/// 解散前后横截屏幕坐标相等（后面的道整体前移不影响被解散道里的卡：它们已是道外节点）。
void _expectScreenStill({
  required CanvasNode node,
  required List<StyleLane> lanes,
  required Set<String> collapsed,
  required LaneDirection direction,
  required double scale,
}) {
  final Map<String, Offset> moved = dissolvedPositions(
    laneNodes: <CanvasNode>[node],
    laneId: node.laneId!,
    lanes: lanes,
    collapsed: collapsed,
    direction: direction,
    scale: scale,
  );
  expect(moved.keys, <String>[node.id]);
  // 被解散的道按展开厚度算 ⇒ 「解散前」的屏幕位置也按它展开时量。
  final Set<String> before = <String>{
    for (final String id in collapsed)
      if (id != node.laneId) id,
  };
  final double screenBefore =
      _crossScreen(node, lanes: lanes, collapsed: before, direction: direction, scale: scale);
  final CanvasNode after = CanvasNode(
    id: node.id,
    label: node.label,
    type: node.type,
    position: moved[node.id]!,
  );
  final List<StyleLane> remaining = <StyleLane>[
    for (final StyleLane l in lanes)
      if (l.id != node.laneId) l,
  ];
  final double screenAfter =
      _crossScreen(after, lanes: remaining, collapsed: before, direction: direction, scale: scale);
  expect(screenAfter, closeTo(screenBefore, 0.5), reason: '解散后卡片屏幕位置不动');
  // 主轴不动。
  if (direction == LaneDirection.horizontal) {
    expect(moved[node.id]!.dx, node.position.dx);
  } else {
    expect(moved[node.id]!.dy, node.position.dy);
  }
}

void main() {
  group('dissolvedPositions', () {
    test('横向两道 [a 400, b 300]、scale 1：b 里的卡解散后 crossToScreen 前后相等', () {
      final CanvasNode n = _node('n1', const Offset(120, 520), laneId: 'b');
      _expectScreenStill(
        node: n,
        lanes: const <StyleLane>[_a, _b],
        collapsed: const <String>{},
        direction: LaneDirection.horizontal,
        scale: 1,
      );
    });

    test('横向 scale 0.5 / 2.0 同样屏幕不动，且世界坐标确实换了（不是原样返回）', () {
      for (final double scale in <double>[0.5, 2.0]) {
        final CanvasNode n = _node('n1', const Offset(80, 480), laneId: 'b');
        _expectScreenStill(
          node: n,
          lanes: const <StyleLane>[_a, _b, _c],
          collapsed: const <String>{},
          direction: LaneDirection.horizontal,
          scale: scale,
        );
        final Map<String, Offset> moved = dissolvedPositions(
          laneNodes: <CanvasNode>[n],
          laneId: 'b',
          lanes: const <StyleLane>[_a, _b, _c],
          collapsed: const <String>{},
          direction: LaneDirection.horizontal,
          scale: scale,
        );
        expect(moved['n1'], isNot(n.position), reason: 'scale $scale：道起始边 400 ≠ 0，锚定换了世界坐标必变');
      }
    });

    test('竖向泳道只改 x（scale 0.5 / 1 / 2.0）', () {
      for (final double scale in <double>[0.5, 1.0, 2.0]) {
        final CanvasNode n = _node('n1', const Offset(450, 300), laneId: 'b');
        _expectScreenStill(
          node: n,
          lanes: const <StyleLane>[_a, _b],
          collapsed: const <String>{},
          direction: LaneDirection.vertical,
          scale: scale,
        );
        final Map<String, Offset> moved = dissolvedPositions(
          laneNodes: <CanvasNode>[n],
          laneId: 'b',
          lanes: const <StyleLane>[_a, _b],
          collapsed: const <String>{},
          direction: LaneDirection.vertical,
          scale: scale,
        );
        expect(moved['n1']!.dy, 300);
      }
    });

    test('被解散的道折叠与否不改结果（回归钉：结果 == 未折叠时的结果）', () {
      final CanvasNode n = _node('n1', const Offset(120, 520), laneId: 'b');
      for (final double scale in <double>[0.5, 1.0, 2.0]) {
        final Map<String, Offset> collapsed = dissolvedPositions(
          laneNodes: <CanvasNode>[n],
          laneId: 'b',
          lanes: const <StyleLane>[_a, _b, _c],
          collapsed: const <String>{'b'},
          direction: LaneDirection.horizontal,
          scale: scale,
        );
        final Map<String, Offset> expanded = dissolvedPositions(
          laneNodes: <CanvasNode>[n],
          laneId: 'b',
          lanes: const <StyleLane>[_a, _b, _c],
          collapsed: const <String>{},
          direction: LaneDirection.horizontal,
          scale: scale,
        );
        expect(collapsed, expanded);
      }
    });

    test('别的道折叠：用折叠厚度（前面的 a 折成 36，b 的起始边跟着前移）', () {
      final CanvasNode n = _node('n1', const Offset(120, 520), laneId: 'b');
      _expectScreenStill(
        node: n,
        lanes: const <StyleLane>[_a, _b],
        collapsed: const <String>{'a'},
        direction: LaneDirection.horizontal,
        scale: 2.0,
      );
      final Map<String, Offset> withA = dissolvedPositions(
        laneNodes: <CanvasNode>[n],
        laneId: 'b',
        lanes: const <StyleLane>[_a, _b],
        collapsed: const <String>{'a'},
        direction: LaneDirection.horizontal,
        scale: 2.0,
      );
      final Map<String, Offset> withoutA = dissolvedPositions(
        laneNodes: <CanvasNode>[n],
        laneId: 'b',
        lanes: const <StyleLane>[_a, _b],
        collapsed: const <String>{},
        direction: LaneDirection.horizontal,
        scale: 2.0,
      );
      expect(withA['n1'], isNot(withoutA['n1']), reason: '前面的道折叠 ⇒ 起始边不同 ⇒ 换算结果不同');
    });

    test('只换算本道里的卡：别的道、道外的卡不在结果里', () {
      final Map<String, Offset> moved = dissolvedPositions(
        laneNodes: <CanvasNode>[
          _node('in-b', const Offset(0, 500), laneId: 'b'),
          _node('in-a', const Offset(0, 100), laneId: 'a'),
          _node('free', const Offset(0, 900)),
        ],
        laneId: 'b',
        lanes: const <StyleLane>[_a, _b],
        collapsed: const <String>{},
        direction: LaneDirection.horizontal,
        scale: 1,
      );
      expect(moved.keys, <String>['in-b']);
    });
  });

  group('activeJobsInLane', () {
    const Set<String> laneIds = <String>{'n1', 'n2'};

    test('running / queued / submitting 命中；succeeded / failed / cancelled 不算', () {
      final List<JobState> jobs = <JobState>[
        const JobState.running(jobId: 'j-run', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1'),
        const JobState.queued(jobId: 'j-q', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n2'),
        const JobState.submitting(jobId: 'j-sub', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1'),
        const JobState.succeeded(
            jobId: 'j-ok', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1', artifactPath: 'a.png'),
        const JobState.failed(
          jobId: 'j-fail',
          providerId: 'p',
          canvasId: 'c1',
          sourceNodeId: 'n1',
          error: LocalIOError(extra: <String, Object?>{'op': 'x'}),
        ),
        const JobState.cancelled(jobId: 'j-cx', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n2'),
      ];
      expect(
        activeJobsInLane(canvasId: 'c1', laneNodeIds: laneIds, jobs: jobs).map((JobState j) => j.jobId),
        <String>['j-run', 'j-q', 'j-sub'],
      );
    });

    test('succeeded 不算', () {
      final List<JobState> jobs = <JobState>[
        const JobState.succeeded(
            jobId: 'j-ok', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1', artifactPath: 'a.png'),
      ];
      expect(activeJobsInLane(canvasId: 'c1', laneNodeIds: laneIds, jobs: jobs), isEmpty);
    });

    test('别的 canvasId 不算（哪怕节点 id 撞上）', () {
      final List<JobState> jobs = <JobState>[
        const JobState.running(jobId: 'j-other', providerId: 'p', canvasId: 'c2', sourceNodeId: 'n1'),
      ];
      expect(activeJobsInLane(canvasId: 'c1', laneNodeIds: laneIds, jobs: jobs), isEmpty);
    });

    test('resultNodeId 命中也算；两头都不在道里不算', () {
      final List<JobState> jobs = <JobState>[
        const JobState.running(
            jobId: 'j-res', providerId: 'p', canvasId: 'c1', sourceNodeId: 'outside', resultNodeId: 'n2'),
        const JobState.running(
            jobId: 'j-out', providerId: 'p', canvasId: 'c1', sourceNodeId: 'outside', resultNodeId: 'other'),
        const JobState.running(jobId: 'j-null', providerId: 'p', canvasId: 'c1'),
      ];
      expect(
        activeJobsInLane(canvasId: 'c1', laneNodeIds: laneIds, jobs: jobs).map((JobState j) => j.jobId),
        <String>['j-res'],
      );
    });
  });
}
