// 左栏素材页第三段「参考库」（reference_library_section.dart）。
//
// 前几组直接 pump 本段（ProviderScope 覆盖参考库 reader / 选文件夹 / 偏好设置 / 画布节点与边），最后一组走外壳，
// 钉分段切换：切到参考库再切回「本画布」，原来的画廊网格还在、两边内容不串。
//
// 钉：
//   - 没选文件夹 ⇒ 空态 + 「选择参考库文件夹」，不画网格；点它 ⇒ 调 picker，再 set(path)：reader 读到那个路径，
//     偏好设置也存下了它。
//   - reader 返回 NotFound（选成了图库上一级 / data 下一级）⇒ 显示「这个文件夹里没找到参考库」+ 重新选择，不画网格
//     （Review Focus 1）。
//   - 读到了 ⇒ 默认姿势，chip 计数对；切到人像只剩人像；搜索过滤并改计数。
//   - 视角只对姿势生效：选了「正面」再切到人像，人像照样全出来。
//   - 没有选中节点时点格子 ⇒ 菜单「当姿势参考」置灰（节点名的位置写原因），「只放进画布」可点，「存为角色」只对人像可点；
//     选中的是 shot ⇒ 置灰，原因另起一行。
//
// 变异对照：filterReferenceItems 的 angle 不按类别过（总是传 _angle）⇒「视角只对姿势生效」红；
// 空态分支删掉 NotFound（落到网格）⇒「NotFound」红；菜单 attach 的 enabled 写死 true ⇒「没有选中」红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/preferences.dart';
import 'package:inkframe/core/di/reference_library.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/reference_library_reader.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/reference_item.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/left_rail_state.dart';
import 'package:inkframe/features/canvas/widgets/canvas_menu/canvas_menu_popover.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_model.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/assets_panel.dart';
import 'package:inkframe/features/canvas/widgets/left_rail/reference_library_section.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/services/file_preferences_service.dart';
import 'package:inkframe/theme/components/ink_menu_panel.dart';

import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/fake_repositories.dart';
import '../../../../_harness/fake_toast_service.dart';
import '../../../../_harness/shell_app.dart';
import '../../../../_harness/test_app.dart';

// ===== 夹具 =====

ReferenceItem _item(
  String id, {
  ReferenceCategory category = ReferenceCategory.pose,
  String? angle,
  required String searchText,
}) =>
    ReferenceItem(
      id: id,
      category: category,
      name: 'Name $id',
      group: 'g',
      angle: angle,
      thumbPath: 'D:/__missing__/thumbs/$id.webp',
      originalPath: 'D:/__missing__/img/$id.webp',
      searchText: searchText,
    );

final List<ReferenceItem> _items = <ReferenceItem>[
  _item('p1', angle: '正面', searchText: 'standing 站姿'),
  _item('p2', angle: '侧面', searchText: 'sitting 坐姿'),
  _item('r1', category: ReferenceCategory.portrait, searchText: 'short hair 短发'),
  _item('r2', category: ReferenceCategory.portrait, searchText: 'long hair 长发'),
  _item('c1', category: ReferenceCategory.costume, searchText: 'spring coat 春季'),
];

/// reader：记下读了哪些路径，每次都返回 [result]。
class _Reader implements ReferenceLibraryReader {
  _Reader(this.result);
  final ReferenceLibraryLoad result;
  final List<String> loaded = <String>[];

  @override
  Future<ReferenceLibraryLoad> load(String rootPath) async {
    loaded.add(rootPath);
    return result;
  }
}

class _Nodes extends CanvasNodesController {
  _Nodes(this._seed);
  final List<CanvasNode> _seed;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _seed;
}

class _Edges extends CanvasEdgesController {
  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[];
}

typedef _Rig = ({ProviderContainer container, _Reader reader, InMemoryPreferencesService prefs, List<int> picks});

