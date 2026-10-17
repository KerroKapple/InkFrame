// ⌘K 的动作组（buildCommandActions）：全部来自应用级动作表（kAppActions），集合与顺序与改写前一致。
//
// 断言写法：结果先按 [kLegacyPaletteIds]（改写前 ⌘K 的全部动作，按新 id 写）过滤，再与改写前的序列比——
// 后续切片往 ⌘K 加行时不必改本测试；「全部来自表」与「没有占位行」两条另查，不过滤。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/app_actions/app_action_catalog.dart';
import 'package:inkframe/features/app_actions/app_action_ids.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/command_palette/command_actions.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/test_app.dart';

const String _canvasId = 'c1';
const ProjectRef _project = ProjectRef(id: 'p1', name: 'Alpha');

/// 改写前 ⌘K 的全部动作（按新 id 写：短剧示例改前叫 createSampleProject，现在是 openSampleProject）。
const List<String> kLegacyPaletteIds = <String>[
  AppActionIds.importProject,
  AppActionIds.openSampleProject,
  AppActionIds.openSettings,
  AppActionIds.addImageNode,
  AppActionIds.addVideoNode,
  AppActionIds.addShotNode,
  AppActionIds.exportVideo,
  AppActionIds.backToStudio,
];

/// 第二批的占位行（comingSoon）：一条都不该进 ⌘K。
const Set<String> _comingSoonIds = <String>{
  AppActionIds.undo,
  AppActionIds.redo,
  AppActionIds.cut,
  AppActionIds.copy,
  AppActionIds.paste,
  AppActionIds.find,
  AppActionIds.importMedia,
  AppActionIds.newNote,
  AppActionIds.wrapInLane,
  AppActionIds.focusNotifications,
};

/// 一张可导出的视频产物（role=result、type=video、有 video_url、有 canvasId）。
const CanvasNode _video = CanvasNode(
  id: 'vid',
  label: 'clip',
  type: CanvasNodeType.video,
  role: NodeRole.result,
  projectId: 'p1',
  canvasId: _canvasId,
  typeConfig: <String, Object?>{'video_url': 'videos/a.mp4'},
);

/// 一张图像配置（没有可导出的东西）。
const CanvasNode _image = CanvasNode(
  id: 'img',
  label: 'Shot A',
  type: CanvasNodeType.image,
  canvasId: _canvasId,
);

/// 外壳播种成 [shell]、画布 c1 的节点 = [nodes]，返回 buildCommandActions 的 id 序列。节点先挂订阅预热
/// （生产里 CanvasScreen 常驻 watch；没订阅者时 ref.read 只拿得到 AsyncLoading）。
Future<List<String>> _paletteIds(
  WidgetTester tester,
  ShellState shell, {
  List<CanvasNode> nodes = const <CanvasNode>[],
}) async {
  late BuildContext captured;
  late WidgetRef capturedRef;
  await pumpInkApp(
    tester,
    Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        captured = context;
        capturedRef = ref;
        return const SizedBox.shrink();
      },
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: shell)),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(nodes)),
      canvasEdgesControllerProvider.overrideWith(FakeEdgesController.new),
      canvasLanesControllerProvider.overrideWith(EmptyLanesController.new),
    ],
  );
  final ProviderContainer container = ProviderScope.containerOf(captured);
  container.listen(canvasNodesControllerProvider(_canvasId), (_, _) {});
  await container.read(canvasNodesControllerProvider(_canvasId).future);
  return buildCommandActions(captured, capturedRef)
      .map((CommandAction a) => a.id)
      .toList();
}

List<String> _legacy(List<String> ids) =>
    ids.where(kLegacyPaletteIds.contains).toList();

/// 「全部来自表」+「没有占位行」：不过滤，原样查。
void _expectFromTable(List<String> ids, String where) {
  for (final String id in ids) {
    expect(appActionById(id), isNotNull, reason: '$where：⌘K 的 $id 不在动作表里');
    expect(_comingSoonIds, isNot(contains(id)), reason: '$where：占位行 $id 进了 ⌘K');
  }
}

