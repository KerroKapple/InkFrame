// LifecycleTimer 单测：计时一个阶段落且仅落一条 app.lifecycle info 记录，
// stage 正确、ms 由注入 fake clock 驱动故确定性可断言。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/services/lifecycle_timer.dart';

import '../_harness/fake_clock.dart';
import '../helpers/recording_logger.dart';

void main() {
  late FakeClock clock;
  late RecordingLogger logger;
  late LifecycleTimer timer;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 1, 1));
    logger = RecordingLogger();
    timer = LifecycleTimer(logger: logger, clock: clock);
  });

  test('timeSync logs one app.lifecycle info with stage + elapsed ms', () {
    final int result = timer.timeSync<int>('paths', () {
      clock.advance(const Duration(milliseconds: 42));
      return 7;
    });

    expect(result, 7);
    final List<LogRecord> recs = logger.byModule('app.lifecycle');
    expect(recs, hasLength(1));
    expect(recs.single.level, InkLogLevel.info);
    expect(recs.single.extra!['stage'], 'paths');
    expect(recs.single.extra!['ms'], 42);
  });

  test('timeAsync awaits action then logs elapsed ms', () async {
    final String value = await timer.timeAsync<String>('pg_ready', () async {
      clock.advance(const Duration(seconds: 3));
      return 'ok';
    });

    expect(value, 'ok');
    final LogRecord rec = logger.byModule('app.lifecycle').single;
    expect(rec.level, InkLogLevel.info);
    expect(rec.extra!['stage'], 'pg_ready');
    expect(rec.extra!['ms'], 3000);
  });

  test('record settles elapsed from a captured start to now', () {
    final DateTime start = timer.now();
    clock.advance(const Duration(milliseconds: 1500));
    timer.record('first_frame', start);

    final LogRecord rec = logger.byModule('app.lifecycle').single;
    expect(rec.level, InkLogLevel.info);
    expect(rec.extra!['stage'], 'first_frame');
    expect(rec.extra!['ms'], 1500);
  });

  test('each timed stage emits exactly one record', () {
    timer.timeSync<void>('media_kit', () => clock.advance(Duration.zero));
    timer.timeSync<void>('window_manager', () => clock.advance(Duration.zero));

    expect(logger.byModule('app.lifecycle'), hasLength(2));
  });
}
