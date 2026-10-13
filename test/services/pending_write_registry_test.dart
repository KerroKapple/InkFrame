// InMemoryPendingWriteRegistry 单测：退出前冲刷挂起写入的注册表契约。
//
// 这一层的全部职责就是「问一圈谁有挂起内容、并发冲一遍、用超时封顶」。两条最
// 要紧的性质在这里钉住：
//   - **超时上限**：退出时卡住比丢一笔更糟——用户点了关窗，窗口就该关
//   - **一个对象失手不拖垮别人**：Future.wait 遇错会提前结束，那会把其他对象
//     的挂起写入一起丢掉
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/pending_write_flush.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/services/pending_write_registry.dart';

import '../helpers/recording_logger.dart';

void main() {
  late RecordingLogger logger;

  setUp(() => logger = RecordingLogger());

  InMemoryPendingWriteRegistry makeRegistry({Duration? timeout}) =>
      InMemoryPendingWriteRegistry(
        logger: () => logger,
        timeout: timeout ?? InMemoryPendingWriteRegistry.defaultTimeout,
      );

  test('只冲有挂起内容的对象，干净的对象一次都不碰', () async {
    final dirty = _FakeFlushable(pending: true);
    final clean = _FakeFlushable(pending: false);
    final registry = makeRegistry()
      ..register(dirty)
      ..register(clean);

    await registry.flushAll();

    expect(dirty.flushCalls, 1);
    expect(clean.flushCalls, 0,
        reason: '干净的对象去冲等于凭空产生一次 UPDATE');
  });

  test('全都干净 → 不留日志（绝大多数退出走这条快路径）', () async {
    final registry = makeRegistry()..register(_FakeFlushable(pending: false));

    await registry.flushAll();

    expect(logger.records, isEmpty,
        reason: '正常退出不该每次都往日志里写一行冲刷记录');
  });

  test('register 幂等：同一对象注册两次只冲一次', () async {
    final target = _FakeFlushable(pending: true);
    final registry = makeRegistry()
      ..register(target)
      ..register(target);

    await registry.flushAll();

    expect(target.flushCalls, 1,
        reason: 'Notifier 的 build 可能重跑，register 必须幂等');
  });

  test('unregister 后不再被冲（对象已销毁，冲它就是碰悬空引用）', () async {
    final target = _FakeFlushable(pending: true);
    final registry = makeRegistry()
      ..register(target)
      ..unregister(target);

    await registry.flushAll();

    expect(target.flushCalls, 0);
  });

  test('冲刷有超时上限：某个对象永不完成，flushAll 仍按时返回', () async {
    final stuck = _FakeFlushable(pending: true, gate: Completer<void>());
    final registry = makeRegistry(timeout: const Duration(milliseconds: 80))
      ..register(stuck);

    final Stopwatch sw = Stopwatch()..start();
    await registry.flushAll();
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(2000),
        reason: '退出时卡住比丢一笔更糟——用户点了关窗，窗口就该关');
    final records = logger.byLevel(InkLogLevel.error);
    expect(records, hasLength(1), reason: '放弃等待必须留痕，否则这一笔静默消失');
    expect(records.single.extra?['still_pending'], 1);
    stuck.gate!.complete(); // 放行，免得 pending future 吊在测试生命周期外
  });

  test('超时只放弃等待、不放弃别人：没卡住的对象照样冲完', () async {
    final stuck = _FakeFlushable(pending: true, gate: Completer<void>());
    final quick = _FakeFlushable(pending: true);
    final registry = makeRegistry(timeout: const Duration(milliseconds: 80))
      ..register(stuck)
      ..register(quick);

    await registry.flushAll();

    expect(quick.flushCalls, 1);
    stuck.gate!.complete();
  });

  test('一个对象抛出不阻断其余对象（Future.wait 遇错会提前结束）', () async {
    final boom = _FakeFlushable(pending: true, throws: true);
    final ok = _FakeFlushable(pending: true);
    final registry = makeRegistry()
      ..register(boom)
      ..register(ok);

    await registry.flushAll();

    expect(ok.flushCalls, 1, reason: '实现方失手不能把别人的挂起写入一起带走');
    expect(logger.byLevel(InkLogLevel.error), hasLength(1));
  });

  test('flushAll 永不抛——它的调用方是退出路径', () async {
    final registry = makeRegistry()
      ..register(_FakeFlushable(pending: true, throws: true));

    await expectLater(registry.flushAll(), completes);
  });

  test('默认超时远小于 AppDelegate 的 15s native 兜底', () {
    expect(
      InMemoryPendingWriteRegistry.defaultTimeout,
      lessThan(const Duration(seconds: 5)),
      reason: '冲刷吃掉预算 → Pool.close + pg_ctl stop 被 native 强杀 → 孤儿 postmaster，'
          '那比丢一笔草稿严重得多',
    );
  });
}

/// 可编程的冲刷目标：可挂起、可抛、可卡住不返回。
class _FakeFlushable implements PendingWriteFlushable {
  _FakeFlushable({required bool pending, this.throws = false, this.gate})
      : _pending = pending;

  final bool throws;

  /// 非 null 时 flush 会一直等它——用来模拟「库不响应」。
  final Completer<void>? gate;

  bool _pending;
  int flushCalls = 0;

  @override
  bool get hasPendingWrites => _pending;

  @override
  Future<void> flushPendingWrites() async {
    flushCalls++;
    if (throws) throw StateError('flush blew up');
    if (gate != null) {
      await gate!.future;
      return; // 卡住期间 hasPendingWrites 保持 true，供超时日志统计
    }
    _pending = false;
  }
}
