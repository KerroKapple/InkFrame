// config 卡图区的文字（提示词条与节点文字稿）：
//   - 正文（提示词 / 文本 / 镜头备注）贴图区顶部、最多三行省略，12 / 1.55 fg2；
//     以前是两行 11px fg6 沉在图区左下角——一大块空盒子底下一条灰字。
//   - video config 的「起始帧 ← X · 运镜」挪到底部单独一行，不再顶掉提示词；
//     image config 设了镜头语言时底部一行镜头语言摘要。
//   - 画布缩到 0.6 以下：正文与摘要都收起，只留居中的类型图标。
//   - result 占位（还没出图）照旧是左下角小字，不跟着改。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/models/shot_language.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_compact_cards.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/test_app.dart';

/// 这里没有产物要读，任何解析都不该发生。
class _FakeResolver implements FileResolverService {
  @override
  File resolveInProject({required String projectId, required String relativePath}) =>
      throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory.systemTemp;

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      throw UnimplementedError();
}

class _Nodes extends CanvasNodesController {
  _Nodes(this.nodes);
  final List<CanvasNode> nodes;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => nodes;
}

class _Edges extends CanvasEdgesController {
  _Edges(this.edges);
  final List<CanvasEdge> edges;

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => edges;
}

/// 缩小态：画布已缩到阈值以下。
class _Compact extends CanvasCompactCards {
  @override
  bool build(String canvasId) => true;
}

const String _prompt = 'an ink wash painting of mountains at dawn';

Future<void> _pump(
  WidgetTester tester,
  CanvasNode node, {
  List<Override> overrides = const <Override>[],
}) async {
  await pumpInkApp(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: NodeCard(node: node, selected: false, onTap: () {}, onDragEnd: (_) {}),
      ),
    ),
    overrides: <Override>[
      fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
}

Finder get _text => find.byKey(NodeCard.configTextKey);
Finder get _summary => find.byKey(NodeCard.configSummaryKey);
Finder get _glyph => find.byKey(NodeCard.compactGlyphKey);

/// 16:9 图区——按 [NodeCard.thumbHeight] 认出那只定高盒子。
Rect _thumb(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(NodeCard),
        matching: find.byWidgetPredicate(
          (Widget w) => w is SizedBox && w.height == NodeCard.thumbHeight,
          description: 'NodeCard thumb box',
        ),
      ),
    );

