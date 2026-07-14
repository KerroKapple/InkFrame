import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DefaultAppPaths.conventionalRootPath', () {
    test('Windows → %LOCALAPPDATA%\\InkFrame', () {
      expect(
        DefaultAppPaths.conventionalRootPath(
          isWindows: true,
          isMacOS: false,
          env: <String, String>{'LOCALAPPDATA': r'C:\Users\u\AppData\Local'},
        ),
        p.join(r'C:\Users\u\AppData\Local', 'InkFrame'),
      );
    });

    test('macOS → ~/Library/Application Support/InkFrame', () {
      expect(
        DefaultAppPaths.conventionalRootPath(
          isWindows: false,
          isMacOS: true,
          env: <String, String>{'HOME': '/Users/u'},
        ),
        p.join('/Users/u', 'Library', 'Application Support', 'InkFrame'),
      );
    });

    test('对应环境变量缺失或非 Win/mac 平台 → null（回退 path_provider）', () {
      expect(
        DefaultAppPaths.conventionalRootPath(
          isWindows: true,
          isMacOS: false,
          env: const <String, String>{},
        ),
        isNull,
      );
      expect(
        DefaultAppPaths.conventionalRootPath(
          isWindows: false,
          isMacOS: true,
          env: const <String, String>{},
        ),
        isNull,
      );
      expect(
        DefaultAppPaths.conventionalRootPath(
          isWindows: false,
          isMacOS: false,
          env: <String, String>{'HOME': '/home/u'},
        ),
        isNull,
      );
    });
  });

  group('DefaultAppPaths.legacyRootPath', () {
    test('HOME 优先，USERPROFILE 兜底', () {
      expect(
        DefaultAppPaths.legacyRootPath(
          <String, String>{'HOME': '/Users/u', 'USERPROFILE': r'C:\Users\u'},
        ),
        p.join('/Users/u', 'InkFrame'),
      );
      expect(
        DefaultAppPaths.legacyRootPath(
          <String, String>{'USERPROFILE': r'C:\Users\u'},
        ),
        p.join(r'C:\Users\u', 'InkFrame'),
      );
    });

    test('两者都缺失 → null（无旧址可迁）', () {
      expect(
        DefaultAppPaths.legacyRootPath(const <String, String>{}),
        isNull,
      );
    });
  });

  group('DefaultAppPaths.forRoot', () {
    test('exposes logs / crashes / config / database / projects under root',
        () {
      final tmp = Directory.systemTemp.createTempSync('ink_paths_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final paths = DefaultAppPaths.forRoot(tmp);
      expect(paths.root.path, tmp.path);
      expect(paths.logs.path, p.join(tmp.path, 'logs'));
      expect(paths.crashes.path, p.join(tmp.path, 'crashes'));
      expect(paths.config.path, p.join(tmp.path, 'config'));
      expect(paths.database.path, p.join(tmp.path, 'database'));
      expect(paths.projects.path, p.join(tmp.path, 'projects'));
    });

    test('ensureInitialized creates all subdirs', () async {
      final tmp = Directory.systemTemp.createTempSync('ink_paths_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final paths = DefaultAppPaths.forRoot(Directory(p.join(tmp.path, 'root')));
      await paths.ensureInitialized();
      expect(await paths.root.exists(), isTrue);
      expect(await paths.logs.exists(), isTrue);
      expect(await paths.crashes.exists(), isTrue);
      expect(await paths.config.exists(), isTrue);
      expect(await paths.database.exists(), isTrue);
      expect(await paths.projects.exists(), isTrue);
    });
  });
}
