// 退出前冲刷挂起写入的契约（BOARD 第 201 行）。
//
// 为什么需要一层抽象，而不是让 AppTeardown 直接去调检查器：
// 挂起状态在 `features/canvas/providers/inspector_submit_controller.dart` 里，
// 而 `AppTeardown` 在 `lib/services/`。让 services 层 import features 是反向
// 依赖——退出路径会从此认识某一个 feature 的领域对象，再来一个有挂起写入的
// feature（草稿、角色编辑、序列标记……）就得再改一次 teardown。方向反过来：
// 本接口住在 core（谁都在它之上），**feature 侧注册进来**，teardown 只认
// [PendingWriteRegistry] 这一个抽象。
//
// 冲刷对用户完全不可见——没有任何上屏文案（所以这条卡不动 ARB），唯一的可观测面
// 是日志，而日志 module / 消息按项目规则是英文内部常量。
//
// 两种口径，各走各的口（#12）：
//   - 退出口（[PendingWriteRegistry.flushAll] → [PendingWriteFlushable.flushPendingWrites]）：
//     容器马上 dispose，失败即用尽、不再排退避重试；
//   - 编辑口（[PendingWriteRegistry.flushBeforeEdit] → [PendingWriteFlushable.flushBeforeEdit]）：
//     撤销 / 重做之前把挂起内容先落盘，app 还要接着跑，失败照常走退避重试。
// 编辑口不许借退出口：退出口的失败记账会把一次连接池瞬断记成「已用尽」、停掉自动
// 重试，日志也会把每次撤销记成一次关机冲刷。
import 'dart:async';

/// 持有「用户已改、但还没落盘」内容的对象。
///
/// 接口刻意只有一个判据 + 两个口径的尽力落盘（I：不造胖接口）。
abstract class PendingWriteFlushable {
  /// 是否还有未落盘内容。必须是**便宜的同步判据**——退出路径会对每个注册对象
  /// 问一次，不许在这里碰 IO。
  ///
  /// 语义上只包含「还没发出去」的写入。已经发出、正在 await 的那一笔不算：
  /// `Pool.close(force: false)` 会等在用连接归还（内部 `package:pool`
  /// semaphore 的 `close()` 等到所有资源释放才完成），在途的 UPDATE 自己会落地。
  bool get hasPendingWrites;

  /// 把挂起内容尽力写一次。**不得抛**——调用方在退出路径上，抛出只会让后面的
  /// PG 回收少跑一步。失败自己记日志（那是这一笔丢失的唯一线索）。
  ///
  /// 调用时机：连接池尚未关闭，但容器马上要 dispose。所以这里不要再安排任何
  /// 退避重试——计时器永远不会再触发。
  Future<void> flushPendingWrites();

  /// 编辑口：撤销 / 重做之前把挂起内容立刻写一次，让命令读到的库是用户最后改的样子。
  /// **不得抛**（同 [flushPendingWrites]）。
  ///
  /// 与 [flushPendingWrites] 的区别：app 还要接着跑，所以这一笔写失败按正常的
  /// 失败记账走（进重试表、按退避自动重试），也不许停掉已经排着的重试。
  Future<void> flushBeforeEdit();
}

/// 谁有挂起写入，谁注册进来；退出序列只认这一个口。
abstract class PendingWriteRegistry {
  /// 幂等：同一对象重复注册只算一次（Notifier 的 build 可能重跑）。
  void register(PendingWriteFlushable target);

  /// 对象销毁时必须撤销注册，否则注册表持悬空引用，退出时去冲一个已死的控制器。
  void unregister(PendingWriteFlushable target);

  /// 冲刷所有仍有挂起内容的注册对象。**有超时上限、永不抛**：退出时卡住比丢
  /// 一笔更糟——用户点了关窗，窗口就该关。
  ///
  /// **只给退出序列用**；撤销 / 重做之前走 [flushBeforeEdit]。
  Future<void> flushAll();

  /// 编辑口：撤销 / 重做之前冲刷所有仍有挂起内容的注册对象（逐个走
  /// [PendingWriteFlushable.flushBeforeEdit]）。同样**有超时上限、永不抛**：撤销等在
  /// 它后面，库写不进去时不能把撤销一起卡死。
  Future<void> flushBeforeEdit();
}
