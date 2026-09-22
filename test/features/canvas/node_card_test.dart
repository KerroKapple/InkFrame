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
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

class _FakeResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      throw UnimplementedError();

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

  // 标题条：空 label 回退本地化类型名（不得泄漏裸 enum 名，i18n-1）；
  // 有 label 则显示 label、不再显示类型名（简约化：默认态一条文字）。
  for (final (CanvasNodeType type, String en, String zh) in const [
    (CanvasNodeType.text, 'Text', '文本'),
    (CanvasNodeType.video, 'Video', '视频'),
    (CanvasNodeType.shot, 'Shot', '分镜'),
  ]) {
    testWidgets('${type.name} 标题条：空 label 回退本地化类型名 (en/zh)',
        (tester) async {
      final n = CanvasNode(id: 'c1', label: '', type: type);
      Widget card() => Scaffold(
            body: Center(
              child: NodeCard(
                node: n,
                selected: false,
                onTap: () {},
                onDragEnd: (_) {},
              ),
            ),
          );
      final overrides = [
        fileResolverServiceProvider
            .overrideWithValue(_FakeResolver(Directory.systemTemp)),
      ];

      await pumpInkApp(tester, card(), overrides: overrides);
      await tester.pumpAndSettle();
      expect(find.text(en), findsOneWidget);
      // 稿：标题行右侧有 10px 类型标签（image / video / shot），用的就是枚举名。
      expect(find.text(type.name), findsOneWidget);

      await pumpInkApp(tester, card(),
          overrides: overrides, locale: const Locale('zh'));
      await tester.pumpAndSettle();
      expect(find.text(zh), findsOneWidget);
    });
  }

  // 稿：图区一律 1px outline（有无媒体都描），选中 accent；outline 画在盒子外一圈
  //（圆角 s5 = 4 + 1），由此定位那只 DecoratedBox。
  group('图区 outline', () {
    Color outlineColor(WidgetTester tester) {
      for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(NodeCard),
          matching: find.byType(DecoratedBox),
        ),
      )) {
        final BoxDecoration d = box.decoration as BoxDecoration;
        if (d.border != null &&
            d.borderRadius == BorderRadius.circular(InkRadius.s5)) {
          return (d.border! as Border).top.color;
        }
      }
      throw StateError('outline DecoratedBox not found');
    }

    Future<void> pump(
      WidgetTester tester,
      CanvasNode n, {
      bool selected = false,
    }) async {
      await pumpInkApp(
        tester,
        Scaffold(
          body: Center(
            child: NodeCard(
              node: n,
              selected: selected,
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
    }

    const mediaNode = CanvasNode(
      id: 'm1',
      label: '',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      projectId: 'p',
      canvasId: 'c',
      typeConfig: <String, Object?>{'image_url': 'a.png'},
    );

    testWidgets('有媒体 → 默认态 outline 色', (tester) async {
      await pump(tester, mediaNode);
      expect(outlineColor(tester), InkColors.dark().outline);
    });

    testWidgets('无媒体 → 默认态 outline 色', (tester) async {
      const n = CanvasNode(id: 'c1', label: '', type: CanvasNodeType.image);
      await pump(tester, n);
      expect(outlineColor(tester), InkColors.dark().outline);
    });

    testWidgets('有媒体且选中 → accent', (tester) async {
      await pump(tester, mediaNode, selected: true);
      expect(outlineColor(tester), InkColors.dark().accent);
    });
  });

  testWidgets('标题条：有 label 显示 label，类型名不再出现', (tester) async {
    const n = CanvasNode(id: 'c2', label: 'My Shot', type: CanvasNodeType.shot);
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
    expect(find.text('My Shot'), findsOneWidget);
    expect(find.text('Shot'), findsNothing);
  });
}
