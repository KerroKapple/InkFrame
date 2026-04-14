// PgBinaryLocator：按平台定位嵌入式 PostgreSQL 二进制目录。
//
// 约定（PRD §22.1）：
//   macOS-arm64 : macos/Runner/Resources/pg/macos-arm64/bin + /lib
//   macOS-x64   : macos/Runner/Resources/pg/macos-x64/bin  + /lib
//   Windows-x64 : windows/runner/resources/pg/windows-x64/bin + /lib
//
// 三条查找路径（按优先级）：
//   1) 环境变量 INKFRAME_PG_BIN 明确指定 bin 目录（开发机 / CI 使用 Homebrew PG 时走这条）
//   2) 应用 Bundle 打包的 resources 相对路径（生产）
//   3) 仓库源代码相对路径（本地开发，从仓库根启动时自动命中）
//
// 不命中 → 抛 PgBinaryNotFoundError。上层 PgController 会把它翻译成 InkError。
import 'dart:io';

import 'package:path/path.dart' as p;

/// 平台 ID。与 `scripts/pg/fetch-binaries.sh` 和 resources 目录名保持一致。
enum PgPlatform {
  macosArm64('macos-arm64'),
  macosX64('macos-x64'),
  windowsX64('windows-x64'),
  linuxX64('linux-x64');

  const PgPlatform(this.wire);
  final String wire;

  /// 按当前运行平台推断。Linux 仅作本地烟测用，不进发布。
  static PgPlatform current() {
    if (Platform.isMacOS) {
      // ProcessInfo 不区分 arm/x86，取 uname -m。
      final arch = _arch();
      return arch == 'arm64' ? PgPlatform.macosArm64 : PgPlatform.macosX64;
    }
    if (Platform.isWindows) return PgPlatform.windowsX64;
    if (Platform.isLinux) return PgPlatform.linuxX64;
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  static String _arch() {
    try {
      final result = Process.runSync('uname', <String>['-m']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } on ProcessException {
      // uname 不可用时退回 x64。
    }
    return 'x64';
  }
}

/// 二进制定位结果。
class PgBinaryLocation {
  const PgBinaryLocation({required this.binDir, required this.libDir});
  final Directory binDir;
  final Directory libDir;

  File get initdb => File(p.join(binDir.path, _exe('initdb')));
  File get pgCtl => File(p.join(binDir.path, _exe('pg_ctl')));
  File get postgres => File(p.join(binDir.path, _exe('postgres')));

  static String _exe(String name) =>
      Platform.isWindows ? '$name.exe' : name;
}

class PgBinaryNotFoundError extends StateError {
  PgBinaryNotFoundError(super.message);
}

/// Locator 契约——测试可注入 fake。
abstract class PgBinaryLocator {
  PgBinaryLocation locate();
}

/// 默认实现：按 PgPlatform + 三条路径策略。
class DefaultPgBinaryLocator implements PgBinaryLocator {
  DefaultPgBinaryLocator({
    PgPlatform? platform,
    Map<String, String>? environment,
    Directory? repoRoot,
  })  : _platform = platform ?? PgPlatform.current(),
        _env = environment ?? Platform.environment,
        _repoRoot = repoRoot ?? Directory.current;

  final PgPlatform _platform;
  final Map<String, String> _env;
  final Directory _repoRoot;

  @override
  PgBinaryLocation locate() {
    // 1) 环境变量优先
    final envBin = _env['INKFRAME_PG_BIN'];
    if (envBin != null && envBin.isNotEmpty) {
      final binDir = Directory(envBin);
      final libDir = Directory(p.normalize(p.join(envBin, '..', 'lib')));
      if (_isUsable(binDir)) {
        return PgBinaryLocation(binDir: binDir, libDir: libDir);
      }
    }

    // 2) 应用 Bundle：Platform.resolvedExecutable → .../<App>.app/Contents/Resources/pg/<platform>/bin
    final bundleCandidates = _bundleCandidates();
    for (final b in bundleCandidates) {
      if (_isUsable(b.binDir)) return b;
    }

    // 3) 源码仓库相对路径
    final repoCandidate = _repoCandidate();
    if (_isUsable(repoCandidate.binDir)) return repoCandidate;

    throw PgBinaryNotFoundError(
      'PostgreSQL binaries not found for ${_platform.wire}. '
      'Tried INKFRAME_PG_BIN, app bundle resources, and repo resources. '
      'Run scripts/pg/fetch-binaries.sh or set INKFRAME_PG_BIN.',
    );
  }

  bool _isUsable(Directory binDir) {
    if (!binDir.existsSync()) return false;
    final postgres = File(
      p.join(binDir.path, PgBinaryLocation._exe('postgres')),
    );
    return postgres.existsSync();
  }

  List<PgBinaryLocation> _bundleCandidates() {
    final exe = File(Platform.resolvedExecutable);
    final out = <PgBinaryLocation>[];
    if (!exe.existsSync()) return out;

    // macOS: <App>.app/Contents/MacOS/inkframe → ../Resources/pg/<platform>/
    final macOsResources = Directory(
      p.normalize(
        p.join(exe.parent.path, '..', 'Resources', 'pg', _platform.wire),
      ),
    );
    out.add(
      PgBinaryLocation(
        binDir: Directory(p.join(macOsResources.path, 'bin')),
        libDir: Directory(p.join(macOsResources.path, 'lib')),
      ),
    );

    // Windows: <build>/inkframe.exe → resources/pg/<platform>/
    final winResources = Directory(
      p.normalize(p.join(exe.parent.path, 'resources', 'pg', _platform.wire)),
    );
    out.add(
      PgBinaryLocation(
        binDir: Directory(p.join(winResources.path, 'bin')),
        libDir: Directory(p.join(winResources.path, 'lib')),
      ),
    );
    return out;
  }

  PgBinaryLocation _repoCandidate() {
    final relative = switch (_platform) {
      PgPlatform.macosArm64 ||
      PgPlatform.macosX64 =>
        p.join('macos', 'Runner', 'Resources', 'pg', _platform.wire),
      PgPlatform.windowsX64 =>
        p.join('windows', 'runner', 'resources', 'pg', _platform.wire),
      PgPlatform.linuxX64 => p.join('build', 'pg', _platform.wire),
    };
    final base = Directory(p.join(_repoRoot.path, relative));
    return PgBinaryLocation(
      binDir: Directory(p.join(base.path, 'bin')),
      libDir: Directory(p.join(base.path, 'lib')),
    );
  }
}
