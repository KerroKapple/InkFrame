// FileCrashReporter 单测：落盘内容、轮转（保留 3 删最旧）、无键值上下文。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/crash_reporter.dart';
import 'package:path/path.dart' as p;

import '../_harness/fake_clock.dart';

List<File> _crashFiles(Directory crashesDir) {
  if (!crashesDir.existsSync()) return const <File>[];
  final files = <File>[
    for (final e in crashesDir.listSync())
      if (e is File && p.basename(e.path).startsWith('inkframe.crash.')) e,
  ]..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  return files;
}

void main() {
  late Directory tmp;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ink_crash_');
    paths = DefaultAppPaths.forRoot(tmp);
    await paths.ensureInitialized();
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  group('FileCrashReporter.report', () {
    test('writes a crash file with error, stack, version and timestamp',
        () async {
      final clock = FakeClock(DateTime.utc(2026, 4, 13, 10, 30, 15));
      final reporter = FileCrashReporter(
        paths: paths,
        clock: clock,
        appVersion: '2.0.0+7',
      );

      reporter.report(
        StateError('boom-xyz'),
        StackTrace.fromString('#0 frame-abc'),
      );

      final files = _crashFiles(paths.crashes);
      expect(files, hasLength(1));
      final content = files.single.readAsStringSync();
      expect(content, contains('2.0.0+7'));
      expect(content, contains('boom-xyz'));
      expect(content, contains('#0 frame-abc'));
      expect(content, contains('2026-04-13T10:30:15'));
    });

    test('crash file carries no extra / key-value context section', () async {
      final clock = FakeClock(DateTime.utc(2026, 4, 13, 10, 30, 15));
      final reporter = FileCrashReporter(
        paths: paths,
        clock: clock,
        appVersion: '2.0.0+7',
      );

      reporter.report(StateError('boom'), StackTrace.fromString('#0 f'));

      final content = _crashFiles(paths.crashes).single.readAsStringSync();
      // 崩溃文件不得有 extra / context 键值区（结构性排除敏感数据）。
      expect(content.toLowerCase(), isNot(contains('extra')));
      expect(content.toLowerCase(), isNot(contains('context')));
      // 只允许固定字段标签。
      expect(content, contains('version:'));
      expect(content, contains('error:'));
      expect(content, contains('stack:'));
    });

    test('rotation keeps exactly the 3 newest files, deletes the oldest',
        () async {
      final clock = FakeClock(DateTime.utc(2026, 4, 13, 10, 0, 0));
      final reporter = FileCrashReporter(
        paths: paths,
        clock: clock,
        appVersion: '2.0.0+7',
      );

      // 写 4 个（时钟每次前进，保证文件名各异且可判先后）。
      final stamps = <String>[];
      for (var i = 0; i < 4; i++) {
        reporter.report(StateError('crash-$i'), StackTrace.fromString('#$i'));
        clock.advance(const Duration(seconds: 1));
      }
      // 记录 4 个的内容标记，用于断言"最旧被删"。
      for (var i = 0; i < 4; i++) {
        stamps.add('crash-$i');
      }

      final files = _crashFiles(paths.crashes);
      expect(files, hasLength(3), reason: '只保留 3 个');

      final remaining = files.map((f) => f.readAsStringSync()).join('\n');
      // 最旧（crash-0）应被删除；最近 3 个（crash-1/2/3）保留。
      expect(remaining, isNot(contains('crash-0')));
      expect(remaining, contains('crash-1'));
      expect(remaining, contains('crash-2'));
      expect(remaining, contains('crash-3'));
    });

    test('creates the crashes dir if missing', () async {
      // 删掉 ensureInitialized 建好的目录，验证 report 会自愈重建。
      paths.crashes.deleteSync(recursive: true);
      final clock = FakeClock(DateTime.utc(2026, 4, 13, 10, 30, 15));
      final reporter = FileCrashReporter(
        paths: paths,
        clock: clock,
        appVersion: '1.0.0',
      );

      reporter.report(StateError('boom'), null);

      expect(_crashFiles(paths.crashes), hasLength(1));
    });
  });
}
