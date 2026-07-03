// FfmpegVideoExportService 单测：fake runner 捕获完整命令行 + list 文件内容，
// 覆盖 concat demuxer 正常路径、错误映射与临时文件清理（成功/失败两路）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/ffmpeg_locator.dart';
import 'package:inkframe/services/ffmpeg_video_export_service.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FfmpegVideoExportService.concat', () {
    late Directory tempRoot;
    late DefaultFileResolverService resolver;
    late _FakeRunner runner;
    late _FakeLocator locator;

    const projectId = 'p1';
    const relA = 'canvases/c1/videos/a.mp4';
    // 文件名带单引号——验证 list 文件转义。
    const relB = "canvases/c1/videos/b'clip.mp4";

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('ffx_');
      final paths = DefaultAppPaths.forRoot(tempRoot);
      await paths.ensureInitialized();
      resolver = DefaultFileResolverService(paths);
      runner = _FakeRunner();
      for (final rel in <String>[relA, relB]) {
        resolver.resolveInProject(projectId: projectId, relativePath: rel)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(const <int>[0, 1, 2]);
      }
    });

    tearDown(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    FfmpegVideoExportService buildService({String? ffmpegPath = 'ffmpeg'}) {
      locator = _FakeLocator(ffmpegPath);
      return FfmpegVideoExportService(
        fileResolver: resolver,
        ffmpegLocator: locator,
        processRunner: runner,
        clock: _FixedClock(),
      );
    }

    test('正常路径：命令行 / list 内容与转义 / 输出相对路径', () async {
      final svc = buildService();

      final rel = await svc.concat(
        projectId: projectId,
        inputRelativePaths: const <String>[relA, relB],
        outputBaseName: 'final',
      );

      expect(rel, 'exports/final.mp4');
      final outAbs = resolver
          .resolveInProject(projectId: projectId, relativePath: rel)
          .path;
      expect(runner.executable, 'ffmpeg');
      final args = runner.arguments!;
      expect(args, hasLength(10));
      expect(args.sublist(0, 5), <String>['-f', 'concat', '-safe', '0', '-i']);
      expect(args[5], runner.listPath);
      expect(args.sublist(6), <String>['-c', 'copy', '-y', outAbs]);

      final absA = resolver
          .resolveInProject(projectId: projectId, relativePath: relA)
          .path;
      final absB = resolver
          .resolveInProject(projectId: projectId, relativePath: relB)
          .path;
      final escapedB = absB.replaceAll("'", r"'\''");
      expect(runner.listContent, "file '$absA'\nfile '$escapedB'\n");

      expect(Directory(p.dirname(outAbs)).existsSync(), isTrue,
          reason: 'exports 目录应已创建');
    });

    test('未传 outputBaseName → 以 clock 生成 export_<utc millis> 默认名', () async {
      final svc = buildService();

      final rel = await svc.concat(
        projectId: projectId,
        inputRelativePaths: const <String>[relA],
      );

      final millis = _FixedClock().nowUtc().millisecondsSinceEpoch;
      expect(rel, 'exports/export_$millis.mp4');
    });

    test('空输入列表 → ProviderError(invalidParameter)', () async {
      final svc = buildService();

      await expectLater(
        svc.concat(projectId: projectId, inputRelativePaths: const <String>[]),
        throwsA(
          isA<ProviderError>()
              .having((e) => e.code, 'code', InkErrorCode.invalidParameter)
              .having((e) => e.extra['reason'], 'reason', 'empty_input_list'),
        ),
      );
      expect(runner.executable, isNull, reason: '不应触发 ffmpeg');
    });

    test('输入文件不存在 → LocalIOError(input_not_found)', () async {
      final svc = buildService();

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>['canvases/c1/videos/missing.mp4'],
        ),
        throwsA(
          isA<LocalIOError>()
              .having((e) => e.extra['reason'], 'reason', 'input_not_found')
              .having(
                (e) => e.extra['path'],
                'path',
                'canvases/c1/videos/missing.mp4',
              ),
        ),
      );
    });

    test('输入路径逃逸 → PathSecurityError（resolver 抛出）', () async {
      final svc = buildService();

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>['../../outside.mp4'],
        ),
        throwsA(isA<PathSecurityError>()),
      );
    });

    test('outputBaseName 含分隔符或 .. → PathSecurityError', () async {
      final svc = buildService();

      for (final bad in <String>[
        'a/b', r'a\b', '..', 'x..y', 'a:b', '',
        // Windows 保留设备名(Win10 经典解析会重定向到设备)
        'CON', 'nul', 'lpt3',
      ]) {
        await expectLater(
          svc.concat(
            projectId: projectId,
            inputRelativePaths: const <String>[relA],
            outputBaseName: bad,
          ),
          throwsA(isA<PathSecurityError>()),
          reason: 'should reject: $bad',
        );
      }
    });

    test('ffmpeg 未安装（locator=null）→ LocalIOError(ffmpeg_not_found)', () async {
      final svc = buildService(ffmpegPath: null);

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
        ),
        throwsA(
          isA<LocalIOError>()
              .having((e) => e.extra['reason'], 'reason', 'ffmpeg_not_found'),
        ),
      );
      expect(runner.executable, isNull);
    });

    test('ffmpeg 非零退出 → LocalIOError(ffmpeg_failed)，stderr 进 extra', () async {
      runner
        ..exitCode = 1
        ..stderrText = 'boom: invalid data';
      final svc = buildService();

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
        ),
        throwsA(
          isA<LocalIOError>()
              .having((e) => e.extra['reason'], 'reason', 'ffmpeg_failed')
              .having((e) => e.extra['exit_code'], 'exit_code', 1)
              .having(
                (e) => e.extra['stderr'],
                'stderr',
                contains('boom: invalid data'),
              ),
        ),
      );
    });

    test('运行期 ProcessException → LocalIOError(ffmpeg_not_found) + 缓存失效', () async {
      runner.throwOnRun = true;
      final svc = buildService();

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
        ),
        throwsA(
          isA<LocalIOError>()
              .having((e) => e.extra['reason'], 'reason', 'ffmpeg_not_found')
              .having((e) => e.cause, 'cause', isA<ProcessException>()),
        ),
      );
      expect(locator.invalidations, 1,
          reason: 'TOCTOU 后应失效 locator 缓存,下次重新探测');
    });

    test('ffmpeg 非零退出 → 半截输出产物被清理', () async {
      runner.exitCode = 1;
      final svc = buildService();
      // 预置"ffmpeg -y 已写出的半截产物"
      final partial = resolver.resolveInProject(
        projectId: projectId,
        relativePath: 'exports/partial.mp4',
      )
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(const <int>[9, 9]);

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
          outputBaseName: 'partial',
        ),
        throwsA(
          isA<LocalIOError>()
              .having((e) => e.extra['reason'], 'reason', 'ffmpeg_failed'),
        ),
      );
      expect(partial.existsSync(), isFalse, reason: '失败不留损坏产物');
    });

    test('临时 list 文件成功路径清理', () async {
      final svc = buildService();

      await svc.concat(
        projectId: projectId,
        inputRelativePaths: const <String>[relA],
        outputBaseName: 'ok',
      );

      expect(runner.listPath, isNotNull);
      expect(File(runner.listPath!).existsSync(), isFalse);
      expect(Directory(p.dirname(runner.listPath!)).existsSync(), isFalse);
    });

    test('临时 list 文件失败路径同样清理', () async {
      runner.exitCode = 1;
      final svc = buildService();

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
        ),
        throwsA(isA<LocalIOError>()),
      );

      expect(runner.listPath, isNotNull);
      expect(File(runner.listPath!).existsSync(), isFalse);
      expect(Directory(p.dirname(runner.listPath!)).existsSync(), isFalse);
    });
  });
}

class _FakeLocator implements FfmpegLocator {
  _FakeLocator(this.path);
  final String? path;
  int invalidations = 0;

  @override
  Future<String?> locate() async => path;

  @override
  void invalidate() => invalidations++;
}

class _FixedClock implements Clock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 7, 3, 12);
}

class _FakeRunner implements ProcessRunner {
  String? executable;
  List<String>? arguments;
  String? listPath;
  String? listContent;
  int exitCode = 0;
  String stderrText = '';
  bool throwOnRun = false;

  @override
  Future<ProcessResult> run(String exe, List<String> args) async {
    executable = exe;
    arguments = List<String>.of(args);
    if (throwOnRun) throw ProcessException(exe, args, 'gone', 2);
    final i = args.indexOf('-i');
    if (i >= 0 && i + 1 < args.length) {
      listPath = args[i + 1];
      // 服务在 finally 里删 list——此处即时读出内容供断言。
      listContent = File(args[i + 1]).readAsStringSync();
    }
    return ProcessResult(1, exitCode, '', stderrText);
  }
}
