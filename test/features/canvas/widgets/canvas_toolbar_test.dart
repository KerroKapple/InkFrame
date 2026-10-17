// CanvasToolbar：画布舞台顶部居中的浮动工具条（取代左侧 37px 工具条与右下角加号）。
//
// 钉住的几件事：
// 1. 九个键的顺序与图标（图标集 v1，20px）；tooltip =「名称  键位」，键位与快捷键表同源。
// 2. 模式键：默认选择亮；点平移 → 平移亮、选择暗；按住空格（临时平移）平移键也亮。
// 3. 建节点键：图像 / 视频 / 文本 / 分镜各建对应类型；写库失败 → 错误卡「Failed to add node」。
// 4. 连线键：没选中 / 选中两个时禁用；恰好选中一个时可按，点了以它为源进连线，再点退出。
// 5. 泳道键开「新建泳道」框、保存即建；更多 → 导入脚本… 开脚本导入框（不建节点）；「更多」的项 = kMoreMenuActionIds
//    逐项取动作表的行，不能用的灰着、悬停说原因。
// 6. 键盘可达：聚焦后回车 = 点击；不可按的键不可聚焦。
//
// 写库走真控制器 + 内存仓储（与旧加号测试同一套），失败卡覆盖成 RecordingToastService 断言。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/app_actions/app_action_catalog.dart';
import 'package:inkframe/features/app_actions/app_action_ids.dart';
import 'package:inkframe/features/canvas/util/more_menu_model.dart';
import 'package:inkframe/features/canvas/widgets/canvas_toolbar.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/storyboard/widgets/script_import_dialog.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/a11y.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const String _canvasId = 'cv1';

/// 键 id → 该键应画的图标，按稿上的显示顺序。
const List<(String, InkGlyph)> _order = <(String, InkGlyph)>[
  ('select', InkGlyph.select),
  ('pan', InkGlyph.pan),
  ('image', InkGlyph.imageConfig),
  ('video', InkGlyph.videoConfig),
  ('text', InkGlyph.text),
  ('shot', InkGlyph.shot),
  ('lane', InkGlyph.lane),
  ('link', InkGlyph.link),
  ('more', InkGlyph.more),
];

/// create 一律抛 InkError 的节点仓储：走到「添加节点失败」那条提示。
class _FailingNodeRepository extends InMemoryNodeRepository {
  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) async =>
      throw const LocalIOError();
}

/// 外壳默认播种成「画布标签在前台、打开的是 cv1」：「更多」的项取动作表的行，判据看外壳此刻看得见的画布
/// （生产里工具条只在画布标签可见时点得到，外壳的 canvasId 就是它这张）。
const ShellState _onCanvas = ShellState(tab: ShellTab.canvas, canvasId: _canvasId);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  InMemoryNodeRepository? nodeRepo,
  InMemoryStyleLaneRepository? laneRepo,
  RecordingToastService? toast,
  ShellState shell = _onCanvas,
}) async {
  final InMemoryNodeRepository nodes = nodeRepo ?? InMemoryNodeRepository();
  final InMemoryStyleLaneRepository lanes =
      laneRepo ?? InMemoryStyleLaneRepository();
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: CanvasToolbar(canvasId: _canvasId),
      ),
    ),
    overrides: <Override>[
      nodeRepositoryProvider.overrideWith((ref) async => nodes),
      styleLaneRepositoryProvider.overrideWith((ref) async => lanes),
      toastServiceProvider.overrideWithValue(toast ?? RecordingToastService()),
      shellControllerProvider.overrideWith(() => ShellNavigator(initial: shell)),
    ],
    surfaceSize: const Size(800, 600),
  );
  await tester.pumpAndSettle();
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(CanvasToolbar)),
  );
  // 预热两个仓储：控制器的写方法在入口同步取仓储，仓储还没解析出来就抛 StateError。
  // 生产里舞台常驻 watch 节点 / 泳道，这一步天然发生。
  await container.read(canvasNodesControllerProvider(_canvasId).future);
  await container.read(canvasLanesControllerProvider(_canvasId).future);
  await tester.pump();
  return container;
}

Finder _key(String id) => find.byKey(CanvasToolbar.keyOf(id));

InkIcon _iconOf(WidgetTester tester, String id) => tester.widget<InkIcon>(
      find.descendant(of: _key(id), matching: find.byType(InkIcon)),
    );

