// ExportController —— 路径根换算（canvas 相对 → 项目相对）+ 顺序透传 + 状态机。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/video_export_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/export/providers/export_controller.dart';

class _FakeVideoExportService implements VideoExportService {
  _FakeVideoExportService({this.error});

  final Object? error;
  final String result = 'exports/out.mp4';

  String? lastProjectId;
  List<String>? lastInputs;
  String? lastOutputBaseName;
  int? lastTotalDurationMs;
  void Function(double progress)? lastOnProgress;
  ExportCancelToken? lastToken;
  Completer<String>? gate;

  @override
  Future<String> concat({
    required String projectId,
    required List<String> inputRelativePaths,
    String? outputBaseName,
    int? totalDurationMs,
    void Function(double progress)? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    lastProjectId = projectId;
    lastInputs = inputRelativePaths;
    lastOutputBaseName = outputBaseName;
    lastTotalDurationMs = totalDurationMs;
    lastOnProgress = onProgress;
    lastToken = cancelToken;
    final g = gate;
    if (g != null) return g.future;
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

CanvasNode _videoResult(
  String id, {
  String canvasId = 'c1',
  String? videoUrl = 'videos/$_kDefault',
  int? durationMs,
}) =>
    CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: canvasId,
      sourceNodeId: 'cfg-$id',
      typeConfig: <String, Object?>{
        'video_url': ?videoUrl,
        if (durationMs != null) 'duration_ms': durationMs,
      },
    );

const _kDefault = 'a.mp4';

(ProviderContainer, _FakeVideoExportService) _make({
  Object? error,
  Completer<String>? gate,
}) {
  final fake = _FakeVideoExportService(error: error)..gate = gate;
  final container = ProviderContainer(
    overrides: <Override>[
      videoExportServiceProvider.overrideWithValue(fake),
    ],
  );
  addTearDown(container.dispose);
  container.listen(exportControllerProvider, (_, _) {});
  return (container, fake);
}

void main() {
  test('路径换算：video_url 画布相对 → 补 canvases/<canvasId>/ 前缀', () async {
    final (container, fake) = _make();
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[
        _videoResult('n1', canvasId: 'c1', videoUrl: 'videos/a.mp4'),
        _videoResult('n2', canvasId: 'c2', videoUrl: 'videos/b.mp4'),
      ],
    );

    expect(fake.lastProjectId, 'p1');
    expect(fake.lastInputs, <String>[
      'canvases/c1/videos/a.mp4',
      'canvases/c2/videos/b.mp4',
    ]);
    expect(fake.lastOutputBaseName, isNull);
  });

  test('顺序透传：入参顺序即 concat 顺序 + outputBaseName 原样透传', () async {
    final (container, fake) = _make();
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[
        _videoResult('n3', videoUrl: 'videos/z.mp4'),
        _videoResult('n1', videoUrl: 'videos/a.mp4'),
        _videoResult('n2', videoUrl: 'videos/m.mp4'),
      ],
      outputBaseName: 'my_cut',
    );

    expect(fake.lastInputs, <String>[
      'canvases/c1/videos/z.mp4',
      'canvases/c1/videos/a.mp4',
      'canvases/c1/videos/m.mp4',
    ]);
    expect(fake.lastOutputBaseName, 'my_cut');
  });

