// ExportVideoDialog —— 排序/勾选/上下移/文件名预校验/导出参数/成败反馈。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/video_export_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/export/widgets/export_video_dialog.dart';
import 'package:inkframe/theme/components/ink_progress_bar.dart';

import '../../../_harness/test_app.dart';

class _FakeVideoExportService implements VideoExportService {
  _FakeVideoExportService({this.error});

  final Object? error;
  final String result = 'exports/out.mp4';

  String? lastProjectId;
  List<String>? lastInputs;
  String? lastOutputBaseName;
  int calls = 0;
  Completer<String>? gate;

  @override
  Future<String> concat({
    required String projectId,
    required List<String> inputRelativePaths,
    String? outputBaseName,
  }) async {
    calls++;
    lastProjectId = projectId;
    lastInputs = inputRelativePaths;
    lastOutputBaseName = outputBaseName;
    final g = gate;
    if (g != null) return g.future;
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

class _FakeFileResolver implements FileResolverService {
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
      throw UnimplementedError();

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

CanvasNode _videoResult(String label, double x, String file) => CanvasNode(
      id: 'node-$label',
      label: label,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: 'c1',
      sourceNodeId: 'cfg-$label',
      typeConfig: <String, Object?>{'video_url': 'videos/$file'},
      position: Offset(x, 0),
    );

Future<void> _pumpDialog(
  WidgetTester tester, {
  required _FakeVideoExportService service,
  List<CanvasNode>? nodes,
}) async {
  final videoNodes = nodes ??
      <CanvasNode>[
        // 故意乱序：断言按 position.x 升序展示。
        _videoResult('B', 200, 'b.mp4'),
        _videoResult('A', 100, 'a.mp4'),
        _videoResult('C', 300, 'c.mp4'),
      ];
  await pumpInkApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showExportVideoDialog(
            ctx,
            projectId: 'p1',
            videoNodes: videoNodes,
          ),
          child: const Text('open'),
        ),
      ),
    ),
    overrides: <Override>[
      videoExportServiceProvider.overrideWithValue(service),
      fileResolverServiceProvider.overrideWithValue(_FakeFileResolver()),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('exportableVideoNodes：result+video+videoUrl+canvasId 全满足才入选', () {
    final valid = _videoResult('ok', 100, 'a.mp4');
    const noCanvas = CanvasNode(
      id: 'no-canvas',
      label: 'no-canvas',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      sourceNodeId: 'cfg-nc',
      typeConfig: <String, Object?>{'video_url': 'videos/x.mp4'},
    );
    const noUrl = CanvasNode(
      id: 'no-url',
      label: 'no-url',
      type: CanvasNodeType.video,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: 'cfg-nu',
    );
    const config = CanvasNode(
      id: 'cfg',
      label: 'cfg',
      type: CanvasNodeType.video,
      canvasId: 'c1',
      typeConfig: <String, Object?>{'video_url': 'videos/y.mp4'},
    );
    const image = CanvasNode(
      id: 'img',
      label: 'img',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: 'cfg-img',
      typeConfig: <String, Object?>{'video_url': 'videos/z.mp4'},
    );

    expect(
      exportableVideoNodes(
        <CanvasNode>[valid, noCanvas, noUrl, config, image],
      ),
      <CanvasNode>[valid],
    );
  });

  testWidgets('列表按 position.x 升序展示 + 默认全选', (tester) async {
    final service = _FakeVideoExportService();
    await _pumpDialog(tester, service: service);

    expect(find.text('Export video'), findsOneWidget);
    final yA = tester.getTopLeft(find.text('A')).dy;
    final yB = tester.getTopLeft(find.text('B')).dy;
    final yC = tester.getTopLeft(find.text('C')).dy;
    expect(yA, lessThan(yB));
    expect(yB, lessThan(yC));

    for (final cb in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      expect(cb.value, isTrue);
    }
  });

  testWidgets('全选直接导出：按 x 序透传项目相对路径，文件名留空 → null', (tester) async {
    final service = _FakeVideoExportService();
    await _pumpDialog(tester, service: service);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(service.lastProjectId, 'p1');
    expect(service.lastInputs, <String>[
      'canvases/c1/videos/a.mp4',
      'canvases/c1/videos/b.mp4',
      'canvases/c1/videos/c.mp4',
    ]);
    expect(service.lastOutputBaseName, isNull);
  });

  testWidgets('取消勾选 + 上移重排 → 导出仅含选中项且按新顺序', (tester) async {
    final service = _FakeVideoExportService();
    await _pumpDialog(tester, service: service);

    // 展示序 [A,B,C]：取消勾选 B（index 1）。
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    // C 上移两次：[A,B,C] → [A,C,B] → [C,A,B]。
    await tester.tap(find.byIcon(Icons.arrow_upward).at(2));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward).at(1));
    await tester.pump();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(service.lastInputs, <String>[
      'canvases/c1/videos/c.mp4',
      'canvases/c1/videos/a.mp4',
    ]);
  });

  testWidgets('非法文件名 → 导出按钮禁用 + 提示文案', (tester) async {
    final service = _FakeVideoExportService();
    await _pumpDialog(tester, service: service);

    await tester.enterText(find.byType(TextField), 'a/b');
    await tester.pump();

    expect(
      find.text(
        'File name cannot contain \\ / : * ? " < > |, \'..\', '
        'control characters, or reserved device names',
      ),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('合法文件名 → outputBaseName 原样透传（trim 后）', (tester) async {
    final service = _FakeVideoExportService();
    await _pumpDialog(tester, service: service);

    await tester.enterText(find.byType(TextField), '  my_cut  ');
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(service.lastOutputBaseName, 'my_cut');
  });

  testWidgets('ffmpeg_not_found → 专门文案 snackbar，对话框保持打开', (tester) async {
    final service = _FakeVideoExportService(
      error: const LocalIOError(
        extra: <String, Object?>{'reason': 'ffmpeg_not_found'},
      ),
    );
    await _pumpDialog(tester, service: service);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'ffmpeg not found — install it and retry (set the INKFRAME_FFMPEG '
        'environment variable to use a custom location)',
      ),
      findsOneWidget,
    );
    expect(find.text('Export video'), findsOneWidget);
  });

  testWidgets('其他 LocalIOError → 走通用 errorLocalIO 文案', (tester) async {
    final service = _FakeVideoExportService(
      error: const LocalIOError(
        extra: <String, Object?>{'reason': 'export_io_failed'},
      ),
    );
    await _pumpDialog(tester, service: service);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(
      find.text('Local disk I/O error. Check space and permissions.'),
      findsOneWidget,
    );
  });

  testWidgets('成功 → 关对话框 + snackbar 相对路径 + 复制绝对路径 action', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final service = _FakeVideoExportService();
    await _pumpDialog(tester, service: service);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Export video'), findsNothing);
    expect(find.text('Exported to exports/out.mp4'), findsOneWidget);

    await tester.tap(find.text('Copy path'));
    await tester.pumpAndSettle();
    expect(copied, <String>['Z:/fake/p1/exports/out.mp4']);
  });

  testWidgets('busy 态：不确定进度条 + 导出按钮与输出名输入禁用', (tester) async {
    final service = _FakeVideoExportService()..gate = Completer<String>();
    await _pumpDialog(tester, service: service);

    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(find.byType(InkProgressBar), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.enabled, isFalse);

    service.gate!.complete('exports/out.mp4');
    await tester.pumpAndSettle();
    expect(find.text('Export video'), findsNothing);
  });
}
