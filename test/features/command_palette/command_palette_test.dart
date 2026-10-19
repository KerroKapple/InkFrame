// PL-1 ⌘K 命令面板：唤起/关闭/键盘导航/搜索过滤/上下文动作集/执行语义。
// 测试平台默认 android → 用 Ctrl+K 绑定（macOS 走 meta 绑定，同一实现）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_focus_request.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_shortcuts.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../_harness/fake_repositories.dart';
import '../../_harness/fake_toast_service.dart';
import '../../helpers/recording_logger.dart';

/// 空画布节点集（隔离 DB DI）。
class _EmptyNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async =>
      const <CanvasNode>[];
}

/// 带一个可导出 video result 节点的画布。
class _ExportableNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        CanvasNode(
          id: 'v1',
          label: 'clip',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          projectId: 'p1',
          canvasId: canvasId,
          sourceNodeId: 'cfg1',
          typeConfig: const <String, Object?>{'video_url': 'videos/a.mp4'},
        ),
      ];
}

/// 「⌘K 导出默认勾固定的 take」夹具：一个视频配置 cfg-p 固定了**较旧**的 r-old，名下还有一个**较新**的 r-new。
/// 不看固定的话「当前 take」= 最新 = r-new；看了才是 r-old——两种口径默认勾的行正好相反。
class _PinnedTakeNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        CanvasNode(
          id: 'cfg-p',
          label: 'cfg-p',
          type: CanvasNodeType.video,
          projectId: 'p1',
          canvasId: canvasId,
          typeConfig: const <String, Object?>{'pinned_result_id': 'r-old'},
        ),
        CanvasNode(
          id: 'r-old',
          label: 'clip-old',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          projectId: 'p1',
          canvasId: canvasId,
          sourceNodeId: 'cfg-p',
          position: const Offset(100, 0),
          createdAt: DateTime.utc(2026, 1, 1),
          typeConfig: const <String, Object?>{'video_url': 'videos/old.mp4'},
        ),
        CanvasNode(
          id: 'r-new',
          label: 'clip-new',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          projectId: 'p1',
          canvasId: canvasId,
          sourceNodeId: 'cfg-p',
          position: const Offset(200, 0),
          createdAt: DateTime.utc(2026, 8, 7),
          typeConfig: const <String, Object?>{'video_url': 'videos/new.mp4'},
        ),
      ];
}

/// 没有边（导出时 ref.read 边控制器要拿到 AsyncData，别去起真仓储）。
class _NoEdgesController extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[];
}

/// R86 夹具：**链序第一个**可导出产物的 projectId 为空，**原序第一个**非空。
///
/// 这正是 `canExport`（看 `exportableVideoNodes(...).first`，即原序）与
/// 旧 `_openExport`（看 `orderVideoNodesForExport(...).first`，即链序）不同源
/// 时的失败形态：面板里出现「Export video」、点下去什么都不发生。
/// 存量行允许 `project_id` 为空，所以这不是构造出来的幻想态。
class _ChainOrderNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        // 原序在前 ⇒ canExport 看到的是它（projectId 非空 ⇒ 动作出现）。
        // position.x 也在前 ⇒ 边一旦落空，链序会退化成 position.x 序并把它排
        // 到头一个，本用例的鉴别力就没了——所以下面必须 _warmEdges。
        CanvasNode(
          id: 'cfg-a',
          label: 'cfg-a',
          type: CanvasNodeType.video,
          projectId: 'p1',
          canvasId: canvasId,
          position: const Offset(0, 0),
        ),
        CanvasNode(
          id: 'r-a',
          label: 'clip-a',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          projectId: 'p1',
          canvasId: canvasId,
          sourceNodeId: 'cfg-a',
          position: const Offset(0, 0),
          typeConfig: const <String, Object?>{'video_url': 'videos/a.mp4'},
        ),
        CanvasNode(
          id: 'cfg-b',
          label: 'cfg-b',
          type: CanvasNodeType.video,
          projectId: 'p1',
          canvasId: canvasId,
          position: const Offset(100, 0),
        ),
        // 链头是 cfg-b ⇒ 链序第一个产物是它，而它的 project_id 为空。
        CanvasNode(
          id: 'r-b',
          label: 'clip-b',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          canvasId: canvasId,
          sourceNodeId: 'cfg-b',
          position: const Offset(100, 0),
          typeConfig: const <String, Object?>{'video_url': 'videos/b.mp4'},
        ),
      ];
}

