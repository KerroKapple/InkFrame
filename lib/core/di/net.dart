// 网络相关 DI。
//
// 代理只从进程启动时的环境变量读（core/net/proxy_env.dart 的 applyEnvProxy），
// 所以这里把 env 当一份注入物暴露出来：设置「网络」页读它呈现当前代理状态，
// 测试注入假 env 即可，不必动真实进程环境。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 进程环境快照。Platform.environment 本身在进程启动时就固定了，改 env 要重启。
final processEnvironmentProvider = Provider<Map<String, String>>(
  (ref) => Platform.environment,
  name: 'processEnvironmentProvider',
);
