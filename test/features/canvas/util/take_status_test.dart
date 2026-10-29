// resultTakeStatusOf：result 节点在同源兄弟里的 take 状态（卡片 / 导出 / 历史页 / 菜单共用的判据）。
//
// 变异对照：
// - notAdopted 写成「非当前」（不看是否比当前新）⇒「固定旧的：…更旧的都不是」红（最旧那张会被标 notAdopted）。
// - pinned 不看「固定的还活着」⇒「固定的被删 → 回落最新」红。
// - number 不走 takeNumbersOn 的「只有一个不编号」⇒「只有一个 take」红。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/take_keys.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/take_status.dart';

CanvasNode _config({String? pin}) => CanvasNode(
      id: 'cfg',
      label: 'Shot 01',
      type: CanvasNodeType.image,
      canvasId: 'c1',
      typeConfig: <String, Object?>{
        'prompt': 'harbor',
        TakeKeys.pinnedResultId: ?pin,
      },
    );

CanvasNode _take(String id, int day, {String? source = 'cfg', bool withUrl = true}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      sourceNodeId: source,
      createdAt: DateTime.utc(2026, 5, day),
      typeConfig: <String, Object?>{if (withUrl) 'image_url': 'images/$id.png'},
    );

final CanvasNode _t1 = _take('t1', 1);
final CanvasNode _t2 = _take('t2', 2);
final CanvasNode _t3 = _take('t3', 3);
final CanvasNode _t4 = _take('t4', 4);

void main() {
  test('没固定：最新是当前，其余非当前，无 notAdopted', () {
    final List<CanvasNode> nodes = <CanvasNode>[_config(), _t1, _t2, _t3];
    expect(resultTakeStatusOf(_t3, nodes),
        (number: 3, total: 3, current: true, pinned: false, notAdopted: false));
    expect(resultTakeStatusOf(_t2, nodes),
        (number: 2, total: 3, current: false, pinned: false, notAdopted: false));
    expect(resultTakeStatusOf(_t1, nodes),
        (number: 1, total: 3, current: false, pinned: false, notAdopted: false));
  });

  test('固定旧的：它 current+pinned，更新的 notAdopted，更旧的都不是', () {
    // 固定 t2：t3 / t4 比它新 ⇒ 未采用；t1 比它旧 ⇒ 只是非当前。
    final List<CanvasNode> nodes = <CanvasNode>[_config(pin: 't2'), _t1, _t2, _t3, _t4];
    expect(resultTakeStatusOf(_t2, nodes),
        (number: 2, total: 4, current: true, pinned: true, notAdopted: false));
    expect(resultTakeStatusOf(_t3, nodes),
        (number: 3, total: 4, current: false, pinned: false, notAdopted: true));
    expect(resultTakeStatusOf(_t4, nodes),
        (number: 4, total: 4, current: false, pinned: false, notAdopted: true));
    expect(resultTakeStatusOf(_t1, nodes),
        (number: 1, total: 4, current: false, pinned: false, notAdopted: false),
        reason: '比当前旧的不是「未采用」');
  });

  test('显式传 pinnedResultId（行里没有配置节点）与读配置节点同语义', () {
    final List<CanvasNode> rows = <CanvasNode>[_t1, _t2, _t3];
    expect(resultTakeStatusOf(_t1, rows, pinnedResultId: 't1'),
        (number: 1, total: 3, current: true, pinned: true, notAdopted: false));
    expect(resultTakeStatusOf(_t3, rows, pinnedResultId: 't1')?.notAdopted, isTrue);
    expect(resultTakeStatusOf(_t3, rows)?.current, isTrue, reason: '不传也找不到配置节点 ⇒ 没固定、最新是当前');
  });

  test('固定的被删（不在 nodes）→ 回落最新为当前', () {
    // 固定的 t2 被软删：listByCanvas 不再返回它。
    final List<CanvasNode> nodes = <CanvasNode>[_config(pin: 't2'), _t1, _t3];
    expect(resultTakeStatusOf(_t3, nodes),
        (number: 2, total: 2, current: true, pinned: false, notAdopted: false));
    expect(resultTakeStatusOf(_t1, nodes),
        (number: 1, total: 2, current: false, pinned: false, notAdopted: false));
  });

  test('只有一个 take：number null、total 1、current', () {
    final List<CanvasNode> nodes = <CanvasNode>[_config(), _t1];
    expect(resultTakeStatusOf(_t1, nodes),
        (number: null, total: 1, current: true, pinned: false, notAdopted: false));
    // 固定的就是它：pinned。
    expect(resultTakeStatusOf(_t1, <CanvasNode>[_config(pin: 't1'), _t1])?.pinned, isTrue);
  });

  test('孤儿 / 非 result → null', () {
    final CanvasNode orphan = _take('o', 5, source: null);
    final CanvasNode placeholder = _take('p', 6, withUrl: false);
    final List<CanvasNode> nodes = <CanvasNode>[_config(), _t1, orphan, placeholder];
    expect(resultTakeStatusOf(orphan, nodes), isNull, reason: '没有来源');
    expect(resultTakeStatusOf(_config(), nodes), isNull, reason: '配置节点不是 take');
    expect(resultTakeStatusOf(placeholder, nodes), isNull, reason: '生成中 / 失败的占位没有产物 url');
    expect(resultTakeStatusOf(_t2, nodes), isNull, reason: '不在 nodes 里');
  });
}
