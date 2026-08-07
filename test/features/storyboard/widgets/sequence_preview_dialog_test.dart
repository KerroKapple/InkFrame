// SB-6 序列预览播放器的 widget 测试。
//
// media_kit 真播放需要 GPU / 原生层，测试里一律走 fake handle。重点钉三件：
//   ① **handle 必须被 dispose**（卡面点名 media_kit 泄漏高发）
//   ② 纯图片序列**不该**唤起 media_kit（不 create handle）
//   ③ 推进语义：图片按时长走定时器、暂停真的停、末镜不越界

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/video_player.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/video_player_service.dart';
import 'package:inkframe/features/storyboard/models/sequence_shot.dart';
import 'package:inkframe/features/storyboard/widgets/sequence_preview_dialog.dart';

import '../../../_harness/test_app.dart';

class _FakeHandle implements VideoPlayerHandle {
  final List<String> opened = <String>[];
  int disposeCount = 0;
  int playCount = 0;
  int pauseCount = 0;

  final StreamController<Duration> _pos =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _dur =
      StreamController<Duration?>.broadcast();

  void emitDuration(Duration d) => _dur.add(d);
  void emitPosition(Duration d) => _pos.add(d);

  @override
  Future<void> open(String filePath) async => opened.add(filePath);

  @override
  Future<void> play() async => playCount++;

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> seek(Duration at) async {}

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

  /// 非 media_kit Player → 对话框不会去构造 VideoController。
  @override
  Object get rawPlayer => Object();
}

class _FakeVideoPlayerService implements VideoPlayerService {
  int createCount = 0;
  final List<_FakeHandle> handles = <_FakeHandle>[];

  @override
  VideoPlayerHandle create() {
    createCount++;
    final h = _FakeHandle();
    handles.add(h);
    return h;
  }
}

class _FakeResolver implements FileResolverService {
  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      File('Z:/fake/$projectId/$relativePath');

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('Z:/fake/$projectId/canvases/$canvasId/$relativePath');

  @override
  String toRelative({
    required String projectId,
    required String canvasId,
    required File source,
  }) =>
      throw UnimplementedError();

  @override
  Directory canvasRoot({required String projectId, required String canvasId}) =>
      throw UnimplementedError();
}

SequenceShot _image(String id, {int ms = 3000}) => SequenceShot(
      nodeId: id,
      kind: SequenceArtifactKind.image,
      durationMs: ms,
      canvasId: 'c1',
      relativePath: '$id.png',
    );

SequenceShot _placeholder(String id, {int ms = 3000, String? notes}) =>
    SequenceShot(
      nodeId: id,
      kind: SequenceArtifactKind.none,
      durationMs: ms,
      notes: notes ?? 'notes for $id',
    );

SequenceShot _video(String id, {int ms = 4000}) => SequenceShot(
      nodeId: id,
      kind: SequenceArtifactKind.video,
      durationMs: ms,
      canvasId: 'c1',
      relativePath: '$id.mp4',
    );

