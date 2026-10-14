// 端口按需显示（画布重设计稿 › 画布交互）：没连线的卡片不再挂两颗悬空的小圆点。
//
// 悬停 / 选中 / 连线模式（起点或候选）时两侧端口都亮出来供连线；平时只留真挂着
// 线的那一侧（hasInEdge / hasOutEdge，由画布按存量边 + 产出线算好传进来）。
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../../_harness/test_app.dart';

/// 卡片图区读文件解析器；这里没有产物，任何解析都不该发生。
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

const CanvasNode _image = CanvasNode(
  id: 'n1',
  label: 'Shot 01',
  type: CanvasNodeType.image,
);

/// 稿：shot config 只有出端口。
const CanvasNode _shot = CanvasNode(
  id: 's1',
  label: 'Beat 01',
  type: CanvasNodeType.shot,
);

Finder get _inPort => find.byKey(NodeCard.inPortKey);
Finder get _outPort => find.byKey(NodeCard.outPortKey);

Future<void> _pump(
  WidgetTester tester, {
  CanvasNode node = _image,
  bool selected = false,
  bool isLinkSource = false,
  bool isLinkCandidate = false,
  bool hasInEdge = false,
  bool hasOutEdge = false,
}) =>
    pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: NodeCard(
            node: node,
            selected: selected,
            isLinkSource: isLinkSource,
            isLinkCandidate: isLinkCandidate,
            hasInEdge: hasInEdge,
            hasOutEdge: hasOutEdge,
            onTap: () {},
            onDragEnd: (_) {},
          ),
        ),
      ),
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
      ],
    );

void main() {
  testWidgets('没连线、没悬停、没选中 → 两侧端口都不画', (tester) async {
    await _pump(tester);
    expect(_inPort, findsNothing);
    expect(_outPort, findsNothing);
  });

  testWidgets('出口挂着线 → 只常驻出端口', (tester) async {
    await _pump(tester, hasOutEdge: true);
    expect(_outPort, findsOneWidget);
    expect(_inPort, findsNothing);
  });

  testWidgets('入口挂着线 → 只常驻入端口', (tester) async {
    await _pump(tester, hasInEdge: true);
    expect(_inPort, findsOneWidget);
    expect(_outPort, findsNothing);
  });

  testWidgets('两侧都挂着线 → 两侧都常驻', (tester) async {
    await _pump(tester, hasInEdge: true, hasOutEdge: true);
    expect(_inPort, findsOneWidget);
    expect(_outPort, findsOneWidget);
  });

  testWidgets('鼠标悬停 → 两侧端口都亮出来；移开 → 收回', (tester) async {
    await _pump(tester);
    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(_inPort, findsNothing, reason: '指针在卡片外');

    await mouse.moveTo(tester.getCenter(find.byType(NodeCard)));
    await tester.pump();
    expect(_inPort, findsOneWidget);
    expect(_outPort, findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(_inPort, findsNothing);
    expect(_outPort, findsNothing);
  });

  testWidgets('选中 → 两侧端口都亮出来', (tester) async {
    await _pump(tester, selected: true);
    expect(_inPort, findsOneWidget);
    expect(_outPort, findsOneWidget);
  });

  testWidgets('连线模式：起点与候选都亮出两侧端口', (tester) async {
    await _pump(tester, isLinkSource: true);
    expect(_inPort, findsOneWidget);
    expect(_outPort, findsOneWidget);

    await _pump(tester, isLinkCandidate: true);
    expect(_inPort, findsOneWidget);
    expect(_outPort, findsOneWidget);
  });

  testWidgets('shot config 没有入端口：选中、挂着入边都不画', (tester) async {
    await _pump(tester, node: _shot, selected: true, hasInEdge: true);
    expect(_inPort, findsNothing);
    expect(_outPort, findsOneWidget);
  });
}
