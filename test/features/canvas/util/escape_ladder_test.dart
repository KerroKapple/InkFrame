// Esc 阶梯的层序表（util/escape_ladder.dart）：判序只看 EscapeRungId 的声明序。
//
// 期望层序在本文件里写死（[_order]），不从 EscapeRungId.values 现取——否则把枚举里两层对调，
// 「两两同时生效取靠前的」照样绿。变异对照：枚举里 menu 与 wireDrag 对调 ⇒ 前两条红；
// resolveEscape 改成遍历 rungs.keys ⇒「登记顺序与优先级无关」红。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/escape_ladder.dart';

/// KeyMap 十档：菜单 > @ 补全 > 查找条 > 输入框 > 拖线 > 框选 > 连线 > 工具锁 > 平移 > 选中。
const List<EscapeRungId> _order = <EscapeRungId>[
  EscapeRungId.menu,
  EscapeRungId.mentionPopup,
  EscapeRungId.findBar,
  EscapeRungId.textField,
  EscapeRungId.wireDrag,
  EscapeRungId.marquee,
  EscapeRungId.linkMode,
  EscapeRungId.toolLock,
  EscapeRungId.panTool,
  EscapeRungId.selection,
];

EscapeRung _rung({required bool active}) =>
    (isActive: () => active, dismiss: () {});

/// 全部十层都登记，只有 [on] 里的生效；按 [ids] 的顺序插进 Map。
Map<EscapeRungId, EscapeRung> _rungs(
  Iterable<EscapeRungId> ids,
  Set<EscapeRungId> on,
) =>
    <EscapeRungId, EscapeRung>{
      for (final EscapeRungId id in ids) id: _rung(active: on.contains(id)),
    };

void main() {
  test('层序表', () {
    expect(EscapeRungId.values, _order);
  });

  test('两两同时生效取靠前的', () {
    for (int i = 0; i < _order.length; i++) {
      for (int j = i + 1; j < _order.length; j++) {
        expect(
          resolveEscape(_rungs(_order, <EscapeRungId>{_order[i], _order[j]})),
          _order[i],
          reason: '${_order[i]} 与 ${_order[j]} 同时生效',
        );
      }
    }
  });

  test('登记顺序与优先级无关：倒序插入，结果不变', () {
    for (int i = 0; i < _order.length; i++) {
      for (int j = i + 1; j < _order.length; j++) {
        expect(
          resolveEscape(
            _rungs(_order.reversed, <EscapeRungId>{_order[i], _order[j]}),
          ),
          _order[i],
          reason: '${_order[i]} 与 ${_order[j]} 同时生效（倒序登记）',
        );
      }
    }
  });

  test('只登记了一部分层也照层序判；不生效的层跳过', () {
    expect(
      resolveEscape(<EscapeRungId, EscapeRung>{
        EscapeRungId.selection: _rung(active: true),
        EscapeRungId.menu: _rung(active: false),
        EscapeRungId.panTool: _rung(active: true),
      }),
      EscapeRungId.panTool,
    );
  });

  test('全不生效 → null', () {
    expect(resolveEscape(_rungs(_order, const <EscapeRungId>{})), isNull);
    expect(resolveEscape(const <EscapeRungId, EscapeRung>{}), isNull);
  });
}
