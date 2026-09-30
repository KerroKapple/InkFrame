// 节目监视器（P2）的 widget 测试。播放逻辑从 sequence_preview_dialog 搬来，原测试的三条硬约束
// 照钉：① handle 必须 dispose；② 纯图片序列不唤起 media_kit；③ 推进语义。
// 再加 P2 拍板的三条：④ 不自动播放；⑤ paused 变 true 即停、回来不续播；⑥ 外部 seek 走 token，
// 自报进度不回环。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/video_player.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/video_player_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/sequence/models/sequence_lens.dart';
import 'package:inkframe/features/sequence/providers/sequence_playhead.dart';
import 'package:inkframe/features/sequence/widgets/sequence_monitor.dart';
import 'package:inkframe/features/storyboard/models/sequence_shot.dart';

import '../../../_harness/test_app.dart';

class _FakeHandle implements VideoPlayerHandle {
  final List<String> opened = <String>[];
  final List<Duration> seeks = <Duration>[];
  int disposeCount = 0;
  int playCount = 0;
  int pauseCount = 0;

  final StreamController<Duration> _pos = StreamController<Duration>.broadcast();
  final StreamController<Duration?> _dur = StreamController<Duration?>.broadcast();

  void emitDuration(Duration d) => _dur.add(d);
  void emitPosition(Duration d) => _pos.add(d);

  @override
  Future<void> open(String filePath) async => opened.add(filePath);
  @override
  Future<void> play() async => playCount++;
  @override
  Future<void> pause() async => pauseCount++;
  @override
  Future<void> seek(Duration at) async => seeks.add(at);
  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<Duration?> get durationStream => _dur.stream;
  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();
  @override
  Future<void> dispose() async {
    disposeCount++;
    await _pos.close();
    await _dur.close();
  }

  /// 非 media_kit Player → 监视器不会去构造 VideoController。
  @override
  Object get rawPlayer => Object();
}

class _FakeVideoPlayerService implements VideoPlayerService {
  int createCount = 0;
  final List<_FakeHandle> handles = <_FakeHandle>[];
  @override
  VideoPlayerHandle create() {
    createCount++;
    final _FakeHandle h = _FakeHandle();
    handles.add(h);
    return h;
  }
}

class _FakeResolver implements FileResolverService {
  @override
  File resolveInProject({required String projectId, required String relativePath}) => File('Z:/fake/$projectId/$relativePath');
  @override
  File resolve({required String projectId, required String canvasId, required String relativePath}) =>
      File('Z:/fake/$projectId/canvases/$canvasId/$relativePath');
  @override
  String toRelative({required String projectId, required String canvasId, required File source}) => throw UnimplementedError();
  @override
  Directory canvasRoot({required String projectId, required String canvasId}) => throw UnimplementedError();
}

class _EmptyNodes extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => const <CanvasNode>[];
}

/// 叠字用：shot 折叠借了 cfg 的产物（result 的 image_url == 镜的 relativePath），cfg 带运镜 + 景别。
class _OverlayNodes extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => const <CanvasNode>[
        CanvasNode(id: 'a', label: 'a', type: CanvasNodeType.shot, canvasId: 'c1'),
        CanvasNode(
          id: 'cfg',
          label: 'cfg',
          type: CanvasNodeType.image,
          canvasId: 'c1',
          typeConfig: <String, Object?>{'camera': 'pushIn', 'shot_size': 'mediumShot'},
        ),
        CanvasNode(
          id: 'r',
          label: '',
          type: CanvasNodeType.image,
          role: NodeRole.result,
          canvasId: 'c1',
          sourceNodeId: 'cfg',
          typeConfig: <String, Object?>{'image_url': 'a.png'},
        ),
      ];
}

SequenceShot _image(String id, {int ms = 3000}) =>
    SequenceShot(nodeId: id, kind: SequenceArtifactKind.image, durationMs: ms, canvasId: 'c1', relativePath: '$id.png', label: id);

SequenceShot _placeholder(String id, {int ms = 3000, String? notes}) =>
    SequenceShot(nodeId: id, kind: SequenceArtifactKind.none, durationMs: ms, notes: notes ?? 'notes for $id', label: id);