/// 三个图像 config 节点：cfg-a / cfg-b 在链上（边见 _ChainEdgesController），cfg-lone 孤立。
/// 链上两个都有提示词：既无产物也无备注的节点在序列里会被跳过、不编号（镜号是序列的口径）。
class _ChainShotsController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        CanvasNode(
          id: 'cfg-a',
          label: 'cfg-a',
          type: CanvasNodeType.image,
          canvasId: canvasId,
          typeConfig: const <String, Object?>{'prompt': 'harbor at dawn'},
        ),
        CanvasNode(
          id: 'cfg-b',
          label: 'cfg-b',
          type: CanvasNodeType.image,
          canvasId: canvasId,
          typeConfig: const <String, Object?>{'prompt': 'a lone boat'},
        ),
        CanvasNode(id: 'cfg-lone', label: 'cfg-lone', type: CanvasNodeType.image, canvasId: canvasId),
      ];
}

/// narrative 链 cfg-b → cfg-a（与 position.x 序刻意相反）。
class _ChainEdgesController extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => <CanvasEdge>[
        CanvasEdge(
          id: 'e-ba',
          canvasId: canvasId,
          sourceNodeId: 'cfg-b',
          targetNodeId: 'cfg-a',
          edgeType: EdgeType.narrative,
        ),
      ];
}

/// 「导入剧本 + 用本镜备注生成图像」的主路径：镜头 Scene 1 → Scene 2 → Scene 3，Scene 2 上生成图像接出的
/// 图像配置 Scene 2 image 也接在 Scene 2 后面（排在 Scene 3 前），它名下有图——序列把这张图放在 Scene 2
/// 那一镜（边见 _SceneEdgesController）。
class _SceneShotsController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async {
    CanvasNode shot(String id, String label, String notes) => CanvasNode(
          id: id,
          label: label,
          type: CanvasNodeType.shot,
          canvasId: canvasId,
          typeConfig: <String, Object?>{'shot_notes': notes},
        );
    return <CanvasNode>[
      shot('s1', 'Scene 1', 'harbor at dawn'),
      shot('s2', 'Scene 2', 'a lone boat'),
      shot('s3', 'Scene 3', 'far peaks'),
      CanvasNode(
        id: 'c2',
        label: 'Scene 2 image',
        type: CanvasNodeType.image,
        canvasId: canvasId,
        typeConfig: const <String, Object?>{'prompt': 'a lone boat'},
      ),
      CanvasNode(
        id: 'r2',
        label: 'r2',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        canvasId: canvasId,
        sourceNodeId: 'c2',
        createdAt: DateTime.utc(2026, 5, 1),
        typeConfig: const <String, Object?>{'image_url': 'images/r2.png'},
      ),
    ];
  }
}

/// s1 → s2（sortOrder 0）、s2 → s3（sortOrder 1）、s2 → c2（sortOrder 0）。
class _SceneEdgesController extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async {
    CanvasEdge narrative(String from, String to, int sortOrder) => CanvasEdge(
          id: 'e-$from-$to',
          canvasId: canvasId,
          sourceNodeId: from,
          targetNodeId: to,
          edgeType: EdgeType.narrative,
          sortOrder: sortOrder,
        );
    return <CanvasEdge>[narrative('s1', 's2', 0), narrative('s2', 's3', 1), narrative('s2', 'c2', 0)];
  }
}

/// 带一个可搜到的图像 config 节点（「镜头 · 当前画布」组的数据源）。
class _ShotNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        CanvasNode(
          id: 'img',
          label: 'Sunrise',
          type: CanvasNodeType.image,
          projectId: 'p1',
          canvasId: canvasId,
        ),
      ];
}

/// 记录 addNode 调用的 fake（验证面板动作真实触达 controller）。
class _RecordingNodesController extends CanvasNodesController {
  static final List<CanvasNodeType> added = <CanvasNodeType>[];

  @override
  Future<List<CanvasNode>> build(String canvasId) async =>
      const <CanvasNode>[];

  @override
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    String? laneId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    added.add(type);
    return CanvasNode(id: 'n1', label: label, type: type, canvasId: arg);
  }
}

