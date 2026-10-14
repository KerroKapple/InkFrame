// EdgePainter（widgets/edge_painter.dart）：画什么、用什么色、标不标、箭头往哪指。
//
// 用户报告「画布中没有看到连线」：示例项目里 config → 产物的来历只存在
// source_node_id 里，原来的画法只认存量边，于是一条线都不画；画出来的线也一律
// 是同一种灰，角色标签只在多入边时才出现、参考线从来不标。这里逐条钉死。
//
// paints 匹配器吃 `void Function(Canvas)`；要看几何（箭头朝向、标签位置）时直接
// 用 TestRecordingCanvas 取出调用参数。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/edge_style.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/lineage_edges.dart';
import 'package:inkframe/features/canvas/widgets/edge_painter.dart';
import 'package:inkframe/theme/tokens.dart';

final InkColors _colors = InkColors.dark();

final EdgePalette _palette = EdgePalette(
  narrative: _colors.fg4,
  lineage: _colors.fg6,
  firstFrame: _colors.edgeFirstFrame,
  lastFrame: _colors.edgeLastFrame,
  reference: _colors.edgeReference,
  accent: _colors.accent,
  chipFill: _colors.surface1,
);

const TextStyle _labelStyle = TextStyle(fontSize: 10);
const Size _canvasSize = Size(2000, 1200);

/// 示例项目的形状：一个 config + 它名下一个产物，edges 表里什么都没有。
const CanvasNode _config = CanvasNode(
  id: 'cfg',
  label: 'Config',
  type: CanvasNodeType.image,
);
const CanvasNode _result = CanvasNode(
  id: 'res',
  label: '',
  type: CanvasNodeType.image,
  role: NodeRole.result,
  sourceNodeId: 'cfg',
  position: Offset(400, 0),
);

/// 数据线两端：图 (0,0) → 视频 (400,0)，横向下是一条 y = 87 的直线。
const CanvasNode _image = CanvasNode(
  id: 'img',
  label: 'Image',
  type: CanvasNodeType.image,
);
const CanvasNode _video = CanvasNode(
  id: 'vid',
  label: 'Video',
  type: CanvasNodeType.video,
  position: Offset(400, 0),
);
const List<CanvasNode> _pair = <CanvasNode>[_image, _video];

CanvasEdge _dataEdge(EdgeRole role, {String id = 'e1'}) => CanvasEdge(
      id: id,
      canvasId: 'c',
      sourceNodeId: 'img',
      targetNodeId: 'vid',
      edgeType: EdgeType.data,
      role: role,
    );

EdgePainter _painter({
  List<CanvasEdge> edges = const <CanvasEdge>[],
  List<CanvasNode> nodes = _pair,
  List<LineageEdge> lineage = const <LineageEdge>[],
  Set<String> selectedNodeIds = const <String>{},
  String? selectedEdgeId,
  LaneDirection direction = LaneDirection.horizontal,
}) =>
    EdgePainter(
      edges: edges,
      nodes: nodes,
      lineage: lineage,
      palette: _palette,
      labelStyle: _labelStyle,
      firstFrameLabel: 'First frame',
      lastFrameLabel: 'Last frame',
      referenceLabel: 'Reference',
      direction: direction,
      selectedNodeIds: selectedNodeIds,
      selectedEdgeId: selectedEdgeId,
    );

void Function(Canvas) _paintOf(EdgePainter painter) =>
    (Canvas canvas) => painter.paint(canvas, _canvasSize);

/// 按调用顺序取出某一种画布调用的位置参数。
List<List<Object?>> _calls(EdgePainter painter, Symbol method) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  painter.paint(canvas, _canvasSize);
  return <List<Object?>>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == method)
        call.invocation.positionalArguments,
  ];
}

bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