SequenceShot _video(String id, {int ms = 4000}) =>
    SequenceShot(nodeId: id, kind: SequenceArtifactKind.video, durationMs: ms, canvasId: 'c1', relativePath: '$id.mp4', label: id);

SequenceLens _lens(List<SequenceShot> shots) {
  final List<int> starts = <int>[];
  int acc = 0;
  for (final SequenceShot s in shots) {
    starts.add(acc);
    acc += s.durationMs;
  }
  return SequenceLens(shots: shots, startsMs: starts, totalMs: acc, markers: const <SceneMarker>[], unchainedCount: 0);
}

/// 宿主：paused 由外部 ValueNotifier 驱动，模拟外壳按 isTabVisible 逐帧下传。
class _Host extends StatelessWidget {
  const _Host({required this.lens, required this.paused});
  final SequenceLens lens;
  final ValueNotifier<bool> paused;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: paused,
        builder: (_, bool p, _) => SequenceMonitor(canvasId: 'c1', projectId: 'p1', lens: lens, paused: p),
      );
}

void main() {
  late _FakeVideoPlayerService player;
  late ValueNotifier<bool> paused;

  setUp(() {
    player = _FakeVideoPlayerService();
    paused = ValueNotifier<bool>(false);
  });
  tearDown(() => paused.dispose());

  Future<ProviderContainer> pump(WidgetTester tester, List<SequenceShot> shots) async {
    await pumpInkApp(
      tester,
      Scaffold(body: _Host(lens: _lens(shots), paused: paused)),
      surfaceSize: const Size(900, 700),
      overrides: <Override>[
        videoPlayerServiceProvider.overrideWithValue(player),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
        canvasNodesControllerProvider.overrideWith(_EmptyNodes.new),
      ],
    );
    await tester.pump(); // postFrameCallback 里的 _enterShot(0)
    return ProviderScope.containerOf(tester.element(find.byType(SequenceMonitor)));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('空清单 → 空态文案，不建 handle', (tester) async {
    await pump(tester, const <SequenceShot>[]);
    expect(find.text('Nothing to preview yet'), findsOneWidget);
    expect(player.createCount, 0);
  });

  testWidgets('拍板④：不自动播放——挂上 3 秒仍停在首镜，播放键是 play', (tester) async {
    await pump(tester, <SequenceShot>[_placeholder('a', ms: 1000, notes: 'first'), _placeholder('b', ms: 1000, notes: 'second')]);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
  });

  testWidgets('纯图片序列不唤起 media_kit——一个 handle 都不建', (tester) async {
    await pump(tester, <SequenceShot>[_image('a'), _placeholder('b')]);
    expect(player.createCount, 0);
  });

  testWidgets('有视频镜 → 只建一个 handle，卸载时 dispose', (tester) async {
    await pump(tester, <SequenceShot>[_image('a'), _video('v'), _image('c')]);
    expect(player.createCount, 1);
    final _FakeHandle h = player.handles.single;
    expect(h.disposeCount, 0);

    await unmount(tester);
    expect(h.disposeCount, 1);
  });

  testWidgets('按播放：图片镜按 durationMs 推进到下一镜，并 report 到播放头（token 不动）', (tester) async {
    final ProviderContainer c = await pump(tester, <SequenceShot>[
      _placeholder('a', ms: 1000, notes: 'first'),
      _placeholder('b', ms: 1000, notes: 'second'),
    ]);

    await tester.tap(find.byKey(SequenceMonitor.playPauseKey));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('second'), findsOneWidget);
    final SequencePlayhead head = c.read(sequencePlayheadProvider('c1'));
    expect(head.index, 1);
    expect(head.seekToken, 0, reason: '监视器自报进度不应自增 seekToken');

    await unmount(tester);
  });

  testWidgets('末镜播完停住不越界，播放键回到 play', (tester) async {
    await pump(tester, <SequenceShot>[_placeholder('only', ms: 500)]);
    await tester.tap(find.byKey(SequenceMonitor.playPauseKey));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('拍板⑤：paused 变 true 立即停；变回 false 不续播', (tester) async {
    await pump(tester, <SequenceShot>[
      _placeholder('a', ms: 1000, notes: 'first'),
      _placeholder('b', ms: 1000, notes: 'second'),
    ]);
    await tester.tap(find.byKey(SequenceMonitor.playPauseKey));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);

    paused.value = true; // 切走标签 / 浮层盖住
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget, reason: '离台即停');

    paused.value = false; // 回来
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byIcon(Icons.play_arrow), findsOneWidget, reason: '回来不续播');
    expect(find.text('first'), findsOneWidget, reason: '停在离台时那一镜');
  });

  testWidgets('视频镜：paused 变 true → handle.pause 被调', (tester) async {
    await pump(tester, <SequenceShot>[_video('v', ms: 60000)]);
    await tester.pump();
    final _FakeHandle h = player.handles.single;
    expect(h.opened.single.replaceAll('\\', '/'), 'Z:/fake/p1/canvases/c1/v.mp4');
    expect(h.playCount, 0, reason: 'open 后不自动 play');

    await tester.tap(find.byKey(SequenceMonitor.playPauseKey));
    await tester.pump();
    expect(h.playCount, 1);
    final int pausesBefore = h.pauseCount;

    paused.value = true;
    await tester.pump();
    expect(h.pauseCount, pausesBefore + 1);

    await unmount(tester);
  });

  testWidgets('拍板⑥：外部 selectShot 换镜；同镜内 seekGlobal 只动播放器位置', (tester) async {
    final ProviderContainer c = await pump(tester, <SequenceShot>[
      _placeholder('a', ms: 1000, notes: 'first'),
      _video('v', ms: 60000),
    ]);
    await tester.pump();

    c.read(sequencePlayheadProvider('c1').notifier).selectShot(1);
    await tester.pump();
    await tester.pump();
    expect(find.text('first'), findsNothing);
    final _FakeHandle h = player.handles.single;
    expect(h.opened, hasLength(1));

    // 同一镜内跳 2.5s：不重开文件，只 seek。
    c.read(sequencePlayheadProvider('c1').notifier).seekGlobal(1000 + 2500, _lens(<SequenceShot>[_placeholder('a', ms: 1000), _video('v', ms: 60000)]));
    await tester.pump();
    expect(h.opened, hasLength(1), reason: '同镜 seek 不重开');
    expect(h.seeks, contains(const Duration(milliseconds: 2500)));

    await unmount(tester);
  });

  testWidgets('视频镜：position 到达 duration 即推进，不等兜底定时器', (tester) async {
    await pump(tester, <SequenceShot>[_video('v', ms: 60000), _placeholder('after', notes: 'after-notes')]);
    await tester.pump();
    await tester.tap(find.byKey(SequenceMonitor.playPauseKey));
    await tester.pump();

    final _FakeHandle h = player.handles.single;
    h.emitDuration(const Duration(seconds: 2));
    await tester.pump();
    h.emitPosition(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();

    expect(find.text('after-notes'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('前后镜键：首镜 prev 无效、next 走播放头换镜', (tester) async {
    final ProviderContainer c = await pump(tester, <SequenceShot>[
      _placeholder('a', notes: 'first'),
      _placeholder('b', notes: 'second'),
    ]);

    await tester.tap(find.byKey(SequenceMonitor.prevKey));
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    await tester.tap(find.byKey(SequenceMonitor.nextKey));
    await tester.pump();
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
    expect(c.read(sequencePlayheadProvider('c1')).seekToken, 1);
  });

  testWidgets('叠字：序号 · 时码 src；无节点信息时不出运镜 / 景别 / 模型段', (tester) async {
    await pump(tester, <SequenceShot>[_placeholder('a', ms: 2000)]);
    expect(find.text('001'), findsOneWidget);
    expect(find.text('src 00:00:00:00 / 00:00:02:00'), findsOneWidget);
  });

  testWidgets('叠字（P3）：运镜与景别取自产物的 config 节点——序号 · 运镜 · 景别', (tester) async {
    await pumpInkApp(
      tester,
      Scaffold(body: _Host(lens: _lens(<SequenceShot>[_image('a')]), paused: paused)),
      surfaceSize: const Size(900, 700),
      overrides: <Override>[
        videoPlayerServiceProvider.overrideWithValue(player),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
        canvasNodesControllerProvider.overrideWith(_OverlayNodes.new),
      ],
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('001 · Dolly in · Medium shot MS'), findsOneWidget);
  });
}
