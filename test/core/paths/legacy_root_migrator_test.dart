import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/legacy_root_migrator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_dir1_');
  });

  tearDown(() {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  Directory legacy() => Directory(p.join(tmp.path, 'home', 'InkFrame'));
  Directory target() =>
      Directory(p.join(tmp.path, 'AppData', 'Local', 'InkFrame'));

  LegacyRootMigrator migrator({
    Future<void> Function(Directory from, String toPath)? moveDirectory,
  }) =>
      LegacyRootMigrator(
        legacyRoot: legacy(),
        targetRoot: target(),
        moveDirectory: moveDirectory,
      );

  // 造一个带嵌套真实数据的旧根（config + database 两支）。
  void seedLegacy() {
    File(p.join(legacy().path, 'config', 'preferences.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"theme":"dark"}');
    File(p.join(legacy().path, 'database', 'PG_VERSION'))
      ..createSync(recursive: true)
      ..writeAsStringSync('17');
  }

  group('LegacyRootMigrator.shouldRun', () {
    test('惯例根解析失败（fallback 根）→ 不迁移（防搬进 path_provider 兜底目录）', () {
      expect(
        LegacyRootMigrator.shouldRun(
          conventionalRoot: null,
          legacyRoot: r'C:\Users\u\InkFrame',
        ),
        isFalse,
      );
    });

    test('无旧址 / 新旧同路径 → 不迁移；两者有效且不同 → 迁移', () {
      expect(
        LegacyRootMigrator.shouldRun(
          conventionalRoot: r'C:\Users\u\AppData\Local\InkFrame',
          legacyRoot: null,
        ),
        isFalse,
      );
      expect(
        LegacyRootMigrator.shouldRun(
          conventionalRoot: '/same/InkFrame',
          legacyRoot: '/same/InkFrame',
        ),
        isFalse,
      );
      expect(
        LegacyRootMigrator.shouldRun(
          conventionalRoot: r'C:\Users\u\AppData\Local\InkFrame',
          legacyRoot: r'C:\Users\u\InkFrame',
        ),
        isTrue,
      );
    });
  });

  group('LegacyRootMigrator.migrate', () {
    test('全新安装（旧址不存在）→ freshInstall，不创建任何目录', () async {
      final result = await migrator().migrate();

      expect(result.outcome, LegacyMigrationOutcome.freshInstall);
      expect(result.effectiveRoot.path, target().path);
      // 目录创建交给 ensureInitialized，迁移器自身不落任何东西。
      expect(target().existsSync(), isFalse);
      expect(legacy().existsSync(), isFalse);
    });

    test('旧址存在且目标不存在 → 整树搬迁，数据完整落新址', () async {
      seedLegacy();

      final result = await migrator().migrate();

      expect(result.outcome, LegacyMigrationOutcome.migrated);
      expect(result.effectiveRoot.path, target().path);
      expect(
        File(p.join(target().path, 'config', 'preferences.json'))
            .readAsStringSync(),
        '{"theme":"dark"}',
      );
      expect(
        File(p.join(target().path, 'database', 'PG_VERSION'))
            .readAsStringSync(),
        '17',
      );
    });

    test('搬迁成功后旧址只留 MOVED 标记文件（内容含新址路径）', () async {
      seedLegacy();

      await migrator().migrate();

      final File marker =
          File(p.join(legacy().path, LegacyRootMigrator.markerFileName));
      expect(marker.existsSync(), isTrue);
      expect(marker.readAsStringSync(), contains(target().path));
      // 旧址除标记外不残留任何数据。
      expect(legacy().listSync(), hasLength(1));
    });

    test('目标已存在 → alreadyAtTarget，旧址残留原样不动（防重复搬迁）', () async {
      seedLegacy();
      Directory(p.join(target().path, 'config')).createSync(recursive: true);

      final result = await migrator().migrate();

      expect(result.outcome, LegacyMigrationOutcome.alreadyAtTarget);
      expect(result.effectiveRoot.path, target().path);
      expect(
        File(p.join(legacy().path, 'config', 'preferences.json')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(legacy().path, LegacyRootMigrator.markerFileName))
            .existsSync(),
        isFalse,
      );
    });

    test('旧址只剩 MOVED 标记（空壳）→ freshInstall，不搬迁、不再写标记', () async {
      File(p.join(legacy().path, LegacyRootMigrator.markerFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync('InkFrame data moved to: elsewhere\n');

      final result = await migrator().migrate();

      expect(result.outcome, LegacyMigrationOutcome.freshInstall);
      expect(result.effectiveRoot.path, target().path);
      expect(target().existsSync(), isFalse);
      // 空壳原样保留（仍只有那一个标记文件）。
      expect(legacy().listSync(), hasLength(1));
    });

    test('旧址是空目录 → freshInstall，不做无意义搬迁', () async {
      legacy().createSync(recursive: true);

      final result = await migrator().migrate();

      expect(result.outcome, LegacyMigrationOutcome.freshInstall);
      expect(target().existsSync(), isFalse);
    });

    test('目标已存在且旧址仍有真实数据 → legacyDataIgnored=true（供启动日志告警）', () async {
      seedLegacy();
      Directory(p.join(target().path, 'config')).createSync(recursive: true);

      final result = await migrator().migrate();

      expect(result.outcome, LegacyMigrationOutcome.alreadyAtTarget);
      expect(result.legacyDataIgnored, isTrue);
    });

    test('目标已存在且旧址只剩标记 → legacyDataIgnored=false（无告警噪音）', () async {
      File(p.join(legacy().path, LegacyRootMigrator.markerFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync('moved\n');
      Directory(p.join(target().path, 'config')).createSync(recursive: true);

      final result = await migrator().migrate();

      expect(result.outcome, LegacyMigrationOutcome.alreadyAtTarget);
      expect(result.legacyDataIgnored, isFalse);
    });

    test('搬迁失败 → failureReason 携带底层原因（可诊断）', () async {
      seedLegacy();

      final result = await migrator(
        moveDirectory: (Directory from, String toPath) async {
          throw const FileSystemException('cross-device link');
        },
      ).migrate();

      expect(result.outcome, LegacyMigrationOutcome.keptLegacy);
      expect(result.failureReason, contains('cross-device link'));
    });

    test('搬迁失败 → keptLegacy，旧址完好无标记，本次会话继续用旧址', () async {
      seedLegacy();

      final result = await migrator(
        moveDirectory: (Directory from, String toPath) async {
          throw const FileSystemException('cross-device link');
        },
      ).migrate();

      expect(result.outcome, LegacyMigrationOutcome.keptLegacy);
      expect(result.effectiveRoot.path, legacy().path);
      expect(
        File(p.join(legacy().path, 'config', 'preferences.json'))
            .readAsStringSync(),
        '{"theme":"dark"}',
      );
      expect(
        File(p.join(legacy().path, LegacyRootMigrator.markerFileName))
            .existsSync(),
        isFalse,
      );
      expect(target().existsSync(), isFalse);
    });
  });
}
