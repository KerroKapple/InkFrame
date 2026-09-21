// 当前活跃项目——ShellState.project 的【派生只读投影】。
//
// 【外壳级测试禁止 override 本 provider】——override 投影会把它与真相源脱钩：
// widget 读投影看到某个 ProjectRef，任何读 shellControllerProvider 的代码看到 null。
// 外壳级测试一律用：
//   shellControllerProvider.overrideWith(() => ShellNavigator(initial: ShellState(...)))
// 由 test/quality/shell_projection_override_test.dart 强制。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shell_state.dart';
import 'shell_controller.dart';

final activeProjectProvider = Provider<ProjectRef?>(
  (ref) => ref.watch(shellControllerProvider.select((ShellState s) => s.project)),
  name: 'activeProjectProvider',
);
