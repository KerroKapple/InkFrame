// NodeCard widget 测试 —— 覆盖 config label / result pending / PathSecurityError 兜底。
// Image.file 真正解码失败的 errorBuilder 路径走 golden/烟测，不在 widget 单测覆盖
// （异步解码时机在 test 环境不稳定）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_resolver_service.dart';

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

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

ProviderScope scope(Widget child, FileResolverService resolver) {
  return ProviderScope(
    overrides: [fileResolverServiceProvider.overrideWithValue(resolver)],
    child: child,
  );
}

void main() {
  testWidgets('config 节点渲染 label', (tester) async {
    const n = CanvasNode(
      id: 'c1',
      label: 'Config Node Label',
      type: CanvasNodeType.image,
    );
    await tester.pumpWidget(
      scope(
        host(NodeCard(
          node: n,
          selected: false,
          onTap: () {},
          onPanUpdate: (_) {},
        )),
        _FakeResolver(Directory.systemTemp),
      ),
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
    await tester.pumpWidget(
      scope(
        host(NodeCard(
          node: n,
          selected: false,
          onTap: () {},
          onPanUpdate: (_) {},
        )),
        _FakeResolver(Directory.systemTemp),
      ),
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
    await tester.pumpWidget(
      scope(
        host(NodeCard(
          node: n,
          selected: false,
          onTap: () {},
          onPanUpdate: (_) {},
        )),
        _FakeResolver(Directory.systemTemp),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Image file missing'), findsOneWidget);
  });
}