/// addNode 一律抛 InkError 的 fake：⌘K「添加节点」失败那条提示的入口。
class _FailingNodesController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async =>
      const <CanvasNode>[];

  @override
  Future<CanvasNode> addNode({
    required String label,
    required CanvasNodeType type,
    NodeRole role = NodeRole.config,
    String? sourceNodeId,
    String? laneId,
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async =>
      throw const LocalIOError();
}

/// 导入流程测试用 fake service。
class _FakeImportService implements ProjectImportService {
  @override
  Future<ImportResult> importArchive({required String zipPath}) async =>
      const ImportResult(outcome: ImportOutcome.failed);
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
}) async {
  final container = ProviderContainer(overrides: <Override>[
    // 「镜头」组的路径面包屑读画布名（canvases 表）——封住，别去起真 PG。
    canvasRepositoryProvider.overrideWith((_) async => InMemoryCanvasRepository()),
    ...overrides,
  ]);
  addTearDown(container.dispose);
  await tester.binding.setSurfaceSize(const Size(1000, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CommandPaletteShortcuts(
        child: Scaffold(body: SizedBox.expand()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// 预热画布节点 provider（真实 app 内 CanvasScreen 常驻 watch，测试里补一个监听）。
Future<void> _warmNodes(ProviderContainer container, String canvasId) async {
  container.listen(
    canvasNodesControllerProvider(canvasId),
    (_, _) {},
  );
  await container.read(canvasNodesControllerProvider(canvasId).future);
}

/// 同上，但预热【边】控制器。`_openExport` 里 `ref.read(edges).valueOrNull`
/// 在没订阅者时只拿得到 AsyncLoading ⇒ 链序静默退化成 position.x 序。
Future<void> _warmEdges(ProviderContainer container, String canvasId) async {
  container.listen(canvasEdgesControllerProvider(canvasId), (_, _) {});
  await container.read(canvasEdgesControllerProvider(canvasId).future);
}

/// 导出对话框里与 [label] 同一行（纵向中心最近）的那个复选框的勾选态——不依赖列表行序。
bool? _checkedOnRowOf(WidgetTester tester, String label) {
  final double y = tester.getCenter(find.text(label)).dy;
  final Finder boxes = find.byType(Checkbox);
  final int count = boxes.evaluate().length;
  expect(count, greaterThan(0), reason: '对话框里没有复选框');
  int best = 0;
  double bestDistance = double.infinity;
  for (int i = 0; i < count; i++) {
    final double d = (tester.getCenter(boxes.at(i)).dy - y).abs();
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return tester.widget<Checkbox>(boxes.at(best)).value;
}

Future<void> _pressCtrlK(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_RecordingNodesController.added.clear);

  testWidgets('Ctrl+K 唤起面板，Esc 关闭', (tester) async {
    await _pumpShell(tester);

    expect(find.byType(CommandPaletteDialog), findsNothing);
    await _pressCtrlK(tester);
    expect(find.byType(CommandPaletteDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsNothing);
  });

  testWidgets('studio 上下文只有 Open settings；执行后导航到设置页', (tester) async {
    final container = await _pumpShell(tester);
    await _pressCtrlK(tester);

    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Back to Studio'), findsNothing);
    expect(find.text('Add image node'), findsNothing);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(container.read(shellControllerProvider).overlay, ShellOverlay.settings);
  });

  testWidgets('studio 上下文能直接执行 Import project（回归 2026-08-31 审计 P0）',
      (tester) async {
    final toast = RecordingToastService();
    final container = await _pumpShell(tester, overrides: <Override>[
      openFilePickerProvider.overrideWithValue(() async => null),
      projectImportServiceProvider.overrideWith((ref) async => _FakeImportService()),
      toastServiceProvider.overrideWithValue(toast),
      loggerProvider.overrideWithValue(RecordingLogger()),
    ]);
    await _pressCtrlK(tester);

    expect(find.text('Import project…'), findsOneWidget);
    await tester.tap(find.text('Import project…'));
    await tester.pumpAndSettle();

    // picker 返回 null（用户取消）：面板已经关闭，且没有崩溃/挂起。
    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(container.read(projectImportBusyProvider), isFalse);
    expect(toast.shown, isEmpty, reason: '用户取消选文件 ≠ 失败，不该弹任何卡');
  });

  testWidgets('canvas 上下文动作集：三种新建节点 + 返回/设置；无可导出节点时不出 Export video',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    expect(find.text('Add image node'), findsOneWidget);
    expect(find.text('Add video node'), findsOneWidget);
    expect(find.text('Add shot node'), findsOneWidget);
    expect(find.text('Back to Studio'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Export video'), findsNothing);
  });

  testWidgets('canvas 有可导出 video result 时出现 Export video', (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider
          .overrideWith(_ExportableNodesController.new),
    ]);
    // BOARD 210：导出可用性 = 有 video result【且】外壳有项目上下文。
    container.read(shellControllerProvider.notifier).openCanvas(
          'c1',
          withProject: const ProjectRef(id: 'p1', name: 'Alpha'),
        );
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    expect(find.text('Export video'), findsOneWidget);
  });

  testWidgets('BOARD 210：有 video result 但外壳无项目上下文 → 不出 Export video',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider
          .overrideWith(_ExportableNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    expect(find.text('Export video'), findsNothing);
  });

  // fix round 18（R86）：⌘K 的 Export video 是 spec §8.2「projectId 走
  // ShellState」漏下的第三个写点（T10 只改了 export_tab / sequence_tab 两个
  // 标签体）。夹具刻意让【链序第一个】产物的 project_id 为空、【原序第一个】
  // 非空——canExport 看原序所以动作出现，旧 _openExport 看链序所以静默返回：
  // 「看着能点、点了没反应」。
  // 实跑变异：把 _openExport 的 projectId 改回 `videoNodes.first.projectId` →
  // 本条红在 `find.text(.clip-b.)`（Found 0 widgets），而它上面那条
  // 「Export video 动作出现」的前置断言仍绿——红的正是"点了没反应"本身。
  testWidgets('R86：链序首个产物 project_id 为空时，⌘K Export video 仍能弹出对话框',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_ChainOrderNodesController.new),
      canvasEdgesControllerProvider.overrideWith(_ChainEdgesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas(
          'c1',
          withProject: const ProjectRef(id: 'p1', name: 'Alpha'),
        );
    await _warmNodes(container, 'c1');
    // 必需：边落空 ⇒ 链序退化成 position.x 序 ⇒ 头一个变成 project_id 非空的
    // r-a ⇒ 旧代码也能弹出对话框 ⇒ 本用例鉴别力归零。
    await _warmEdges(container, 'c1');
    await _pressCtrlK(tester);

    expect(
      find.text('Export video'),
      findsOneWidget,
      reason: '前置条件：canExport 取原序首个（project_id 非空）⇒ 动作必须出现，'
          '否则下面那条"对话框弹出"测的是别的东西',
    );
    await tester.tap(find.text('Export video'));
    await tester.pumpAndSettle();

    // 链序首个（r-b / clip-b）在列表最前——既证明对话框真的弹了，也证明
    // 排序仍走 narrative 链序（EX-1′ 没被这次改动带歪）。
    expect(find.text('clip-b'), findsOneWidget);
    expect(find.text('clip-a'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('clip-b')).dy,
      lessThan(tester.getTopLeft(find.text('clip-a')).dy),
      reason: '链序 cfg-b→cfg-a 必须赢过 position.x 序（a 在左）',
    );
  });

  // W1 验收：⌘K 的 Export video 走 openExportVideoDialogForCanvas，与旧 _openExport 的区别只在固定的 take
  // （pinnedBySource 从全量节点算好传进对话框）。对话框只拿得到 video result 子集、看不到配置节点上的
  // pinned_result_id，所以这条只能从入口这一层钉。
  // 变异：删掉 open_export_dialog.dart 里传给 showExportVideoDialog 的 pinnedBySource ⇒ 默认勾回最新的 clip-new，
  // 本条红在 clip-old 那行的勾选态。
  testWidgets('⌘K 导出：默认勾选配置节点固定的那条 take，不是最新那条', (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_PinnedTakeNodesController.new),
      canvasEdgesControllerProvider.overrideWith(_NoEdgesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas(
          'c1',
          withProject: const ProjectRef(id: 'p1', name: 'Alpha'),
        );
    await _warmNodes(container, 'c1');
    await _warmEdges(container, 'c1');
    await _pressCtrlK(tester);

    await tester.tap(find.text('Export video'));
    await tester.pumpAndSettle();

    // 候选集不收窄：两条都列着。
    expect(find.text('clip-old'), findsOneWidget);
    expect(find.text('clip-new'), findsOneWidget);
    expect(_checkedOnRowOf(tester, 'clip-old'), isTrue, reason: '固定的那条默认勾上');
    expect(_checkedOnRowOf(tester, 'clip-new'), isFalse, reason: '更新但没固定的那条默认不勾');
    // 「旧 take」标记跟着当前集走：挂在没固定的 clip-new 那一行。
    expect(find.text('Earlier take'), findsOneWidget);
    expect(
      (tester.getCenter(find.text('Earlier take')).dy -
              tester.getCenter(find.text('clip-new')).dy)
          .abs(),
      lessThan((tester.getCenter(find.text('Earlier take')).dy -
              tester.getCenter(find.text('clip-old')).dy)
          .abs()),
      reason: '「旧 take」标在 clip-new 那行',
    );
  });

  testWidgets('键盘 ↓ + Enter 执行第二项（Add video node 真实触达 controller）',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider
          .overrideWith(_RecordingNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(_RecordingNodesController.added, <CanvasNodeType>[
      CanvasNodeType.video,
    ]);
  });

  // 建节点失败要说一声：画布上什么都没多出来，不说 = 用户以为命令没执行。
  // 提示走全应用的通知出口（错误卡，不自动消失），不再是 Material 的底部提示条。
  testWidgets('Add image node 失败 → 错误卡「Failed to add node」', (tester) async {
    final toast = RecordingToastService();
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_FailingNodesController.new),
      toastServiceProvider.overrideWithValue(toast),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    await tester.tap(find.text('Add image node'));
    await tester.pumpAndSettle();

    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(toast.titles, <String>['Failed to add node']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
  });

  testWidgets('搜索过滤动作；无命中显示 no-results 文案', (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    await tester.enterText(find.byType(TextField), 'image');
    await tester.pumpAndSettle();
    expect(find.text('Add image node'), findsOneWidget);
    expect(find.text('Add video node'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching commands'), findsOneWidget);
  });

  testWidgets('Back to Studio 动作切回 studio 标签，canvasId 与会话记录都不动',
      (tester) async {
    final prefs = InMemoryPreferencesService(
      const AppPreferences(lastCanvasId: 'cv-saved', lastProjectId: 'p-saved'),
    );
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
      preferencesServiceProvider.overrideWithValue(prefs),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    await tester.tap(find.text('Back to Studio'));
    await tester.pumpAndSettle();

    // T6：goTab(studio) 不清 canvasId——保活宿主在 T7 落地后，画布标签
    // 应继续持有 'c1'，只是不再是当前可见标签。
    expect(container.read(shellControllerProvider).tab, ShellTab.studio);
    expect(container.read(currentCanvasIdProvider), 'c1');
    // T11：这条动作【不再】写 clearLastCanvas。标签模型下切到 Studio 标签
    // 不等于关闭画布，而「下次启动是否回到上次画布」的唯一真相源是
    // shellKeepLastCanvas 开关——⌘K 不该背着用户把记录清掉。
    expect(prefs.current.lastCanvasId, 'cv-saved');
    expect(prefs.current.lastProjectId, 'p-saved');
  });

  // fix round 2（R34）：overlay-first 动作集此前零测试覆盖。画布上开着
  // Settings 时按 ⌘K 应该拿到 Settings 上下文动作集，而不是对着当前不可见
  // 画布动刀的 addNode/export 动作集（command_actions.dart 的
  // tab==canvas 判据在 overlay!=null 时短路，见 R33/M-4）。
  // fix round 3（R39）：节点集换成 _ExportableNodesController——
  // _EmptyNodesController 下 canExport 恒 false，'Export video' 那条
  // findsNothing 即便判序坏掉也不会出现，鉴别力为零，纯装饰。
  testWidgets('画布上开着 Settings 时按 ⌘K → 只有 Settings 动作集，没有画布动作',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider
          .overrideWith(_ExportableNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    container
        .read(shellControllerProvider.notifier)
        .openOverlay(ShellOverlay.settings);
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    expect(find.text('Back to Studio'), findsOneWidget);
    expect(find.text('Add image node'), findsNothing);
    expect(find.text('Add video node'), findsNothing);
    expect(find.text('Add shot node'), findsNothing);
    expect(find.text('Export video'), findsNothing);
  });

  // fix round 3（R38）：command_actions.dart:72 的 tab==canvas 判据此前零
  // 覆盖——R34 那条走 overlay 短路，测不到这里。失败场景：T7 重构时若丢掉
  // 这行判据，回到 Studio 后 ⌘K 仍会拿到对着【当前不可见】画布动刀的
  // addNode/export 动作集，往后台画布里静默塞节点。
  testWidgets('回到 Studio 后按 ⌘K → 不再是画布动作集，是 Studio 动作集',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    container.read(shellControllerProvider.notifier).goTab(ShellTab.studio);
    await _pressCtrlK(tester);

    expect(find.text('Add image node'), findsNothing);
    expect(find.text('Add video node'), findsNothing);
    expect(find.text('Add shot node'), findsNothing);
    expect(find.text('Import project…'), findsOneWidget);
  });

  // ---- 视觉重做（Screens 稿第 4 屏右）：三组 + 范围说明 + 计数 ----

  testWidgets('有查询词时出「镜头 · 当前画布」组：只搜当前画布已加载的 config 节点',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_ShotNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas(
          'c1',
          withProject: const ProjectRef(id: 'p1', name: 'Alpha'),
        );
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    // 空查询：只有动作组，镜头组不出现（不是搜索结果）。
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Shots · current canvas'), findsNothing);

    await tester.enterText(find.byType(TextField), 'sun');
    await tester.pumpAndSettle();
    expect(find.text('Shots · current canvas'), findsOneWidget);
    expect(find.text('Sunrise'), findsOneWidget);
    expect(find.text('Actions'), findsNothing, reason: '没有动作匹配 sun');
    expect(find.text('1 results'), findsOneWidget);
  });

  testWidgets('镜头路径第三段：在叙事链上写「序列 NNN」（链序，不是原序），链外写节点类型',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_ChainShotsController.new),
      canvasEdgesControllerProvider.overrideWith(_ChainEdgesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _warmEdges(container, 'c1');
    await _pressCtrlK(tester);
    await tester.enterText(find.byType(TextField), 'cfg');
    await tester.pumpAndSettle();

    // 链 cfg-b → cfg-a：b 是 001、a 是 002；lone 不在链上 ⇒ 类型名。
    expect(find.textContaining('Sequence 001'), findsOneWidget);
    expect(find.textContaining('Sequence 002'), findsOneWidget);
    final String pathA = tester.widget<Text>(find.textContaining('Sequence 002')).data!;
    final String pathB = tester.widget<Text>(find.textContaining('Sequence 001')).data!;
    expect(tester.getTopLeft(find.text(pathA)).dy, lessThan(tester.getTopLeft(find.text(pathB)).dy),
        reason: '条目顺序是节点原序（cfg-a 在前、序号 002），序号却按链序——序号不是行号');
    expect(find.textContaining('Sequence 003'), findsNothing);
    expect(find.textContaining('Image'), findsWidgets, reason: 'cfg-lone 不在链上 ⇒ 第三段是类型名');
  });

  testWidgets('镜头路径的「序列 NNN」是序列的口径：借出产物的图像配置与镜头同号，后面的镜不往后挪', (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_SceneShotsController.new),
      canvasEdgesControllerProvider.overrideWith(_SceneEdgesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _warmEdges(container, 'c1');
    await _pressCtrlK(tester);
    await tester.enterText(find.byType(TextField), 'scene');
    await tester.pumpAndSettle();

    // 链上 DFS 序是 Scene 1、Scene 2、Scene 2 image、Scene 3；序列把 Scene 2 image 的图放进 Scene 2 那一镜，
    // 所以只有三镜——与序列视图、画廊（「序列 002」）、左栏大纲同一个号。
    expect(find.textContaining('Sequence 001'), findsOneWidget);
    expect(find.textContaining('Sequence 002'), findsNWidgets(2), reason: 'Scene 2 与 Scene 2 image 同一镜');
    expect(find.textContaining('Sequence 003'), findsOneWidget, reason: 'Scene 3 是第三镜');
    expect(find.textContaining('Sequence 004'), findsNothing);
  });

  testWidgets('「设置项」组不存在；Studio 上下文有查询词也只出动作组', (tester) async {
    await _pumpShell(tester);
    await _pressCtrlK(tester);
    await tester.enterText(find.byType(TextField), 'settings');
    await tester.pumpAndSettle();

    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Shots · current canvas'), findsNothing);
    expect(find.text('Artifacts'), findsNothing);
  });

  testWidgets('↵ 打开镜头条目 = 挂起该节点的定位请求；面板关闭', (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_ShotNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    // 本外壳没挂画布：⌘K 只负责挂起请求；请求在画布上落地（单选 + 移到视口中心）由
    // canvas_focus_request_test.dart 钉。
    await _pressCtrlK(tester);
    await tester.enterText(find.byType(TextField), 'sunrise');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(
      container.read(canvasFocusRequestProvider),
      const CanvasFocusRequest(canvasId: 'c1', nodeId: 'img'),
    );
  });
}
