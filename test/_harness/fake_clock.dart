// FakeClock：手动推进时间，吃掉 Clock 抽象在单测里的不确定性。
//
// 不解决 Future.delayed 的时间问题——那是 fakeAsync 的活，后续 sprint 再补。
// 本 fake 仅替换 Clock.nowUtc()，用于轮转 / 限流窗口等"看时钟"的逻辑。

import 'package:inkframe/core/logging/logger_service.dart';

class FakeClock implements Clock {
  FakeClock([DateTime? start])
      : _now = (start ?? DateTime.utc(2026, 1, 1)).toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// 推进时间。
  void advance(Duration d) {
    _now = _now.add(d);
  }

  /// 直接跳到指定时刻。
  void setNow(DateTime t) {
    _now = t.toUtc();
  }
}