Future<_Rig> _pump(
  WidgetTester tester, {
  String? root = 'D:/lib',
  ReferenceLibraryLoad? result,
  List<CanvasNode> nodes = const <CanvasNode>[],
  String? pickResult = 'D:/picked',
}) async {
  final _Reader reader =
      _Reader(result ?? ReferenceLibraryLoaded(_items, const <String>[]));
  final InMemoryPreferencesService prefs =
      InMemoryPreferencesService(AppPreferences(referenceLibraryRoot: root));
  final List<int> picks = <int>[];
  await pumpInkApp(
    tester,
    const Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 241,
          height: 700,
          child: ReferenceLibrarySection(canvasId: 'c1'),
        ),
      ),
    ),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: const ShellState(
            tab: ShellTab.canvas,
            canvasId: 'c1',
            project: ProjectRef(id: 'p1', name: 'Alpha'),
          ),
        ),
      ),
      preferencesServiceProvider.overrideWithValue(prefs),
      referenceLibraryReaderProvider.overrideWithValue(reader),
      referenceFolderPickerProvider.overrideWithValue(() async {
        picks.add(1);
        return pickResult;
      }),
      canvasNodesControllerProvider.overrideWith(() => _Nodes(nodes)),
      canvasEdgesControllerProvider.overrideWith(_Edges.new),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
    surfaceSize: const Size(800, 800),
  );
  await tester.pumpAndSettle();
  final ProviderContainer c = ProviderScope.containerOf(
    tester.element(find.byType(ReferenceLibrarySection)),
    listen: false,
  );
  // 选中集是 autoDispose：挂住它（画布开着时它就活着）。
  final ProviderSubscription<Set<String>> keep =
      c.listen(canvasSelectionControllerProvider('c1'), (_, _) {});
  addTearDown(keep.close);
  return (container: c, reader: reader, prefs: prefs, picks: picks);
}

AppLocalizations _l(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ReferenceLibrarySection)));

Finder _tile(String id) => find.byKey(ReferenceLibrarySection.tileKey(id));

/// 开着的格子菜单的分组（直接读弹层收到的 groups）。
List<List<InkMenuEntry<ReferenceMenuAction>>> _menuGroups(WidgetTester tester) => tester
    .widget<CanvasMenuPopover<ReferenceMenuAction>>(
      find.byType(CanvasMenuPopover<ReferenceMenuAction>),
    )
    .groups;

InkMenuEntry<ReferenceMenuAction> _entry(WidgetTester tester, ReferenceMenuAction a) =>
    _menuGroups(tester)
        .expand((List<InkMenuEntry<ReferenceMenuAction>> g) => g)
        .firstWhere((InkMenuEntry<ReferenceMenuAction> e) => e.value == a);