/// 线型谓词：虚线 / 点线画出来是多段子路径，实线是一段。
PaintPatternPredicate _strokeIn(Color color, {required bool broken}) =>
    (Symbol method, List<dynamic> args) {
      if (method != #drawPath) return false;
      final Paint paint = args[1] as Paint;
      if (!_sameColor(paint.color, color)) return false;
      final int contours = (args[0] as Path).computeMetrics().length;
      return broken ? contours > 1 : contours == 1;
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('产出线（由 source_node_id 推导）', () {
    test('只有 config + 产物、没有任何存量边：画出一条产出线（产出色 1.25 点线 + 箭头）', () {
      const List<CanvasNode> nodes = <CanvasNode>[_config, _result];
      final List<LineageEdge> lineage =
          deriveLineageEdges(nodes: nodes, edges: const <CanvasEdge>[]);
      final EdgePainter painter = _painter(nodes: nodes, lineage: lineage);

      expect(
        _paintOf(painter),
        paints
          ..path(color: _palette.lineage, strokeWidth: kLineageEdgeWidth)
          ..path(color: _palette.lineage),
      );
      expect(
        _paintOf(painter),
        paints..something(_strokeIn(_palette.lineage, broken: true)),
        reason: '产出线是点线：画出来是一串短段',
      );
      final Paint line = _calls(painter, #drawPath).first[1]! as Paint;
      expect(line.strokeCap, StrokeCap.round, reason: '点线靠圆头才显成点');
      expect(
        _paintOf(painter),
        paintsExactlyCountTimes(#drawParagraph, 0),
        reason: '产出线不挂标签',
      );
    });

    test('对照：同一画面不传产出线（原来的画法只认存量边）就什么都不画', () {
      expect(
        _paintOf(_painter(nodes: const <CanvasNode>[_config, _result])),
        paintsNothing,
      );
    });

    test('产出线端点被选中 → 换成链路色，仍是 1.25 点线', () {
      const List<CanvasNode> nodes = <CanvasNode>[_config, _result];
      final EdgePainter painter = _painter(
        nodes: nodes,
        lineage: deriveLineageEdges(nodes: nodes, edges: const <CanvasEdge>[]),
        selectedNodeIds: const <String>{'res'},
      );
      expect(
        _paintOf(painter),
        paints..path(color: _palette.accent, strokeWidth: kLineageEdgeWidth),
      );
      expect(
        _paintOf(painter),
        paints..something(_strokeIn(_palette.accent, broken: true)),
      );
    });
  });

  group('数据线：按角色着色，三种角色一律挂标签', () {
    test('首帧：首帧色 1.75 实线 + 同色箭头 + 标签胶囊（画布底色填充、首帧色 1px 描边）+ 文字', () {
      final EdgePainter painter =
          _painter(edges: <CanvasEdge>[_dataEdge(EdgeRole.firstFrame)]);
      expect(
        _paintOf(painter),
        paints
          ..path(color: _colors.edgeFirstFrame, strokeWidth: kFrameEdgeWidth)
          ..path(color: _colors.edgeFirstFrame)
          ..rrect(color: _colors.surface1, style: PaintingStyle.fill)
          ..rrect(
            color: _colors.edgeFirstFrame,
            style: PaintingStyle.stroke,
            strokeWidth: kEdgeLabelBorderWidth,
          )
          ..paragraph(),
      );
      expect(
        _paintOf(painter),
        paints..something(_strokeIn(_colors.edgeFirstFrame, broken: false)),
        reason: '首帧线是实线',
      );
    });

    test('尾帧：尾帧色 1.75 实线 + 标签', () {
      final EdgePainter painter =
          _painter(edges: <CanvasEdge>[_dataEdge(EdgeRole.lastFrame)]);
      expect(
        _paintOf(painter),
        paints
          ..path(color: _colors.edgeLastFrame, strokeWidth: kFrameEdgeWidth)
          ..rrect(color: _colors.surface1, style: PaintingStyle.fill)
          ..rrect(color: _colors.edgeLastFrame, style: PaintingStyle.stroke)
          ..paragraph(),
      );
    });

    test('参考：参考色 1.5 虚线；只有这一条入边也挂「参考」标签', () {
      final EdgePainter painter =
          _painter(edges: <CanvasEdge>[_dataEdge(EdgeRole.reference)]);
      expect(
        _paintOf(painter),
        paints
          ..path(color: _colors.edgeReference, strokeWidth: kReferenceEdgeWidth)
          ..rrect(color: _colors.surface1, style: PaintingStyle.fill)
          ..rrect(color: _colors.edgeReference, style: PaintingStyle.stroke)
          ..paragraph(),
      );
      expect(
        _paintOf(painter),
        paints..something(_strokeIn(_colors.edgeReference, broken: true)),
        reason: '参考线是虚线',
      );
    });

    test('标签胶囊居中挂在曲线弧长中点', () {
      // 图 (0,0) 出点 (224, 87) → 视频 (400,0) 入点 (395, 87)：一条直线，中点 (309.5, 87)。
      final List<List<Object?>> rrects = _calls(
        _painter(edges: <CanvasEdge>[_dataEdge(EdgeRole.firstFrame)]),
        #drawRRect,
      );
      expect(rrects, hasLength(2), reason: '一个胶囊 = 填充 + 描边');
      final RRect chip = rrects.first[0]! as RRect;
      expect(chip.center.dx, closeTo(309.5, 0.01));
      expect(chip.center.dy, closeTo(87, 0.01));
    });

    test('三种角色各一条 + 一条叙事线 + 一条产出线：恰好三个标签', () {
      const List<CanvasNode> nodes = <CanvasNode>[
        CanvasNode(id: 'a', label: '', type: CanvasNodeType.image),
        CanvasNode(
          id: 'b',
          label: '',
          type: CanvasNodeType.image,
          position: Offset(0, 300),
        ),
        CanvasNode(
          id: 'c',
          label: '',
          type: CanvasNodeType.image,
          position: Offset(0, 600),
        ),
        CanvasNode(
          id: 'v',
          label: '',
          type: CanvasNodeType.video,
          position: Offset(500, 300),
        ),
        CanvasNode(
          id: 'v2',
          label: '',
          type: CanvasNodeType.video,
          position: Offset(1000, 300),
        ),
        CanvasNode(
          id: 'r',
          label: '',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          sourceNodeId: 'v',
          position: Offset(500, 700),
        ),
      ];
      const List<CanvasEdge> edges = <CanvasEdge>[
        CanvasEdge(
          id: 'e1',
          canvasId: 'c',
          sourceNodeId: 'a',
          targetNodeId: 'v',
          edgeType: EdgeType.data,
          role: EdgeRole.firstFrame,
        ),
        CanvasEdge(
          id: 'e2',
          canvasId: 'c',
          sourceNodeId: 'b',
          targetNodeId: 'v',
          edgeType: EdgeType.data,
          role: EdgeRole.lastFrame,
        ),
        CanvasEdge(
          id: 'e3',
          canvasId: 'c',
          sourceNodeId: 'c',
          targetNodeId: 'v',
          edgeType: EdgeType.data,
        ),
        CanvasEdge(
          id: 'e4',
          canvasId: 'c',
          sourceNodeId: 'v',
          targetNodeId: 'v2',
          edgeType: EdgeType.narrative,
        ),
      ];
      final EdgePainter painter = _painter(
        nodes: nodes,
        edges: edges,
        lineage: deriveLineageEdges(nodes: nodes, edges: edges),
      );
      expect(_paintOf(painter), paintsExactlyCountTimes(#drawParagraph, 3));
      expect(_paintOf(painter), paintsExactlyCountTimes(#drawRRect, 6));
      // 5 条线 × (线 + 箭头)。
      expect(_paintOf(painter), paintsExactlyCountTimes(#drawPath, 10));
    });
  });

  group('叙事线', () {
    test('叙事色（fg4）2.0 实线 + 箭头，不挂标签', () {
      const CanvasEdge narrative = CanvasEdge(
        id: 'n1',
        canvasId: 'c',
        sourceNodeId: 'img',
        targetNodeId: 'vid',
        edgeType: EdgeType.narrative,
      );
      final EdgePainter painter = _painter(edges: <CanvasEdge>[narrative]);
      expect(
        _paintOf(painter),
        paints
          ..path(color: _colors.fg4, strokeWidth: kNarrativeEdgeWidth)
          ..path(color: _colors.fg4),
      );
      expect(
        _paintOf(painter),
        paints..something(_strokeIn(_colors.fg4, broken: false)),
      );
      expect(_paintOf(painter), paintsExactlyCountTimes(#drawParagraph, 0));
      expect(_paintOf(painter), paintsExactlyCountTimes(#drawRRect, 0));
    });
  });

  group('当前链路：只换颜色，线宽 / 标签照旧', () {
    test('端点被选中 → 线、箭头、胶囊描边都换成链路色；线宽仍是 1.75，标签仍在', () {
      final EdgePainter painter = _painter(
        edges: <CanvasEdge>[_dataEdge(EdgeRole.firstFrame)],
        selectedNodeIds: const <String>{'img'},
      );
      expect(
        _paintOf(painter),
        paints
          ..path(color: _palette.accent, strokeWidth: kFrameEdgeWidth)
          ..path(color: _palette.accent)
          ..rrect(color: _colors.surface1, style: PaintingStyle.fill)
          ..rrect(color: _palette.accent, style: PaintingStyle.stroke)
          ..paragraph(),
      );
    });

    test('选中这条线本身 → 同样换链路色；参考线仍是虚线', () {
      final EdgePainter painter = _painter(
        edges: <CanvasEdge>[_dataEdge(EdgeRole.reference)],
        selectedEdgeId: 'e1',
      );
      expect(
        _paintOf(painter),
        paints
          ..path(color: _palette.accent, strokeWidth: kReferenceEdgeWidth),
      );
      expect(
        _paintOf(painter),
        paints..something(_strokeIn(_palette.accent, broken: true)),
      );
    });
  });

  group('终点箭头沿曲线终点切线取向，尖端落在入端口外缘', () {
    Rect arrowBounds(EdgePainter painter) {
      final List<List<Object?>> paths = _calls(painter, #drawPath);
      expect(paths, hasLength(2), reason: '一条实线 = 线 + 箭头');
      return (paths[1][0]! as Path).getBounds();
    }

    void expectRect(Rect actual, Rect expected) {
      expect(actual.left, closeTo(expected.left, 0.01));
      expect(actual.top, closeTo(expected.top, 0.01));
      expect(actual.right, closeTo(expected.right, 0.01));
      expect(actual.bottom, closeTo(expected.bottom, 0.01));
    }

    test('横向：尖端 (395, 87)，两翼往左收 7、上下各 3.5', () {
      expectRect(
        arrowBounds(_painter(edges: <CanvasEdge>[_dataEdge(EdgeRole.firstFrame)])),
        const Rect.fromLTRB(388, 83.5, 395, 90.5),
      );
    });

    test('横向回头线（靶在源左边）：曲线仍从左边进入端口，箭头照样朝右', () {
      const List<CanvasNode> nodes = <CanvasNode>[
        CanvasNode(
          id: 'img',
          label: '',
          type: CanvasNodeType.image,
          position: Offset(400, 0),
        ),
        CanvasNode(id: 'vid', label: '', type: CanvasNodeType.video),
      ];
      expectRect(
        arrowBounds(_painter(
          nodes: nodes,
          edges: <CanvasEdge>[_dataEdge(EdgeRole.firstFrame)],
        )),
        const Rect.fromLTRB(-12, 83.5, -5, 90.5),
      );
    });

    test('竖向：尖端落在靶卡上边中点，两翼往上收', () {
      const List<CanvasNode> nodes = <CanvasNode>[
        _image,
        CanvasNode(
          id: 'vid',
          label: '',
          type: CanvasNodeType.video,
          position: Offset(0, 400),
        ),
      ];
      // 靶上边中点 = (0 + 224 / 2, 400)。
      expectRect(
        arrowBounds(_painter(
          nodes: nodes,
          edges: <CanvasEdge>[_dataEdge(EdgeRole.firstFrame)],
          direction: LaneDirection.vertical,
        )),
        const Rect.fromLTRB(108.5, 393, 115.5, 400),
      );
    });
  });

  group('shouldRepaint', () {
    // 列表 / 集合必须是同一个实例：它们按引用比（与 canvas_view 里整层算一次的口径一致）。
    final List<CanvasEdge> edges = <CanvasEdge>[_dataEdge(EdgeRole.reference)];
    final List<LineageEdge> noLineage = <LineageEdge>[];
    const Set<String> selected = <String>{};

    EdgePainter make({
      EdgePalette? palette,
      TextStyle labelStyle = _labelStyle,
      String firstFrameLabel = 'First frame',
      String lastFrameLabel = 'Last frame',
      String referenceLabel = 'Reference',
    }) =>
        EdgePainter(
          edges: edges,
          nodes: _pair,
          lineage: noLineage,
          palette: palette ?? _palette,
          labelStyle: labelStyle,
          firstFrameLabel: firstFrameLabel,
          lastFrameLabel: lastFrameLabel,
          referenceLabel: referenceLabel,
          selectedNodeIds: selected,
        );

    EdgePalette paletteWith({
      Color? narrative,
      Color? lineage,
      Color? firstFrame,
      Color? lastFrame,
      Color? reference,
      Color? accent,
      Color? chipFill,
    }) =>
        EdgePalette(
          narrative: narrative ?? _palette.narrative,
          lineage: lineage ?? _palette.lineage,
          firstFrame: firstFrame ?? _palette.firstFrame,
          lastFrame: lastFrame ?? _palette.lastFrame,
          reference: reference ?? _palette.reference,
          accent: accent ?? _palette.accent,
          chipFill: chipFill ?? _palette.chipFill,
        );

    test('输入全同 → 不重画', () {
      expect(make().shouldRepaint(make()), isFalse);
    });

    test('标签文字变了（切语言）→ 重画', () {
      expect(make(firstFrameLabel: '起始帧').shouldRepaint(make()), isTrue);
      expect(make(lastFrameLabel: '结束帧').shouldRepaint(make()), isTrue);
      expect(make(referenceLabel: '参考').shouldRepaint(make()), isTrue);
    });

    test('标签字体变了（文字缩放）→ 重画', () {
      expect(
        make(labelStyle: const TextStyle(fontSize: 13)).shouldRepaint(make()),
        isTrue,
      );
    });

    test('任一颜色变了（换主题 / 改自定义连线色）→ 重画', () {
      const Color other = Color(0xFF123456);
      for (final EdgePalette changed in <EdgePalette>[
        paletteWith(narrative: other),
        paletteWith(lineage: other),
        paletteWith(firstFrame: other),
        paletteWith(lastFrame: other),
        paletteWith(reference: other),
        paletteWith(accent: other),
        paletteWith(chipFill: other),
      ]) {
        expect(make(palette: changed).shouldRepaint(make()), isTrue);
      }
    });
  });
}
