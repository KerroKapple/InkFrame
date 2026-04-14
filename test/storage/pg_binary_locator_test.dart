// PgBinaryLocator 行为测试：三条查找路径优先级 + 不命中抛错。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/storage/pg_binary_locator.dart';
import 'package:path/path.dart' as p;

void main() {
  group('PgBinaryLocator', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('pg_locator_');
    });

    tearDown(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('env var INKFRAME_PG_BIN 最高优先级', () {
      final bin = Directory(p.join(tempRoot.path, 'env_bin'))
        ..createSync(recursive: true);
      _touchExec(File(p.join(bin.path, _exe('postgres'))));

      final locator = DefaultPgBinaryLocator(
        platform: PgPlatform.macosArm64,
        environment: {'INKFRAME_PG_BIN': bin.path},
        repoRoot: tempRoot,
      );

      final loc = locator.locate();
      expect(loc.binDir.path, bin.path);
    });

    test('repo 相对路径命中时返回 repo 候选', () {
      final repoBin = Directory(
        p.join(tempRoot.path, 'macos', 'Runner', 'Resources', 'pg',
            'macos-arm64', 'bin'),
      )..createSync(recursive: true);
      _touchExec(File(p.join(repoBin.path, _exe('postgres'))));

      final locator = DefaultPgBinaryLocator(
        platform: PgPlatform.macosArm64,
        environment: const {},
        repoRoot: tempRoot,
      );

      final loc = locator.locate();
      expect(loc.binDir.path, repoBin.path);
      expect(loc.postgres.existsSync(), isTrue);
    });

    test('Windows 平台走 windows/runner/resources 路径', () {
      final repoBin = Directory(
        p.join(tempRoot.path, 'windows', 'runner', 'resources', 'pg',
            'windows-x64', 'bin'),
      )..createSync(recursive: true);
      final exe = File(p.join(repoBin.path, _exe('postgres')));
      _touchExec(exe);

      final locator = DefaultPgBinaryLocator(
        platform: PgPlatform.windowsX64,
        environment: const {},
        repoRoot: tempRoot,
      );

      final loc = locator.locate();
      expect(loc.binDir.path, repoBin.path);
    });

    test('全部未命中抛 PgBinaryNotFoundError', () {
      final locator = DefaultPgBinaryLocator(
        platform: PgPlatform.macosArm64,
        environment: const {},
        repoRoot: tempRoot,
      );
      expect(locator.locate, throwsA(isA<PgBinaryNotFoundError>()));
    });

    test('INKFRAME_PG_BIN 为空字符串走下一候选', () {
      final repoBin = Directory(
        p.join(tempRoot.path, 'macos', 'Runner', 'Resources', 'pg',
            'macos-x64', 'bin'),
      )..createSync(recursive: true);
      _touchExec(File(p.join(repoBin.path, _exe('postgres'))));

      final locator = DefaultPgBinaryLocator(
        platform: PgPlatform.macosX64,
        environment: const {'INKFRAME_PG_BIN': ''},
        repoRoot: tempRoot,
      );
      expect(locator.locate().binDir.path, repoBin.path);
    });
  });
}

void _touchExec(File f) {
  f.createSync(recursive: true);
  // Windows 下 Dart 的 File 没有 chmod 概念，postgres.exe 只要存在即算命中。
  if (!Platform.isWindows) {
    Process.runSync('chmod', <String>['+x', f.path]);
  }
}

String _exe(String name) => Platform.isWindows ? '$name.exe' : name;