void main() {
  testWidgets('Studio → 导入项目、短剧示例、设置', (tester) async {
    final List<String> ids = await _paletteIds(tester, const ShellState());
    _expectFromTable(ids, 'Studio');
    expect(_legacy(ids), <String>[
      AppActionIds.importProject,
      AppActionIds.openSampleProject,
      AppActionIds.openSettings,
    ]);
  });

  testWidgets('画布、没有可导出的视频（有项目）→ 三种新建节点 + 返回 / 设置，没有导出视频', (tester) async {
    final List<String> ids = await _paletteIds(
      tester,
      const ShellState(tab: ShellTab.canvas, canvasId: _canvasId, project: _project),
      nodes: const <CanvasNode>[_image],
    );
    _expectFromTable(ids, '画布无视频');
    expect(_legacy(ids), <String>[
      AppActionIds.addImageNode,
      AppActionIds.addVideoNode,
      AppActionIds.addShotNode,
      AppActionIds.backToStudio,
      AppActionIds.openSettings,
    ]);
  });

  testWidgets('画布、有视频 + 有项目 → 导出视频排在镜头节点之后', (tester) async {
    final List<String> ids = await _paletteIds(
      tester,
      const ShellState(tab: ShellTab.canvas, canvasId: _canvasId, project: _project),
      nodes: const <CanvasNode>[_image, _video],
    );
    _expectFromTable(ids, '画布有视频');
    expect(_legacy(ids), <String>[
      AppActionIds.addImageNode,
      AppActionIds.addVideoNode,
      AppActionIds.addShotNode,
      AppActionIds.exportVideo,
      AppActionIds.backToStudio,
      AppActionIds.openSettings,
    ]);
  });

  // BOARD 210：导出可用性 = 有视频产物【且】外壳有项目上下文。
  testWidgets('画布、有视频但外壳没有项目 → 没有导出视频', (tester) async {
    final List<String> ids = await _paletteIds(
      tester,
      const ShellState(tab: ShellTab.canvas, canvasId: _canvasId),
      nodes: const <CanvasNode>[_video],
    );
    expect(ids, isNot(contains(AppActionIds.exportVideo)));
  });

  testWidgets('画廊、有项目 → 返回工作室、设置', (tester) async {
    final List<String> ids = await _paletteIds(
      tester,
      const ShellState(tab: ShellTab.gallery, project: _project),
    );
    _expectFromTable(ids, '画廊');
    expect(_legacy(ids), <String>[
      AppActionIds.backToStudio,
      AppActionIds.openSettings,
    ]);
  });

  // 浮层优先：画布上开着设置（canvasId 保留、有可导出的视频）时，拿到的是设置的动作集，不是对着看不见的画布
  // 动刀的建节点 / 导出。
  testWidgets('画布标签上开着设置浮层 → 只有返回工作室', (tester) async {
    final List<String> ids = await _paletteIds(
      tester,
      const ShellState(
        tab: ShellTab.canvas,
        overlay: ShellOverlay.settings,
        canvasId: _canvasId,
        project: _project,
      ),
      nodes: const <CanvasNode>[_image, _video],
    );
    _expectFromTable(ids, '设置浮层');
    expect(_legacy(ids), <String>[AppActionIds.backToStudio]);
  });

  testWidgets('标签条上切回 Studio（画布保活、canvasId 还在）→ 拿到 Studio 的动作集', (tester) async {
    final List<String> ids = await _paletteIds(
      tester,
      const ShellState(canvasId: _canvasId, project: _project),
      nodes: const <CanvasNode>[_image, _video],
    );
    expect(_legacy(ids), <String>[
      AppActionIds.importProject,
      AppActionIds.openSampleProject,
      AppActionIds.openSettings,
    ]);
  });
}
