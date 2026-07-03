// FfmpegLocator 单测：fake ProcessRunner 驱动探测两态 + 缓存语义。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';

void main() {
  group('DefaultFfmpegLocator', () {
    late _FakeRunner runner;

    setUp(() {
      runner = _FakeRunner();
    });

    test('PATH 上 ffmpeg -version 退出 0 → 返回 ffmpeg', () async {
      runner.okExes.add('ffmpeg');
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{},
      );

      expect(await locator.locate(), 'ffmpeg');
      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.$1, 'ffmpeg');
      expect(runner.calls.single.$2, <String>['-version']);
    });

    test('可执行不存在（ProcessException）→ null', () async {
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{},
      );

      expect(await locator.locate(), isNull);
    });

    test('非零退出 → null', () async {
      runner.exitCodes['ffmpeg'] = 1;
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{},
      );

      expect(await locator.locate(), isNull);
    });

    test('INKFRAME_FFMPEG 环境变量优先于 PATH', () async {
      runner.okExes.addAll(<String>['/opt/ffmpeg/bin/ffmpeg', 'ffmpeg']);
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{
          'INKFRAME_FFMPEG': '/opt/ffmpeg/bin/ffmpeg',
        },
      );

      expect(await locator.locate(), '/opt/ffmpeg/bin/ffmpeg');
      expect(runner.calls, hasLength(1));
    });

    test('INKFRAME_FFMPEG 不可用 → 回退 PATH', () async {
      runner.okExes.add('ffmpeg');
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{'INKFRAME_FFMPEG': '/nope'},
      );

      expect(await locator.locate(), 'ffmpeg');
      expect(runner.calls, hasLength(2));
    });

    test('命中结果缓存：二次 locate 不再探测', () async {
      runner.okExes.add('ffmpeg');
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{},
      );

      await locator.locate();
      await locator.locate();
      expect(runner.calls, hasLength(1));
    });

    test('invalidate 后重新探测：缓存命中的二进制消失可换用新位置', () async {
      runner.okExes.add('ffmpeg');
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{},
      );

      expect(await locator.locate(), 'ffmpeg');
      // 二进制被卸载
      runner.okExes.remove('ffmpeg');
      locator.invalidate();
      expect(await locator.locate(), isNull);
      expect(runner.calls.length, greaterThan(1), reason: 'invalidate 后应重探');
    });

    test('未命中不缓存：装好 ffmpeg 后重探可命中', () async {
      final locator = DefaultFfmpegLocator(
        runner: runner,
        environment: const <String, String>{},
      );

      expect(await locator.locate(), isNull);
      runner.okExes.add('ffmpeg');
      expect(await locator.locate(), 'ffmpeg');
    });
  });
}

class _FakeRunner implements ProcessRunner {
  final Set<String> okExes = <String>{};
  final Map<String, int> exitCodes = <String, int>{};
  final List<(String, List<String>)> calls = <(String, List<String>)>[];

  @override
  Future<ProcessResult> run(String executable, List<String> arguments) async {
    calls.add((executable, List<String>.of(arguments)));
    final exitCode = exitCodes[executable];
    if (exitCode != null) return ProcessResult(1, exitCode, '', '');
    if (okExes.contains(executable)) return ProcessResult(1, 0, '', '');
    throw ProcessException(executable, arguments, 'not found', 2);
  }
}
