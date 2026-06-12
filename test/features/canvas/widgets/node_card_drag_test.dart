// NodeCard 拖拽：
//   1) 视觉态：onPanStart → onPanEnd 之间 AnimatedScale 1.0 → 1.02；
//   2) HI-13 落点提交：拖拽中位移只在卡片内部 Transform.translate 局部累积
//      （不每帧推 controller），onPanEnd 一次性回调 onDragEnd(累计位移)。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../../_harness/test_app.dart';

class _FakeResolver implements FileResolverService {
  _FakeResolver(this.dir);
  final Directory dir;

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      dir;

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('${dir.path}/$relativePath');

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required CanvasNode node,
    required void Function(Offset) onDragEnd,
  }) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: NodeCard(
            node: node,
            selected: false,
            onTap: () {},
            onDragEnd: onDragEnd,
          ),
        ),
      ),
      overrides: [
        fileResolverServiceProvider
            .overrideWithValue(_FakeResolver(Directory.systemTemp)),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pan 开始 → AnimatedScale 切到 1.02；pan 结束 → 回到 1.0',
      (tester) async {
    const n = CanvasNode(
      id: 'n1',
      label: 'Drag me',
      type: CanvasNodeType.image,
    );
    await pumpCard(tester, node: n, onDragEnd: (_) {});

    AnimatedScale scaleWidget() => tester
        .widget<AnimatedScale>(find.byType(AnimatedScale).first);
    expect(scaleWidget().scale, 1.0);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Drag me')));
    await gesture.moveBy(const Offset(30, 40));
    await tester.pump();
    expect(scaleWidget().scale, 1.02);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleWidget().scale, 1.0);
  });

  testWidgets('拖拽中位移局部累积（Transform），onDragEnd 仅在落点回调一次',
      (tester) async {
    final commits = <Offset>[];
    const n = CanvasNode(
      id: 'n2',
      label: 'Drag me',
      type: CanvasNodeType.image,
    );
    await pumpCard(tester, node: n, onDragEnd: commits.add);

    Transform translateWidget() =>
        tester.widget<Transform>(find.byType(Transform).first);
    final idleTransform = translateWidget().transform;

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Drag me')));
    await gesture.moveBy(const Offset(30, 40));
    await gesture.moveBy(const Offset(10, -5));
    await tester.pump();

    // 拖拽中：不提交 controller，位移体现在局部 Transform 上。
    expect(commits, isEmpty);
    expect(translateWidget().transform, isNot(equals(idleTransform)));

    await gesture.up();
    await tester.pumpAndSettle();

    // 落点：恰好一次提交，且 Transform 归零（位置交还上层 Positioned）。
    expect(commits, hasLength(1));
    expect(commits.single, isNot(Offset.zero));
    expect(translateWidget().transform, equals(idleTransform));
  });

  testWidgets('pan 取消 → 不提交 onDragEnd，位移归零', (tester) async {
    final commits = <Offset>[];
    const n = CanvasNode(
      id: 'n3',
      label: 'Drag me',
      type: CanvasNodeType.image,
    );
    await pumpCard(tester, node: n, onDragEnd: commits.add);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Drag me')));
    await gesture.moveBy(const Offset(30, 40));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(commits, isEmpty);
  });
}
