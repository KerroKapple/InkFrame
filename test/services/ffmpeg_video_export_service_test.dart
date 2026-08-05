// FfmpegVideoExportService 单测：fake starter 捕获完整命令行 + list 文件内容，
// 覆盖 concat demuxer 正常路径、错误映射、临时文件清理（成功/失败两路）、
// 进度解析（out_time_ms 微秒怪癖/单调/垃圾行防御）与取消路径（EX-3）。
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/core/interfaces/video_export_service.dart';
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
    late _FakeStarter starter;
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
      starter = _FakeStarter();
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
        processStarter: starter,
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
      expect(starter.executable, 'ffmpeg');
      final args = starter.arguments!;
      expect(args, hasLength(13));
      expect(args.sublist(0, 5), <String>['-f', 'concat', '-safe', '0', '-i']);
      expect(args[5], starter.listPath);
      expect(args.sublist(6), <String>[
        '-c', 'copy',
        '-progress', 'pipe:1',
        '-nostats',
        '-y', outAbs,
      ]);

      final absA = resolver
          .resolveInProject(projectId: projectId, relativePath: relA)
          .path;
      final absB = resolver
          .resolveInProject(projectId: projectId, relativePath: relB)
          .path;
      final escapedB = absB.replaceAll("'", r"'\''");
      expect(starter.listContent, "file '$absA'\nfile '$escapedB'\n");

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
      expect(starter.executable, isNull, reason: '不应触发 ffmpeg');
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
        // Windows 文件名非法字符
        'final*cut', 'a?b', 'x|y', 'a"b', 'x<y', 'x>y',
        // Windows 保留设备名(Win10 经典解析会重定向到设备)，含带扩展名形态
        'CON', 'nul', 'lpt3', 'con.backup', 'NUL.mp4', 'Com1.txt',
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

    test('保留名按首个点段匹配：普通前缀 console / config-x 放行', () async {
      final svc = buildService();

      for (final ok in <String>['console', 'config-x']) {
        expect(
          await svc.concat(
            projectId: projectId,
            inputRelativePaths: const <String>[relA],
            outputBaseName: ok,
          ),
          'exports/$ok.mp4',
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
      expect(starter.executable, isNull);
    });

    test('ffmpeg 非零退出 → LocalIOError(ffmpeg_failed)，stderr 进 extra', () async {
      starter
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

    test('启动期 ProcessException → LocalIOError(ffmpeg_not_found) + 缓存失效', () async {
      starter.throwOnStart = true;
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
      starter.exitCode = 1;
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

      expect(starter.listPath, isNotNull);
      expect(File(starter.listPath!).existsSync(), isFalse);
      expect(Directory(p.dirname(starter.listPath!)).existsSync(), isFalse);
    });

    test('临时 list 文件失败路径同样清理', () async {
      starter.exitCode = 1;
      final svc = buildService();

      await expectLater(
        svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
        ),
        throwsA(isA<LocalIOError>()),
      );

      expect(starter.listPath, isNotNull);
      expect(File(starter.listPath!).existsSync(), isFalse);
      expect(Directory(p.dirname(starter.listPath!)).existsSync(), isFalse);
    });

    group('进度（EX-3）', () {
      test('out_time_ms(微秒) → 0..1 回调，忽略无关行，末尾强制 1.0', () async {
        starter.stdoutLines = <String>[
          'frame=10',
          'out_time_ms=1500000', // 1.5s（键名 ms 实为微秒）
          'fps=30.2',
          'out_time_ms=3000000', // 3.0s
          'progress=end',
        ];
        final svc = buildService();
        final seen = <double>[];

        await svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
          outputBaseName: 'ok',
          totalDurationMs: 3000,
          onProgress: seen.add,
        );

        expect(seen, <double>[0.5, 1.0]);
      });

      test('totalDurationMs 缺省/非正 → 零回调（indeterminate 语义）', () async {
        starter.stdoutLines = <String>['out_time_ms=1500000'];
        final svc = buildService();
        final seen = <double>[];

        await svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
          outputBaseName: 'a',
          onProgress: seen.add,
        );
        await svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
          outputBaseName: 'b',
          totalDurationMs: 0,
          onProgress: seen.add,
        );

        expect(seen, isEmpty);
      });

      test('进度单调：回退值/负值/垃圾行不回调，超界 clamp 到 1.0', () async {
        starter.stdoutLines = <String>[
          'out_time_ms=2000000',
          'out_time_ms=1000000', // 回退 → 忽略
          'out_time_ms=-500000', // 负值 → 忽略
          'out_time_ms=abc', // 乱码 → 忽略
          'out_time_ms=9000000', // 超总时长 → clamp 1.0
        ];
        final svc = buildService();
        final seen = <double>[];

        await svc.concat(
          projectId: projectId,
          inputRelativePaths: const <String>[relA],
          outputBaseName: 'ok',
          totalDurationMs: 4000,
          onProgress: seen.add,
        );

        expect(seen, <double>[0.5, 1.0]);
      });
    });

    group('取消（EX-3）', () {
      test('进行中取消 → kill + 半成品删除 + CancelledError + 临时目录清理', () async {
        starter.stdoutLines = <String>[
          'out_time_ms=1000000',
          'out_time_ms=2000000',
          'out_time_ms=3000000',
        ];
        final svc = buildService();
        final token = ExportCancelToken();
        // 预置"取消前 -y 已写出的半截产物"
        final partial = resolver.resolveInProject(
          projectId: projectId,
          relativePath: 'exports/cx.mp4',
        )
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(const <int>[7]);

        await expectLater(
          svc.concat(
            projectId: projectId,
            inputRelativePaths: const <String>[relA],
            outputBaseName: 'cx',
            totalDurationMs: 4000,
            onProgress: (_) => token.cancel(),
            cancelToken: token,
          ),
          throwsA(
            isA<CancelledError>().having(
              (e) => e.extra['reason'],
              'reason',
              'export_cancelled',
            ),
          ),
        );

        expect(starter.last!.killed, isTrue, reason: '取消必须 kill 子进程');
        expect(partial.existsSync(), isFalse, reason: '取消不留半成品');
        expect(File(starter.listPath!).existsSync(), isFalse);
        expect(Directory(p.dirname(starter.listPath!)).existsSync(), isFalse);
      });

      test('启动前已取消 → 立即 kill，不产出成功', () async {
        final svc = buildService();
        final token = ExportCancelToken()..cancel();

        await expectLater(
          svc.concat(
            projectId: projectId,
            inputRelativePaths: const <String>[relA],
            outputBaseName: 'pre',
            cancelToken: token,
          ),
          throwsA(isA<CancelledError>()),
        );
        expect(starter.last!.killed, isTrue);
      });

      test('取消后的非零退出不映射 ffmpeg_failed（CancelledError 优先）', () async {
        starter.stdoutLines = <String>['out_time_ms=1000000'];
        final svc = buildService();
        final token = ExportCancelToken();

        await expectLater(
          svc.concat(
            projectId: projectId,
            inputRelativePaths: const <String>[relA],
            outputBaseName: 'cy',
            totalDurationMs: 2000,
            onProgress: (_) => token.cancel(),
            cancelToken: token,
          ),
          throwsA(isA<CancelledError>()),
        );
      });
    });
  });

  group('ExportCancelToken', () {
    test('cancel 幂等；attach 后触发回调；已取消再 attach 立即回调', () {
      final token = ExportCancelToken();
      var calls = 0;
      token.attach(() => calls++);
      expect(token.isCancelled, isFalse);

      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(calls, 1);

      final late = ExportCancelToken()..cancel();
      var lateCalls = 0;
      late.attach(() => lateCalls++);
      expect(lateCalls, 1, reason: '已取消再 attach 应立即回调');
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

class _FakeStarter implements ProcessStarter {
  String? executable;
  List<String>? arguments;
  String? listPath;
  String? listContent;
  int exitCode = 0;
  String stderrText = '';
  bool throwOnStart = false;
  List<String> stdoutLines = <String>[];
  _FakeProcess? last;

  @override
  Future<RunningProcess> start(
    String exe,
    List<String> args, {
    Map<String, String>? environment,
  }) async {
    executable = exe;
    arguments = List<String>.of(args);
    if (throwOnStart) throw ProcessException(exe, args, 'gone', 2);
    final i = args.indexOf('-i');
    if (i >= 0 && i + 1 < args.length) {
      listPath = args[i + 1];
      // 服务在 finally 里删 list——此处即时读出内容供断言。
      listContent = File(args[i + 1]).readAsStringSync();
    }
    return last = _FakeProcess(
      lines: stdoutLines,
      exit: exitCode,
      stderr: stderrText,
    );
  }
}

class _FakeProcess implements RunningProcess {
  _FakeProcess({
    required List<String> lines,
    required int exit,
    required String stderr,
  })  : _lines = lines,
        _exit = exit,
        _stderr = stderr;

  final List<String> _lines;
  final int _exit;
  final String _stderr;
  bool killed = false;
  final Completer<int> _exitCompleter = Completer<int>();
  late final StreamController<String> _ctrl =
      StreamController<String>(onListen: _pump);

  Future<void> _pump() async {
    for (final line in _lines) {
      await Future<void>.delayed(Duration.zero);
      // kill 竞态：终止后停止发射，收尾由 kill() 负责。
      if (killed || _ctrl.isClosed) return;
      _ctrl.add(line);
    }
    await Future<void>.delayed(Duration.zero);
    if (!killed && !_ctrl.isClosed) {
      await _ctrl.close();
      _exitCompleter.complete(_exit);
    }
  }

  @override
  Stream<String> get stdoutLines => _ctrl.stream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  String get stderrTail => _stderr;

  @override
  void kill() {
    if (killed) return;
    killed = true;
    _ctrl.close();
    if (!_exitCompleter.isCompleted) _exitCompleter.complete(-15);
  }
}