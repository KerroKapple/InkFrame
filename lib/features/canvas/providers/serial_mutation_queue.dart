// SerialMutationQueue —— LB-04 乐观变更串行队列。
//
// 乐观变更是 read-modify-write：读快照 →（异步）持久化 → 写回 / 回滚。两个变更并发时
// 会读到同一份基准快照，后者写回覆盖前者 → 丢更新。把每个变更整体排到单条 FIFO 尾部，
// 同一 controller 内一次只跑一个，快照 → 回滚天然不再交错。
import 'dart:async';

mixin SerialMutationQueue {
  Future<void> _tail = Future<void>.value();

  /// 把 [op] 追加到串行队列尾部，返回其结果。
  ///
  /// 这里的宽捕获是"透明转发"而非"吞异常"——原样把错误 + 栈交回调用方（等价跨异步边界的
  /// rethrow），不改写也不吞没，故不违反"只捕获具体 InkError"铁律；且失败不污染队列尾
  /// （尾 future 总是正常完成），后续变更照常执行。
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
