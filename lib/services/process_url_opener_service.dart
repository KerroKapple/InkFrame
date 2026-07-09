// ProcessUrlOpenerService：用系统自带命令在默认浏览器打开 URL（UPD-1）。
//
// 刻意不引 url_launcher：桌面双平台（macOS/Windows）各有稳定的系统级入口
// （`open` / rundll32 FileProtocolHandler）,复用既有 ProcessRunner 抽象即可,
// 省掉一条插件依赖链（含平台侧 pod/CMake 产物）与 pubspec.lock 漂移。
import 'dart:io';

import '../core/errors/ink_error.dart';
import '../core/interfaces/process_runner.dart';
import '../core/interfaces/url_opener_service.dart';

class ProcessUrlOpenerService implements UrlOpenerService {
  ProcessUrlOpenerService({required ProcessRunner runner, bool? isWindows})
      : _runner = runner,
        _isWindows = isWindows ?? Platform.isWindows;

  final ProcessRunner _runner;
  final bool _isWindows;

  @override
  Future<void> openExternal(Uri url) async {
    if (url.scheme != 'https' && url.scheme != 'http') {
      throw ArgumentError.value(url, 'url', 'only http/https can be opened');
    }
    final (String executable, List<String> arguments) = _isWindows
        ? ('rundll32', <String>['url.dll,FileProtocolHandler', url.toString()])
        : ('open', <String>[url.toString()]);
    try {
      final ProcessResult result = await _runner.run(executable, arguments);
      if (result.exitCode != 0) {
        throw LocalIOError(
          extra: <String, Object?>{
            'source': 'url_opener',
            'exit_code': result.exitCode,
            'url': url.toString(),
          },
        );
      }
    } on ProcessException catch (e) {
      throw LocalIOError(
        extra: <String, Object?>{
          'source': 'url_opener',
          'url': url.toString(),
        },
        cause: e,
      );
    }
  }
}
