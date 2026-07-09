// ProcessUrlOpenerService 单测（UPD-1）。
//
// 用系统自带命令打开默认浏览器（macOS `open` / Windows rundll32）,
// 复用 ProcessRunner 抽象——不为「打开一个 URL」引入 url_launcher 及其插件链。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/process_runner.dart';
import 'package:inkframe/services/process_url_opener_service.dart';

class _RecordingRunner implements ProcessRunner {
  _RecordingRunner({this.exitCode = 0, this.throws = false});

  final int exitCode;
  final bool throws;
  final List<(String, List<String>)> calls = <(String, List<String>)>[];

  @override
  Future<ProcessResult> run(String executable, List<String> arguments) async {
    calls.add((executable, arguments));
    if (throws) {
      throw ProcessException(executable, arguments, 'not found');
    }
    return ProcessResult(1, exitCode, '', '');
  }
}

final Uri _kUrl =
    Uri.parse('https://github.com/KerroKapple/InkFrame/releases/tag/v1');

void main() {
  test('macOS 走 open <url>', () async {
    final runner = _RecordingRunner();
    final opener = ProcessUrlOpenerService(runner: runner, isWindows: false);

    await opener.openExternal(_kUrl);

    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.$1, 'open');
    expect(runner.calls.single.$2, [_kUrl.toString()]);
  });

  test('Windows 走 rundll32 FileProtocolHandler', () async {
    final runner = _RecordingRunner();
    final opener = ProcessUrlOpenerService(runner: runner, isWindows: true);

    await opener.openExternal(_kUrl);

    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.$1, 'rundll32');
    expect(
      runner.calls.single.$2,
      ['url.dll,FileProtocolHandler', _kUrl.toString()],
    );
  });

  test('非 http(s) scheme 拒绝：不执行命令并抛 ArgumentError', () async {
    final runner = _RecordingRunner();
    final opener = ProcessUrlOpenerService(runner: runner, isWindows: false);

    await expectLater(
      opener.openExternal(Uri.parse('file:///etc/passwd')),
      throwsArgumentError,
    );
    expect(runner.calls, isEmpty);
  });

  test('非零退出码 → LocalIOError', () async {
    final runner = _RecordingRunner(exitCode: 1);
    final opener = ProcessUrlOpenerService(runner: runner, isWindows: false);

    await expectLater(
      opener.openExternal(_kUrl),
      throwsA(isA<LocalIOError>()),
    );
  });

  test('可执行文件缺失（ProcessException）→ LocalIOError', () async {
    final runner = _RecordingRunner(throws: true);
    final opener = ProcessUrlOpenerService(runner: runner, isWindows: true);

    await expectLater(
      opener.openExternal(_kUrl),
      throwsA(isA<LocalIOError>()),
    );
  });
}
