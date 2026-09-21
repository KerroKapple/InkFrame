// PL-1 ⌘K 命令面板：唤起/关闭/键盘导航/搜索过滤/上下文动作集/执行语义。
// 测试平台默认 android → 用 Ctrl+K 绑定（macOS 走 meta 绑定，同一实现）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/project_archive.dart';
import 'package:inkframe/core/interfaces/project_import_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_shortcuts.dart';
import 'package:inkframe/features/generation/services/toast_service.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

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
  final container = ProviderContainer(overrides: overrides);
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

  testWidgets('Back to Studio 动作切回 studio 标签，canvasId 保持不变',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
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
}