void main() {
  late _FakeVideoPlayerService player;

  setUp(() => player = _FakeVideoPlayerService());

  Future<void> pump(WidgetTester tester, List<SequenceShot> shots) async {
    await pumpInkApp(
      tester,
      Scaffold(
        body: SequencePreviewContent(projectId: 'p1', shots: shots),
      ),
      overrides: <Override>[
        videoPlayerServiceProvider.overrideWithValue(player),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
      ],
    );
    await tester.pump(); // 让 postFrameCallback 里的 _enterShot(0) 跑起来
  }

  testWidgets('空清单 → 空态文案,不建 handle', (tester) async {
    await pump(tester, const <SequenceShot>[]);

    expect(find.text('Nothing to preview yet'), findsOneWidget);
    expect(player.createCount, 0);
  });

  testWidgets('纯图片序列不唤起 media_kit——一个 handle 都不建', (tester) async {
    await pump(tester, [_image('a'), _placeholder('b')]);

    expect(player.createCount, 0, reason: '没有视频镜就不该 create');
    // 收尾：定时器还挂着，pump 到底避免 pending timer 报错。
    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });

  testWidgets('有视频镜 → 只建一个 handle,关闭时被 dispose（卡面点名的泄漏点）',
      (tester) async {
    await pump(tester, [_image('a'), _video('v'), _image('c')]);

    expect(player.createCount, 1, reason: '整个对话框只 create 一次');
    final handle = player.handles.single;
    expect(handle.disposeCount, 0);

    // 拆掉 widget（等价于关对话框）。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(handle.disposeCount, 1, reason: 'dispose 必须调 handle.dispose');
  });

  testWidgets('图片镜按 durationMs 自动推进到下一镜', (tester) async {
    await pump(tester, [
      _placeholder('a', ms: 1000, notes: 'first'),
      _placeholder('b', ms: 1000, notes: 'second'),
    ]);

    expect(find.text('first'), findsOneWidget);
    expect(find.text('Shot 1 of 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('second'), findsOneWidget);
    expect(find.text('Shot 2 of 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('末镜播完停住,不越界', (tester) async {
    await pump(tester, [_placeholder('only', ms: 500)]);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Shot 1 of 1'), findsOneWidget);
    // 停在暂停态：播放键回到 play。
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('暂停后不再自动推进', (tester) async {
    await pump(tester, [
      _placeholder('a', ms: 1000, notes: 'first'),
      _placeholder('b', ms: 1000, notes: 'second'),
    ]);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('first'), findsOneWidget, reason: '暂停期间不该翻镜');
  });

  testWidgets('前后镜按钮：首镜禁用上一镜,末镜禁用下一镜', (tester) async {
    await pump(tester, [_placeholder('a'), _placeholder('b')]);

    IconButton btn(IconData icon) =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

    expect(btn(Icons.skip_previous).onPressed, isNull);
    expect(btn(Icons.skip_next).onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();

    expect(btn(Icons.skip_previous).onPressed, isNotNull);
    expect(btn(Icons.skip_next).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });

  testWidgets('视频镜：open 目标文件并起播', (tester) async {
    await pump(tester, [_video('v', ms: 2000)]);
    await tester.pump();

    final handle = player.handles.single;
    expect(handle.opened, hasLength(1));
    expect(handle.opened.single.replaceAll('\\', '/'),
        'Z:/fake/p1/canvases/c1/v.mp4');
    expect(handle.playCount, 1);

    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });

  testWidgets('视频镜：position 到达 duration 即推进,不等兜底定时器',
      (tester) async {
    await pump(tester, [_video('v', ms: 60000), _placeholder('after')]);
    await tester.pump();

    final handle = player.handles.single;
    handle.emitDuration(const Duration(seconds: 2));
    await tester.pump();
    handle.emitPosition(const Duration(seconds: 2));
    await tester.pump();

    // 兜底定时器是 60s+1.5s，这里只走了几个 pump——推进只可能来自 position。
    expect(find.text('notes for after'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });

  testWidgets('视频镜：拿不到 duration 时兜底定时器接管,不永远卡住',
      (tester) async {
    await pump(tester, [_video('v', ms: 1000), _placeholder('after')]);
    await tester.pump();

    // 从不 emitDuration——模拟播放器打开了但时长拿不到。
    await tester.pump(const Duration(milliseconds: 2600)); // 1000 + 1500 余量
    expect(find.text('notes for after'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });

  testWidgets('「从头播放」回到第一镜并恢复播放', (tester) async {
    await pump(tester, [_placeholder('a'), _placeholder('b')]);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(find.text('Shot 2 of 2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.replay));
    await tester.pump();

    expect(find.text('Shot 1 of 2'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget, reason: '恢复播放态');

    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });

  testWidgets('无产物镜显示 notes 占位', (tester) async {
    await pump(tester, [_placeholder('a', notes: 'dawn ridge, wide shot')]);

    expect(find.text('Not generated yet'), findsOneWidget);
    expect(find.text('dawn ridge, wide shot'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
  });
}
