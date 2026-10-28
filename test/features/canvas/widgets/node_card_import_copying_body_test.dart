// 导入卡复制中的图区：壳还没有 url，图区不能再画「等待生成」（导入的媒体不是生成出来的，
// 且与状态行「复制中 N%」矛盾）——图、视频两种卡都只留底色 + 进度条，不走
// _ResultBody / VideoNodeBody。复制完（不在进度表里）照常走原来的图区。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/import_keys.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/media_import_controller.dart';
import 'package:inkframe/features/canvas/widgets/node_card.dart';
import 'package:inkframe/features/canvas/widgets/video_node_body.dart';

import '../../../_harness/fake_canvas.dart' show StubFileResolver;
import '../../../_harness/test_app.dart';

const String _cid = 'cv';
const String _waiting = 'Waiting for generation';

/// 进度表钉成固定值的导入控制器。
class _FixedProgress extends MediaImportController {
  _FixedProgress(this.value);
  final Map<String, double> value;

  @override
  Map<String, double> build(String canvasId) => value;
}

CanvasNode _shell(String id, CanvasNodeType type, String name) => CanvasNode(
      id: id,
      label: name,
      type: type,
      role: NodeRole.result,
      canvasId: _cid,
      typeConfig: <String, Object?>{
        ImportKeys.origin: ImportKeys.originImport,
        ImportKeys.originalName: name,
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

  testWidgets('图片复制中：图区不写「等待生成」，只有进度条', (tester) async {
    await pump(
      tester,
      _shell('n1', CanvasNodeType.image, '雾江.jpg'),
      progress: <String, double>{'n1': 0.48},
    );

    expect(find.text('Copying 48%'), findsOneWidget, reason: '前提：在复制中');
    expect(find.text(_waiting), findsNothing);
    expect(find.byKey(NodeCard.importProgressKey), findsOneWidget);
  });

  testWidgets('视频复制中：不走 VideoNodeBody，图区不写「等待生成」，只有进度条', (tester) async {
    await pump(
      tester,
      _shell('v1', CanvasNodeType.video, '船桨.mp4'),
      progress: <String, double>{'v1': 0.48},
    );

    expect(find.text('Copying 48%'), findsOneWidget, reason: '前提：在复制中');
    expect(find.byType(VideoNodeBody), findsNothing);
    expect(find.text(_waiting), findsNothing);
    expect(find.byKey(NodeCard.importProgressKey), findsOneWidget);
  });

  testWidgets('不在进度表里的视频壳：照常走 VideoNodeBody（只在复制中换图区）', (tester) async {
    await pump(tester, _shell('v1', CanvasNodeType.video, '船桨.mp4'));

    expect(find.byType(VideoNodeBody), findsOneWidget);
    expect(find.byKey(NodeCard.importProgressKey), findsNothing);
  });
}
