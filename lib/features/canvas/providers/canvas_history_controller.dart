// CanvasHistoryController：画布撤销栈（每张画布一个，最多 100 步，纯内存）。
//
// 设计依据：UndoClipboard 稿「撤销 / 重做」「什么进栈」「和撤销卡的关系」三节。
// 这一层只管栈的状态与契约，不出 UI、不认识任何具体命令——具体命令由后续
// undo-* 切片在 models/commands/ 下各自成文件，按 [CanvasCommand] 的契约写。
//
// 规则摘要（详细见各方法注释）：
// - [record] 只登记、不执行：调用方把操作做成功之后再 record；入 undo 顶、清空 redo。
// - 撤销 / 重做 / 抽步都先冲挂起写入（检查器 500ms 防抖 patch），冲完再取栈顶。
//   走编辑口 flushBeforeEdit，不借退出口 flushAll（#12）。
// - revert / apply 的三种结果：done ⇒ 换栈；failed（含抛 InkError）⇒ 原地不动；
//   gone ⇒ 这一步作废丢掉，**不**连带撤下一步。
// - 只有一道 busy 闸，不排队：撤销在途时再按直接返回 busy。命令内部经各控制器
//   的 serialize 排队写库，这里不另加串行队列。
// - 关画布（外壳 canvasId 从本画布变走）⇒ 丢栈并收起全部绑定的撤销卡；
//   切标签不算关。
//
// keepAlive（非 autoDispose）：画布页卸载（切到别的标签）时栈不能丢，丢栈只认外壳
// 的 canvasId 变化。重启即空——不落库。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/pending_writes.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';
import '../models/canvas_command.dart';

/// 每个栈（undo / redo 各自）最多留多少步。
const int kCanvasHistoryDepth = 100;

final canvasHistoryControllerProvider =
    NotifierProvider.family<CanvasHistoryController, CanvasHistoryState, String>(
  CanvasHistoryController.new,
  name: 'canvasHistoryControllerProvider',
);

/// 栈里的一步：步 id（`'<canvasId>#<n>'`，控制器内自增）+ 命令。
@immutable
class CanvasHistoryStep {
  const CanvasHistoryStep({required this.id, required this.command});

  final String id;
  final CanvasCommand command;

  @override
  String toString() => 'CanvasHistoryStep($id)';
}

/// 栈的快照。两个列表都不可变，栈顶 = last。
@immutable
class CanvasHistoryState {
  CanvasHistoryState({
    List<CanvasHistoryStep> undo = const <CanvasHistoryStep>[],
    List<CanvasHistoryStep> redo = const <CanvasHistoryStep>[],
    this.busy = false,
  })  : undo = List<CanvasHistoryStep>.unmodifiable(undo),
        redo = List<CanvasHistoryStep>.unmodifiable(redo);

  final List<CanvasHistoryStep> undo;
  final List<CanvasHistoryStep> redo;

  /// 撤销 / 重做 / 抽步正在进行（菜单置灰由调用方看这一位）。
  final bool busy;
}

/// 一次撤销 / 重做 / 抽步的结果。
enum CanvasUndoStatus {
  /// 做成了：步已换栈（或从 undo 里抽掉）。
  done,

  /// 要撤的对象已不在：这一步丢掉了，没有连带撤下一步。
  gone,

  /// 没做成：步原样留在原处。
  failed,

  /// 没有可撤 / 可重做的（或 undoSpecific 的 id 已不在 undo 栈里）。
  empty,

  /// 上一次还没做完，这一次没执行。
  busy,
}

typedef CanvasUndoResult = ({CanvasUndoStatus status, CanvasHistoryStep? step});

