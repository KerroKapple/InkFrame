// DIP 铁律回归：把原 check-direct-instantiation.sh 固化为 Dart 静态测试。
//
// 铁律（docs/CLAUDE.md §依赖注入）：所有 service / repository / provider 经 Riverpod
// ref.watch / ref.read 注入；唯一允许直接 new 的地方是 DI 装配层（lib/core/di/）与
// main.dart 引导。禁止静态单例（.instance / .shared / .singleton）、ServiceLocator /
// GetIt 模式、全局可变服务变量。
//
// 覆盖原脚本 4 类规则：
//   R1 直接实例化 *Service/*Repository/*Provider/*Client/*Manager/*Handler（非 DI 层、无 ref.）
//   R2 静态单例访问 X.instance / X.shared / X.singleton（豁免 Flutter 框架 binding 单例）
//   R3 ServiceLocator / GetIt 反模式（收窄：仅类型/构造级用法，避免 *_locator 服务名误报）
//   R4 全局可变服务变量（var/late 顶层 *Service= 等，未声明 final）
//
// 删除 check-direct-instantiation.sh 后，本测试是 DIP 铁律的回归靶子（custom_lint
// 升级接入前唯一的自动闸门）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isGenerated(String p) =>
    p.endsWith('.g.dart') ||
    p.endsWith('.freezed.dart') ||
    p.endsWith('_test.dart') ||
    p.contains('l10n/generated/') ||
    p.contains('generated/');

/// DI 装配层与引导入口是唯一允许直接 new 注入物的地方。
bool _isWiringFile(String p) =>
    p.contains('lib/core/di/') || p.endsWith('lib/main.dart');

/// 值对象 / 标准库类型：直接构造合法，不属于 DIP 注入物范畴。
const _allowedDirectClasses = <String>{
  'DateTime',
  'Duration',
  'Uri',
  'RegExp',
  'StringBuffer',
  'Map',
  'List',
  'Set',
  'File',
  'Directory',
  'Completer',
  'StreamController',
  'StreamSubscription',
  'TextEditingController',
  'ScrollController',
  'FocusNode',
  'GlobalKey',
  'ValueNotifier',
};

/// Flutter / Dart 框架单例：X.instance 是框架契约（WidgetsBinding.instance 等），
/// 非 app 自定义服务单例，对 R2 豁免。
const _frameworkSingletonOwners = <String>{
  'WidgetsBinding',
  'WidgetsFlutterBinding',
  'ServicesBinding',
  'SchedulerBinding',
  'GestureBinding',
  'PaintingBinding',
  'RendererBinding',
  'SemanticsBinding',
  'PlatformDispatcher',
  'HardwareKeyboard',
  'RawKeyboard',
};

void main() {
  // R1：直接实例化注入物。命中"赋值/返回 + 大写类名 + (" 且不含 ref.watch/read/listen。
  final r1Call = RegExp(
    r'[A-Z][a-zA-Z]*(Service|Repository|Provider|Client|Manager|Handler)\s*\(',
  );
  final r1AssignContext = RegExp(r'(return|=|final|var)\s+[A-Z].*\(');
  final r1RefAccess = RegExp(r'ref\.(watch|read|listen)');
  final r1ClassName = RegExp(
    r'[A-Z][a-zA-Z]*(Service|Repository|Provider|Client|Manager|Handler)',
  );

  // R2：静态单例访问。捕获 Owner 以便对框架 binding 豁免。
  final r2Singleton =
      RegExp(r'\b([A-Z][a-zA-Z]+)\.(instance|shared|singleton)\b');

  // R3：ServiceLocator / GetIt 反模式。收窄到类型/构造级用法，避免 *_locator 业务服务误报。
  //   命中 GetIt.xxx / ServiceLocator.xxx / GetIt<...> / GetIt( —— 不再匹配裸 'locator'/'sl'。
  final r3ServiceLocator = RegExp(r'\b(GetIt|ServiceLocator)\s*[<.(]');

  // R4：全局可变服务变量（顶层 var/late，名形如 xxxService=，未 final）。
  final r4GlobalMutable = RegExp(
    r'^(var|late)\s+[a-z][a-zA-Z]*(Service|Repository|Provider|Client)\s*=',
  );

  test('lib 下无直接实例化注入物 / 静态单例 / ServiceLocator / 全局可变服务（DIP 铁律）',
      () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ not found');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      if (_isGenerated(path)) continue;
      if (_isWiringFile(path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final trimmed = raw.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        final at = '$path:${i + 1}';

        // R1：直接实例化注入物（赋值/返回上下文，且非 ref. 注入）。
        if (r1Call.hasMatch(raw) &&
            r1AssignContext.hasMatch(raw) &&
            !r1RefAccess.hasMatch(raw)) {
          final cls = r1ClassName.firstMatch(raw)?.group(0);
          if (cls != null && !_allowedDirectClasses.contains(cls)) {
            violations.add(
              '$at  [R1 DIRECT_INSTANTIATION] new $cls(...) 违反 DIP，'
              '改经 ref.watch(provider) 注入 / 移到 lib/core/di/：${raw.trim()}',
            );
          }
        }

        // R2：静态单例访问（框架 binding 单例豁免）。
        for (final m in r2Singleton.allMatches(raw)) {
          final owner = m.group(1)!;
          if (_frameworkSingletonOwners.contains(owner)) continue;
          violations.add(
            '$at  [R2 STATIC_SINGLETON] ${m.group(0)} 是静态单例，禁用；'
            '改用 Riverpod keepAlive provider：${raw.trim()}',
          );
        }

        // R3：ServiceLocator / GetIt 反模式。
        if (r3ServiceLocator.hasMatch(raw)) {
          violations.add(
            '$at  [R3 SERVICE_LOCATOR] ServiceLocator/GetIt 反模式禁用，'
            '改用 ref.watch()：${raw.trim()}',
          );
        }

        // R4：全局可变服务变量。
        if (r4GlobalMutable.hasMatch(trimmed)) {
          violations.add(
            '$at  [R4 GLOBAL_MUTABLE_STATE] 全局可变服务变量禁用，'
            '改为 lib/core/di/ 下 final provider：${raw.trim()}',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'DIP 违例（直接实例化 / 静态单例 / ServiceLocator / 全局可变）：'
          '\n${violations.join('\n')}',
    );
  });
}
