// ShellState 的 7 个具名迁移 + 字段级相等性 + isPristine 真值表。
// 手写值对象、无 freezed：== / hashCode 漏一个字段的症状是静默丢导航，
// 没有任何现有测试会红，所以这里表驱动逐字段钉死。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';

void main() {
  const p1 = ProjectRef(id: 'p1', name: 'Alpha');
  const p2 = ProjectRef(id: 'p2', name: 'Beta');

  group('迁移语义', () {
    test('goTab 切标签即关浮层，保留 canvasId 与 project', () {
      const s = ShellState(
        tab: ShellTab.canvas, overlay: ShellOverlay.settings,
        canvasId: 'c1', project: p1);
      final n = s.goTab(ShellTab.gallery);
      expect(n.tab, ShellTab.gallery);
      expect(n.overlay, isNull);
      expect(n.canvasId, 'c1', reason: '切标签绝不可清 canvasId——那会当场毁掉画布保活');
      expect(n.project, p1);
    });

    test('openCanvas 落在 canvas 标签、写 canvasId、关浮层', () {
      const s = ShellState(tab: ShellTab.studio, overlay: ShellOverlay.settings, project: p1);
      final n = s.openCanvas('c9');
      expect(n.tab, ShellTab.canvas);
      expect(n.canvasId, 'c9');
      expect(n.overlay, isNull);
      expect(n.project, p1, reason: '不传 withProject 时保留原项目上下文');
    });

    test('openCanvas 带 withProject 时换项目上下文', () {
      const s = ShellState(project: p1);
      expect(s.openCanvas('c9', withProject: p2).project, p2);
    });

    // M-4（fix round 2）：openCanvas('') 不该被照单全收——空串会让 canvasId
    // 变成非 null 但无意义的 ''，isPristine 判假、画布标签进入"已打开"分支，
    // 下游按 id 查库直接落空。
    test('openCanvas 空串 id 触发 assert', () {
      const s = ShellState();
      expect(() => s.openCanvas(''), throwsAssertionError);
    });

    test('openGallery 落在 gallery 标签、写 project、保留 canvasId、清浮层', () {
      // M-5（fix round 2）：起始态刻意带一个已打开的 overlay——原用例起点本来
      // 就是 overlay:null，观测不到"清浮层"这一步，和 R19 修掉的 navigator
      // 委托测试是同一个数据构造错误，R19 只修了那一层，这里补上 state 层。
      const s = ShellState(
        tab: ShellTab.canvas,
        overlay: ShellOverlay.settings,
        canvasId: 'c1',
        project: p1,
      );
      final n = s.openGallery(p2);
      expect(n.tab, ShellTab.gallery);
      expect(n.project, p2);
      expect(n.canvasId, 'c1');
      expect(n.overlay, isNull,
          reason: 'M-5：起点已经打开了浮层，这里才能真正观测到 openGallery 清浮层的动作');
    });

    test('setProject 只换上下文，不动标签与浮层', () {
      const s = ShellState(
        tab: ShellTab.canvas, overlay: ShellOverlay.showcase, canvasId: 'c1', project: p1);
      final n = s.setProject(p2);
      expect(n.tab, ShellTab.canvas);
      expect(n.overlay, ShellOverlay.showcase);
      expect(n.canvasId, 'c1');
      expect(n.project, p2);
    });

    test('openOverlay 只加浮层，其余全保留', () {
      const s = ShellState(tab: ShellTab.gallery, canvasId: 'c1', project: p1);
      final n = s.openOverlay(ShellOverlay.settings);
      expect(n.overlay, ShellOverlay.settings);
      expect(n.tab, ShellTab.gallery);
      expect(n.canvasId, 'c1');
      expect(n.project, p1);
    });

    test('closeOverlay 只清浮层，回到原标签', () {
      const s = ShellState(
        tab: ShellTab.gallery, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1);
      final n = s.closeOverlay();
      expect(n.overlay, isNull);
      expect(n.tab, ShellTab.gallery);
      expect(n.canvasId, 'c1');
      expect(n.project, p1);
    });

    test('resetSession 四项归零（还原备份后：库换了）', () {
      const s = ShellState(
        tab: ShellTab.gallery, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1);
      expect(s.resetSession(), const ShellState());
    });
  });

  group('派生判据', () {
    test('isTabVisible：浮层盖住时一律不可见', () {
      const s = ShellState(tab: ShellTab.canvas);
      expect(s.isTabVisible(ShellTab.canvas), isTrue);
      expect(s.isTabVisible(ShellTab.gallery), isFalse);
      expect(s.openOverlay(ShellOverlay.settings).isTabVisible(ShellTab.canvas), isFalse,
          reason: '一个谓词同时覆盖"切走标签"与"开浮层遮挡"两种不可见');
    });

    test('isPristine 真值表', () {
      expect(const ShellState().isPristine, isTrue);
      expect(const ShellState(canvasId: 'c1').isPristine, isFalse);
      expect(const ShellState(overlay: ShellOverlay.settings).isPristine, isFalse);
      expect(const ShellState(tab: ShellTab.gallery).isPristine, isFalse);
      // project 不参与：Studio 里选了项目但没导航，仍应恢复上次画布。
      expect(const ShellState(project: p1).isPristine, isTrue);
    });

    // M-3（fix round 2）：hasOverlay 此前零覆盖——写成 `overlay == null`（符号
    // 反了）也没有任何用例会红，违反 docs/CLAUDE.md「Every public method has
    // a test」。
    test('hasOverlay：有浮层为真，无浮层为假', () {
      expect(const ShellState().hasOverlay, isFalse);
      expect(const ShellState(overlay: ShellOverlay.settings).hasOverlay, isTrue);
      expect(const ShellState(overlay: ShellOverlay.showcase).hasOverlay, isTrue);
    });
  });

  group('字段级相等性（漏一个字段 = 静默丢导航）', () {
    const base = ShellState(
      tab: ShellTab.canvas, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1);
    final variants = <String, ShellState>{
      'tab': ShellState(
        tab: ShellTab.gallery, overlay: base.overlay, canvasId: base.canvasId, project: base.project),
      'overlay': ShellState(
        tab: base.tab, overlay: ShellOverlay.showcase, canvasId: base.canvasId, project: base.project),
      'canvasId': ShellState(
        tab: base.tab, overlay: base.overlay, canvasId: 'c2', project: base.project),
      'project': ShellState(
        tab: base.tab, overlay: base.overlay, canvasId: base.canvasId, project: p2),
    };
    variants.forEach((field, other) {
      test('只差 $field 即不相等', () {
        expect(other, isNot(base));
        expect(other.hashCode, isNot(base.hashCode));
      });
    });
    test('全同即相等', () {
      expect(
        const ShellState(
          tab: ShellTab.canvas, overlay: ShellOverlay.settings, canvasId: 'c1', project: p1),
        base,
      );
    });
    test('ProjectRef 逐字段相等', () {
      expect(const ProjectRef(id: 'p1', name: 'Alpha'), p1);
      expect(const ProjectRef(id: 'p1', name: 'Other'), isNot(p1));
    });
  });
}
