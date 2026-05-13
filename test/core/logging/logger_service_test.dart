// LoggerService 单测：覆盖结构化输出、轮转、限流、脱敏、紧急模式、DI 接入。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/paths.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:path/path.dart' as p;

class _FakeClock implements Clock {
  DateTime value;
  _FakeClock(this.value);
  @override
  DateTime nowUtc() => value;
  void advance(Duration d) => value = value.add(d);
}

Future<Directory> _makeTmpRoot() async {
  final d = await Directory.systemTemp.createTemp('ink_logger_');
  return d;
}

Future<List<String>> _readActiveLog(Directory logsDir) async {
  final f = File(p.join(logsDir.path, 'inkframe.log'));
  if (!await f.exists()) {
    return <String>[];
  }
  return (await f.readAsString()).trim().split('\n')
      .where((l) => l.isNotEmpty)
      .toList();
}

void main() {
  group('FileLoggerService structured output', () {
    test('writes one JSON line per event with all five fields', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();
      final clock = _FakeClock(DateTime.utc(2026, 4, 13, 10, 30, 0));
      final logger = FileLoggerService(paths: paths, clock: clock);

      logger.info('provider.kling', 'job submitted',
          extra: <String, Object?>{'job_id': 'abc'});
      await logger.flush();

      final lines = await _readActiveLog(paths.logs);
      expect(lines.length, 1);
      final parsed = jsonDecode(lines.first) as Map<String, Object?>;
      expect(parsed['ts'], '2026-04-13T10:30:00.000Z');
      expect(parsed['level'], 'INFO');
      expect(parsed['module'], 'provider.kling');
      expect(parsed['msg'], 'job submitted');
      expect(parsed['extra'], <String, Object?>{'job_id': 'abc'});

      await logger.close();
      await tmp.delete(recursive: true);
    });

    test('redacts sensitive keys in extra', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();
      final logger = FileLoggerService(
        paths: paths,
        clock: const SystemClock(),
      );

      logger.warn('auth', 'key used', extra: <String, Object?>{
        'api_key': 'sk-real-secret',
        'token': 'abc.xyz',
        'authorization': 'Bearer 123',
        'prompt': 'very private user text',
        'password': 'hunter2',
        'proxy_password': 'corp-proxy-secret',
        'proxyPassword': 'camel-case-secret',
        'secret': 'oauth-client-secret',
        'job_id': 'J-1',
        // 否定面：URL 本身不是凭证，必须保留以便排障
        'proxy_url': 'http://proxy.corp.local:8080',
        'proxyUrl': 'http://proxy.corp.local:8080',
      });
      await logger.flush();

      final lines = await _readActiveLog(paths.logs);
      final parsed = jsonDecode(lines.first) as Map<String, Object?>;
      final extra = parsed['extra'] as Map<String, Object?>;
      expect(extra['api_key'], '***');
      expect(extra['token'], '***');
      expect(extra['authorization'], '***');
      expect(extra['prompt'], '***');
      expect(extra['password'], '***');
      expect(extra['proxy_password'], '***');
      expect(extra['proxyPassword'], '***');
      expect(extra['secret'], '***');
      expect(extra['job_id'], 'J-1');
      // proxy_url / proxyUrl 不在白名单，原样落盘
      expect(extra['proxy_url'], 'http://proxy.corp.local:8080');
      expect(extra['proxyUrl'], 'http://proxy.corp.local:8080');

      // 兜底：整行原文不得出现任何原始密码值
      final raw = lines.first;
      expect(raw.contains('corp-proxy-secret'), isFalse);
      expect(raw.contains('camel-case-secret'), isFalse);
      expect(raw.contains('hunter2'), isFalse);
      expect(raw.contains('sk-real-secret'), isFalse);

      await logger.close();
      await tmp.delete(recursive: true);
    });
  });

  group('rotation', () {
    test('rotates when active log exceeds maxFileBytes', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();
      final clock = _FakeClock(DateTime.utc(2026, 4, 13, 10));
      final logger = FileLoggerService(
        paths: paths,
        clock: clock,
        config: const LoggerConfig(
          maxFileBytes: 2 * 1024, // 2 KB 阈值便于测试
          totalDiskBudgetBytes: 1024 * 1024,
          emergencyReclaimTargetBytes: 512 * 1024,
        ),
      );

      // 写入约 4KB 数据，每次前推时钟保证轮转文件名唯一。
      for (var i = 0; i < 60; i++) {
        clock.advance(const Duration(seconds: 1));
        logger.info('test', 'line $i', extra: <String, Object?>{
          'pad': 'x' * 100,
        });
        await logger.flush();
      }
      // 强制刷一条驱动下一轮轮转检查
      await logger.flush();

      final files = await paths.logs.list().toList();
      final names = files.map((e) => p.basename(e.path)).toList()..sort();
      // 至少轮转过一次 → 存在 inkframe.YYYYMMDDTHHMMSS.log
      final rotated =
          names.where((n) => n != 'inkframe.log' && n.endsWith('.log')).toList();
      expect(rotated, isNotEmpty,
          reason: 'expected at least one rotated file, got $names');

      await logger.close();
      await tmp.delete(recursive: true);
    });

    test('11MB write triggers rotation (acceptance line)', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();
      final clock = _FakeClock(DateTime.utc(2026, 4, 13, 10));
      final logger = FileLoggerService(
        paths: paths,
        clock: clock,
        // 生产默认 10MB 阈值
      );

      // 每条 ~2KB，写 6000 条 ≈ 12MB，足够跨过 10MB 阈值。
      final big = 'x' * 2000;
      for (var i = 0; i < 6000; i++) {
        clock.advance(const Duration(milliseconds: 10));
        logger.info('bulk', 'msg$i', extra: <String, Object?>{'blob': big});
      }
      await logger.flush();
      // 等轮转异步动作
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final files = await paths.logs.list().toList();
      final rotated = files
          .map((e) => p.basename(e.path))
          .where((n) => n != 'inkframe.log')
          .toList();
      expect(rotated, isNotEmpty);

      await logger.close();
      await tmp.delete(recursive: true);
    });
  });

  group('debug throttle', () {
    test('drops beyond 100/s and emits WARN summary next window', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();
      final clock = _FakeClock(DateTime.utc(2026, 4, 13, 12, 0, 0));
      final logger = FileLoggerService(
        paths: paths,
        clock: clock,
        config: const LoggerConfig(
          minLevel: InkLogLevel.debug,
          debugPerSecondLimit: 3,
        ),
      );

      // 同一秒写 10 条 DEBUG，应只有 3 条落盘。
      for (var i = 0; i < 10; i++) {
        logger.debug('busy', 'entry $i');
      }
      // 推进 1 秒，触发窗口翻页 + 汇总 WARN。
      clock.advance(const Duration(seconds: 2));
      logger.debug('busy', 'new window');
      await logger.flush();

      final lines = await _readActiveLog(paths.logs);
      final decoded = lines.map(jsonDecode).cast<Map<String, Object?>>().toList();
      final debugs = decoded.where((m) => m['level'] == 'DEBUG').toList();
      final warns = decoded.where((m) => m['level'] == 'WARN').toList();
      expect(debugs.length, 4); // 3 from first window + 1 from new window
      expect(warns.length, 1);
      expect(warns.first['module'], 'logger.throttle');
      expect((warns.first['extra']! as Map<String, Object?>)['dropped'], 7);

      await logger.close();
      await tmp.delete(recursive: true);
    });
  });

  group('disk budget', () {
    test('deletes oldest rotated files when total exceeds budget', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();

      // 预先放 3 个老旧轮转文件，每个 40KB。
      for (var i = 0; i < 3; i++) {
        final f = File(p.join(paths.logs.path, 'inkframe.2026010${i}T000000.log'));
        await f.writeAsBytes(List<int>.filled(40 * 1024, 65));
        await f.setLastModified(DateTime(2026, 1, 1 + i));
      }

      final clock = _FakeClock(DateTime.utc(2026, 4, 13));
      final logger = FileLoggerService(
        paths: paths,
        clock: clock,
        config: const LoggerConfig(
          maxFileBytes: 80 * 1024,
          totalDiskBudgetBytes: 100 * 1024,
          emergencyReclaimTargetBytes: 60 * 1024,
        ),
      );

      // 这一条写入后触发预算检查（合计 ~120KB > 100KB）→ 删最旧直至 <60KB。
      logger.info('probe', 'trigger budget check');
      await logger.flush();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final remaining = await paths.logs.list().toList();
      final total = await remaining.fold<Future<int>>(
        Future.value(0),
        (acc, e) async => (await acc) + (e is File ? await e.length() : 0),
      );
      expect(total <= 60 * 1024 + 200, isTrue,
          reason: 'expected reclaim below target, got $total bytes');

      await logger.close();
      await tmp.delete(recursive: true);
    });
  });

  group('level filtering', () {
    test('ignores messages below minLevel', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();
      final logger = FileLoggerService(
        paths: paths,
        clock: const SystemClock(),
        config: const LoggerConfig(minLevel: InkLogLevel.warn),
      );

      logger.debug('x', 'dropped');
      logger.info('x', 'dropped');
      logger.warn('x', 'kept');
      logger.error('x', 'kept');
      await logger.flush();

      final lines = await _readActiveLog(paths.logs);
      expect(lines.length, 2);

      await logger.close();
      await tmp.delete(recursive: true);
    });
  });

  group('DI wiring', () {
    test('loggerProvider resolves with overridden AppPaths', () async {
      final tmp = await _makeTmpRoot();
      final paths = DefaultAppPaths.forRoot(tmp);
      await paths.ensureInitialized();

      final container = ProviderContainer(
        overrides: <Override>[
          appPathsProvider.overrideWithValue(paths),
        ],
      );
      addTearDown(container.dispose);

      final logger = container.read(loggerProvider);
      logger.info('di', 'wired up');
      await logger.flush();
      final lines = await _readActiveLog(paths.logs);
      expect(lines.length, 1);

      await tmp.delete(recursive: true);
    });

    test('appPathsProvider without override throws StateError', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(() => container.read(appPathsProvider),
          throwsA(isA<StateError>()));
    });
  });
}
