// InkError：所有业务层错误的统一抽象。
//
// 对齐 PRD §10.6「错误码统一枚举」，在其基础上增加 providerInvalidResponse
// （远端报终态成功却无产物 URL——确定性失败，不可重试，避免轮询风暴）。
// 任何 Provider / Repository / Service 的失败路径最终都要翻译成一个 InkError
// 子类，Widget 只消费 `messageKey` 走 i18n，从不直接看到裸 Exception。
import 'package:flutter/foundation.dart';

/// 统一错误码枚举。字符串值与 PRD §10.6 / DB 列 `jobs.error_code` 完全一致。
enum InkErrorCode {
  invalidKey('invalid_key'),
  insufficientBalance('insufficient_balance'),
  contentPolicy('content_policy'),
  invalidParameter('invalid_parameter'),
  networkTimeout('network_timeout'),
  networkOffline('network_offline'),
  providerServer('provider_5xx'),
  providerBusy('provider_busy'),
  providerInvalidResponse('provider_invalid_response'),
  pollTimeout('poll_timeout'),
  downloadFailed('download_failed'),
  localIOError('local_io_error'),
  cancelledByUser('cancelled_by_user'),
  cancelledOnExit('cancelled_on_exit'),
  unknown('unknown');

  const InkErrorCode(this.wire);

  /// 持久化 / 日志 / 跨进程传递时使用的字符串 code（与 DB 一致）。
  final String wire;

  static InkErrorCode fromWire(String wire) {
    return InkErrorCode.values.firstWhere(
      (c) => c.wire == wire,
      orElse: () => InkErrorCode.unknown,
    );
  }
}

/// 每个 code 对应的 i18n ARB key（app_en.arb / app_zh.arb 中必须存在）。
const Map<InkErrorCode, String> _messageKeys = <InkErrorCode, String>{
  InkErrorCode.invalidKey: 'errorInvalidKey',
  InkErrorCode.insufficientBalance: 'errorInsufficientBalance',
  InkErrorCode.contentPolicy: 'errorContentPolicy',
  InkErrorCode.invalidParameter: 'errorInvalidParameter',
  InkErrorCode.networkTimeout: 'errorNetworkTimeout',
  InkErrorCode.networkOffline: 'errorNetworkOffline',
  InkErrorCode.providerServer: 'errorProviderServer',
  InkErrorCode.providerBusy: 'errorProviderBusy',
  InkErrorCode.providerInvalidResponse: 'errorProviderInvalidResponse',
  InkErrorCode.pollTimeout: 'errorPollTimeout',
  InkErrorCode.downloadFailed: 'errorDownloadFailed',
  InkErrorCode.localIOError: 'errorLocalIO',
  InkErrorCode.cancelledByUser: 'errorCancelled',
  InkErrorCode.cancelledOnExit: 'errorCancelledOnExit',
  InkErrorCode.unknown: 'errorUnknown',
};

/// 可重试白名单（PRD §10.6 "覆盖 §10.3"）。
const Set<InkErrorCode> _retryable = <InkErrorCode>{
  InkErrorCode.networkTimeout,
  InkErrorCode.networkOffline,
  InkErrorCode.providerServer,
  InkErrorCode.providerBusy,
  InkErrorCode.downloadFailed,
};

/// 顶层错误基类——sealed 强制下游 exhaustive switch。
@immutable
sealed class InkError implements Exception {
  const InkError({
    required this.code,
    this.extra = const <String, Object?>{},
    this.cause,
    this.stackTrace,
  });

  final InkErrorCode code;

  /// 附加上下文：job_id / provider_id / status_code 等。不得含敏感信息。
  final Map<String, Object?> extra;

  /// 原始异常（供日志/诊断追溯，不暴露给 UI）。
  final Object? cause;
  final StackTrace? stackTrace;

  String get messageKey => _messageKeys[code]!;
  bool get retryable => _retryable.contains(code);

  Map<String, Object?> toLogJson() => <String, Object?>{
        'code': code.wire,
        'retryable': retryable,
        'extra': extra,
      };

  @override
  String toString() => 'InkError(${code.wire}, retryable=$retryable)';
}

/// 鉴权 / 配额 / 请求参数错误。
final class ProviderError extends InkError {
  const ProviderError({
    required super.code,
    super.extra,
    super.cause,
    super.stackTrace,
  }) : assert(
          code == InkErrorCode.invalidKey ||
              code == InkErrorCode.insufficientBalance ||
              code == InkErrorCode.contentPolicy ||
              code == InkErrorCode.invalidParameter ||
              code == InkErrorCode.providerServer ||
              code == InkErrorCode.providerBusy ||
              code == InkErrorCode.providerInvalidResponse ||
              code == InkErrorCode.pollTimeout,
          'ProviderError only wraps provider/account/poll codes',
        );
}

/// 网络层错误（本机 / 链路 / TLS / 代理）。
final class NetworkError extends InkError {
  const NetworkError({
    required super.code,
    super.extra,
    super.cause,
    super.stackTrace,
  }) : assert(
          code == InkErrorCode.networkTimeout ||
              code == InkErrorCode.networkOffline,
          'NetworkError only wraps network_timeout / network_offline',
        );
}

/// 产物下载错误（生成成功但取文件失败）。
final class DownloadError extends InkError {
  const DownloadError({
    super.extra,
    super.cause,
    super.stackTrace,
  }) : super(code: InkErrorCode.downloadFailed);
}

/// 本地 I/O（磁盘满、权限拒绝、路径不存在）。
final class LocalIOError extends InkError {
  const LocalIOError({
    super.extra,
    super.cause,
    super.stackTrace,
  }) : super(code: InkErrorCode.localIOError);
}

/// 取消（用户主动 / 应用退出）。
final class CancelledError extends InkError {
  const CancelledError.byUser({super.extra})
      : super(code: InkErrorCode.cancelledByUser);
  const CancelledError.onExit({super.extra})
      : super(code: InkErrorCode.cancelledOnExit);
}

/// 兜底：未归类的异常，必须带 cause 以便诊断。
final class UnknownError extends InkError {
  const UnknownError({
    required Object super.cause,
    super.stackTrace,
    super.extra,
  }) : super(code: InkErrorCode.unknown);
}
