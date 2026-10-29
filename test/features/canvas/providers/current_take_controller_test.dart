// CurrentTakeController.setCurrent：「设为当前」的唯一执行口。
//
// 装配：ProviderContainer + 真 CanvasNodesController（InMemoryNodeRepository + FakeUnitOfWork）+ 真撤销栈
// （canvasHistoryControllerProvider）+ 真胶囊；通知换成 RecordingToastService；泳道换空表（撤销后效会读它）。
// 外壳停在画布 c1。节点 / 胶囊 / 选中挂订阅保活（autoDispose）。
//
// 变异对照：
// - setCurrent 不判已是当前 ⇒「已是当前 → alreadyCurrent，不写库不入栈」红。
// - 成功后不 record ⇒「setCurrent：写 pinned_result_id、入栈一步、出胶囊」与「Ctrl Z（history.undo）」红。
// - 写失败仍入栈 ⇒「写库失败 → 内存回滚、错误卡、不入栈」红。
// - 胶囊「撤销」改成 runCanvasUndo（撤栈顶）⇒「胶囊「撤销」= undoSpecific 这一步」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/take_keys.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/current_take_controller.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

import '../../../_harness/fake_canvas.dart' show EmptyLanesController;
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/fake_unit_of_work.dart';

const String _cid = 'c1';
const ProjectRef _p1 = ProjectRef(id: 'p1', name: 'P1');

final AppLocalizations _zh = lookupAppLocalizations(const Locale('zh'));

/// [failPatch] 为真时 patchTypeConfig 抛 LocalIOError（仓储层把 PgException 翻成的正是这个）。
class _FlakyNodeRepository extends InMemoryNodeRepository {
  bool failPatch = false;

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    if (failPatch) {
      throw const LocalIOError(extra: <String, Object?>{'op': 'patchTypeConfig'});
    }
    return super.patchTypeConfig(id, patch);
  }
}

