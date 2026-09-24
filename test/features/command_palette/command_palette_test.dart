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
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_shortcuts.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/app_theme.dart';

import '../../_harness/fake_repositories.dart';
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
class _ChainShotsController extends CanvasNodesController {
  @override
  Future<List<CanvasNode>> build(String canvasId) async => <CanvasNode>[
        CanvasNode(id: 'cfg-a', label: 'cfg-a', type: CanvasNodeType.image, canvasId: canvasId),
        CanvasNode(id: 'cfg-b', label: 'cfg-b', type: CanvasNodeType.image, canvasId: canvasId),
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
    Offset position = Offset.zero,
    Size? size,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    added.add(type);
    return CanvasNode(id: 'n1', label: label, type: type, canvasId: arg);
  }
}

/// 导入流程测试用 fake service。
class _FakeImportService implements ProjectImportService {
  @override
  Future<ImportResult> importArchive({required String zipPath}) async =>
      const ImportResult(outcome: ImportOutcome.failed);
}

/// 记录 toast 调用的 fake。
class _RecordingToast implements ToastService {
  final List<String> messages = [];

  @override
  void show(String message, {ToastKind kind = ToastKind.info}) {
    messages.add(message);
  }
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
    final toast = _RecordingToast();
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
  });

  testWidgets('showcase 上下文可返回 Studio 或打开设置', (tester) async {
    final container = await _pumpShell(tester);
    container
        .read(shellControllerProvider.notifier)
        .openOverlay(ShellOverlay.showcase);
    await _pressCtrlK(tester);

    expect(find.text('Back to Studio'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);

    await tester.tap(find.text('Back to Studio'));
    await tester.pumpAndSettle();
    expect(container.read(shellControllerProvider).tab, ShellTab.studio);
    // fix round 18（R88）：上面那条 tab 断言是**恒真**的——_pumpShell 的起始
    // tab 本来就是 studio，而 openOverlay(showcase) 不动 tab。把 _backToStudio
    // 的 run 改成空实现，它照绿。真正说明"返回 Studio"发生过的是浮层被关掉。
    // 实跑：把 run 改成 `(context, ref) async {}` → 上面那条 tab 断言【仍绿】，
    // 只有下面这条红（:270 Expected null, Actual ShellOverlay.showcase）。
    expect(
      container.read(shellControllerProvider).overlay,
      isNull,
      reason: 'goTab 必须顺带关掉浮层，否则用户点了「Back to Studio」还困在示例里',
    );
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
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    expect(find.text('Export video'), findsOneWidget);
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

  testWidgets('↵ 打开镜头条目 = 在画布里选中该节点；面板关闭', (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_ShotNodesController.new),
    ]);
    container.read(shellControllerProvider.notifier).openCanvas('c1');
    await _warmNodes(container, 'c1');
    // 选择集 provider 是 autoDispose：真 app 里画布常驻 watch，这里补一个监听，
    // 否则动作写完的选中态会在断言前被回收成空集。
    container.listen(canvasSelectionControllerProvider('c1'), (_, _) {});
    await _pressCtrlK(tester);
    await tester.enterText(find.byType(TextField), 'sunrise');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CommandPaletteDialog), findsNothing);
    expect(container.read(canvasSelectionControllerProvider('c1')), <String>{'img'});
  });
}
