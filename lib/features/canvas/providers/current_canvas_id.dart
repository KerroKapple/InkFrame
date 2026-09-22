// 当前画布 id——ShellState.canvasId 的【派生只读投影】。
//
// 降级自 StateProvider：Provider 上不存在 .notifier.state，"谁都能偷改路由"
// 在类型层面消失。写入一律走 shellControllerProvider.notifier。
//
// 【外壳级测试禁止 override 本 provider】——override 投影会把它与真相源脱钩：
// widget 读投影看到 'c1'，任何读 shellControllerProvider 的代码看到 null。
// 外壳级测试一律用：
//   shellControllerProvider.overrideWith(() => ShellNavigator(initial: ShellState(...)))
// 纯画布组件测试不受此限（那正是保留本 provider 名字与路径的价值）。
// 由 test/quality/shell_projection_override_test.dart 强制。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';

final currentCanvasIdProvider = Provider<String?>(
  (ref) => ref.watch(shellControllerProvider.select((ShellState s) => s.canvasId)),
  name: 'currentCanvasIdProvider',
);
