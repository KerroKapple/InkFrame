// 画布右键菜单的注册表（canvas_menu/menu_registry.dart）：id 全局唯一、不含冒号；buildMenuGroups 先按组号、
// 组内按序号排，build 返回 null 的项不出、整组都没了的组不出；menuItemForPick 只拿第一个冒号之前的部分比 id，
// scope 不符不认。
//
// 排序 / 过滤 / 派发用自造的表（items:）测，不碰真菜单项——build 只返回固定的 InkMenuEntry，上下文里的
// BuildContext / WidgetRef 是不会被读到的 Fake。拿掉组内按序号排 ⇒「先按 group 再按 order 排」红；
// menuItemForPick 整串比 id ⇒「认 <id>:<参数> 与裸 id」红。
//
// 真表里只有「新建…」这一条单独测：它原地换成新建菜单，不调 dismiss（关了再开会先把焦点还给画布）。
// 给它的 run 开头加一行 c.dismiss?.call() ⇒「空白处『新建…』原地换成新建菜单」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_menu/canvas_menu_request.dart';
import 'package:inkframe/features/canvas/widgets/canvas_menu/menu_registry.dart';
import 'package:inkframe/theme/components/ink_menu_panel.dart';

import '../../../../_harness/test_app.dart';

class _FakeContext extends Fake implements BuildContext {}

class _FakeRef extends Fake implements WidgetRef {}

final CanvasMenuContext _c = CanvasMenuContext(
  context: _FakeContext(),
  ref: _FakeRef(),
  canvasId: 'c1',
  request: const CanvasMenuRequest(kind: CanvasMenuKind.blank, anchor: Offset.zero),
  targets: const <String>{},
);

/// 一条自造的定义：build 出一行（值 = 文案 = id），[hidden] 时 build 返回 null。
CanvasMenuItemDef _def(
  String id, {
  CanvasMenuScope scope = CanvasMenuScope.blank,
  required int group,
  required int order,
  bool hidden = false,
}) =>
    CanvasMenuItemDef(
      id: id,
      scope: scope,
      group: group,
      order: order,
      build: (CanvasMenuContext c) =>
          hidden ? null : InkMenuEntry<String>(value: id, label: id),
      run: (CanvasMenuContext c) {},
    );

/// 分组 → 每组的值。
List<List<String>> _values(List<List<InkMenuEntry<String>>> groups) => <List<String>>[
      for (final List<InkMenuEntry<String>> g in groups)
        <String>[for (final InkMenuEntry<String> e in g) e.value],
    ];

