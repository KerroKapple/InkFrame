// Lanes 稿改动 3：卡片底部「继承 X」行——在泳道里的节点写道名 + 道的 tint 色点；无道节点留空。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../../_harness/test_app.dart';

/// 卡片图区读文件解析器；这里没有产物，任何解析都不该发生。
class _FakeResolver implements FileResolverService {
  @override
  File resolveInProject({required String projectId, required String relativePath}) => throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) => Directory.systemTemp;

  @override
  File resolve({required String projectId, required String canvasId, required String relativePath}) =>
      throw UnimplementedError();

  @override
  String toRelative({required String projectId, required String canvasId, required File source}) =>
      throw UnimplementedError();
}

const CanvasNode _node = CanvasNode(
  id: 'n1',
  label: 'Shot 05',
  type: CanvasNodeType.image,
  canvasId: 'c1',
  laneId: 'lane-dusk',
);

Future<void> _pump(WidgetTester tester, StyleLane? lane) => pumpInkApp(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: NodeCard(node: _node, lane: lane, selected: false, onTap: () {}, onDragEnd: (_) {}),
        ),
      ),
      overrides: <Override>[fileResolverServiceProvider.overrideWithValue(_FakeResolver())],
    );

void main() {
  testWidgets('在泳道里：底部一行「Inherits <道名>」', (tester) async {
    await _pump(tester, const StyleLane(id: 'lane-dusk', canvasId: 'c1', label: 'Dusk', stylePrompt: 'warm dusk'));
    expect(find.text('Inherits Dusk'), findsOneWidget);
    expect(tester.getSize(find.byType(NodeCard)), kNodeCardSize, reason: '继承行已预留在卡片尺寸里');
  });

  testWidgets('无道节点：继承行留空，卡片尺寸不变', (tester) async {
    await _pump(tester, null);
    expect(find.textContaining('Inherits'), findsNothing);
    expect(tester.getSize(find.byType(NodeCard)), kNodeCardSize);
  });

  testWidgets('CJK 超长道名：继承行单行省略，不溢出', (tester) async {
    await _pump(
      tester,
      const StyleLane(
        id: 'lane-dusk',
        canvasId: 'c1',
        label: '黄昏山径松林逆光背影渐清破晓山脊第一缕光回望收尾空镜黄昏山径松林逆光',
        stylePrompt: 'warm dusk',
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Inherits'), findsOneWidget);
    expect(tester.getSize(find.byType(NodeCard)), kNodeCardSize);
  });
}
