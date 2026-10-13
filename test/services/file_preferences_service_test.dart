import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/models/app_preferences.dart';
import 'package:inkframe/core/models/window_bounds.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/services/file_preferences_service.dart';

import '../helpers/recording_logger.dart';

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

  // ---- 原子写 / 失败留痕（2026-10-13）----
  //
  // 原来直接覆写、catch 块是空的：写到一半被杀 ⇒ 半截 JSON ⇒ 下次启动静默退默认
  // ⇒ 下一次任何改动把默认值写回去 ⇒ 全部设置（含「首启向导已完成」）永久丢失，
  // 日志里什么都没有。

  test('文件损坏 → 先把坏文件另存为 .corrupt 再退默认，并落 warn', () async {
    await paths.config.create(recursive: true);
    const String broken = '{"themePreference": "light", "loca';
    File('${paths.config.path}/preferences.json').writeAsStringSync(broken);
    final RecordingLogger logger = RecordingLogger();

    expect(await FilePreferencesService(paths, logger: logger).load(),
        const AppPreferences());

    expect(
      File('${paths.config.path}/preferences.json.corrupt').readAsStringSync(),
      broken,
      reason: '下一次 update 会用默认值覆盖原文件——不另存，设置连同丢失原因一起没了',
    );
    expect(
      logger.byLevel(InkLogLevel.warn).map((LogRecord r) => r.msg),
      contains('preferences.corrupt'),
    );
  });

  test('写盘失败 → 落 warn、内存值仍在，不抛', () async {
    // 把 config 目录的位置占成一个文件：create(recursive) 必然失败。
    File(paths.config.path).createSync(recursive: true);
    final RecordingLogger logger = RecordingLogger();
    final svc = FilePreferencesService(paths, logger: logger);

    await svc.update((p) => p.copyWith(themePreference: 'light'));

    expect(svc.current.themePreference, 'light', reason: '内存更新不该被写盘失败拖累');
    expect(
      logger.byLevel(InkLogLevel.warn).map((LogRecord r) => r.msg),
      contains('preferences.write_failed'),
      reason: '持续写不进去时，用户每次重启都丢设置——日志是唯一线索',
    );
  });

  test('写盘失败 → 原来那份完整的 preferences.json 原样保留', () async {
    final svc = FilePreferencesService(paths);
    await svc.load();
    await svc.update((p) => p.copyWith(themePreference: 'light'));
    final File f = File('${paths.config.path}/preferences.json');
    final String before = f.readAsStringSync();
    // 让 .partial 写不进去（同名目录）。原子写只在 .partial 写完之后才动原文件。
    Directory('${f.path}.partial').createSync();

    await svc.update((p) => p.copyWith(themePreference: 'dark'));

    expect(f.readAsStringSync(), before,
        reason: '写失败不能留下半截文件——原文件必须还是上一次完整写入的样子');
    expect(
      (await FilePreferencesService(paths).load()).themePreference,
      'light',
    );
  });

  test('写完不留 .partial', () async {
    final svc = FilePreferencesService(paths);
    await svc.update((p) => p.copyWith(themePreference: 'light'));
    expect(File('${paths.config.path}/preferences.json.partial').existsSync(),
        isFalse);
  });

  test('窗口状态 update 落盘 + 新实例 load 读回', () async {
    final svc = FilePreferencesService(paths);
    await svc.load();
    await svc.update((p) => p.copyWith(
          windowBounds:
              const WindowBounds(x: 120, y: 80, width: 1440, height: 900),
          windowMaximized: true,
        ));

    final loaded = await FilePreferencesService(paths).load();
    expect(loaded.windowBounds,
        const WindowBounds(x: 120, y: 80, width: 1440, height: 900));
    expect(loaded.windowMaximized, true);
  });
}