void main() {
  group('空态', () {
    testWidgets('没选文件夹 ⇒ 说明 + 选择按钮、没有网格；点按钮 ⇒ picker → set(path)，reader 读那个路径', (tester) async {
      final _Rig rig = await _pump(tester, root: null);
      final AppLocalizations l = _l(tester);

      expect(find.text(l.referenceEmptyNoFolder), findsOneWidget);
      expect(find.byKey(ReferenceLibrarySection.pickFolderKey), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(rig.reader.loaded, isEmpty, reason: '没选文件夹不读');

      await tester.tap(find.byKey(ReferenceLibrarySection.pickFolderKey));
      await tester.pumpAndSettle();

      expect(rig.picks, hasLength(1));
      expect(rig.container.read(referenceLibraryRootProvider), 'D:/picked');
      expect(rig.prefs.current.referenceLibraryRoot, 'D:/picked', reason: '落进偏好设置');
      expect(rig.reader.loaded, <String>['D:/picked']);
      expect(_tile('p1'), findsOneWidget, reason: '选好之后网格出来');
    });

    testWidgets('picker 取消 ⇒ 什么都不改', (tester) async {
      final _Rig rig = await _pump(tester, root: null, pickResult: null);
      await tester.tap(find.byKey(ReferenceLibrarySection.pickFolderKey));
      await tester.pumpAndSettle();

      expect(rig.picks, hasLength(1));
      expect(rig.container.read(referenceLibraryRootProvider), isNull);
      expect(rig.reader.loaded, isEmpty);
    });

    testWidgets('文件夹里没有参考库（NotFound）⇒「没找到参考库」+ 重新选择，不画网格（Review Focus 1）', (tester) async {
      await _pump(tester, result: const ReferenceLibraryNotFound());
      final AppLocalizations l = _l(tester);

      expect(find.text(l.referenceEmptyNotFound), findsOneWidget);
      expect(find.byKey(ReferenceLibrarySection.pickFolderKey), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });
  });

  group('浏览', () {
    testWidgets('默认姿势、chip 计数对；切到人像只剩人像；搜索过滤并改计数', (tester) async {
      await _pump(tester);
      final AppLocalizations l = _l(tester);

      expect(find.text(l.referenceCategoryPose(2)), findsOneWidget);
      expect(find.text(l.referenceCategoryPortrait(2)), findsOneWidget);
      expect(find.text(l.referenceCategoryCostume(1)), findsOneWidget);
      expect(_tile('p1'), findsOneWidget);
      expect(_tile('p2'), findsOneWidget);
      expect(_tile('r1'), findsNothing);

      await tester.tap(find.byKey(ReferenceLibrarySection.categoryKey(ReferenceCategory.portrait)));
      await tester.pumpAndSettle();
      expect(_tile('r1'), findsOneWidget);
      expect(_tile('r2'), findsOneWidget);
      expect(_tile('p1'), findsNothing);
      expect(_tile('c1'), findsNothing);
      expect(find.text(l.referenceAngleAll), findsNothing, reason: '视角行只在姿势下出');

      await tester.enterText(find.byType(TextField), 'SHORT');
      await tester.pumpAndSettle();
      expect(_tile('r1'), findsOneWidget);
      expect(_tile('r2'), findsNothing);
      expect(find.text(l.referenceCategoryPortrait(1)), findsOneWidget);
      expect(find.text(l.referenceCategoryPose(0)), findsOneWidget);
    });

    testWidgets('视角只对姿势生效：选「正面」只剩正面；切到人像，人像照样全出来', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(ReferenceLibrarySection.angleKey('正面')));
      await tester.pumpAndSettle();
      expect(_tile('p1'), findsOneWidget);
      expect(_tile('p2'), findsNothing);

      await tester.tap(find.byKey(ReferenceLibrarySection.categoryKey(ReferenceCategory.portrait)));
      await tester.pumpAndSettle();
      expect(_tile('r1'), findsOneWidget);
      expect(_tile('r2'), findsOneWidget);

      // 切回姿势：选着的视角还在。
      await tester.tap(find.byKey(ReferenceLibrarySection.categoryKey(ReferenceCategory.pose)));
      await tester.pumpAndSettle();
      expect(_tile('p1'), findsOneWidget);
      expect(_tile('p2'), findsNothing);
    });
  });

  group('格子菜单', () {
    testWidgets('没有选中节点 ⇒「当姿势参考」置灰（节点名的位置写原因），「只放进画布」可点，「存为角色」置灰', (tester) async {
      await _pump(tester);
      final AppLocalizations l = _l(tester);

      await tester.tap(_tile('p1'));
      await tester.pumpAndSettle();
      expect(find.byKey(ReferenceLibrarySection.menuKey), findsOneWidget);

      final InkMenuEntry<ReferenceMenuAction> attach = _entry(tester, ReferenceMenuAction.attach);
      expect(attach.enabled, isFalse);
      expect(attach.label, l.referenceMenuAttachPose(l.referenceBlockNoSelection));
      expect(
        _menuGroups(tester).expand((g) => g).where((e) => e.value == ReferenceMenuAction.reason),
        isEmpty,
        reason: '原因已经写在节点名的位置，不再多一行',
      );
      expect(_entry(tester, ReferenceMenuAction.place).enabled, isTrue);
      expect(_entry(tester, ReferenceMenuAction.saveCharacter).enabled, isFalse, reason: '姿势不能存为角色');
    });

    testWidgets('人像格子：「存为角色」可点，「当长相参考」', (tester) async {
      await _pump(tester);
      final AppLocalizations l = _l(tester);
      await tester.tap(find.byKey(ReferenceLibrarySection.categoryKey(ReferenceCategory.portrait)));
      await tester.pumpAndSettle();

      await tester.tap(_tile('r1'));
      await tester.pumpAndSettle();
      expect(_entry(tester, ReferenceMenuAction.saveCharacter).enabled, isTrue);
      expect(
        _entry(tester, ReferenceMenuAction.attach).label,
        l.referenceMenuAttachPortrait(l.referenceBlockNoSelection),
      );
    });

    testWidgets('选中的是 shot ⇒「当姿势参考 → 镜头名」置灰，原因另起一行', (tester) async {
      final _Rig rig = await _pump(
        tester,
        nodes: const <CanvasNode>[
          CanvasNode(id: 'shot', label: 'Shot 01', type: CanvasNodeType.shot, canvasId: 'c1'),
        ],
      );
      final AppLocalizations l = _l(tester);
      rig.container.read(canvasSelectionControllerProvider('c1').notifier).select('shot');
      await tester.pump();

      await tester.tap(_tile('p1'));
      await tester.pumpAndSettle();
      final InkMenuEntry<ReferenceMenuAction> attach = _entry(tester, ReferenceMenuAction.attach);
      expect(attach.enabled, isFalse);
      expect(attach.label, l.referenceMenuAttachPose('Shot 01'));
      final InkMenuEntry<ReferenceMenuAction> reason = _entry(tester, ReferenceMenuAction.reason);
      expect(reason.label, l.referenceBlockNotConfig);
      expect(reason.enabled, isFalse);
    });

    testWidgets('选中 wanx-image 配置 ⇒「当姿势参考 → 节点名」可点，没有原因行', (tester) async {
      final _Rig rig = await _pump(
        tester,
        nodes: const <CanvasNode>[
          CanvasNode(
            id: 'cfg',
            label: 'Harbor',
            type: CanvasNodeType.image,
            canvasId: 'c1',
            typeConfig: <String, Object?>{'provider_id': 'wanx-image'},
          ),
        ],
      );
      final AppLocalizations l = _l(tester);
      rig.container.read(canvasSelectionControllerProvider('c1').notifier).select('cfg');
      await tester.pump();

      await tester.tap(_tile('p1'));
      await tester.pumpAndSettle();
      final InkMenuEntry<ReferenceMenuAction> attach = _entry(tester, ReferenceMenuAction.attach);
      expect(attach.enabled, isTrue);
      expect(attach.label, l.referenceMenuAttachPose('Harbor'));
      expect(
        _menuGroups(tester).expand((g) => g).where((e) => e.value == ReferenceMenuAction.reason),
        isEmpty,
      );
    });
  });

  group('素材页分段', () {
    testWidgets('切到参考库再切回「本画布」：画廊网格还在，两边内容不串', (tester) async {
      final InMemoryCanvasRepository canvases = InMemoryCanvasRepository();
      final InMemoryNodeRepository nodes = InMemoryNodeRepository();
      final String cvA = await canvases.create(projectId: 'p1', name: 'A');
      final String harbor = await nodes.create(
        canvasId: cvA,
        type: 'text',
        nodeRole: 'config',
        label: 'Harbor',
        typeConfig: <String, Object?>{'text': 'dawn'},
      );
      await nodes.create(
        canvasId: cvA,
        type: 'image',
        nodeRole: 'result',
        label: 'Harbor take',
        sourceNodeId: harbor,
        positionX: 300,
        typeConfig: <String, Object?>{'image_url': 'images/h1.png'},
      );

      final paths = await setupTempPaths(tester, 'ink_left_reference_');
      await pumpInkShell(
        tester,
        paths: paths,
        initial: ShellState(
          tab: ShellTab.canvas,
          canvasId: cvA,
          project: const ProjectRef(id: 'p1', name: 'Alpha'),
        ),
        extraOverrides: <Override>[
          canvasRepositoryProvider.overrideWith((_) async => canvases),
          nodeRepositoryProvider.overrideWith((_) async => nodes),
          fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
          toastServiceProvider.overrideWithValue(RecordingToastService()),
        ],
      );
      final ProviderContainer c = readShellContainer(tester);
      c.read(leftRailProvider.notifier).open(LeftRailPage.assets);
      for (int i = 0; i < 8; i++) {
        await tester.pump();
      }

      final Finder galleryTile = find.byKey(ValueKey<String>('leftRail-asset-$cvA|images/h1.png|null'));
      expect(galleryTile, findsOneWidget, reason: '前提：本画布段有画廊格子');
      expect(find.byType(ReferenceLibrarySection), findsNothing);

      await tester.tap(find.byKey(AssetsPanel.scopeKey(AssetScope.reference)));
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.byType(ReferenceLibrarySection), findsOneWidget);
      expect(find.byKey(ReferenceLibrarySection.pickFolderKey), findsOneWidget,
          reason: '外壳的偏好设置里没有参考库文件夹 ⇒ 空态');
      expect(galleryTile, findsNothing, reason: '参考库段不画画廊产物');
      expect(find.byKey(AssetsPanel.kindKey(AssetKindFilter.all)), findsNothing,
          reason: '参考库段没有类型 chip');

      await tester.tap(find.byKey(AssetsPanel.scopeKey(AssetScope.canvas)));
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(galleryTile, findsOneWidget, reason: '切回来画廊网格还在');
      expect(find.byType(ReferenceLibrarySection), findsNothing);
      expect(find.byKey(AssetsPanel.kindKey(AssetKindFilter.all)), findsOneWidget);
    });
  });
}
