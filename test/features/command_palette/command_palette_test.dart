// PL-1 ⌘K 命令面板：唤起/关闭/键盘导航/搜索过滤/上下文动作集/执行语义。
// 测试平台默认 android → 用 Ctrl+K 绑定（macOS 走 meta 绑定，同一实现）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/current_screen.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_dialog.dart';
import 'package:inkframe/features/command_palette/widgets/command_palette_shortcuts.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

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
    Size size = const Size(200, 160),
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async {
    added.add(type);
    return CanvasNode(id: 'n1', label: label, type: type, canvasId: arg);
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
    expect(container.read(currentScreenProvider), AppScreen.settings);
  });

  testWidgets('canvas 上下文动作集：三种新建节点 + 返回/设置；无可导出节点时不出 Export video',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
    ]);
    container.read(currentCanvasIdProvider.notifier).state = 'c1';
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
    container.read(currentCanvasIdProvider.notifier).state = 'c1';
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
    container.read(currentCanvasIdProvider.notifier).state = 'c1';
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
    container.read(currentCanvasIdProvider.notifier).state = 'c1';
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

  testWidgets('Back to Studio 动作清空 currentCanvasIdProvider 并回 studio',
      (tester) async {
    final container = await _pumpShell(tester, overrides: <Override>[
      canvasNodesControllerProvider.overrideWith(_EmptyNodesController.new),
    ]);
    container.read(currentCanvasIdProvider.notifier).state = 'c1';
    await _warmNodes(container, 'c1');
    await _pressCtrlK(tester);

    await tester.tap(find.text('Back to Studio'));
    await tester.pumpAndSettle();

    expect(container.read(currentCanvasIdProvider), isNull);
    expect(container.read(currentScreenProvider), AppScreen.studio);
  });
}
