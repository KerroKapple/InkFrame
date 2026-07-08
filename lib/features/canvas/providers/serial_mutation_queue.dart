// SerialMutationQueue —— LB-04 乐观变更串行队列。
//
// 乐观变更是 read-modify-write：读快照 →（异步）持久化 → 写回 / 回滚。两个变更并发时
// 会读到同一份基准快照，后者写回覆盖前者 → 丢更新。把每个变更整体排到单条 FIFO 尾部，
// 同一 controller 内一次只跑一个，快照 → 回滚天然不再交错。
//
// 两处已知取舍（刻意接受）：
//   1) 队头延迟：变更的乐观 state 写回如今要等前面所有排队变更各自的完整 DB 往返
//      （此前部分变更是同步写回）。刻意为之——正确性 > 延迟，本地 PG 往返极快；队列积压
//      时，拖拽收尾类变更（moveNode / reorderLanes）可能短暂回弹后再定位。
//   2) dispose 后空转：把快照读进 op 内的变更（moveNode / reorderLanes）若其 op 首次
//      运行已在 dispose 之后，previous=[] → 找不到目标 → 提前 return，跳过 DB 写入。
//      视为良性（画布关掉后就不该再落这次变更）——与修复前"入口即捕获目标"行为的一处
//      刻意、已记录的分歧。
import 'dart:async';

mixin SerialMutationQueue {
  Future<void> _tail = Future<void>.value();

  /// 把 [op] 追加到串行队列尾部，返回其结果。
  ///
  /// 这里的宽捕获是"透明转发"而非"吞异常"——原样把错误 + 栈交回调用方（等价跨异步边界的
  /// rethrow），不改写也不吞没，故不违反"只捕获具体 InkError"铁律；且失败不污染队列尾
  /// （尾 future 总是正常完成），后续变更照常执行。
  ///
  /// 关键：宽捕获而非 `on InkError` 收窄——若某 op 抛出非 InkError（如 StateError），
  /// 收窄会让 `_tail` 以错误态完成，后续所有排队变更将永远挂起。宽捕获保证队列尾恒常态
  /// 完成，异常只回流给该 op 自己的调用方（见 serial_mutation_queue_test 的尾不中毒用例）。
  Future<T> serialize<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