void main() {
  testWidgets('九个键按稿的顺序排开，各画图标集 v1 的对应图标（20px）', (tester) async {
    await _pump(tester);

    double? lastX;
    for (final (String id, InkGlyph glyph) in _order) {
      expect(_key(id), findsOneWidget, reason: id);
      final InkIcon icon = _iconOf(tester, id);
      expect(icon.glyph, glyph, reason: '$id 键的图标');
      expect(icon.size, InkIconSize.md, reason: '$id 键的图标尺寸');
      final double x = tester.getCenter(_key(id)).dx;
      if (lastX != null) {
        expect(x, greaterThan(lastX), reason: '$id 应排在前一个键的右边');
      }
      lastX = x;
    }
  });

  testWidgets('tooltip =「名称  键位」；平移键另带「按住空格」，分镜 / 更多只有名称',
      (tester) async {
    await _pump(tester);

    expect(find.byTooltip('Select  V'), findsOneWidget);
    expect(find.byTooltip('Pan  H · hold Space'), findsOneWidget);
    expect(find.byTooltip('Image node  I'), findsOneWidget);
    expect(find.byTooltip('Video node  G'), findsOneWidget);
    expect(find.byTooltip('Text node  T'), findsOneWidget);
    expect(find.byTooltip('Shot node'), findsOneWidget);
    expect(find.byTooltip('Lane  F'), findsOneWidget);
    expect(find.byTooltip('Link  L'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
  });

  testWidgets('默认选择键亮；点平移 → 平移亮、选择暗；点选择 → 回来', (tester) async {
    final ProviderContainer container = await _pump(tester);
    final InkColors c = InkColors.dark();

    expect(_iconOf(tester, 'select').color, c.accent);
    expect(_iconOf(tester, 'pan').color, c.fg3);

    await tester.tap(_key('pan'));
    await tester.pump();
    expect(container.read(canvasToolModeProvider(_canvasId)), CanvasToolMode.pan);
    expect(_iconOf(tester, 'pan').color, c.accent);
    expect(_iconOf(tester, 'select').color, c.fg3);

    await tester.tap(_key('select'));
    await tester.pump();
    expect(
      container.read(canvasToolModeProvider(_canvasId)),
      CanvasToolMode.select,
    );
    expect(_iconOf(tester, 'select').color, c.accent);
    expect(_iconOf(tester, 'pan').color, c.fg3);
  });

  testWidgets('按住空格临时平移时平移键也亮（亮的是实际在用的工具），工具态不变',
      (tester) async {
    final ProviderContainer container = await _pump(tester);
    final InkColors c = InkColors.dark();

    container.read(canvasSpacePanProvider(_canvasId).notifier).hold();
    await tester.pump();
    expect(_iconOf(tester, 'pan').color, c.accent);
    expect(_iconOf(tester, 'select').color, c.fg3);
    expect(
      container.read(canvasToolModeProvider(_canvasId)),
      CanvasToolMode.select,
      reason: '空格只是临时平移，不改工具态——松开要回得去',
    );

    container.read(canvasSpacePanProvider(_canvasId).notifier).release();
    await tester.pump();
    expect(_iconOf(tester, 'select').color, c.accent);
  });


  for (final (String id, String type) in <(String, String)>[
    ('image', 'image'),
    ('video', 'video'),
    ('text', 'text'),
    ('shot', 'shot'),
  ]) {
    testWidgets('点「$id」键 → 建一个 $type config 节点', (tester) async {
      final InMemoryNodeRepository nodeRepo = InMemoryNodeRepository();
      await _pump(tester, nodeRepo: nodeRepo);

      await tester.tap(_key(id));
      await tester.pumpAndSettle();

      expect(nodeRepo.rows, hasLength(1));
      expect(nodeRepo.rows.values.single['type'], type);
      expect(nodeRepo.rows.values.single['node_role'], 'config');
    });
  }

  // 建节点失败要说一声：画布上什么都没多出来，不说 = 用户以为键点空了。
  testWidgets('建节点写库失败 → 错误卡「Failed to add node」，库里没多出节点',
      (tester) async {
    final _FailingNodeRepository nodeRepo = _FailingNodeRepository();
    final RecordingToastService toast = RecordingToastService();
    await _pump(tester, nodeRepo: nodeRepo, toast: toast);

    await tester.tap(_key('image'));
    await tester.pumpAndSettle();

    expect(nodeRepo.rows, isEmpty);
    expect(toast.titles, <String>['Failed to add node']);
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
  });

  testWidgets('连线键：没选中 / 选中两个时禁用；恰好选中一个时可按，点了以它为源进连线，再点退出',
      (tester) async {
    final ProviderContainer container = await _pump(tester);
    final InkColors c = InkColors.dark();
    final CanvasSelectionController selection =
        container.read(canvasSelectionControllerProvider(_canvasId).notifier);

    expect(_iconOf(tester, 'link').color, c.fg6, reason: '没选中节点：不知道从哪个节点连出去');
    await tester.tap(_key('link'));
    await tester.pump();
    expect(container.read(linkModeControllerProvider(_canvasId)), isNull);

    selection.select('n1');
    selection.select('n2', toggle: true);
    await tester.pump();
    expect(_iconOf(tester, 'link').color, c.fg6, reason: '选中两个同样不可按');

    selection.select('n1');
    await tester.pump();
    expect(_iconOf(tester, 'link').color, c.fg3);

    await tester.tap(_key('link'));
    await tester.pump();
    expect(container.read(linkModeControllerProvider(_canvasId)), 'n1');
    expect(_iconOf(tester, 'link').color, c.accent, reason: '连线模式下连线键亮');
    expect(_iconOf(tester, 'select').color, c.fg3, reason: '连线模式下选择键不亮');

    await tester.tap(_key('link'));
    await tester.pump();
    expect(
      container.read(linkModeControllerProvider(_canvasId)),
      isNull,
      reason: '再点一次 = 退出连线',
    );
  });

  testWidgets('平移工具里进连线 → 工具回到选择（连线下一步要点目标节点，平移时卡片点不到）',
      (tester) async {
    final ProviderContainer container = await _pump(tester);
    container.read(canvasToolModeProvider(_canvasId).notifier).pan();
    container
        .read(canvasSelectionControllerProvider(_canvasId).notifier)
        .select('n1');
    await tester.pump();

    await tester.tap(_key('link'));
    await tester.pump();

    expect(container.read(linkModeControllerProvider(_canvasId)), 'n1');
    expect(
      container.read(canvasToolModeProvider(_canvasId)),
      CanvasToolMode.select,
    );
  });

  testWidgets('连线模式下点选择键 = 退出连线（与旧左侧工具条「选择」同义）', (tester) async {
    final ProviderContainer container = await _pump(tester);
    container.read(linkModeControllerProvider(_canvasId).notifier).start('n1');
    await tester.pump();

    await tester.tap(_key('select'));
    await tester.pump();

    expect(container.read(linkModeControllerProvider(_canvasId)), isNull);
    expect(_iconOf(tester, 'select').color, InkColors.dark().accent);
  });

  testWidgets('泳道键开「新建泳道」框，保存即建一条泳道', (tester) async {
    final InMemoryStyleLaneRepository laneRepo = InMemoryStyleLaneRepository();
    await _pump(tester, laneRepo: laneRepo);

    await tester.tap(_key('lane'));
    await tester.pumpAndSettle();
    expect(find.text('New lane'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Day');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(laneRepo.rows, hasLength(1));
    expect(laneRepo.rows.values.single['label'], 'Day');
  });

  testWidgets('更多 → 「导入脚本…」开脚本导入框（不建节点）', (tester) async {
    final InMemoryNodeRepository nodeRepo = InMemoryNodeRepository();
    await _pump(tester, nodeRepo: nodeRepo);

    await tester.tap(_key('more'));
    await tester.pumpAndSettle();
    expect(find.text('Import script…'), findsOneWidget);

    await tester.tap(find.text('Import script…'));
    await tester.pumpAndSettle();

    expect(find.byType(ScriptImportDialog), findsOneWidget);
    expect(nodeRepo.rows, isEmpty, reason: '打开对话框本身不该建节点');
  });

  testWidgets('更多 = kMoreMenuActionIds 逐项：项数一致，文字依次是动作表里那一行的文案', (tester) async {
    await _pump(tester);
    final AppLocalizations l =
        AppLocalizations.of(tester.element(find.byType(CanvasToolbar)));

    await tester.tap(_key('more'));
    await tester.pumpAndSettle();

    final Finder items =
        find.byWidgetPredicate((Widget w) => w is PopupMenuItem<String>);
    expect(items, findsNWidgets(kMoreMenuActionIds.length));
    double? lastY;
    for (int i = 0; i < kMoreMenuActionIds.length; i++) {
      final String label = appActionById(kMoreMenuActionIds[i])!.label(l);
      final Finder text =
          find.descendant(of: items.at(i), matching: find.text(label));
      expect(text, findsOneWidget, reason: '第 ${i + 1} 项应是「$label」');
      final double y = tester.getTopLeft(text).dy;
      if (lastY != null) expect(y, greaterThan(lastY), reason: label);
      lastY = y;
    }
  });

  // 不可用的项灰着不藏，悬停说原因（外壳此刻没有看得见的画布 ⇒ 导入剧本「先打开一个画布」）。
  testWidgets('更多：不能用的项灰着、带原因 tooltip，点了不执行', (tester) async {
    final InMemoryNodeRepository nodeRepo = InMemoryNodeRepository();
    await _pump(tester, nodeRepo: nodeRepo, shell: const ShellState());
    final AppLocalizations l =
        AppLocalizations.of(tester.element(find.byType(CanvasToolbar)));

    await tester.tap(_key('more'));
    await tester.pumpAndSettle();

    final String label = appActionById(AppActionIds.importScript)!.label(l);
    final PopupMenuItem<String> item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((Widget w) => w is PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);
    expect(find.byTooltip(l.appActionReasonOpenCanvas), findsOneWidget);

    await tester.tap(find.text(label), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ScriptImportDialog), findsNothing);
  });

  testWidgets('键盘可达：聚焦图像键按回车 = 点它；不可按的连线键也不可聚焦', (tester) async {
    final InMemoryNodeRepository nodeRepo = InMemoryNodeRepository();
    await _pump(tester, nodeRepo: nodeRepo);

    final FocusNode image = activatableFocus(tester, CanvasToolbar.keyOf('image'));
    expect(await tabUntilFocused(tester, image), isTrue, reason: '图像键 Tab 得到');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(nodeRepo.rows.values.single['type'], 'image');
    expect(
      activatableFocus(tester, CanvasToolbar.keyOf('link')).canRequestFocus,
      isFalse,
      reason: '没选中节点时连线键不可按，也不该能被 Tab 到',
    );
  });
}
