// CanvasHistoryController：画布撤销栈的状态与契约（undo-stack 切片）。
//
// 装配：ProviderContainer；挂起写入注册表换成 spy，flushAll 往共享日志里写
// 'flush'；命令用 ScriptedCanvasCommand，同一份日志记 'revert:<名>' /
// 'apply:<名>'——顺序断言就看这一个列表。撤销卡用 RecordingToastService 拿句柄，
// 看 RecordedToast.dismissed。
//
// 外壳初始态：画布标签上开着 c1（项目 p1）。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/pending_writes.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/pending_write_flush.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_command.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas_command.dart';
import '../../../_harness/fake_toast_service.dart';

/// 挂起写入注册表 spy：只记 flush。
class _SpyPendingWrites implements PendingWriteRegistry {
  _SpyPendingWrites(this.log);

  final List<String> log;

  @override
  void register(PendingWriteFlushable target) {}

  @override
  void unregister(PendingWriteFlushable target) {}

  @override
  Future<void> flushAll() async => log.add('flush');
}

const String _c1 = 'c1';
const String _c2 = 'c2';
const ProjectRef _p1 = ProjectRef(id: 'p1', name: 'P1');

void main() {
  late List<String> log;
  late RecordingToastService toasts;
  late ProviderContainer container;

  setUp(() {
    log = <String>[];
    toasts = RecordingToastService();
    container = ProviderContainer(overrides: <Override>[
      pendingWriteRegistryProvider.overrideWithValue(_SpyPendingWrites(log)),
      shellControllerProvider.overrideWith(
        () => ShellNavigator(
          initial: const ShellState(
            tab: ShellTab.canvas,
            canvasId: _c1,
            project: _p1,
          ),
        ),
      ),
    ]);
    addTearDown(container.dispose);
  });

  CanvasHistoryController ctrl([String id = _c1]) =>
      container.read(canvasHistoryControllerProvider(id).notifier);
  CanvasHistoryState st([String id = _c1]) =>
      container.read(canvasHistoryControllerProvider(id));
  List<String> undoIds([String id = _c1]) =>
      <String>[for (final CanvasHistoryStep s in st(id).undo) s.id];
  List<String> redoIds([String id = _c1]) =>
      <String>[for (final CanvasHistoryStep s in st(id).redo) s.id];
  ShellNavigator shell() => container.read(shellControllerProvider.notifier);

  ScriptedCanvasCommand cmd(
    String name, {
    List<Object> revert = const <Object>[],
    List<Object> apply = const <Object>[],
  }) =>
      ScriptedCanvasCommand(
        name,
        log: log,
        revertScript: revert,
        applyScript: apply,
      );

  /// 弹一张撤销卡，返回（句柄, 记录）。
  (ToastHandle, RecordedToast) card() {
    final ToastHandle h = toasts.show('undo card', kind: ToastKind.undo);
    return (h, toasts.shown.last);
  }

  List<String> reverts() =>
      <String>[for (final String e in log) if (e.startsWith('revert:')) e];

  group('record', () {
    test('record：入 undo 顶、返回步 id、清空 redo', () async {
      final String a = ctrl().record(cmd('A'));
      expect(a, 'c1#1');
      expect(undoIds(), <String>['c1#1']);
      expect(ctrl().nextUndo?.id, a);

      await ctrl().undo();
      expect(redoIds(), <String>[a], reason: '前置：A 已进重做栈');

      final String b = ctrl().record(cmd('B'));
      expect(b, 'c1#2');
      expect(redoIds(), isEmpty, reason: '有新操作就清空重做栈');
      expect(undoIds(), <String>[b]);
      expect(ctrl().nextRedo, isNull);
    });

    test('record 只登记、不执行 apply / revert', () {
      final ScriptedCanvasCommand a = cmd('A');
      ctrl().record(a);
      expect(a.applyCalls, 0);
      expect(a.revertCalls, 0);
      expect(log, isEmpty);
    });

    test('深度 100：第 101 步挤掉最老一步并收起它的卡', () {
      final String first = ctrl().record(cmd('S1'));
      final (ToastHandle h, RecordedToast t) = card();
      ctrl().bindCard(first, h);
      for (var i = 2; i <= 100; i++) {
        ctrl().record(cmd('S$i'));
      }
      expect(st().undo.length, 100);
      expect(t.dismissed, isFalse, reason: '满 100 步时第 1 步还在');

      ctrl().record(cmd('S101'));
      expect(st().undo.length, kCanvasHistoryDepth);
      expect(st().undo.length, 100);
      expect(st().undo.first.id, 'c1#2');
      expect(st().undo.last.id, 'c1#101');
      expect(t.dismissed, isTrue);
    });
  });

  group('undo', () {
    test('undo done：步进 redo、卡收起、返回 done', () async {
      final String a = ctrl().record(cmd('A'));
      final (ToastHandle h, RecordedToast t) = card();
      ctrl().bindCard(a, h);

      final CanvasUndoResult r = await ctrl().undo();
      expect(r.status, CanvasUndoStatus.done);
      expect(r.step?.id, a);
      expect(undoIds(), isEmpty);
      expect(redoIds(), <String>[a]);
      expect(t.dismissed, isTrue);
      expect(st().busy, isFalse);
    });

    test('undo failed：步留在栈顶、redo 不变、卡不收', () async {
      final String a = ctrl().record(cmd('A'));
      final String b =
          ctrl().record(cmd('B', revert: <Object>[CanvasCommandOutcome.failed]));
      final String c = ctrl().record(cmd('C'));
      await ctrl().undo(); // C 进 redo
      final (ToastHandle h, RecordedToast t) = card();
      ctrl().bindCard(b, h);

      final CanvasUndoResult r = await ctrl().undo();
      expect(r.status, CanvasUndoStatus.failed);
      expect(r.step?.id, b);
      expect(undoIds(), <String>[a, b]);
      expect(redoIds(), <String>[c]);
      expect(t.dismissed, isFalse);
      expect(st().busy, isFalse);
    });

    test('revert 抛 InkError ⇒ 视同 failed', () async {
      final String a = ctrl().record(
        cmd('A', revert: <Object>[const LocalIOError()]),
      );

      final CanvasUndoResult r = await ctrl().undo();
      expect(r.status, CanvasUndoStatus.failed);
      expect(r.step?.id, a);
      expect(undoIds(), <String>[a]);
      expect(redoIds(), isEmpty);
      expect(st().busy, isFalse, reason: 'busy 必须复位，否则之后再也撤不了');
    });

    test('undo gone：丢掉这一步、不连带撤下一步', () async {
      final ScriptedCanvasCommand first = cmd('A');
      final String a = ctrl().record(first);
      final String b =
          ctrl().record(cmd('B', revert: <Object>[CanvasCommandOutcome.gone]));
      final (ToastHandle h, RecordedToast t) = card();
      ctrl().bindCard(b, h);

      final CanvasUndoResult r = await ctrl().undo();
      expect(r.status, CanvasUndoStatus.gone);
      expect(r.step?.id, b);
      expect(first.revertCalls, 0, reason: '不连带撤下一步');
      expect(undoIds(), <String>[a]);
      expect(redoIds(), isEmpty, reason: 'gone 的步不进重做栈');
      expect(t.dismissed, isTrue);
    });

    test('撤销前先冲挂起写入', () async {
      ctrl().record(cmd('A'));
      await ctrl().undo();
      expect(log, <String>['flush', 'revert:A']);
    });

    test('撤销进行中再按 ⇒ busy、revert 只调一次', () async {
      final Completer<CanvasCommandOutcome> gate =
          Completer<CanvasCommandOutcome>();
      final ScriptedCanvasCommand a = cmd('A', revert: <Object>[gate]);
      ctrl().record(a);

      final Future<CanvasUndoResult> first = ctrl().undo();
      expect(st().busy, isTrue);

      final CanvasUndoResult second = await ctrl().undo();
      expect(second.status, CanvasUndoStatus.busy);
      expect(second.step, isNull);
      // busy 期间 nextUndo 照常返回栈顶。
      expect(ctrl().nextUndo?.id, 'c1#1');

      gate.complete(CanvasCommandOutcome.done);
      final CanvasUndoResult r = await first;
      expect(r.status, CanvasUndoStatus.done);
      expect(a.revertCalls, 1);
      expect(log.where((String e) => e == 'flush').length, 1,
          reason: 'busy 那次不冲写');
      expect(st().busy, isFalse);
    });

    test('栈空 ⇒ empty、不调命令也不报错', () async {
      final CanvasUndoResult r = await ctrl().undo();
      expect(r.status, CanvasUndoStatus.empty);
      expect(r.step, isNull);
      expect(reverts(), isEmpty);
      expect(st().busy, isFalse);

      final CanvasUndoResult rr = await ctrl().redo();
      expect(rr.status, CanvasUndoStatus.empty);
      expect(log.where((String e) => e.startsWith('apply:')), isEmpty);
    });
  });

  group('redo', () {
    test('redo done 回 undo 顶，redo 其余步不动', () async {
      final ScriptedCanvasCommand cmdA = cmd('A');
      final String a = ctrl().record(cmdA);
      final String b = ctrl().record(cmd('B'));
      await ctrl().undo(); // B
      await ctrl().undo(); // A
      expect(redoIds(), <String>[b, a], reason: '前置：A 在重做栈顶');

      final CanvasUndoResult r = await ctrl().redo();
      expect(r.status, CanvasUndoStatus.done);
      expect(r.step?.id, a);
      expect(cmdA.applyCalls, 1);
      expect(undoIds(), <String>[a]);
      expect(redoIds(), <String>[b], reason: '重做不清 redo 其余步');
      expect(log.last, 'apply:A');
      expect(log[log.length - 2], 'flush', reason: '重做前同样先冲写');
    });

    test('redo failed 留在 redo 顶', () async {
      final String a = ctrl().record(
        cmd('A', apply: <Object>[CanvasCommandOutcome.failed]),
      );
      await ctrl().undo();

      final CanvasUndoResult r = await ctrl().redo();
      expect(r.status, CanvasUndoStatus.failed);
      expect(redoIds(), <String>[a]);
      expect(undoIds(), isEmpty);
    });

    test('redo 抛 InkError ⇒ 视同 failed', () async {
      final String a = ctrl().record(
        cmd('A', apply: <Object>[const LocalIOError()]),
      );
      await ctrl().undo();

      final CanvasUndoResult r = await ctrl().redo();
      expect(r.status, CanvasUndoStatus.failed);
      expect(redoIds(), <String>[a]);
      expect(st().busy, isFalse);
    });

    test('redo gone 丢弃', () async {
      ctrl().record(cmd('A', apply: <Object>[CanvasCommandOutcome.gone]));
      await ctrl().undo();

      final CanvasUndoResult r = await ctrl().redo();
      expect(r.status, CanvasUndoStatus.gone);
      expect(redoIds(), isEmpty);
      expect(undoIds(), isEmpty);
    });
  });

  group('undoSpecific', () {
    test('undoSpecific 栈顶 = undo（进 redo）', () async {
      final String a = ctrl().record(cmd('A'));
      final String b = ctrl().record(cmd('B'));
      final (ToastHandle h, RecordedToast t) = card();
      ctrl().bindCard(b, h);

      final CanvasUndoResult r = await ctrl().undoSpecific(b);
      expect(r.status, CanvasUndoStatus.done);
      expect(r.step?.id, b);
      expect(undoIds(), <String>[a]);
      expect(redoIds(), <String>[b]);
      expect(t.dismissed, isTrue);
      expect(log, <String>['flush', 'revert:B']);
    });

    test('undoSpecific 抽中间一步 ⇒ 不进重做栈、其余步顺序不变', () async {
      final String a = ctrl().record(cmd('A'));
      final String b = ctrl().record(cmd('B'));
      final String c = ctrl().record(cmd('C'));
      final (ToastHandle h, RecordedToast t) = card();
      ctrl().bindCard(b, h);

      final CanvasUndoResult r = await ctrl().undoSpecific(b);
      expect(r.status, CanvasUndoStatus.done);
      expect(r.step?.id, b);
      expect(undoIds(), <String>[a, c]);
      expect(redoIds(), isEmpty, reason: '非栈顶抽走的步不进重做栈');
      expect(t.dismissed, isTrue);
      expect(reverts(), <String>['revert:B']);
    });

    test('undoSpecific 中间一步 failed ⇒ 原地不动', () async {
      final String a = ctrl().record(cmd('A'));
      final String b =
          ctrl().record(cmd('B', revert: <Object>[CanvasCommandOutcome.failed]));
      final String c = ctrl().record(cmd('C'));

      final CanvasUndoResult r = await ctrl().undoSpecific(b);
      expect(r.status, CanvasUndoStatus.failed);
      expect(undoIds(), <String>[a, b, c]);
      expect(redoIds(), isEmpty);
    });

    test('undoSpecific 中间一步 gone ⇒ 抽掉', () async {
      final String a = ctrl().record(cmd('A'));
      final String b =
          ctrl().record(cmd('B', revert: <Object>[CanvasCommandOutcome.gone]));
      final String c = ctrl().record(cmd('C'));

      final CanvasUndoResult r = await ctrl().undoSpecific(b);
      expect(r.status, CanvasUndoStatus.gone);
      expect(undoIds(), <String>[a, c]);
      expect(redoIds(), isEmpty);
    });

    test('undoSpecific 未知 id ⇒ empty、不调命令', () async {
      final String a = ctrl().record(cmd('A'));
      await ctrl().undo(); // A 已撤：不在 undo 栈里了
      log.clear();

      final CanvasUndoResult r1 = await ctrl().undoSpecific(a);
      expect(r1.status, CanvasUndoStatus.empty);
      expect(r1.step, isNull);

      final CanvasUndoResult r2 = await ctrl().undoSpecific('nope');
      expect(r2.status, CanvasUndoStatus.empty);
      expect(reverts(), isEmpty);
      expect(redoIds(), <String>[a], reason: '不动重做栈');
    });

    test('undoSpecific 在撤销进行中 ⇒ busy', () async {
      final Completer<CanvasCommandOutcome> gate =
          Completer<CanvasCommandOutcome>();
      final String a = ctrl().record(cmd('A'));
      ctrl().record(cmd('B', revert: <Object>[gate]));

      final Future<CanvasUndoResult> first = ctrl().undo();
      final CanvasUndoResult r = await ctrl().undoSpecific(a);
      expect(r.status, CanvasUndoStatus.busy);

      gate.complete(CanvasCommandOutcome.done);
      await first;
      expect(reverts(), <String>['revert:B']);
    });
  });

  group('竞态', () {
    test('撤销在途时 record 新步 ⇒ 旧步完成后不进 redo', () async {
      final Completer<CanvasCommandOutcome> gate =
          Completer<CanvasCommandOutcome>();
      ctrl().record(cmd('A', revert: <Object>[gate]));

      final Future<CanvasUndoResult> pending = ctrl().undo();
      // 让撤销走过冲写、进到 revert 里再 record。
      await pumpEventQueue();
      expect(reverts(), <String>['revert:A'], reason: '前置：A 的撤销已在途');
      final String b = ctrl().record(cmd('B'));

      gate.complete(CanvasCommandOutcome.done);
      final CanvasUndoResult r = await pending;
      expect(r.status, CanvasUndoStatus.done);
      expect(redoIds(), isEmpty, reason: '晚到的旧步不许复活进重做栈');
      expect(undoIds(), <String>[b]);
    });

    test('撤销在途时画布被关 ⇒ 完成后 undo / redo 都空', () async {
      final Completer<CanvasCommandOutcome> gate =
          Completer<CanvasCommandOutcome>();
      ctrl().record(cmd('A'));
      ctrl().record(cmd('B', revert: <Object>[gate]));

      final Future<CanvasUndoResult> pending = ctrl().undo();
      await pumpEventQueue();
      shell().closeCanvas();
      expect(undoIds(), isEmpty, reason: '前置：已丢栈');

      gate.complete(CanvasCommandOutcome.done);
      final CanvasUndoResult r = await pending;
      expect(r.status, CanvasUndoStatus.done);
      expect(undoIds(), isEmpty);
      expect(redoIds(), isEmpty);
      expect(st().busy, isFalse);
    });

    test('重做在途时画布被关 ⇒ 完成后 undo / redo 都空', () async {
      final Completer<CanvasCommandOutcome> gate =
          Completer<CanvasCommandOutcome>();
      ctrl().record(cmd('A', apply: <Object>[gate]));
      await ctrl().undo();
      expect(redoIds(), <String>['c1#1'], reason: '前置：A 已进重做栈');

      final Future<CanvasUndoResult> pending = ctrl().redo();
      await pumpEventQueue();
      shell().closeCanvas();
      expect(redoIds(), isEmpty, reason: '前置：已丢栈');

      gate.complete(CanvasCommandOutcome.done);
      final CanvasUndoResult r = await pending;
      expect(r.status, CanvasUndoStatus.done);
      expect(undoIds(), isEmpty, reason: '晚到的重做不许把步放回已丢的栈');
      expect(redoIds(), isEmpty);
      expect(st().busy, isFalse);
    });
  });

  group('关画布丢栈', () {
    /// 预置：undo 两步（各绑一张卡）+ redo 一步。
    Future<List<RecordedToast>> seed() async {
      ctrl().record(cmd('A'));
      await ctrl().undo(); // A 进 redo
      final String b = ctrl().record(cmd('B'));
      final String c = ctrl().record(cmd('C'));
      final (ToastHandle hb, RecordedToast tb) = card();
      final (ToastHandle hc, RecordedToast tc) = card();
      ctrl().bindCard(b, hb);
      ctrl().bindCard(c, hc);
      // record 清了 redo；再撤一次让 redo 非空。
      await ctrl().undo(); // C 进 redo（C 的卡随之收起）
      expect(undoIds(), isNotEmpty);
      expect(redoIds(), isNotEmpty);
      return <RecordedToast>[tb, tc];
    }

    void expectDropped(List<RecordedToast> cards) {
      expect(undoIds(), isEmpty);
      expect(redoIds(), isEmpty);
      for (final RecordedToast t in cards) {
        expect(t.dismissed, isTrue);
      }
    }

    test('openCanvas 别的画布 ⇒ 栈清空、卡全部收起', () async {
      final List<RecordedToast> cards = await seed();
      shell().openCanvas(_c2);
      expectDropped(cards);
    });

    test('closeCanvas ⇒ 栈清空、卡全部收起', () async {
      final List<RecordedToast> cards = await seed();
      shell().closeCanvas();
      expectDropped(cards);
    });

    test('closeProject ⇒ 栈清空、卡全部收起', () async {
      final List<RecordedToast> cards = await seed();
      shell().closeProject();
      expectDropped(cards);
    });

    test('切标签 goTab 不丢栈', () async {
      final List<RecordedToast> cards = await seed();
      final List<String> undoBefore = undoIds();
      final List<String> redoBefore = redoIds();
      shell().goTab(ShellTab.studio);
      shell().goTab(ShellTab.canvas);
      expect(undoIds(), undoBefore);
      expect(redoIds(), redoBefore);
      expect(cards.first.dismissed, isFalse, reason: 'B 还在栈里，卡不收');
    });

    test('丢栈后再打开同一张画布是空栈，步 id 继续自增不撞', () async {
      await seed();
      shell().openCanvas(_c2);
      shell().openCanvas(_c1);
      expect(undoIds(), isEmpty);
      expect(redoIds(), isEmpty);
      final String d = ctrl().record(cmd('D'));
      expect(d, 'c1#4', reason: 'seed 里 record 过三次，丢栈不重置序号');
      expect(undoIds(), <String>[d]);
    });
  });

  group('bindCard', () {
    test('bindCard 到已不在栈里的步 ⇒ 立即 dismiss', () async {
      final String a = ctrl().record(cmd('A'));
      await ctrl().undo();
      final (ToastHandle h, RecordedToast t) = card();
      ctrl().bindCard(a, h);
      expect(t.dismissed, isTrue);

      final (ToastHandle h2, RecordedToast t2) = card();
      ctrl().bindCard('nope', h2);
      expect(t2.dismissed, isTrue);
    });

    test('同一步再绑 ⇒ 先收旧卡', () {
      final String a = ctrl().record(cmd('A'));
      final (ToastHandle h1, RecordedToast t1) = card();
      final (ToastHandle h2, RecordedToast t2) = card();
      ctrl().bindCard(a, h1);
      ctrl().bindCard(a, h2);
      expect(t1.dismissed, isTrue);
      expect(t2.dismissed, isFalse);
    });
  });

  test('两个 canvasId 的栈互不影响', () async {
    final String a1 = ctrl(_c1).record(cmd('A1'));
    final String a2 = ctrl(_c2).record(cmd('A2'));
    expect(a1, 'c1#1');
    expect(a2, 'c2#1');

    await ctrl(_c1).undo();
    expect(undoIds(_c1), isEmpty);
    expect(redoIds(_c1), <String>[a1]);
    expect(undoIds(_c2), <String>[a2]);
    expect(redoIds(_c2), isEmpty);
    expect(reverts(), <String>['revert:A1']);

    // 别的画布的步 id 在本画布上不认。
    final CanvasUndoResult r = await ctrl(_c1).undoSpecific(a2);
    expect(r.status, CanvasUndoStatus.empty);
    expect(undoIds(_c2), <String>[a2]);
  });

  test('命令拿到的环境 = 本画布 id', () async {
    final ScriptedCanvasCommand a = cmd('A');
    ctrl().record(a);
    await ctrl().undo();
    expect(a.lastEnv?.canvasId, _c1);
  });
}
