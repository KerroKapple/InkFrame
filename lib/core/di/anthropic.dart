// Claude（Anthropic Messages API）的 DI。
//
// app-scoped：独立 Dio（流式长连接、与生成 Provider 链路隔离），随容器销毁关闭；
// Key 从 SecureStorageKeys.anthropicApiKey 现取（设置页改了即生效）。
// Claude 不进 providerRegistryProvider——它不出图出片。
// 用量不在这里记：导演事件日志是唯一事实源，账从日志派生（ADR-0015，
// features/director/log/claude_usage_ledger.dart）。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/anthropic/anthropic_protocol.dart';
import '../../services/anthropic/dio_anthropic_client.dart';
import '../constants/secure_storage_keys.dart';
import '../errors/ink_error.dart';
import '../interfaces/anthropic_client.dart';
import '../net/proxy_env.dart';
import 'secure_storage.dart';

final anthropicClientProvider = Provider<AnthropicClient>(
  (ref) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AnthropicProtocol.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        // 流式：两段数据之间的最长间隔（服务端会发 ping），不是整次调用的上限。
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    applyEnvProxy(dio); // LB-24：与生成链路同过 env 代理
    ref.onDispose(dio.close);
    final secure = ref.watch(secureStorageServiceProvider);
    return DioAnthropicClient(
      dio: dio,
      keySource: () async {
        final key = await secure.retrieve(SecureStorageKeys.anthropicApiKey);
        if (key == null || key.isEmpty) {
          throw const ProviderError(
            code: InkErrorCode.invalidKey,
            extra: <String, Object?>{
              'provider_id': AnthropicProtocol.clientId,
              'reason': 'key_not_configured',
            },
          );
        }
        return key;
      },
    );
  },
  name: 'anthropicClientProvider',
);

/// 填没填 Claude Key（AI 拆分等导演入口的可用闸）。设置页存 / 清 Key 后失效重算；
/// 读失败是 AsyncError，入口按「未配置」处理。
final claudeKeyConfiguredProvider = FutureProvider<bool>(
  (ref) => ref
      .watch(secureStorageServiceProvider)
      .exists(SecureStorageKeys.anthropicApiKey),
  name: 'claudeKeyConfiguredProvider',
);
