// CH-2 残留②：参考图配额的纯判据。
//
// 口径必须与生成侧逐字一致——注入顺序是「边连 reference 参考图在前、挂载角色按
// character_ids 顺序补足」，provider 再 take(maxRefImages) 从尾部截断。所以超限时
// 掉在地上的恰是角色图，而这份算法就是把"谁掉、掉几张"算出来给 UI 提前说。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/ref_image_budget.dart';

CharacterRefDemand _demand(String id, int count, {String? name}) =>
    CharacterRefDemand(
      id: id,
      name: name ?? id,
      imagePaths: <String>[
        for (int i = 0; i < count; i++) 'characters/$id-$i.png',
      ],
    );

void main() {
  test('未超限 → 不告警，每个角色整份进去', () {
    final RefImageBudgetPlan plan = planRefImageBudget(
      limit: 4,
      edgeRefCount: 1,
      characters: <CharacterRefDemand>[_demand('a', 2)],
    );

    expect(plan.requested, 3);
    expect(plan.overflows, isFalse);
    expect(plan.shortfall, isEmpty);
    expect(plan.characters.single.fitCount, 2);
  });

  test('超限 → 缺口落在尾部的角色身上（与 provider take() 同口径）', () {
    final RefImageBudgetPlan plan = planRefImageBudget(
      limit: 3,
      edgeRefCount: 1,
      characters: <CharacterRefDemand>[_demand('a', 1), _demand('b', 2)],
    );

    expect(plan.requested, 4);
    expect(plan.overflows, isTrue);
    expect(plan.droppedCount, 1);
    expect(
      plan.characters.map((CharacterRefOutcome o) => o.fitCount).toList(),
      <int>[1, 1],
      reason: '前面的角色整份进去，截断只咬住尾部那一个',
    );
    expect(
      plan.shortfall.map((CharacterRefOutcome o) => o.id).toList(),
      <String>['b'],
    );
    expect(plan.shortfall.single.fullyDropped, isFalse, reason: '只掉一张，不是整掉');
  });

  test('边连参考图已占满上限 → 角色一张都进不去', () {
    final RefImageBudgetPlan plan = planRefImageBudget(
      limit: 2,
      edgeRefCount: 2,
      characters: <CharacterRefDemand>[_demand('a', 1)],
    );

    expect(plan.shortfall.single.fullyDropped, isTrue);
    expect(plan.characters.single.fitCount, 0);
  });

  test('角色之间重复路径只算一次（与注入侧去重同口径）', () {
    const CharacterRefDemand shared = CharacterRefDemand(
      id: 'a',
      name: 'A',
      imagePaths: <String>['characters/x.png'],
    );
    const CharacterRefDemand same = CharacterRefDemand(
      id: 'b',
      name: 'B',
      imagePaths: <String>['characters/x.png'],
    );

    final RefImageBudgetPlan plan = planRefImageBudget(
      limit: 1,
      edgeRefCount: 0,
      characters: <CharacterRefDemand>[shared, same],
    );

    expect(plan.requested, 1, reason: '同一张图挂两个角色不该占两格配额');
    expect(plan.overflows, isFalse);
    expect(plan.characters.last.wanted, 0, reason: '第二个角色没有新增张数');
    expect(plan.shortfall, isEmpty);
  });

  test('limit<=0 → 全部进不去，droppedCount 不超过 requested', () {
    final RefImageBudgetPlan plan = planRefImageBudget(
      limit: 0,
      edgeRefCount: 0,
      characters: <CharacterRefDemand>[_demand('a', 2)],
    );

    expect(plan.characters.single.fitCount, 0);
    expect(plan.droppedCount, 2);
  });

  test('没挂角色 → shortfall 恒空（边连超限是入边区那条提示的事）', () {
    final RefImageBudgetPlan plan = planRefImageBudget(
      limit: 1,
      edgeRefCount: 3,
      characters: const <CharacterRefDemand>[],
    );

    expect(plan.overflows, isTrue);
    expect(plan.shortfall, isEmpty);
  });
}
