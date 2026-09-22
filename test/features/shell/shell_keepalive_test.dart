// V1 端到端：切标签不丢状态。
//
// 【本文件与 shell_keep_alive_host_test.dart 的分工】那边证的是「子树还在树上」
// （StatelessWidget + Text 探针）。子树存活是 State 存活的必要条件，不是充分
// 条件——同一个 Element 位置上换一个 Key、或宿主每帧重建 KeyedSubtree，
// 子树照样"在树上"，State 却已经被重建过一轮。V1 要验的是【切换后真实状态还在】，
// 其中只有 ③ 咬到 State 对象本人——①② 在"槽位 Key 随 activeTab 变"的变异下是
// 绿的，它们证到的是 autoDispose family entry 存活（仍是真状态、仍是 V1 用户标准
// 的一部分，但比 State 存活弱一档）。
//
// 三条用例各自钉一种状态载体：
//  ① TransformationController 的矩阵——autoDispose family provider 持有，
//     只有画布子树持续挂载才不会被回收复位。
//  ② 选中集——同上，但载体是 Notifier 的 state。
//  ③ 画廊搜索框——载体是 _GalleryContentState 里的 TextEditingController，
//     真正的 widget State。这条【必须断言实例同一性】：_GalleryContentState
//     的 initState 会从 galleryFilterProvider 回种 text，所以"文本还在"这条
//     断言在 State 被重建时也可能为真（只要 provider 还活着），identical()
//     才是"State 对象本人活着"的唯一证据。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/gallery/models/gallery_item.dart';
import 'package:inkframe/features/gallery/providers/gallery_controller.dart';
import 'package:inkframe/features/gallery/providers/gallery_filter.dart';
import 'package:inkframe/features/gallery/widgets/gallery_screen.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/studio/studio_home_screen.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';
import '../../_harness/shell_expect.dart';

/// 通过 InteractiveViewer widget 读当前变换——绕开 provider，读的是真正
/// 绑在渲染树上的那个控制器。切走标签后画布 offstage，必须 skipOffstage:false。
Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(
      find.byType(InteractiveViewer, skipOffstage: false),
    )
    .transformationController!
    .value;

/// 画廊搜索框（筛选条里唯一的 TextField）。
///
/// 【必须限定在 GalleryScreen 子树内】——保活宿主下画布/Studio 标签可能同时
/// 挂着自己的输入框，全局 find.byType(TextField) 会在标签切换时静默换目标。
final Finder _searchField = find.descendant(
  of: find.byType(GalleryScreen, skipOffstage: false),
  matching: find.byType(TextField, skipOffstage: false),
  skipOffstage: false,
);

/// 搜索框当前绑定的控制器实例。
TextEditingController _searchController(WidgetTester tester) =>
    tester.widget<TextField>(_searchField).controller!;

/// 恒定返回一批产物的画廊 Fake——真控制器要 await 三个仓储（pool 被封印后永挂）。
class _FakeGalleryController extends GalleryController {
  _FakeGalleryController(this._items);
  final List<GalleryItem> _items;

  @override
  Future<List<GalleryItem>> build(String projectId) async => _items;
}

final List<GalleryItem> _items = <GalleryItem>[
  GalleryItem(
    kind: GalleryItemKind.image,
    relativePath: 'images/one.png',
    canvasId: 'c1',
    canvasName: 'Alpha',
    nodeId: 'n1',
    createdAt: DateTime.utc(2026, 1, 1),
  ),
];

List<Override> _canvasOverrides() => <Override>[
  canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
  canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
  canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
  fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
];

