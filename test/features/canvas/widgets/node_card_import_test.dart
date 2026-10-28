// 导入媒体节点卡：复制中「Copying 48%」（accent 色）+ 图区底部进度条（图片、视频各一条）——复制中图区
// 只画底色占位，不走 _ResultBody / VideoNodeBody，不写「等待生成」（导入的媒体不是生成出来的）；
// 复制完「Imported」（fg4 色）+ 右侧宽高；非导入产物不受影响。
//
// 变异点：node_card.dart _StatusRow 里复制中的 statusColor 改成 colors.fg4 ⇒「图片复制中」用例红；
// 导入完成改成 colors.accent ⇒「图片导入完成」用例红；_NodeBody 去掉 progress 分支（复制中仍走
// _ResultBody / VideoNodeBody）⇒ 两条复制中用例的「Waiting for generation」/ VideoNodeBody 断言红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/media_import_controller.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/canvas/widgets/video_node_body.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_progress_bar.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart' show StubFileResolver;
import '../../../_harness/test_app.dart';

const String _cid = 'cv';

/// 进度表钉成固定值的导入控制器。
class _FixedProgress extends MediaImportController {
  _FixedProgress(this.value);
  final Map<String, double> value;

  @override
  Map<String, double> build(String canvasId) => value;
}

CanvasNode _imported(
  String id, {
  CanvasNodeType type = CanvasNodeType.image,
  Map<String, Object?> extra = const <String, Object?>{},
  String name = '雾江.jpg',
}) =>
    CanvasNode(
      id: id,
      label: name,
      type: type,
      role: NodeRole.result,
      canvasId: _cid,
      typeConfig: <String, Object?>{
        'origin': 'import',
        'original_name': name,
        ...extra,
      },
    );

void main() {
  Future<void> pump(
    WidgetTester tester,
    CanvasNode node, {
    Map<String, double> progress = const <String, double>{},
  }) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: Center(
          child: NodeCard(
            node: node,
            selected: false,
            onTap: () {},
            onDragEnd: (_) {},
          ),
        ),
      ),
      overrides: <Override>[
        fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
        mediaImportControllerProvider.overrideWith(() => _FixedProgress(progress)),
      ],
    );
    await tester.pump();
  }

  testWidgets('图片复制中：状态行「Copying 48%」（accent）+ 图区进度条，不写「等待生成」', (tester) async {
    await pump(tester, _imported('n1'), progress: <String, double>{'n1': 0.48});

    expect(find.text('Copying 48%'), findsOneWidget);
    expect(find.text('Waiting for generation'), findsNothing);
    expect(find.byKey(NodeCard.importProgressKey), findsOneWidget);
    final InkProgressBar bar =
        tester.widget<InkProgressBar>(find.byKey(NodeCard.importProgressKey));
    expect(bar.value, 0.48);

    final Text status = tester.widget<Text>(find.text('Copying 48%'));
    final InkColors colors = tester.element(find.text('Copying 48%')).inkColors;
    expect(status.style?.color, colors.accent);
  });

  testWidgets('视频复制中：状态行「Copying 48%」+ 进度条，图区不走 VideoNodeBody、不写「等待生成」', (tester) async {
    await pump(
      tester,
      _imported('v1', type: CanvasNodeType.video, name: '船桨.mp4'),
      progress: <String, double>{'v1': 0.48},
    );

    expect(find.byType(VideoNodeBody), findsNothing);
    expect(find.text('Waiting for generation'), findsNothing);
    expect(find.text('Copying 48%'), findsOneWidget);
    expect(find.byKey(NodeCard.importProgressKey), findsOneWidget);
  });

  testWidgets('进度表里是别的节点：本卡不画进度', (tester) async {
    await pump(tester, _imported('n1'), progress: <String, double>{'other': 0.3});

    expect(find.textContaining('Copying'), findsNothing);
    expect(find.byKey(NodeCard.importProgressKey), findsNothing);
  });

  testWidgets('图片导入完成：状态行「Imported」（fg4）+ 右侧「1920×1080」，无进度条', (tester) async {
    await pump(
      tester,
      _imported('n1', extra: <String, Object?>{
        'image_url': 'imports/u1.jpg',
        'width': 1920,
        'height': 1080,
      }),
    );

    expect(find.text('Imported'), findsOneWidget);
    expect(find.text('1920×1080'), findsOneWidget);
    expect(find.byKey(NodeCard.importProgressKey), findsNothing);
    expect(find.text('Done'), findsNothing);

    final Text status = tester.widget<Text>(find.text('Imported'));
    final InkColors colors = tester.element(find.text('Imported')).inkColors;
    expect(status.style?.color, colors.fg4);
  });

  testWidgets('视频导入完成：「Imported」+ 宽高，不写时长', (tester) async {
    await pump(
      tester,
      _imported('v1', type: CanvasNodeType.video, name: '船桨.mp4', extra: <String, Object?>{
        'video_url': 'imports/u1.mp4',
        'thumbnail_url': 'imports/u1.jpg',
        'duration_ms': 5000,
        'width': 1280,
        'height': 720,
      }),
    );

    expect(find.text('Imported'), findsOneWidget);
    // meta 恰好是宽高这一串：没有拼上时长。
    expect(find.text('1280×720'), findsOneWidget);
  });

  testWidgets('导入完成但没有宽高：右侧 meta 留空', (tester) async {
    await pump(
      tester,
      _imported('n1', extra: <String, Object?>{'image_url': 'imports/u1.webp'}),
    );

    expect(find.text('Imported'), findsOneWidget);
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('非导入产物：状态行不变（Done），进度表里有它也不画进度', (tester) async {
    const CanvasNode plain = CanvasNode(
      id: 'r1',
      label: 'R',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: _cid,
      sourceNodeId: 'cfg',
      typeConfig: <String, Object?>{
        'image_url': 'images/r1.png',
        'width': 1920,
        'height': 1080,
      },
    );
    await pump(tester, plain, progress: <String, double>{'r1': 0.5});

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Imported'), findsNothing);
    expect(find.textContaining('Copying'), findsNothing);
    expect(find.text('1920×1080'), findsNothing);
    expect(find.byKey(NodeCard.importProgressKey), findsNothing);
  });
}