class CanvasHistoryController
    extends FamilyNotifier<CanvasHistoryState, String> {
  /// 步 id 计数（确定性，便于测）。
  int _seq = 0;

  /// 记录代数：每次 [record] +1。撤销在途时用户又做了别的（record 已清 redo），
  /// 那次撤销完成后它的步就不许再复活进 redo。
  int _recordGen = 0;

  /// 纪元：每次丢栈 +1。撤销在途时画布被关，完成后什么也不放回。
  int _epoch = 0;

  /// 步 id → 它绑定的撤销卡。只有还在 undo 栈里的步才有卡。
  final Map<String, ToastHandle> _cards = <String, ToastHandle>{};

  late CanvasCommandEnv _env;

  @override
  CanvasHistoryState build(String arg) {
    _env = _HistoryEnv(arg, ref);
    // 关画布 = 外壳 canvasId 从本画布变成别的值或 null（openCanvas 别的画布 /
    // closeCanvas / closeProject / resetSession）。切标签 canvasId 不变，不算。
    ref.listen<ShellState>(shellControllerProvider, (prev, next) {
      if (prev?.canvasId == arg && next.canvasId != arg) _drop();
    });
    return CanvasHistoryState();
  }

  /// undo 栈顶（下一次撤销会撤的那步）；busy 期间照常返回。
  CanvasHistoryStep? get nextUndo => state.undo.lastOrNull;

  /// redo 栈顶（下一次重做会重做的那步）；busy 期间照常返回。
  CanvasHistoryStep? get nextRedo => state.redo.lastOrNull;

  /// 登记一步**已经做成功**的操作：入 undo 顶、清空 redo、返回步 id。
  /// 不执行 apply。栈满时挤掉最老一步并收起它的卡。
  String record(CanvasCommand command) {
    _seq++;
    _recordGen++;
    final CanvasHistoryStep step =
        CanvasHistoryStep(id: '$arg#$_seq', command: command);
    state = CanvasHistoryState(
      undo: _pushCapped(state.undo, step),
      redo: const <CanvasHistoryStep>[],
      busy: state.busy,
    );
    return step.id;
  }

  /// 把撤销卡挂到某一步上：这一步离开 undo 栈（撤销成功、gone、被挤掉、丢栈）
  /// 时卡跟着收起。步已不在 undo 栈 ⇒ 立即收卡；同一步再绑 ⇒ 先收旧卡。
  void bindCard(String stepId, ToastHandle card) {
    if (!state.undo.any((CanvasHistoryStep s) => s.id == stepId)) {
      card.dismiss();
      return;
    }
    final ToastHandle? old = _cards[stepId];
    if (old != null && !identical(old, card)) old.dismiss();
    _cards[stepId] = card;
  }

  /// 撤销 undo 栈顶那一步。
  Future<CanvasUndoResult> undo() => _exclusive(() {
        final CanvasHistoryStep? step = state.undo.lastOrNull;
        if (step == null) return Future<CanvasUndoResult>.value(_empty);
        return _revertStep(step, toRedo: true);
      });

  /// 重做 redo 栈顶那一步。done ⇒ 回到 undo 顶（redo 其余步不动）；
  /// failed ⇒ 留在 redo 顶；gone ⇒ 丢掉。
  Future<CanvasUndoResult> redo() => _exclusive(() async {
        final CanvasHistoryStep? step = state.redo.lastOrNull;
        if (step == null) return _empty;
        final int epoch = _epoch;
        final CanvasCommandOutcome outcome =
            await _invoke(() => step.command.apply(_env));
        final CanvasUndoStatus status = _statusOf(outcome);
        // 重做在途时画布被关：栈已丢，什么也不放回。
        if (epoch != _epoch) return (status: status, step: step);
        switch (outcome) {
          case CanvasCommandOutcome.failed:
            break;
          case CanvasCommandOutcome.done:
            state = CanvasHistoryState(
              undo: _pushCapped(_without(state.undo, step.id), step),
              redo: _without(state.redo, step.id),
              busy: state.busy,
            );
          case CanvasCommandOutcome.gone:
            state = CanvasHistoryState(
              undo: state.undo,
              redo: _without(state.redo, step.id),
              busy: state.busy,
            );
        }
        return (status: status, step: step);
      });

  /// 撤销卡上「撤销」：点哪步撤哪步（设计 Q1 → A）。
  ///
  /// - 在 undo 栈顶 ⇒ 完全等同 [undo]（进 redo）。
  /// - 在栈中间 ⇒ 成功后只从 undo 里抽掉，**不进 redo**（重做只能按栈序），其余步
  ///   顺序不变；failed 原地不动；gone 抽掉。
  /// - 不在 undo 栈（已撤 / 已丢 / 别的画布的步）⇒ empty，不调任何命令。
  Future<CanvasUndoResult> undoSpecific(String stepId) => _exclusive(() {
        final List<CanvasHistoryStep> undo = state.undo;
        final int index =
            undo.indexWhere((CanvasHistoryStep s) => s.id == stepId);
        if (index < 0) return Future<CanvasUndoResult>.value(_empty);
        return _revertStep(undo[index], toRedo: index == undo.length - 1);
      });

  static const CanvasUndoResult _empty =
      (status: CanvasUndoStatus.empty, step: null);

  /// busy 闸 + 冲挂起写入。冲完再由 [body] 取栈顶：冲写可能登记新步。
  Future<CanvasUndoResult> _exclusive(
    Future<CanvasUndoResult> Function() body,
  ) async {
    if (state.busy) return (status: CanvasUndoStatus.busy, step: null);
    _setBusy(true);
    try {
      // app 级、永不抛、2s 封顶。走编辑口而不是退出口 flushAll：那一笔写失败要照常
      // 退避重试，不能按「已用尽」记账、停掉所有自动重试（#12）。
      await ref.read(pendingWriteRegistryProvider).flushBeforeEdit();
      return await body();
    } finally {
      _setBusy(false);
    }
  }

  /// 撤销某一步。[toRedo]：done 时是否推进 redo（只有栈顶那一步才推）。
  Future<CanvasUndoResult> _revertStep(
    CanvasHistoryStep step, {
    required bool toRedo,
  }) async {
    final int gen = _recordGen;
    final int epoch = _epoch;
    final CanvasCommandOutcome outcome =
        await _invoke(() => step.command.revert(_env));
    final CanvasUndoStatus status = _statusOf(outcome);
    // 撤销在途时画布被关：栈已丢、卡已收，什么也不放回。
    if (epoch != _epoch) return (status: status, step: step);
    switch (outcome) {
      case CanvasCommandOutcome.failed:
        // 整步回滚：原样留在原处，卡不收。
        break;
      case CanvasCommandOutcome.done:
        // 撤销在途时又 record 了新步 ⇒ redo 已被清，旧步不许复活。
        final bool pushRedo = toRedo && gen == _recordGen;
        state = CanvasHistoryState(
          undo: _without(state.undo, step.id),
          redo: pushRedo ? _pushCapped(state.redo, step) : state.redo,
          busy: state.busy,
        );
        _dismissCard(step.id);
      case CanvasCommandOutcome.gone:
        // 对象已不在：丢掉这一步，不连带撤下一步。
        state = CanvasHistoryState(
          undo: _without(state.undo, step.id),
          redo: state.redo,
          busy: state.busy,
        );
        _dismissCard(step.id);
    }
    return (status: status, step: step);
  }

  /// 命令只许抛 InkError，视同 failed；别的异常照常上抛（busy 由 finally 复位）。
  Future<CanvasCommandOutcome> _invoke(
    Future<CanvasCommandOutcome> Function() run,
  ) async {
    try {
      return await run();
    } on InkError {
      return CanvasCommandOutcome.failed;
    }
  }

  static CanvasUndoStatus _statusOf(CanvasCommandOutcome o) => switch (o) {
        CanvasCommandOutcome.done => CanvasUndoStatus.done,
        CanvasCommandOutcome.gone => CanvasUndoStatus.gone,
        CanvasCommandOutcome.failed => CanvasUndoStatus.failed,
      };

  /// 丢栈：清 undo / redo、收起全部绑定的卡、纪元 +1。
  void _drop() {
    _epoch++;
    final List<ToastHandle> cards = _cards.values.toList();
    _cards.clear();
    for (final ToastHandle c in cards) {
      c.dismiss();
    }
    state = CanvasHistoryState(busy: state.busy);
  }

  void _setBusy(bool busy) {
    state = CanvasHistoryState(undo: state.undo, redo: state.redo, busy: busy);
  }

  void _dismissCard(String stepId) => _cards.remove(stepId)?.dismiss();

  /// 压到栈顶并封顶 [kCanvasHistoryDepth]：挤掉的最老步一并收卡。
  List<CanvasHistoryStep> _pushCapped(
    List<CanvasHistoryStep> stack,
    CanvasHistoryStep step,
  ) {
    final List<CanvasHistoryStep> next = <CanvasHistoryStep>[...stack, step];
    while (next.length > kCanvasHistoryDepth) {
      _dismissCard(next.removeAt(0).id);
    }
    return next;
  }

  static List<CanvasHistoryStep> _without(
    List<CanvasHistoryStep> stack,
    String stepId,
  ) =>
      <CanvasHistoryStep>[
        for (final CanvasHistoryStep s in stack)
          if (s.id != stepId) s,
      ];
}

/// 命令执行环境：哪张画布 + 本控制器的 ref。
class _HistoryEnv implements CanvasCommandEnv {
  _HistoryEnv(this.canvasId, this.ref);

  @override
  final String canvasId;

  @override
  final Ref ref;
}
