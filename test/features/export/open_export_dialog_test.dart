// openExportVideoDialogForCanvas —— 外壳打开导出对话框的唯一路径（导出标签 / 序列标签 / ⌘K 都走它）。
//
// 钉住的一件事：对话框只拿得到 video result 子集，配置节点上的固定（pinned_result_id）得由这里从
// 全量节点算好再传进去。所以画布上配置节点固定了旧 take 时，从这条路打开的对话框默认勾的是那条旧 take，
// 不是最新的。直接调 showExportVideoDialog 的对话框用例够不到这一步：把 pinnedBySource 实参删掉、
// 或改成从 videoNodes 算（候选里没有配置节点，固定表恒为空），那边照样全绿，只有这里会红。
//
// 两条入口各钉一次：直接调 openExportVideoDialogForCanvas（导出标签 / 序列标签），
// 以及 ⌘K / 动作表的 AppActionIds.exportVideo。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/take_keys.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/video_export.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/video_export_service.dart';
import 'package:inkframe/features/app_actions/app_action.dart';
import 'package:inkframe/features/app_actions/app_action_catalog.dart';
import 'package:inkframe/features/app_actions/app_action_ids.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/export/open_export_dialog.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/fake_toast_service.dart';
import '../../_harness/test_app.dart';

const String _canvasId = 'c1';
const ProjectRef _project = ProjectRef(id: 'p1', name: 'Alpha');

/// 画布标签在前台、有项目上下文：⌘K 的 exportVideo 只对看得见的画布动手。
const ShellState _onCanvas =
    ShellState(tab: ShellTab.canvas, canvasId: _canvasId, project: _project);

/// 只记参数的导出服务。
class _RecordingVideoExportService implements VideoExportService {
  String? lastProjectId;
  List<String>? lastInputs;

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
    return 'exports/out.mp4';
  }
}

/// 指向不存在的路径即可：缩略图读不到走占位，同名检查恒为「不存在」。
class _MissingFileResolver implements FileResolverService {
  static const String _root = 'Z:/fake';

  @override
  File resolveInProject({
    required String projectId,
    required String relativePath,
  }) =>
      File('$_root/$projectId/$relativePath');

  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File('$_root/$projectId/canvases/$canvasId/$relativePath');

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

CanvasNode _videoTake(String id, double x, DateTime createdAt) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: _canvasId,
      sourceNodeId: 'cfg-s1',
      createdAt: createdAt,
      typeConfig: <String, Object?>{'video_url': 'videos/$id.mp4'},
      position: Offset(x, 0),
    );

/// 一镜两条 take：old 早、new 晚；配置节点把 old 固定成当前 take。
/// 没有固定时默认勾的会是 new——两者对得上才说明固定表真的传到了对话框。
final List<CanvasNode> _seed = <CanvasNode>[
  const CanvasNode(
    id: 'cfg-s1',
    label: 'Shot 1',
    type: CanvasNodeType.video,
    projectId: 'p1',
    canvasId: _canvasId,
    typeConfig: <String, Object?>{TakeKeys.pinnedResultId: 'old'},
  ),
  _videoTake('old', 100, DateTime.utc(2026, 1, 1)),
  _videoTake('new', 200, DateTime.utc(2026, 8, 7)),
];

/// 各行复选框的勾选态，按展示序（链序：本镜新→旧成组，new 在上）。
List<bool?> _checkboxValues(WidgetTester tester) => tester
    .widgetList<Checkbox>(find.byType(Checkbox))
    .map((Checkbox c) => c.value)
    .toList();

/// 起一个只有一个按钮的页面，按钮用 [open] 打开导出对话框；节点 / 边先挂上订阅并预热——
/// openExportVideoDialogForCanvas 里的 ref.read 没有订阅者时只拿得到 AsyncLoading
/// （生产里画布页常驻 watch 它们）。
Future<void> _pumpAndOpen(
  WidgetTester tester,
  _RecordingVideoExportService service,
  void Function(BuildContext context, WidgetRef ref) open,
) async {
  late BuildContext captured;
  await pumpInkApp(
    tester,
    Scaffold(
      body: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          captured = context;
          return TextButton(
            onPressed: () => open(context, ref),
            child: const Text('open'),
          );
        },
      ),
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: _onCanvas)),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_seed)),
      canvasEdgesControllerProvider.overrideWith(FakeEdgesController.new),
      videoExportServiceProvider.overrideWithValue(service),
      fileResolverServiceProvider.overrideWithValue(_MissingFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
  );
  final ProviderContainer container = ProviderScope.containerOf(captured);
  container.listen(canvasNodesControllerProvider(_canvasId), (_, _) {});
  container.listen(canvasEdgesControllerProvider(_canvasId), (_, _) {});
  await container.read(canvasNodesControllerProvider(_canvasId).future);
  await container.read(canvasEdgesControllerProvider(_canvasId).future);

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// 对话框默认勾的是固定的旧 take；直接导出只含 old.mp4，项目取自外壳。
Future<void> _expectPinnedTakeSelected(
  WidgetTester tester,
  _RecordingVideoExportService service,
) async {
  // 候选集不收窄：两条 take 都列出。
  expect(find.text('new'), findsOneWidget);
  expect(find.text('old'), findsOneWidget);
  expect(
    tester.getTopLeft(find.text('new')).dy,
    lessThan(tester.getTopLeft(find.text('old')).dy),
    reason: '链序：本镜新→旧成组',
  );
  expect(
    _checkboxValues(tester),
    <bool?>[false, true],
    reason: '配置节点固定了 old：默认勾 old，不勾更新的 new',
  );

  await tester.tap(find.text('Export'));
  await tester.pumpAndSettle();

  expect(service.lastProjectId, 'p1');
  expect(service.lastInputs, <String>['canvases/c1/videos/old.mp4']);
}

void main() {
  testWidgets('直接调 openExportVideoDialogForCanvas（导出标签 / 序列标签）→ 默认勾固定的旧 take',
      (tester) async {
    final service = _RecordingVideoExportService();
    await _pumpAndOpen(
      tester,
      service,
      (BuildContext context, WidgetRef ref) =>
          openExportVideoDialogForCanvas(context, ref, _canvasId),
    );
    await _expectPinnedTakeSelected(tester, service);
  });

  testWidgets('⌘K / 动作表 exportVideo → 默认勾固定的旧 take', (tester) async {
    final service = _RecordingVideoExportService();
    await _pumpAndOpen(
      tester,
      service,
      (BuildContext context, WidgetRef ref) {
        final AppAction? action = appActionById(AppActionIds.exportVideo);
        expect(action, isNotNull, reason: '动作表里没有 exportVideo');
        action!.run(AppActionContext.read(context, ref));
      },
    );
    await _expectPinnedTakeSelected(tester, service);
  });
}
