// LifecycleTimer 单测：计时一个阶段落且仅落一条 app.lifecycle info 记录，
// stage 正确、ms 由注入的 fake 单调源驱动故确定性可断言；阶段抛错仍落埋点后重抛。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/services/lifecycle_timer.dart';

import '../helpers/recording_logger.dart';

/// 测试用单调流逝源：手动推进，确定性且免受墙钟跳变影响。
class _FakeElapsed implements ElapsedSource {
  Duration _elapsed = Duration.zero;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration d) => _elapsed += d;
}

void main() {
  late _FakeElapsed elapsed;
  late RecordingLogger logger;
  late LifecycleTimer timer;

  setUp(() {
    elapsed = _FakeElapsed();
    logger = RecordingLogger();
    timer = LifecycleTimer(logger: logger, elapsed: elapsed);
  });

  test('timeSync logs one app.lifecycle info with stage + elapsed ms', () {
    final int result = timer.timeSync<int>('paths', () {
      elapsed.advance(const Duration(milliseconds: 42));
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
      elapsed.advance(const Duration(seconds: 3));
      return 'ok';
    });

    expect(value, 'ok');
    final LogRecord rec = logger.byModule('app.lifecycle').single;
    expect(rec.level, InkLogLevel.info);
    expect(rec.extra!['stage'], 'pg_ready');
    expect(rec.extra!['ms'], 3000);
  });

  test('record settles elapsed from a captured start marker to now', () {
    final Duration start = timer.mark();
    elapsed.advance(const Duration(milliseconds: 1500));
    timer.record('first_frame', start);

    final LogRecord rec = logger.byModule('app.lifecycle').single;
    expect(rec.level, InkLogLevel.info);
    expect(rec.extra!['stage'], 'first_frame');
    expect(rec.extra!['ms'], 1500);
  });

  test('timeSync emits the stage record even when the body throws, then rethrows',
      () {
    expect(
      () => timer.timeSync<void>('media_kit', () {
        elapsed.advance(const Duration(milliseconds: 5));
        throw const FormatException('boom');
      }),
      throwsA(isA<FormatException>()),
    );

    final LogRecord rec = logger.byModule('app.lifecycle').single;
    expect(rec.extra!['stage'], 'media_kit');
    expect(rec.extra!['ms'], 5);
  });

  test(
      'timeAsync emits the stage record even when the future throws, then rethrows',
      () async {
    await expectLater(
      timer.timeAsync<void>('window_manager', () async {
        elapsed.advance(const Duration(milliseconds: 7));
        throw const FormatException('boom');
      }),
      throwsA(isA<FormatException>()),
    );

    final LogRecord rec = logger.byModule('app.lifecycle').single;
    expect(rec.extra!['stage'], 'window_manager');
    expect(rec.extra!['ms'], 7);
  });

  test('each timed stage emits exactly one record', () {
    timer.timeSync<void>('media_kit', () {});
    timer.timeSync<void>('window_manager', () {});

    expect(logger.byModule('app.lifecycle'), hasLength(2));
  });
}
