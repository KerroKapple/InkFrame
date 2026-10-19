// narrative_splice 纯函数用例：插入一镜 / 删除接上 / 让位 / 挪位 / 兄弟换序 / 成环 / 撤销。
//
// 夹具里刻意让「入边」与「出边」的 sortOrder 不同、让「被删边」的 sortOrder 不是 0——
// 取错一条、写死 0 都会当场红。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/edge_endpoints.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/narrative_splice.dart';

CanvasEdge _e(
  String id,
  String source,
  String target, {
  EdgeType type = EdgeType.narrative,
  EdgeRole role = EdgeRole.reference,
  int sortOrder = 0,
}) =>
    CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: source,
      targetNodeId: target,
      edgeType: type,
      role: role,
      sortOrder: sortOrder,
    );

CanvasNode _n(
  String id, {
  CanvasNodeType type = CanvasNodeType.image,
  NodeRole role = NodeRole.config,
  double x = 0,
  double y = 0,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: type,
      role: role,
      position: Offset(x, y),
    );

SpliceEdgeSpec _narr(String s, String t, int sortOrder) => (
      sourceNodeId: s,
      targetNodeId: t,
      edgeType: EdgeType.narrative,
      role: EdgeRole.reference,
      sortOrder: sortOrder,
    );

EdgeEndpoints _key(String s, String t,
        {EdgeType type = EdgeType.narrative,
        EdgeRole role = EdgeRole.reference}) =>
    EdgeEndpoints(
        sourceNodeId: s, targetNodeId: t, edgeType: type, role: role);

/// 一格 = 卡片主轴尺寸 + kSpliceSlotGap。
final double _slotX = kNodeCardSize.width + kSpliceSlotGap;
final double _slotY = kNodeCardSize.height + kSpliceSlotGap;

void main() {
  group('canInsertType', () {
    test('canInsertType：image / video / shot 配置可插，text 与 result 不可插', () {
      expect(canInsertType(_n('i')), isTrue);
      expect(canInsertType(_n('v', type: CanvasNodeType.video)), isTrue);
      expect(canInsertType(_n('s', type: CanvasNodeType.shot)), isTrue);
      expect(canInsertType(_n('t', type: CanvasNodeType.text)), isFalse);
      expect(
          canInsertType(_n('r', role: NodeRole.result)), isFalse);
      expect(
          canInsertType(
              _n('rv', type: CanvasNodeType.video, role: NodeRole.result)),
          isFalse);
    });
  });

  group('insertPlan', () {
    test('insertPlan：删 A→B、加 A→X（沿用 sortOrder 5）与 X→B', () {
      final CanvasEdge ab = _e('ab', 'A', 'B', sortOrder: 5);
      final SplicePlan? plan =
          insertPlan(edge: ab, newNodeId: 'X', edges: <CanvasEdge>[ab]);

      expect(plan, isNotNull);
      expect(plan!.removeEdgeIds, <String>{'ab'});
      expect(plan.addEdges, <SpliceEdgeSpec>[
        _narr('A', 'X', 5),
        _narr('X', 'B', 0),
      ]);
      expect(plan.sortOrders, isEmpty);
    });

    test('insertPlan：X 已在链上 / 边是 data ⇒ null', () {
      final CanvasEdge ab = _e('ab', 'A', 'B', sortOrder: 5);
      final CanvasEdge xy = _e('xy', 'X', 'Y');
      expect(
          insertPlan(edge: ab, newNodeId: 'X', edges: <CanvasEdge>[ab, xy]),
          isNull,
          reason: 'X 已有叙事出边——已在链上的挪位只走大纲 movePlan');
      final CanvasEdge zx = _e('zx', 'Z', 'X');
      expect(
          insertPlan(edge: ab, newNodeId: 'X', edges: <CanvasEdge>[ab, zx]),
          isNull,
          reason: 'X 有叙事入边也算在链上');

      final CanvasEdge data = _e('d', 'A', 'B', type: EdgeType.data);
      expect(
          insertPlan(edge: data, newNodeId: 'X', edges: <CanvasEdge>[data]),
          isNull);
    });

    test('insertPlan：X 只有 data 边仍可插；X 是 A 或 B ⇒ null', () {
      final CanvasEdge ab = _e('ab', 'A', 'B', sortOrder: 2);
      final CanvasEdge xd = _e('xd', 'X', 'Q', type: EdgeType.data);
      expect(
          insertPlan(edge: ab, newNodeId: 'X', edges: <CanvasEdge>[ab, xd]),
          isNotNull);
      expect(insertPlan(edge: ab, newNodeId: 'A', edges: <CanvasEdge>[ab]),
          isNull);
      expect(insertPlan(edge: ab, newNodeId: 'B', edges: <CanvasEdge>[ab]),
          isNull);
    });
  });

  group('bridgePlan', () {
    test('bridgePlan：A→X→B 删 X ⇒ 接 A→B，sortOrder 取入边', () {
      final BridgePlan r = bridgePlan(deletedIds: <String>{'X'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X', sortOrder: 3),
        _e('xb', 'X', 'B', sortOrder: 7),
      ]);
      expect(r.skippedSegments, 0);
      expect(r.plan.removeEdgeIds, isEmpty);
      expect(r.plan.addEdges, <SpliceEdgeSpec>[_narr('A', 'B', 3)]);
    });

    test('bridgePlan：连续两张 A→X→Y→B ⇒ 一条 A→B', () {
      final BridgePlan r =
          bridgePlan(deletedIds: <String>{'X', 'Y'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X', sortOrder: 4),
        _e('xy', 'X', 'Y', sortOrder: 1),
        _e('yb', 'Y', 'B', sortOrder: 9),
      ]);
      expect(r.skippedSegments, 0);
      expect(r.plan.addEdges, <SpliceEdgeSpec>[_narr('A', 'B', 4)]);
    });

    test('bridgePlan：两段不相连 ⇒ 各接各的', () {
      final BridgePlan r =
          bridgePlan(deletedIds: <String>{'X', 'Y'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X', sortOrder: 1),
        _e('xb', 'X', 'B'),
        _e('by', 'B', 'Y', sortOrder: 2),
        _e('yc', 'Y', 'C'),
      ]);
      expect(r.skippedSegments, 0);
      expect(r.plan.addEdges.toSet(), <SpliceEdgeSpec>{
        _narr('A', 'B', 1),
        _narr('B', 'C', 2),
      });
      expect(r.plan.addEdges, hasLength(2));
    });

    test('bridgePlan：X 两条叙事出边（分叉）⇒ 不接，skippedSegments = 1', () {
      final BridgePlan r = bridgePlan(deletedIds: <String>{'X'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X'),
        _e('xb', 'X', 'B'),
        _e('xc', 'X', 'C', sortOrder: 1),
      ]);
      expect(r.plan.isEmpty, isTrue);
      expect(r.skippedSegments, 1);
    });

    test('bridgePlan：X 两条叙事入边（汇合）⇒ 不接', () {
      final BridgePlan r = bridgePlan(deletedIds: <String>{'X'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X'),
        _e('cx', 'C', 'X'),
        _e('xb', 'X', 'B'),
      ]);
      expect(r.plan.isEmpty, isTrue);
      expect(r.skippedSegments, 1);
    });

    test('bridgePlan：段中间那张分叉 ⇒ 整段不接', () {
      final BridgePlan r =
          bridgePlan(deletedIds: <String>{'X', 'Y'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X'),
        _e('xy', 'X', 'Y'),
        _e('yb', 'Y', 'B'),
        _e('yc', 'Y', 'C', sortOrder: 1),
      ]);
      expect(r.plan.isEmpty, isTrue);
      expect(r.skippedSegments, 1);
    });

    test('bridgePlan：删链头 / 链尾 ⇒ 空 plan、skipped 0', () {
      final List<CanvasEdge> chain = <CanvasEdge>[
        _e('xa', 'X', 'A'),
        _e('ab', 'A', 'B'),
        _e('by', 'B', 'Y'),
      ];
      final BridgePlan head = bridgePlan(deletedIds: <String>{'X'}, edges: chain);
      expect(head.plan.isEmpty, isTrue);
      expect(head.skippedSegments, 0);
      final BridgePlan tail = bridgePlan(deletedIds: <String>{'Y'}, edges: chain);
      expect(tail.plan.isEmpty, isTrue);
      expect(tail.skippedSegments, 0);
    });

    test('bridgePlan：A→B 已存在 ⇒ 不重复建', () {
      final BridgePlan r = bridgePlan(deletedIds: <String>{'X'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X'),
        _e('xb', 'X', 'B'),
        _e('ab', 'A', 'B', sortOrder: 1),
      ]);
      expect(r.plan.isEmpty, isTrue);
      expect(r.skippedSegments, 0);
    });

    test('bridgePlan：data 边不参与', () {
      // X 多一条 data 出边、A 多一条 data 边到 B——都不算分叉，也不挡桥接（类型不同）。
      final BridgePlan r = bridgePlan(deletedIds: <String>{'X'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X', sortOrder: 2),
        _e('xb', 'X', 'B'),
        _e('xd', 'X', 'D', type: EdgeType.data),
        _e('ab', 'A', 'B', type: EdgeType.data),
      ]);
      expect(r.skippedSegments, 0);
      expect(r.plan.addEdges, <SpliceEdgeSpec>[_narr('A', 'B', 2)]);
    });

    test('bridgePlan：P == S（删的是两镜小环里的一镜）⇒ 不接', () {
      final BridgePlan r = bridgePlan(deletedIds: <String>{'X'}, edges: <CanvasEdge>[
        _e('ax', 'A', 'X'),
        _e('xa', 'X', 'A'),
      ]);
      expect(r.plan.isEmpty, isTrue);
      expect(r.skippedSegments, 0);
    });
  });

  group('makeRoomShifts', () {
    final CanvasEdge ab = _e('ab', 'A', 'B');

    test('makeRoomShifts：空隙够 ⇒ 空', () {
      final double enough = kNodeCardSize.width + 2 * kSpliceSlotGap;
      final Map<String, Offset> shifts = makeRoomShifts(
        edge: ab,
        nodes: <CanvasNode>[
          _n('A'),
          _n('B', x: kNodeCardSize.width + enough),
        ],
        edges: <CanvasEdge>[ab],
        direction: LaneDirection.horizontal,
      );
      expect(shifts, isEmpty);
    });

    test('makeRoomShifts：横向放不下 ⇒ B 与其后整条链 x + 一格', () {
      final Map<String, Offset> shifts = makeRoomShifts(
        edge: ab,
        nodes: <CanvasNode>[
          _n('A'),
          _n('B', x: kNodeCardSize.width + 100),
          _n('C', x: 800),
          _n('D', x: 1200),
          _n('E', x: 1600),
          _n('F', x: 2000),
        ],
        edges: <CanvasEdge>[
          ab,
          _e('bc', 'B', 'C'),
          _e('cd', 'C', 'D'),
          _e('bf', 'B', 'F', type: EdgeType.data),
        ],
        direction: LaneDirection.horizontal,
      );
      expect(shifts, <String, Offset>{
        'B': Offset(_slotX, 0),
        'C': Offset(_slotX, 0),
        'D': Offset(_slotX, 0),
      }, reason: 'E 不在链上、F 只经 data 边相连，都不动');
    });

    test('makeRoomShifts：竖向泳道沿 y 后移', () {
      final Map<String, Offset> shifts = makeRoomShifts(
        edge: ab,
        nodes: <CanvasNode>[
          _n('A'),
          // x 上隔得很远也不算——竖向泳道只看 y。
          _n('B', x: 5000, y: kNodeCardSize.height + 50),
          _n('C', y: 900),
        ],
        edges: <CanvasEdge>[ab, _e('bc', 'B', 'C')],
        direction: LaneDirection.vertical,
      );
      expect(shifts, <String, Offset>{
        'B': Offset(0, _slotY),
        'C': Offset(0, _slotY),
      });
    });

    test('makeRoomShifts：链上有环 ⇒ 每个节点只移一次', () {
      final Map<String, Offset> shifts = makeRoomShifts(
        edge: ab,
        nodes: <CanvasNode>[
          _n('A'),
          _n('B', x: 300),
          _n('C', x: 600),
          _n('D', x: 900),
        ],
        edges: <CanvasEdge>[
          ab,
          _e('bc', 'B', 'C'),
          _e('cb', 'C', 'B'),
          _e('cd', 'C', 'D'),
          _e('da', 'D', 'A'),
        ],
        direction: LaneDirection.horizontal,
      );
      expect(shifts, <String, Offset>{
        'B': Offset(_slotX, 0),
        'C': Offset(_slotX, 0),
        'D': Offset(_slotX, 0),
      }, reason: '环回到 A 时停，A 不动');
    });
  });

  group('movePlan', () {
    test('movePlan：摘出后前后接上并插到 A 后', () {
      final SplicePlan? plan = movePlan(
        nodeId: 'X',
        afterId: 'A',
        edges: <CanvasEdge>[
          _e('px', 'P', 'X', sortOrder: 3),
          _e('xs', 'X', 'S', sortOrder: 8),
          _e('ab', 'A', 'B', sortOrder: 6),
        ],
      );
      expect(plan, isNotNull);
      expect(plan!.removeEdgeIds, <String>{'px', 'xs', 'ab'});
      expect(plan.addEdges, <SpliceEdgeSpec>[
        _narr('P', 'S', 3),
        _narr('A', 'X', 6),
        _narr('X', 'B', 0),
      ]);
    });

    test('movePlan：A 无出边 ⇒ 接在末尾', () {
      final SplicePlan? plan = movePlan(
        nodeId: 'X',
        afterId: 'A',
        edges: <CanvasEdge>[
          _e('px', 'P', 'X', sortOrder: 2),
          _e('xs', 'X', 'S'),
          _e('za', 'Z', 'A', sortOrder: 4),
        ],
      );
      expect(plan!.removeEdgeIds, <String>{'px', 'xs'});
      expect(plan.addEdges, <SpliceEdgeSpec>[
        _narr('P', 'S', 2),
        _narr('A', 'X', 0),
      ]);
    });

    test('movePlan：A 有分叉 ⇒ A→X 排在已有分支之后，不拆分叉', () {
      final SplicePlan? plan = movePlan(
        nodeId: 'X',
        afterId: 'A',
        edges: <CanvasEdge>[
          _e('ab', 'A', 'B'),
          _e('ac', 'A', 'C', sortOrder: 1),
        ],
      );
      expect(plan!.removeEdgeIds, isEmpty);
      expect(plan.addEdges, <SpliceEdgeSpec>[_narr('A', 'X', 2)]);
    });

    test('movePlan：X 有分叉 ⇒ null', () {
      final List<CanvasEdge> edges = <CanvasEdge>[
        _e('px', 'P', 'X'),
        _e('xs', 'X', 'S'),
        _e('xt', 'X', 'T', sortOrder: 1),
        _e('ab', 'A', 'B'),
      ];
      expect(movePlan(nodeId: 'X', afterId: 'A', edges: edges), isNull);
      final List<CanvasEdge> merge = <CanvasEdge>[
        _e('px', 'P', 'X'),
        _e('qx', 'Q', 'X'),
        _e('ab', 'A', 'B'),
      ];
      expect(movePlan(nodeId: 'X', afterId: 'A', edges: merge), isNull,
          reason: '汇合与分叉同口径');
      expect(movePlan(nodeId: 'X', afterId: 'X', edges: const <CanvasEdge>[]),
          isNull);
    });

    test('movePlan：已是 A 的后继 ⇒ 空 plan', () {
      final SplicePlan? plan = movePlan(
        nodeId: 'X',
        afterId: 'A',
        edges: <CanvasEdge>[_e('ax', 'A', 'X'), _e('xb', 'X', 'B')],
      );
      expect(plan, isNotNull);
      expect(plan!.isEmpty, isTrue);
    });

    test('movePlan：挪到原后继之后（A→X→B 把 X 挪到 B 后）', () {
      final SplicePlan? plan = movePlan(
        nodeId: 'X',
        afterId: 'B',
        edges: <CanvasEdge>[
          _e('ax', 'A', 'X', sortOrder: 1),
          _e('xb', 'X', 'B'),
          _e('bc', 'B', 'C', sortOrder: 2),
        ],
      );
      expect(plan!.removeEdgeIds, <String>{'ax', 'xb', 'bc'});
      expect(plan.addEdges, <SpliceEdgeSpec>[
        _narr('A', 'B', 1),
        _narr('B', 'X', 2),
        _narr('X', 'C', 0),
      ]);
    });
  });

  group('siblingReorderPlan', () {
    test('siblingReorderPlan：只改 sortOrder，不删不加', () {
      final List<CanvasEdge> edges = <CanvasEdge>[
        _e('pa', 'P', 'a'),
        _e('pb', 'P', 'b', sortOrder: 1),
        _e('pc', 'P', 'c', sortOrder: 2),
        _e('pd', 'P', 'd', type: EdgeType.data, sortOrder: 9),
      ];
      final SplicePlan plan = siblingReorderPlan(
        parentId: 'P',
        orderedChildIds: <String>['c', 'zz', 'a', 'd', 'b'],
        edges: edges,
      );
      expect(plan.removeEdgeIds, isEmpty);
      expect(plan.addEdges, isEmpty);
      expect(plan.sortOrders, <String, int>{'pc': 0, 'pa': 1, 'pb': 2},
          reason: 'zz 不是后继、d 只是 data 边，都忽略');

      final SplicePlan partial = siblingReorderPlan(
        parentId: 'P',
        orderedChildIds: <String>['a', 'c', 'b'],
        edges: edges,
      );
      expect(partial.sortOrders, <String, int>{'pc': 1, 'pb': 2},
          reason: '顺序不变的 a 不写');
    });

    test('siblingReorderPlan：只传部分子节点 ⇒ 没列出的按原序接在后面、不撞号', () {
      final List<CanvasEdge> edges = <CanvasEdge>[
        _e('pa', 'P', 'a'),
        _e('pb', 'P', 'b', sortOrder: 1),
        _e('pc', 'P', 'c', sortOrder: 2),
      ];
      final SplicePlan plan = siblingReorderPlan(
        parentId: 'P',
        orderedChildIds: <String>['c', 'b'],
        edges: edges,
      );
      expect(plan.sortOrders, <String, int>{'pc': 0, 'pa': 2},
          reason: 'c=0、b=1（不变不写）、没列出的 a 接在后面 = 2；a 留在 0 就和 c 撞号');

      // 没列出的不止一条：彼此保持原相对顺序（原 sortOrder 升序），同号按边 id。
      final List<CanvasEdge> wide = <CanvasEdge>[
        _e('pa', 'P', 'a', sortOrder: 3),
        _e('pb', 'P', 'b', sortOrder: 1),
        _e('pc', 'P', 'c', sortOrder: 1),
        _e('pd', 'P', 'd', sortOrder: 0),
      ];
      final SplicePlan rest = siblingReorderPlan(
        parentId: 'P',
        orderedChildIds: <String>['a'],
        edges: wide,
      );
      expect(rest.sortOrders,
          <String, int>{'pa': 0, 'pd': 1, 'pb': 2, 'pc': 3});
    });
  });

  group('wouldCreateNarrativeCycle', () {
    final List<CanvasEdge> chain = <CanvasEdge>[
      _e('ab', 'A', 'B'),
      _e('bc', 'B', 'C'),
      _e('cd', 'C', 'D', type: EdgeType.data),
    ];

    test('wouldCreateNarrativeCycle：直连回头 true', () {
      expect(
          wouldCreateNarrativeCycle(
              sourceNodeId: 'C', targetNodeId: 'A', edges: chain),
          isTrue);
      expect(
          wouldCreateNarrativeCycle(
              sourceNodeId: 'B', targetNodeId: 'A', edges: chain),
          isTrue);
      expect(
          wouldCreateNarrativeCycle(
              sourceNodeId: 'A', targetNodeId: 'A', edges: chain),
          isTrue);
    });

    test('wouldCreateNarrativeCycle：无路径 false', () {
      expect(
          wouldCreateNarrativeCycle(
              sourceNodeId: 'A', targetNodeId: 'C', edges: chain),
          isFalse);
      expect(
          wouldCreateNarrativeCycle(
              sourceNodeId: 'D', targetNodeId: 'A', edges: chain),
          isFalse,
          reason: 'C→D 是 data 边，不算链');
    });
  });

  group('invertSplice', () {
    // 插入 X 到 A→B 之后的令牌：删了 A→B(5)，建了 A→X、X→B。
    SpliceUndoToken insertToken() => SpliceUndoToken(
          removed: <({EdgeEndpoints key, int sortOrder})>[
            (key: _key('A', 'B'), sortOrder: 5),
          ],
          added: <EdgeEndpoints>[_key('A', 'X'), _key('X', 'B')],
        );

    test('invertSplice：按两端找边——新边被删后同两端重建（id 变了）仍能撤掉', () {
      // A→X 曾被删又被重建，id 已经不是当初那条。
      final SplicePlan? plan = invertSplice(insertToken(), <CanvasEdge>[
        _e('rebuilt-ax', 'A', 'X', sortOrder: 5),
        _e('xb', 'X', 'B'),
      ]);
      expect(plan, isNotNull);
      expect(plan!.removeEdgeIds, <String>{'rebuilt-ax', 'xb'});
      expect(plan.addEdges, <SpliceEdgeSpec>[_narr('A', 'B', 5)]);
    });

    test('invertSplice：全部对不上 ⇒ null', () {
      // 新边都已不在；A→B 此刻已有在世的一条（别处建回来了）⇒ 什么都不用做。
      final SplicePlan? plan = invertSplice(insertToken(), <CanvasEdge>[
        _e('ab2', 'A', 'B'),
        _e('ax-data', 'A', 'X', type: EdgeType.data),
      ]);
      expect(plan, isNull);
      expect(
          invertSplice(
              SpliceUndoToken(
                  previousSortOrders: <EdgeEndpoints, int>{_key('P', 'a'): 0}),
              const <CanvasEdge>[]),
          isNull);
    });

    test('invertSplice：被删的边此刻已有同两端在世边 ⇒ 不重复 create', () {
      final SplicePlan? plan = invertSplice(insertToken(), <CanvasEdge>[
        _e('ax', 'A', 'X'),
        _e('ab-again', 'A', 'B', sortOrder: 1),
      ]);
      expect(plan!.removeEdgeIds, <String>{'ax'});
      expect(plan.addEdges, isEmpty);
    });

    test('invertSplice：删了又建同两端 ⇒ 撤销时先删新那条再按原样建回', () {
      final SpliceUndoToken token = SpliceUndoToken(
        removed: <({EdgeEndpoints key, int sortOrder})>[
          (key: _key('A', 'B', type: EdgeType.data, role: EdgeRole.firstFrame),
              sortOrder: 3),
        ],
        added: <EdgeEndpoints>[_key('A', 'B', type: EdgeType.data)],
      );
      final SplicePlan? plan = invertSplice(token, <CanvasEdge>[
        _e('new-ab', 'A', 'B', type: EdgeType.data, role: EdgeRole.lastFrame),
      ]);
      expect(plan!.removeEdgeIds, <String>{'new-ab'},
          reason: '按两端 + 类型匹配，不看 role');
      expect(plan.addEdges, <SpliceEdgeSpec>[
        (
          sourceNodeId: 'A',
          targetNodeId: 'B',
          edgeType: EdgeType.data,
          role: EdgeRole.firstFrame,
          sortOrder: 3,
        ),
      ]);
    });

    test('invertSplice：改过序的边按两端找到后改回原值', () {
      final SplicePlan? plan = invertSplice(
        SpliceUndoToken(previousSortOrders: <EdgeEndpoints, int>{
          _key('P', 'a'): 0,
          _key('P', 'gone'): 4,
        }),
        <CanvasEdge>[_e('pa-new-id', 'P', 'a', sortOrder: 2)],
      );
      expect(plan!.sortOrders, <String, int>{'pa-new-id': 0});
      expect(plan.removeEdgeIds, isEmpty);
      expect(plan.addEdges, isEmpty);
    });

    test('invertSplice：removed 的端点节点已删 ⇒ 不重建，全部对不上时返回 null', () {
      // 先插 X 到 A→B，再删节点 B（B 的边随之软删：X→B 已不在世），乱序撤销插入。
      final SplicePlan? plan = invertSplice(
        insertToken(),
        <CanvasEdge>[_e('ax', 'A', 'X', sortOrder: 5)],
        aliveNodeIds: <String>{'A', 'X'},
      );
      expect(plan, isNotNull);
      expect(plan!.removeEdgeIds, <String>{'ax'});
      expect(plan.addEdges, isEmpty, reason: 'B 已删，A→B 不能建到软删节点上');

      // 两端都在世 ⇒ 照常重建（过滤只看节点在不在，不是一律不建）。
      final SplicePlan? alive = invertSplice(
        insertToken(),
        <CanvasEdge>[_e('ax', 'A', 'X', sortOrder: 5)],
        aliveNodeIds: <String>{'A', 'X', 'B'},
      );
      expect(alive!.addEdges, <SpliceEdgeSpec>[_narr('A', 'B', 5)]);

      // 新边都已不在、被删边的源端也已删 ⇒ 无事可做 ⇒ null（调用方判 gone）。
      expect(
          invertSplice(insertToken(), const <CanvasEdge>[],
              aliveNodeIds: <String>{'B', 'X'}),
          isNull);
      // 对照：不传节点集合时同样的输入会重建 A→B。
      expect(invertSplice(insertToken(), const <CanvasEdge>[]), isNotNull);
    });
  });
}
