// Claude（Anthropic Messages API）的 DI。
//
// app-scoped：独立 Dio（流式长连接、与生成 Provider 链路隔离），随容器销毁关闭；
// Key 从 SecureStorageKeys.anthropicApiKey 现取（设置页改了即生效）。
// Claude 不进 providerRegistryProvider——它不出图出片。
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/anthropic/anthropic_protocol.dart';
import '../../services/anthropic/dio_anthropic_client.dart';
import '../../services/anthropic/in_memory_claude_usage_ledger.dart';
import '../constants/secure_storage_keys.dart';
import '../errors/ink_error.dart';
import '../interfaces/anthropic_client.dart';
import '../models/claude_message.dart';
import '../net/proxy_env.dart';
import 'clock.dart';
import 'secure_storage.dart';

/// 本次会话的 Claude 用量账（内存）。UI watch 这里读记账行；
/// `.notifier` 上有累计用量 / 估算费用。
final claudeUsageLedgerProvider =
    NotifierProvider<InMemoryClaudeUsageLedger, List<ClaudeUsageRecord>>(
  InMemoryClaudeUsageLedger.new,
  name: 'claudeUsageLedgerProvider',
);

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
      ledger: ref.read(claudeUsageLedgerProvider.notifier),
      clock: ref.watch(clockProvider),
    );
  },
  name: 'anthropicClientProvider',
);
