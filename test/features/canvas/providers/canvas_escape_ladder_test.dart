// CanvasEscapeLadder（providers/canvas_escape_ladder.dart）：登记表 + 五档核心层。
//
// 钉的是：register 立刻参与判序、unregister 后不再参与、同 id 二次登记以后者为准、handle(local:) 覆盖
// 同 id、handle 的返回值（剥了一层 = true）；以及五档核心层各自剥什么、不剥什么——尤其是选中那一层
// 节点和边两个都清，连线排在平移之前（设计缺口的拍板：连线 > 工具锁 > 平移）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_escape_ladder.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/util/escape_ladder.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';

/// 建容器，把阶梯与它读的几个 autoDispose 源都订阅住（不然读完一拍就被回收、状态复位）。
ProviderContainer _container() {
  final ProviderContainer c = ProviderContainer();
  addTearDown(c.dispose);
  final List<ProviderListenable<Object?>> keep = <ProviderListenable<Object?>>[
    canvasEscapeLadderProvider('c1'),
    canvasMenuRequestProvider('c1'),
    canvasWireDragProvider('c1'),
    linkModeControllerProvider('c1'),
    canvasToolModeProvider('c1'),
    canvasSelectionControllerProvider('c1'),
    selectedEdgeControllerProvider('c1'),
  ];
  for (final ProviderListenable<Object?> p in keep) {
    c.listen<Object?>(p, (_, _) {});
  }
  return c;
}

CanvasEscapeLadder _ladder(ProviderContainer c) =>
    c.read(canvasEscapeLadderProvider('c1'));

void _selectNodeAndEdge(ProviderContainer c) {
  c.read(canvasSelectionControllerProvider('c1').notifier).select('a');
  c.read(selectedEdgeControllerProvider('c1').notifier).select('e1');
}

