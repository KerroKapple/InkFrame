import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:path/path.dart' as p;

void main() {
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
