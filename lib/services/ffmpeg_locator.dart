// FfmpegLocator：探测系统 ffmpeg 可执行文件（M3 视频导出首切片）。
//
// 参照 PgBinaryLocator 的分层查找模式，但 ffmpeg 不随应用打包
// （体积/许可评估延后），只探测外部安装：
//   1) 环境变量 INKFRAME_FFMPEG 指定完整可执行路径
//   2) PATH 上的 `ffmpeg`
// 候选以 `<exe> -version` 退出码 0 判定可用。命中结果缓存；
// 未命中不缓存——用户装好 ffmpeg 后无需重启即可重试。
import 'dart:io';

import '../core/interfaces/process_runner.dart';

abstract class FfmpegLocator {
  /// 返回可用的 ffmpeg 可执行路径（PATH 命中时即 `ffmpeg`），找不到返回 null。
  Future<String?> locate();

  /// 使命中缓存失效：曾探测成功的二进制在运行期消失（卸载/移动）后调用，
  /// 下次 locate 重新探测,无需重启应用。
  void invalidate();
}

class DefaultFfmpegLocator implements FfmpegLocator {
  DefaultFfmpegLocator({
    required ProcessRunner runner,
    Map<String, String>? environment,
  })  : _runner = runner,
        _env = environment ?? Platform.environment;

  static const String _kEnvVar = 'INKFRAME_FFMPEG';

  final ProcessRunner _runner;
  final Map<String, String> _env;

  String? _cached;

  @override
  void invalidate() => _cached = null;

  @override
  Future<String?> locate() async {
    final cached = _cached;
    if (cached != null) return cached;

    final envPath = _env[_kEnvVar];
    final candidates = <String>[
      if (envPath != null && envPath.isNotEmpty) envPath,
      'ffmpeg',
    ];
    for (final exe in candidates) {
      if (await _probe(exe)) {
        _cached = exe;
        return exe;
      }
    }
    return null;
  }

  Future<bool> _probe(String exe) async {
    try {
      final result = await _runner.run(exe, const <String>['-version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
