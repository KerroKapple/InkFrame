// NodeCard widget 测试 —— 覆盖 config label / result pending / PathSecurityError 兜底。
// Image.file 真正解码失败的 errorBuilder 路径走 golden/烟测，不在 widget 单测覆盖
// （异步解码时机在 test 环境不稳定）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';

import '../../_harness/test_app.dart';

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
  }) {
    if (relativePath.contains('..')) {
      throw PathSecurityError('parent traversal');
    }
    return File('${dir.path}/$relativePath');
  }

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      source.path;
}

void main() {
  testWidgets('config 节点渲染 label', (tester) async {
    const n = CanvasNode(
      id: 'c1',
      label: 'Config Node Label',
      type: CanvasNodeType.image,
    );
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: NodeCard(
            node: n,
            selected: false,
            onTap: () {},
            onDragEnd: (_) {},
          ),
        ),
      ),
      overrides: [
        fileResolverServiceProvider
            .overrideWithValue(_FakeResolver(Directory.systemTemp)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Config Node Label'), findsOneWidget);
  });

  testWidgets('result 节点无 image_url → 显示 pending 占位', (tester) async {
    const n = CanvasNode(
      id: 'r1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      projectId: 'p',
      canvasId: 'c',
    );
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: NodeCard(
            node: n,
            selected: false,
            onTap: () {},
            onDragEnd: (_) {},
          ),
        ),
      ),
      overrides: [
        fileResolverServiceProvider
            .overrideWithValue(_FakeResolver(Directory.systemTemp)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting for generation'), findsOneWidget);
  });

  testWidgets('PathSecurityError → 图像缺失兜底占位', (tester) async {
    const n = CanvasNode(
      id: 'r1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      projectId: 'p',
      canvasId: 'c',
      typeConfig: <String, Object?>{'image_url': '../escape.png'},
    );
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: NodeCard(
            node: n,
            selected: false,
            onTap: () {},
            onDragEnd: (_) {},
          ),
        ),
      ),
      overrides: [
        fileResolverServiceProvider
            .overrideWithValue(_FakeResolver(Directory.systemTemp)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Image file missing'), findsOneWidget);
  });
}
