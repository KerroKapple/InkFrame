// VideoResultInspector（演示 F2）：选中视频产物时检查器不再留空——
//   - 预览：首帧缩略（type_config.thumbnail_url）；
//   - 生成参数：来源 config 的供应商 / 提示词 + 产物探针写的尺寸 / 时长；
//   - 动作：定位来源节点可点；视频文件不在 ⇒ 播放置灰；不在叙事链上 ⇒ 在序列中定位置灰。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/playable_video_path.dart';
import 'package:inkframe/features/canvas/widgets/result_inspector_parts.dart';
import 'package:inkframe/features/canvas/widgets/video_result_inspector.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/primitives/ink_activatable.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/test_app.dart';

const String _canvasId = 'cv1';

/// 解析成一个不存在的文件：playableVideoPathProvider 判「文件不在」⇒ 不可播。
class _MissingFileResolver implements FileResolverService {
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('__missing__/$relativePath');

  @override
  File resolveInProject({required String projectId, required String relativePath}) =>
      File('__missing__/$relativePath');

  @override
  String toRelative({required String projectId, required String canvasId, required File source}) =>
      source.path;

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      Directory('__missing__');
}

void main() {
  late InMemoryNodeRepository nodeRepo;
  late CanvasNode result;

  const Map<String, Object?> resultConfig = <String, Object?>{
    'video_url': 'videos/j1.mp4',
    'thumbnail_url': 'videos/j1.jpg',
    'width': 1280,
    'height': 720,
    'duration_ms': 5040,
  };

  setUp(() async {
    nodeRepo = InMemoryNodeRepository();
    final String sourceId = await nodeRepo.create(
      canvasId: _canvasId,
      type: 'video',
      nodeRole: 'config',
      typeConfig: const <String, Object?>{
        'provider_id': 'test-provider',
        'prompt': '  a fox runs through snow  ',
      },
    );
    final String resultId = await nodeRepo.create(
      canvasId: _canvasId,
      type: 'video',
      nodeRole: 'result',
      sourceNodeId: sourceId,
      typeConfig: resultConfig,
    );
    result = CanvasNode(
      id: resultId,
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: _canvasId,
      sourceNodeId: sourceId,
      typeConfig: resultConfig,
    );
  });

  Future<void> pump(WidgetTester tester, {List<Override> extra = const <Override>[]}) async {
    await pumpInkApp(
      tester,
      Scaffold(body: SingleChildScrollView(child: VideoResultInspector(node: result))),
      overrides: <Override>[
        nodeRepositoryProvider.overrideWith((ref) async => nodeRepo),
        edgeRepositoryProvider.overrideWith((ref) async => InMemoryEdgeRepository()),
        fileResolverServiceProvider.overrideWithValue(_MissingFileResolver()),
        ...extra,
      ],
      surfaceSize: const Size(301, 900),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('预览走首帧缩略图', (tester) async {
    await pump(tester);
    expect(find.byKey(ResultInspectorKeys.preview), findsOneWidget);
    final ResultFileImage image = tester.widget<ResultFileImage>(find.byType(ResultFileImage));
    expect(image.relativePath, 'videos/j1.jpg');
    expect(tester.takeException(), isNull);
  });

  testWidgets('生成参数：来源 config 的供应商 / 提示词 + 产物的尺寸 / 时长', (tester) async {
    await pump(tester);
    expect(find.byKey(ResultInspectorKeys.params), findsOneWidget);
    expect(find.text('test-provider'), findsOneWidget);
    expect(find.text('1280×720'), findsOneWidget);
    expect(find.text('00:00:05'), findsOneWidget);
    final Text prompt = tester.widget<Text>(find.byKey(ResultInspectorKeys.prompt));
    expect(prompt.data, 'a fox runs through snow');
  });

  testWidgets('动作：定位来源可点；文件不在 ⇒ 播放置灰；不在链上 ⇒ 在序列中定位置灰', (tester) async {
    await pump(tester);
    InkActivatable act(Key key) => tester.widget<InkActivatable>(
          find.descendant(of: find.byKey(key), matching: find.byType(InkActivatable)).first,
        );
    expect(act(ResultInspectorKeys.locateSource).onTap, isNotNull);
    expect(act(ResultInspectorKeys.play).onTap, isNull);
    expect(act(ResultInspectorKeys.viewInSequence).onTap, isNull);
  });

  // tc-set-current：「设为当前」排动作行最前（在「播放」之前）；名下只有它一张 ⇒ 它就是当前 ⇒ 打勾置灰。
  testWidgets('动作行第一个是「设为当前」；已是当前时置灰', (tester) async {
    await pump(tester);
    final Finder setCurrent = find.byKey(ResultInspectorKeys.setCurrent);
    expect(setCurrent, findsOneWidget);
    for (final Key other in <Key>[
      ResultInspectorKeys.play,
      ResultInspectorKeys.locateSource,
      ResultInspectorKeys.viewInSequence,
    ]) {
      final Offset a = tester.getTopLeft(setCurrent);
      final Offset b = tester.getTopLeft(find.byKey(other));
      expect(a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx), isTrue, reason: '「设为当前」排在 $other 之前');
    }
    final InkActivatable act =
        tester.widget<InkActivatable>(find.descendant(of: setCurrent, matching: find.byType(InkActivatable)).first);
    expect(act.onTap, isNull, reason: '已是当前：置灰');
    expect(
      find.descendant(
        of: setCurrent,
        matching: find.byWidgetPredicate((Widget w) => w is InkIcon && w.glyph == InkGlyph.success),
      ),
      findsOneWidget,
      reason: '已是当前：打勾',
    );
  });

  testWidgets('名下还有更新的 take ⇒「设为当前」可点', (tester) async {
    await nodeRepo.update(result.id, <String, Object?>{'created_at': DateTime.utc(2026, 5, 1)});
    final String newer = await nodeRepo.create(
      canvasId: _canvasId,
      type: 'video',
      nodeRole: 'result',
      sourceNodeId: result.sourceNodeId,
      typeConfig: const <String, Object?>{'video_url': 'videos/j2.mp4'},
    );
    await nodeRepo.update(newer, <String, Object?>{'created_at': DateTime.utc(2026, 5, 2)});
    await pump(tester);
    final InkActivatable act = tester.widget<InkActivatable>(
      find.descendant(of: find.byKey(ResultInspectorKeys.setCurrent), matching: find.byType(InkActivatable)).first,
    );
    expect(act.onTap, isNotNull);
  });

  testWidgets('视频文件在 ⇒ 播放可点（预览与动作行同一个回调）', (tester) async {
    await pump(tester, extra: <Override>[
      playableVideoPathProvider.overrideWith((ref, node) => '/videos/j1.mp4'),
    ]);
    InkActivatable act(Key key) => tester.widget<InkActivatable>(
          find.descendant(of: find.byKey(key), matching: find.byType(InkActivatable)).first,
        );
    expect(act(ResultInspectorKeys.play).onTap, isNotNull);
  });

  testWidgets('还没出片 ⇒ 预览是占位，不去解析文件', (tester) async {
    result = CanvasNode(
      id: result.id,
      label: '',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: _canvasId,
      sourceNodeId: result.sourceNodeId,
    );
    await pump(tester);
    expect(find.byKey(ResultInspectorKeys.preview), findsOneWidget);
    expect(find.byType(ResultFileImage), findsNothing);
    expect(find.byType(ResultPreviewPlaceholder), findsOneWidget);
  });
}