void main() {
  group('核心层', () {
    test('什么都没有：peek 为 null，handle 返回 false', () {
      final ProviderContainer c = _container();
      expect(_ladder(c).peek(), isNull);
      expect(_ladder(c).handle(), isFalse);
    });

    test('选中：节点与边两个都清，剥完再按无事可剥', () {
      final ProviderContainer c = _container();
      _selectNodeAndEdge(c);

      expect(_ladder(c).peek(), EscapeRungId.selection);
      expect(_ladder(c).handle(), isTrue);
      expect(c.read(canvasSelectionControllerProvider('c1')), isEmpty);
      expect(c.read(selectedEdgeControllerProvider('c1')), isNull);
      expect(_ladder(c).handle(), isFalse);
    });

    test('只选中了一条边：也算选中层', () {
      final ProviderContainer c = _container();
      c.read(selectedEdgeControllerProvider('c1').notifier).select('e1');

      expect(_ladder(c).peek(), EscapeRungId.selection);
      expect(_ladder(c).handle(), isTrue);
      expect(c.read(selectedEdgeControllerProvider('c1')), isNull);
    });

    test('平移工具：回到选择，不动选中', () {
      final ProviderContainer c = _container();
      _selectNodeAndEdge(c);
      c.read(canvasToolModeProvider('c1').notifier).pan();

      expect(_ladder(c).handle(), isTrue);
      expect(c.read(canvasToolModeProvider('c1')), CanvasToolMode.select);
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'a'});
      expect(c.read(selectedEdgeControllerProvider('c1')), 'e1');
    });

    test('连线与平移同时生效：先退连线，再回选择', () {
      final ProviderContainer c = _container();
      c.read(canvasToolModeProvider('c1').notifier).pan();
      c.read(linkModeControllerProvider('c1').notifier).start('a');

      expect(_ladder(c).handle(), isTrue);
      expect(c.read(linkModeControllerProvider('c1')), isNull);
      expect(c.read(canvasToolModeProvider('c1')), CanvasToolMode.pan);

      expect(_ladder(c).handle(), isTrue);
      expect(c.read(canvasToolModeProvider('c1')), CanvasToolMode.select);
    });

    test('菜单与拖线同时生效：先关菜单，再取消拖线', () {
      final ProviderContainer c = _container();
      c.read(canvasWireDragProvider('c1').notifier).start('a', Offset.zero);
      c.read(canvasMenuRequestProvider('c1').notifier).openBlank(Offset.zero);

      expect(_ladder(c).peek(), EscapeRungId.menu);
      expect(_ladder(c).handle(), isTrue);
      expect(c.read(canvasMenuRequestProvider('c1')), isNull);
      expect(c.read(canvasWireDragProvider('c1')), isNotNull);

      expect(_ladder(c).handle(), isTrue);
      expect(c.read(canvasWireDragProvider('c1')), isNull);
    });

    test('拖线排在连线与选中之前', () {
      final ProviderContainer c = _container();
      _selectNodeAndEdge(c);
      c.read(linkModeControllerProvider('c1').notifier).start('a');
      c.read(canvasWireDragProvider('c1').notifier).start('a', Offset.zero);

      expect(_ladder(c).handle(), isTrue);
      expect(c.read(canvasWireDragProvider('c1')), isNull);
      expect(c.read(linkModeControllerProvider('c1')), 'a');
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'a'});
    });
  });

  group('登记表', () {
    test('register 立刻参与判序；unregister 后不再参与', () {
      final ProviderContainer c = _container();
      _selectNodeAndEdge(c);
      int dismissed = 0;

      _ladder(c).register(EscapeRungId.findBar, (
        isActive: () => true,
        dismiss: () => dismissed++,
      ));
      expect(_ladder(c).peek(), EscapeRungId.findBar);
      expect(_ladder(c).handle(), isTrue);
      expect(dismissed, 1);
      expect(c.read(canvasSelectionControllerProvider('c1')), <String>{'a'});

      _ladder(c).unregister(EscapeRungId.findBar);
      expect(_ladder(c).peek(), EscapeRungId.selection);
    });

    test('同 id 二次登记以后者为准', () {
      final ProviderContainer c = _container();
      final List<String> log = <String>[];

      _ladder(c).register(EscapeRungId.toolLock, (
        isActive: () => true,
        dismiss: () => log.add('first'),
      ));
      _ladder(c).register(EscapeRungId.toolLock, (
        isActive: () => true,
        dismiss: () => log.add('second'),
      ));
      expect(_ladder(c).handle(), isTrue);
      expect(log, <String>['second']);
    });

    test('后登记的空位按层序插队：框选排在连线之前、拖线之后', () {
      final ProviderContainer c = _container();
      c.read(linkModeControllerProvider('c1').notifier).start('a');
      _ladder(c).register(EscapeRungId.marquee, (
        isActive: () => true,
        dismiss: () {},
      ));
      expect(_ladder(c).peek(), EscapeRungId.marquee);

      c.read(canvasWireDragProvider('c1').notifier).start('a', Offset.zero);
      expect(_ladder(c).peek(), EscapeRungId.wireDrag);
    });

    test('handle(local:) 覆盖同 id 的登记层；local 里的层同样按层序判', () {
      final ProviderContainer c = _container();
      _selectNodeAndEdge(c);
      int registered = 0;
      int local = 0;
      _ladder(c).register(EscapeRungId.findBar, (
        isActive: () => true,
        dismiss: () => registered++,
      ));

      // local 把查找条覆盖成不生效 ⇒ 往下剥到选中。
      final Map<EscapeRungId, EscapeRung> quietFindBar =
          <EscapeRungId, EscapeRung>{
        EscapeRungId.findBar: (isActive: () => false, dismiss: () => local++),
      };
      expect(_ladder(c).peek(local: quietFindBar), EscapeRungId.selection);
      expect(_ladder(c).handle(local: quietFindBar), isTrue);
      expect(registered, 0);
      expect(local, 0);
      expect(c.read(canvasSelectionControllerProvider('c1')), isEmpty);

      // local 的输入框层排在查找条之后：登记的查找条照样先剥。
      final Map<EscapeRungId, EscapeRung> typing = <EscapeRungId, EscapeRung>{
        EscapeRungId.textField: (isActive: () => true, dismiss: () => local++),
      };
      expect(_ladder(c).handle(local: typing), isTrue);
      expect(registered, 1);
      expect(local, 0);

      _ladder(c).unregister(EscapeRungId.findBar);
      expect(_ladder(c).handle(local: typing), isTrue);
      expect(local, 1);
    });
  });
}
