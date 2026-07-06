import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_preferences_service.dart';

void main() {
  late Directory tmp;
  late AppPaths paths;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_prefs_');
    paths = DefaultAppPaths.forRoot(tmp);
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('缺文件 → load 返回默认值', () async {
    final svc = FilePreferencesService(paths);
    expect(await svc.load(), const AppPreferences());
  });

  test('update 落盘 + 新实例 load 读回', () async {
    final svc = FilePreferencesService(paths);
    await svc.load();
    await svc.update((p) => p.copyWith(
          themePreference: 'light',
          highContrast: true,
          textScale: 1.5,
          localeCode: 'zh',
        ));

    final loaded = await FilePreferencesService(paths).load();
    expect(loaded.themePreference, 'light');
    expect(loaded.highContrast, true);
    expect(loaded.textScale, 1.5);
    expect(loaded.localeCode, 'zh');
  });

  test('文件损坏 → load 退默认，不抛', () async {
    await paths.config.create(recursive: true);
    File('${paths.config.path}/preferences.json')
        .writeAsStringSync('{not valid json');
    expect(await FilePreferencesService(paths).load(), const AppPreferences());
  });
}