  test('缺 videoUrl / canvasId 的节点不进输入列表（防御）', () async {
    final (container, fake) = _make();
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[
        _videoResult('n1', videoUrl: 'videos/a.mp4'),
        _videoResult('n2', videoUrl: null),
        const CanvasNode(
          id: 'n3',
          label: 'n3',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          sourceNodeId: 'cfg-n3',
          typeConfig: <String, Object?>{'video_url': 'videos/c.mp4'},
        ),
      ],
    );

    expect(fake.lastInputs, <String>['canvases/c1/videos/a.mp4']);
  });

  test('成功 → ExportVideoSuccess 携带导出相对路径', () async {
    final (container, _) = _make();
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1')],
    );

    final state = container.read(exportControllerProvider);
    expect(state, isA<ExportVideoSuccess>());
    expect((state as ExportVideoSuccess).relativePath, 'exports/out.mp4');
  });

  test('LocalIOError（如 ffmpeg_not_found）→ ExportVideoFailure 保留原错误', () async {
    const err = LocalIOError(
      extra: <String, Object?>{'reason': 'ffmpeg_not_found'},
    );
    final (container, _) = _make(error: err);
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1')],
    );

    final state = container.read(exportControllerProvider);
    expect(state, isA<ExportVideoFailure>());
    expect((state as ExportVideoFailure).error, same(err));
  });

  test('ProviderError(empty_input_list) → ExportVideoFailure', () async {
    const err = ProviderError(
      code: InkErrorCode.invalidParameter,
      extra: <String, Object?>{'reason': 'empty_input_list'},
    );
    final (container, _) = _make(error: err);
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: const <CanvasNode>[],
    );

    final state = container.read(exportControllerProvider);
    expect(state, isA<ExportVideoFailure>());
    expect((state as ExportVideoFailure).error, same(err));
  });

  test('PathSecurityError（防御分支）→ 翻译为 invalidParameter 失败态', () async {
    final (container, _) = _make(error: PathSecurityError('bad name'));
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1')],
      outputBaseName: 'a/b',
    );

    final state = container.read(exportControllerProvider);
    expect(state, isA<ExportVideoFailure>());
    final error = (state as ExportVideoFailure).error;
    expect(error.code, InkErrorCode.invalidParameter);
    expect(error.cause, isA<PathSecurityError>());
  });

  test('busy 态：concat 未返回期间为 ExportVideoBusy，完成后收敛', () async {
    final gate = Completer<String>();
    final (container, _) = _make(gate: gate);
    final future = container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1')],
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(exportControllerProvider), isA<ExportVideoBusy>());

    gate.complete('exports/gated.mp4');
    await future;
    final state = container.read(exportControllerProvider);
    expect(state, isA<ExportVideoSuccess>());
    expect((state as ExportVideoSuccess).relativePath, 'exports/gated.mp4');
  });

  test('keepAlive：busy 中移除全部 listener，状态机仍走完收敛到 success', () async {
    final gate = Completer<String>();
    final fake = _FakeVideoExportService()..gate = gate;
    final container = ProviderContainer(
      overrides: <Override>[
        videoExportServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(exportControllerProvider, (_, _) {});

    final future = container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1')],
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(exportControllerProvider), isA<ExportVideoBusy>());

    // 对话框中途关闭：无任何 listener，autoDispose 回收窗口打开。
    sub.close();
    await Future<void>.delayed(Duration.zero);

    gate.complete('exports/kept.mp4');
    await future;

    // 若 ref.keepAlive() 缺失，notifier 已被回收，走不到 success。
    final state = container.read(exportControllerProvider);
    expect(state, isA<ExportVideoSuccess>());
    expect((state as ExportVideoSuccess).relativePath, 'exports/kept.mp4');
  });

  test('totalDurationMs：全部节点有时长 → Σ 透传', () async {
    final (container, fake) = _make();
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[
        _videoResult('n1', durationMs: 3000),
        _videoResult('n2', durationMs: 5000),
      ],
    );

    expect(fake.lastTotalDurationMs, 8000);
  });

  test('totalDurationMs：任一节点缺时长 → null（indeterminate 语义）', () async {
    final (container, fake) = _make();
    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[
        _videoResult('n1', durationMs: 3000),
        _videoResult('n2'), // 无 duration_ms
      ],
    );

    expect(fake.lastTotalDurationMs, isNull);
  });

  test('onProgress 回调 → ExportVideoBusy(progress) 更新', () async {
    final gate = Completer<String>();
    final (container, fake) = _make(gate: gate);
    final future = container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1', durationMs: 4000)],
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(exportControllerProvider),
      isA<ExportVideoBusy>().having((s) => s.progress, 'progress', isNull),
    );

    fake.lastOnProgress!(0.5);
    expect(
      container.read(exportControllerProvider),
      isA<ExportVideoBusy>().having((s) => s.progress, 'progress', 0.5),
    );

    gate.complete('exports/out.mp4');
    await future;
  });

  test('cancelExport → token 传导取消；CancelledError 收敛为 idle（非 failure）',
      () async {
    final gate = Completer<String>();
    final (container, fake) = _make(gate: gate);
    final future = container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1', durationMs: 4000)],
    );
    await Future<void>.delayed(Duration.zero);
    expect(fake.lastToken, isNotNull);

    container.read(exportControllerProvider.notifier).cancelExport();
    expect(fake.lastToken!.isCancelled, isTrue);

    // 服务契约：取消后以 CancelledError 收敛。
    gate.completeError(
      const CancelledError.byUser(
        extra: <String, Object?>{'reason': 'export_cancelled'},
      ),
    );
    await future;

    expect(container.read(exportControllerProvider), isA<ExportVideoIdle>());
  });

  test('非 busy 期 cancelExport 为 no-op', () async {
    final (container, fake) = _make();
    container.read(exportControllerProvider.notifier).cancelExport();

    expect(container.read(exportControllerProvider), isA<ExportVideoIdle>());
    expect(fake.lastToken, isNull);
  });

  test('busy 期间重入 export 被忽略', () async {
    final gate = Completer<String>();
    final (container, fake) = _make(gate: gate);
    final first = container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n1')],
    );
    await Future<void>.delayed(Duration.zero);
    fake.lastInputs = null;

    await container.read(exportControllerProvider.notifier).export(
      projectId: 'p1',
      nodes: <CanvasNode>[_videoResult('n2')],
    );
    expect(fake.lastInputs, isNull);

    gate.complete('exports/out.mp4');
    await first;
  });
}