void main() {
  const ProjectRef alpha = ProjectRef(id: 'p1', name: 'Alpha');

  testWidgets('V1：画布切到画廊再切回，视口变换矩阵逐元素不变', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_keepalive_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(
        tab: ShellTab.canvas,
        canvasId: 'c1',
        project: alpha,
      ),
      extraOverrides: <Override>[
        ..._canvasOverrides(),
        galleryControllerProvider
            .overrideWith(() => _FakeGalleryController(_items)),
      ],
    );

    // 缩放画布，制造一个不等于初始相机的变换。
    await sendCtrl(tester, LogicalKeyboardKey.equal);
    final Matrix4 before = _ivTransform(tester);
    expect(
      before,
      isNot(initialCanvasTransform()),
      reason: '前提没成立：⌘+ 没改动变换，后面的"矩阵不变"就是恒真的假绿',
    );

    await tapShellTab(tester, ShellTab.gallery);

    // 切走后画布必须【还在树里、但不在台上、也不可命中】——保活的定义。
    expectShellSurface<CanvasView>(
      mounted: true,
      onstage: false,
      hittable: false,
      reason: '切到画廊后的画布',
    );

    await tapShellTab(tester, ShellTab.canvas);

    final Matrix4 after = _ivTransform(tester);
    for (int i = 0; i < 16; i++) {
      expect(
        after.storage[i],
        closeTo(before.storage[i], 1e-9),
        reason: '矩阵第 $i 位变了——保活没生效，或有人在切标签时卸载了画布子树',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('V1：选中集跨标签保留', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_sel_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(
        tab: ShellTab.canvas,
        canvasId: 'c1',
        project: alpha,
      ),
      extraOverrides: <Override>[
        ..._canvasOverrides(),
        galleryControllerProvider
            .overrideWith(() => _FakeGalleryController(_items)),
      ],
    );

    final ProviderContainer c = readShellContainer(tester);
    c
        .read(canvasSelectionControllerProvider('c1').notifier)
        .selectAll(<String>{'a', 'b'});
    await tester.pump();

    await tapShellTab(tester, ShellTab.gallery);
    await tapShellTab(tester, ShellTab.canvas);

    expect(
      c.read(canvasSelectionControllerProvider('c1')),
      <String>{'a', 'b'},
      reason: '切走再切回不得丢选中集——保活的元素没离开树，family entry 就不该被回收',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('V1：画廊筛选与搜索框跨标签保留（State 对象本人存活）', (tester) async {
    final paths = await setupTempPaths(tester, 'ink_shell_gfilter_');
    await pumpInkShell(
      tester,
      paths: paths,
      initial: const ShellState(tab: ShellTab.gallery, project: alpha),
      extraOverrides: <Override>[
        ..._canvasOverrides(),
        galleryControllerProvider
            .overrideWith(() => _FakeGalleryController(_items)),
      ],
    );

    final ProviderContainer c = readShellContainer(tester);
    // 走真实用户路径：在搜索框里打字（onChanged → provider），而不是直接写
    // provider——后者不会让 _searchCtrl 的内容成为 State 自己的产物。
    await tester.enterText(_searchField, 'moon');
    await tester.pump();
    c.read(galleryFilterProvider('p1').notifier).state = c
        .read(galleryFilterProvider('p1'))
        .copyWith(kind: () => GalleryItemKind.video);
    await tester.pump();

    final TextEditingController beforeCtrl = _searchController(tester);
    expect(beforeCtrl.text, 'moon');

    await tapShellTab(tester, ShellTab.studio);
    expectShellSurface<GalleryScreen>(
      mounted: true,
      onstage: false,
      hittable: false,
      reason: '切到 Studio 后的画廊',
    );
    expectShellSurface<StudioHomeScreen>(
      mounted: true,
      onstage: true,
      hittable: true,
      reason: '当前标签',
    );
    await tapShellTab(tester, ShellTab.gallery);

    expect(c.read(galleryFilterProvider('p1')).kind, GalleryItemKind.video);
    expect(c.read(galleryFilterProvider('p1')).query, 'moon');
    expect(
      _searchController(tester).text,
      'moon',
      reason: '搜索框必须显示当前筛选词，否则显示空、筛选却仍生效——界面撒谎',
    );
    expect(
      identical(_searchController(tester), beforeCtrl),
      isTrue,
      reason: '同一个 TextEditingController 实例 ⇒ _GalleryContentState 本人活过了'
          '这次切换。只断言文本相等是不够的：State 被重建时 initState 会从 '
          'galleryFilterProvider 回种同样的文本，那条断言照样绿。',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
