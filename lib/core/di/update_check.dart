// UpdateCheckService 的 Riverpod DI（UPD-1）。
//
// app-scoped：独立 Dio（GitHub API 专用超时,与 Provider 生成链路隔离）,
// 随容器销毁关闭;版本号懒取自 packageInfoProvider（平台读一次）。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/github_update_check_service.dart';
import '../interfaces/update_check_service.dart';
import '../net/proxy_env.dart';
import 'package_info.dart';

final updateCheckServiceProvider = Provider<UpdateCheckService>(
  (ref) {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.github.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    applyEnvProxy(dio); // LB-24：HTTPS_PROXY/HTTP_PROXY/NO_PROXY env
    ref.onDispose(dio.close);
    return GithubUpdateCheckService(
      dio: dio,
      versionSource: () async =>
          (await ref.read(packageInfoProvider.future)).version,
    );
  },
  name: 'updateCheckServiceProvider',
);