void main() {
  testWidgets('image config：提示词贴图区顶部、最多三行省略，12 / 1.55 fg2', (tester) async {
    const CanvasNode node = CanvasNode(
      id: 'n1',
      label: 'Mountains',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'prompt': '  $_prompt  '},
    );
    await _pump(tester, node);

    final Text text = tester.widget<Text>(_text);
    expect(text.data, _prompt, reason: '首尾空白去掉');
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.style?.fontSize, 12);
    expect(text.style?.height, 1.55);
    expect(text.style?.color, InkColors.dark().fg2);

    final Rect thumb = _thumb(tester);
    final Rect body = tester.getRect(_text);
    expect(body.top - thumb.top, closeTo(InkSpacing.s10, 0.01), reason: '正文贴图区顶部（只隔 10 的内边距）');
    expect(body.left - thumb.left, closeTo(InkSpacing.s12, 0.01));
    expect(thumb.bottom - body.bottom, greaterThan(InkSpacing.lg), reason: '短提示词不该沉在图区底部');
    expect(_summary, findsNothing, reason: '没设镜头语言 → 没有底部行');
  });

  testWidgets('超长提示词：三行封顶，不溢出图区', (tester) async {
    final CanvasNode node = CanvasNode(
      id: 'n1',
      label: 'Mountains',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'prompt': List<String>.filled(30, _prompt).join(' ')},
    );
    await _pump(tester, node);

    expect(tester.takeException(), isNull);
    final Rect thumb = _thumb(tester);
    final Rect body = tester.getRect(_text);
    const double lineHeight = 12 * 1.55;
    expect(body.height, closeTo(3 * lineHeight, 1), reason: '三行就封顶');
    expect(body.bottom, lessThanOrEqualTo(thumb.bottom));
  });

  testWidgets('image config 设了镜头语言：底部一行镜头语言摘要（10px fg5，单行）', (tester) async {
    const CanvasNode node = CanvasNode(
      id: 'n1',
      label: 'Mountains',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{
        'prompt': _prompt,
        ShotLanguage.keyShotSize: 'closeUp',
        ShotLanguage.keyFocalLength: 85,
      },
    );
    await _pump(tester, node);

    expect(tester.widget<Text>(_text).data, _prompt);
    final Text line = tester.widget<Text>(_summary);
    expect(line.data, 'Close-up CU · 85mm');
    expect(line.maxLines, 1);
    expect(line.overflow, TextOverflow.ellipsis);
    expect(line.style?.fontSize, 10);
    expect(line.style?.color, InkColors.dark().fg5);
    expect(_thumb(tester).bottom - tester.getRect(_summary).bottom, closeTo(InkSpacing.s10, 0.01),
        reason: '摘要行贴图区底部');
  });

  testWidgets('video config：提示词照画在顶部，「起始帧 ← X · 运镜」挪到底部单独一行', (tester) async {
    const CanvasNode still = CanvasNode(
      id: 'img',
      label: 'Ref still',
      type: CanvasNodeType.image,
      canvasId: 'cv1',
    );
    const CanvasNode clip = CanvasNode(
      id: 'vid',
      label: 'Clip',
      type: CanvasNodeType.video,
      canvasId: 'cv1',
      typeConfig: <String, Object?>{'prompt': 'slow push through the pines', 'camera': 'pushIn'},
    );
    await _pump(
      tester,
      clip,
      overrides: <Override>[
        canvasNodesControllerProvider.overrideWith(() => _Nodes(const <CanvasNode>[still, clip])),
        canvasEdgesControllerProvider.overrideWith(
          () => _Edges(const <CanvasEdge>[
            CanvasEdge(
              id: 'e1',
              canvasId: 'cv1',
              sourceNodeId: 'img',
              targetNodeId: 'vid',
              edgeType: EdgeType.data,
              role: EdgeRole.firstFrame,
            ),
          ]),
        ),
      ],
    );

    expect(tester.widget<Text>(_text).data, 'slow push through the pines',
        reason: '有入边时摘要不再顶掉提示词');
    expect(tester.widget<Text>(_summary).data, 'First frame ← Ref still · Dolly in');

    final Rect thumb = _thumb(tester);
    final Rect body = tester.getRect(_text);
    final Rect line = tester.getRect(_summary);
    expect(body.top - thumb.top, closeTo(InkSpacing.s10, 0.01));
    expect(thumb.bottom - line.bottom, closeTo(InkSpacing.s10, 0.01));
    expect(line.top, greaterThan(body.bottom));
  });

  testWidgets('video config 没写提示词：只在图区底部画摘要行', (tester) async {
    const CanvasNode clip = CanvasNode(
      id: 'vid',
      label: 'Clip',
      type: CanvasNodeType.video,
      typeConfig: <String, Object?>{'camera': 'pushIn'},
    );
    await _pump(tester, clip);

    expect(_text, findsNothing);
    expect(tester.widget<Text>(_summary).data, 'Dolly in');
    expect(_thumb(tester).bottom - tester.getRect(_summary).bottom, closeTo(InkSpacing.s10, 0.01));
  });

  testWidgets('shot / text config 的正文同样贴顶三行，没有底部行', (tester) async {
    for (final CanvasNode node in const <CanvasNode>[
      CanvasNode(
        id: 's1',
        label: 'Beat 01',
        type: CanvasNodeType.shot,
        typeConfig: <String, Object?>{'shot_notes': 'wide on the ridge at first light'},
      ),
      CanvasNode(
        id: 't1',
        label: 'Note',
        type: CanvasNodeType.text,
        typeConfig: <String, Object?>{'text': 'keep the palette cold until the reveal'},
      ),
    ]) {
      await _pump(tester, node);
      final Text text = tester.widget<Text>(_text);
      expect(text.data, isNotEmpty);
      expect(text.maxLines, 3);
      expect(tester.getRect(_text).top - _thumb(tester).top, closeTo(InkSpacing.s10, 0.01));
      expect(_summary, findsNothing);
    }
  });

  group('缩小态（画布缩到 0.6 以下）', () {
    testWidgets('收起提示词与摘要行，只留居中的类型图标', (tester) async {
      const CanvasNode node = CanvasNode(
        id: 'n1',
        label: 'Mountains',
        type: CanvasNodeType.image,
        canvasId: 'cv1',
        typeConfig: <String, Object?>{'prompt': _prompt, ShotLanguage.keyShotSize: 'closeUp'},
      );
      await _pump(tester, node, overrides: <Override>[
        canvasCompactCardsProvider.overrideWith(_Compact.new),
      ]);

      expect(_text, findsNothing);
      expect(find.text(_prompt), findsNothing);
      expect(_summary, findsNothing);
      final InkIcon glyph = tester.widget<InkIcon>(_glyph);
      expect(glyph.glyph, InkGlyph.imageConfig);
      expect(glyph.size, InkIconSize.md);
      expect(glyph.color, InkColors.dark().fg6);
      final Offset center = tester.getCenter(_glyph);
      final Offset thumbCenter = _thumb(tester).center;
      expect(center.dx, closeTo(thumbCenter.dx, 0.01));
      expect(center.dy, closeTo(thumbCenter.dy, 0.01));
      expect(find.text('Mountains'), findsOneWidget, reason: '标题行不受缩小态影响');
    });

    testWidgets('每种 config 各用自己的类型图标', (tester) async {
      for (final (CanvasNodeType type, InkGlyph expected) in const <(CanvasNodeType, InkGlyph)>[
        (CanvasNodeType.image, InkGlyph.imageConfig),
        (CanvasNodeType.video, InkGlyph.videoConfig),
        (CanvasNodeType.text, InkGlyph.text),
        (CanvasNodeType.shot, InkGlyph.shot),
      ]) {
        await _pump(
          tester,
          CanvasNode(id: 'n1', label: 'Card', type: type, canvasId: 'cv1'),
          overrides: <Override>[canvasCompactCardsProvider.overrideWith(_Compact.new)],
        );
        expect(tester.widget<InkIcon>(_glyph).glyph, expected, reason: type.name);
      }
    });

    testWidgets('常态（没缩小）不画类型图标', (tester) async {
      const CanvasNode node = CanvasNode(
        id: 'n1',
        label: 'Mountains',
        type: CanvasNodeType.image,
        canvasId: 'cv1',
        typeConfig: <String, Object?>{'prompt': _prompt},
      );
      await _pump(tester, node);

      expect(_glyph, findsNothing);
      expect(tester.widget<Text>(_text).data, _prompt);
    });

    testWidgets('result 卡不跟缩小态走：未出图占位照旧是左下角小字', (tester) async {
      const CanvasNode node = CanvasNode(
        id: 'r1',
        label: '',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        canvasId: 'cv1',
      );
      await _pump(tester, node, overrides: <Override>[
        canvasCompactCardsProvider.overrideWith(_Compact.new),
      ]);

      expect(_glyph, findsNothing);
      expect(find.text('Waiting for generation'), findsOneWidget);
    });
  });
}