void main() {
  test('kCanvasMenuItems 的 id 全局唯一、不含冒号', () {
    final List<String> ids = <String>[
      for (final CanvasMenuItemDef d in kCanvasMenuItems) d.id,
    ];
    expect(ids, isNotEmpty);
    expect(ids.toSet().length, ids.length, reason: 'id 重复：$ids');
    expect(ids.where((String id) => id.contains(':')), isEmpty);
  });

  test('kCanvasMenuItems 的初始内容：空白处六项、节点六项，组号 / 序号按约定', () {
    expect(
      <String, (CanvasMenuScope, int, int)>{
        for (final CanvasMenuItemDef d in kCanvasMenuItems)
          d.id: (d.scope, d.group, d.order),
      },
      <String, (CanvasMenuScope, int, int)>{
        'blank.create': (CanvasMenuScope.blank, 10, 10),
        'blank.importScript': (CanvasMenuScope.blank, 10, 20),
        'blank.selectAll': (CanvasMenuScope.blank, 50, 10),
        'blank.fitView': (CanvasMenuScope.blank, 50, 20),
        'node.generate': (CanvasMenuScope.node, 10, 10),
        'node.duplicate': (CanvasMenuScope.node, 10, 20),
        'node.saveAsCharacter': (CanvasMenuScope.node, 30, 10),
        'node.laneSubmenu': (CanvasMenuScope.node, 30, 20),
        'node.locateInSequence': (CanvasMenuScope.node, 30, 30),
        'node.delete': (CanvasMenuScope.node, 90, 10),
        'blank.undo': (CanvasMenuScope.blank, 0, 10),
        'blank.redo': (CanvasMenuScope.blank, 0, 20),
      },
    );
  });

  test('buildMenuGroups 先按 group 再按 order 排', () {
    final List<CanvasMenuItemDef> items = <CanvasMenuItemDef>[
      _def('g20o10', group: 20, order: 10),
      _def('g10o20', group: 10, order: 20),
      _def('g10o10', group: 10, order: 10),
    ];
    expect(
      _values(buildMenuGroups(CanvasMenuScope.blank, _c, items: items)),
      <List<String>>[
        <String>['g10o10', 'g10o20'],
        <String>['g20o10'],
      ],
    );
  });

  test('build 返回 null 的项不出；整组都为 null 时这一组不出；别的菜单的项不出', () {
    final List<CanvasMenuItemDef> items = <CanvasMenuItemDef>[
      _def('a', group: 10, order: 10),
      _def('b', group: 10, order: 20, hidden: true),
      _def('c', group: 20, order: 10, hidden: true),
      _def('c2', group: 20, order: 20, hidden: true),
      _def('d', group: 30, order: 10),
      _def('n', scope: CanvasMenuScope.node, group: 10, order: 5),
    ];
    expect(
      _values(buildMenuGroups(CanvasMenuScope.blank, _c, items: items)),
      <List<String>>[
        <String>['a'],
        <String>['d'],
      ],
    );
  });

  test('menuItemForPick 认 <id>:<参数> 与裸 id；未知 id 返回 null；scope 不符返回 null', () {
    final CanvasMenuItemDef lane =
        _def('node.lane', scope: CanvasMenuScope.node, group: 30, order: 20);
    final CanvasMenuItemDef blank = _def('blank.x', group: 10, order: 10);
    final List<CanvasMenuItemDef> items = <CanvasMenuItemDef>[lane, blank];

    expect(menuItemForPick(CanvasMenuScope.node, 'node.lane:l1', items: items), same(lane));
    expect(menuItemForPick(CanvasMenuScope.node, 'node.lane:', items: items), same(lane));
    expect(menuItemForPick(CanvasMenuScope.node, 'node.lane', items: items), same(lane));
    expect(menuItemForPick(CanvasMenuScope.blank, 'blank.x', items: items), same(blank));

    expect(menuItemForPick(CanvasMenuScope.node, 'node.nope', items: items), isNull);
    expect(menuItemForPick(CanvasMenuScope.node, 'node.lanes:l1', items: items), isNull);
    expect(menuItemForPick(CanvasMenuScope.blank, 'node.lane:l1', items: items), isNull);
    expect(menuItemForPick(CanvasMenuScope.node, 'blank.x', items: items), isNull);
  });

  testWidgets('空白处「新建…」原地换成新建菜单：不调 dismiss、请求中间不经过 null、锚点不变', (tester) async {
    late WidgetRef ref;
    late BuildContext ctx;
    await pumpInkApp(
      tester,
      Consumer(
        builder: (BuildContext context, WidgetRef r, Widget? child) {
          ref = r;
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    );
    final ProviderContainer container = ProviderScope.containerOf(ctx);

    // 先挂监听再开菜单：请求 provider 是 autoDispose 的，没人听会被收掉。
    final List<CanvasMenuRequest?> log = <CanvasMenuRequest?>[];
    final ProviderSubscription<CanvasMenuRequest?> sub = container.listen<CanvasMenuRequest?>(
      canvasMenuRequestProvider('c1'),
      (CanvasMenuRequest? previous, CanvasMenuRequest? next) => log.add(next),
    );
    addTearDown(sub.close);

    const Offset p = Offset(140, 90);
    container.read(canvasMenuRequestProvider('c1').notifier).openBlank(p);
    final CanvasMenuRequest blank = container.read(canvasMenuRequestProvider('c1'))!;
    expect(blank.kind, CanvasMenuKind.blank);
    log.clear();

    // dismiss 照宿主的样子真关菜单：变异后会在日志里留下一个 null。
    int dismissed = 0;
    final CanvasMenuItemDef? create = menuItemForPick(CanvasMenuScope.blank, 'blank.create');
    expect(create, isNotNull);
    await create!.run(
      CanvasMenuContext(
        context: ctx,
        ref: ref,
        canvasId: 'c1',
        request: blank,
        targets: const <String>{},
        picked: 'blank.create',
        dismiss: () {
          dismissed++;
          container.read(canvasMenuRequestProvider('c1').notifier).close(blank);
        },
      ),
    );

    expect(dismissed, 0);
    expect(log, isNotEmpty);
    expect(log.where((CanvasMenuRequest? r) => r == null), isEmpty, reason: '$log');
    expect(log.last!.kind, CanvasMenuKind.create);
    expect(log.last!.anchor, p);
    expect(log.last!.sourceNodeId, isNull);
  });
}