void main() {
  late _FlakyNodeRepository nodes;
  late InMemoryEdgeRepository edges;
  late RecordingToastService toasts;
  late ProviderContainer container;
  late String cfg;
  late String t1;
  late String t2;
  late String t3;

  final nodesProvider = canvasNodesControllerProvider(_cid);

  Future<String> create({String? source, required String role, int? day}) async {
    final String id = await nodes.create(
      canvasId: _cid,
      type: 'image',
      nodeRole: role,
      sourceNodeId: source,
      typeConfig: <String, Object?>{
        if (role == 'result') 'image_url': 'images/$day.png' else 'prompt': 'harbor',
      },
    );
    if (day != null) {
      await nodes.update(id, <String, Object?>{'created_at': DateTime.utc(2026, 5, day)});
    }
    return id;
  }

  setUp(() async {
    nodes = _FlakyNodeRepository();
    edges = InMemoryEdgeRepository();
    toasts = RecordingToastService();
    cfg = await create(role: 'config');
    t1 = await create(source: cfg, role: 'result', day: 1);
    t2 = await create(source: cfg, role: 'result', day: 2);
    t3 = await create(source: cfg, role: 'result', day: 3);
    container = ProviderContainer(overrides: <Override>[
      nodeRepositoryProvider.overrideWith((_) async => nodes),
      edgeRepositoryProvider.overrideWith((_) async => edges),
      unitOfWorkProvider.overrideWith(
        (_) async => FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, edges: edges)),
      ),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      toastServiceProvider.overrideWithValue(toasts),
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: const ShellState(tab: ShellTab.canvas, canvasId: _cid, project: _p1),
        ),
      ),
    ]);
    addTearDown(container.dispose);
    container.listen(nodesProvider, (_, _) {});
    container.listen(canvasCapsuleProvider(_cid), (_, _) {});
    container.listen(canvasSelectionControllerProvider(_cid), (_, _) {});
    container.listen(canvasLanesControllerProvider(_cid), (_, _) {});
    await container.read(nodesProvider.future);
    await container.read(canvasLanesControllerProvider(_cid).future);
  });

  Future<SetCurrentTakeOutcome> setCurrent(String id) =>
      container.read(currentTakeControllerProvider(_cid)).setCurrent(id, l: _zh);

  CanvasHistoryState history() => container.read(canvasHistoryControllerProvider(_cid));
  CanvasCapsuleMessage? capsule() => container.read(canvasCapsuleProvider(_cid));

  Map<String, Object?> stored() => nodes.rows[cfg]!['type_config']! as Map<String, Object?>;
  Map<String, Object?> memory() =>
      container.read(nodesProvider).requireValue.firstWhere((CanvasNode n) => n.id == cfg).typeConfig;

  test('setCurrent：写 pinned_result_id、入栈一步、出胶囊', () async {
    expect(await setCurrent(t1), SetCurrentTakeOutcome.done);

    expect(stored()[TakeKeys.pinnedResultId], t1);
    expect(memory()[TakeKeys.pinnedResultId], t1);

    expect(history().undo, hasLength(1));
    expect(history().undo.single.command.label(_zh), '设为当前 · take 1');
    expect(history().undo.single.command.affectedNodeIds, <String>{cfg, t1});

    final CanvasCapsuleMessage? m = capsule();
    expect(m, isNotNull);
    expect(m!.text, '设为当前 · take 1');
    expect(m.kind, CanvasCapsuleKind.action);
    expect(m.actionLabel, _zh.commonUndo);
    expect(m.onAction, isNotNull);
    expect(toasts.shown, isEmpty);
  });

  test('已是当前 → alreadyCurrent，不写库不入栈', () async {
    // 没固定：最新的 t3 就是当前。
    expect(await setCurrent(t3), SetCurrentTakeOutcome.alreadyCurrent);
    expect(stored().containsKey(TakeKeys.pinnedResultId), isFalse);
    expect(history().undo, isEmpty);
    expect(capsule(), isNull);

    // 固定了 t1 之后，再点 t1 也是 alreadyCurrent，栈里只有第一次那一步。
    expect(await setCurrent(t1), SetCurrentTakeOutcome.done);
    expect(await setCurrent(t1), SetCurrentTakeOutcome.alreadyCurrent);
    expect(history().undo, hasLength(1));
  });

  test('来源配置不在 → noSource', () async {
    final String orphan = await create(role: 'result', day: 4);
    container.invalidate(nodesProvider);
    await container.read(nodesProvider.future);

    expect(await setCurrent(orphan), SetCurrentTakeOutcome.noSource, reason: '孤儿产物');
    expect(await setCurrent('missing'), SetCurrentTakeOutcome.noSource, reason: '产物不在');

    await container.read(nodesProvider.notifier).removeNodes(<String>{cfg});
    expect(await setCurrent(t1), SetCurrentTakeOutcome.noSource, reason: '来源配置已删');
    expect(history().undo, isEmpty);
    expect(capsule(), isNull);
  });

  test('写库失败 → 内存回滚、错误卡、不入栈', () async {
    nodes.failPatch = true;
    expect(await setCurrent(t1), SetCurrentTakeOutcome.failed);

    expect(memory().containsKey(TakeKeys.pinnedResultId), isFalse, reason: '内存回滚');
    expect(stored().containsKey(TakeKeys.pinnedResultId), isFalse);
    expect(toasts.kinds, <ToastKind>[ToastKind.error]);
    expect(history().undo, isEmpty);
    expect(capsule(), isNull, reason: '失败不出胶囊');

    // 再点一次可重试。
    nodes.failPatch = false;
    expect(await setCurrent(t1), SetCurrentTakeOutcome.done);
    expect(history().undo, hasLength(1));
  });

  test('Ctrl Z（history.undo）→ pinned 回旧值；redo 再设回', () async {
    expect(await setCurrent(t2), SetCurrentTakeOutcome.done);
    expect(await setCurrent(t1), SetCurrentTakeOutcome.done);
    expect(history().undo, hasLength(2));

    final CanvasHistoryController h = container.read(canvasHistoryControllerProvider(_cid).notifier);
    expect((await h.undo()).status, CanvasUndoStatus.done);
    expect(stored()[TakeKeys.pinnedResultId], t2, reason: '回到上一次固定的 t2');
    expect(memory()[TakeKeys.pinnedResultId], t2);

    expect((await h.undo()).status, CanvasUndoStatus.done);
    expect(stored()[TakeKeys.pinnedResultId], isNull, reason: '最初没固定：写 null，回落最新');

    expect((await h.redo()).status, CanvasUndoStatus.done);
    expect(stored()[TakeKeys.pinnedResultId], t2);
    expect((await h.redo()).status, CanvasUndoStatus.done);
    expect(stored()[TakeKeys.pinnedResultId], t1);
  });

  test('胶囊「撤销」= undoSpecific 这一步', () async {
    expect(await setCurrent(t1), SetCurrentTakeOutcome.done);
    final String first = history().undo.single.id;
    final void Function() undoFirst = capsule()!.onAction!;
    expect(await setCurrent(t2), SetCurrentTakeOutcome.done);
    final String second = history().undo.last.id;

    // 点第一张胶囊上的「撤销」：撤的是第一步（栈中间那步），不是栈顶。
    undoFirst();
    await pumpEventQueue();

    expect(<String>[for (final CanvasHistoryStep s in history().undo) s.id], <String>[second]);
    expect(history().redo, isEmpty, reason: '栈中间的一步撤掉后不进重做栈');
    expect(stored()[TakeKeys.pinnedResultId], isNull, reason: '第一步撤回到它之前：没固定');
    expect(first, isNot(second));
  });
}
