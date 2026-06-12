// KeyValidationResult：Provider.validateApiKey 返回类型（PRD §11.2）。
//
// 三态：有效 / 无效 / 网络错误。
// 区分无效与网络错误是为了 UI 正确引导用户——网络问题不要提示"Key 失效"。

import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_validation_result.freezed.dart';

/// 无效原因：必须在 PRD §10.6 的错误码子集内。
///
/// ME-10：网络超时/离线属于 [KeyValidationResult.networkError]——
/// 无法判定 Key 本身，不在「无效」原因之列。
enum KeyInvalidReason {
  invalidKey,
  insufficientBalance,
  contentPolicy,
}

@freezed
sealed class KeyValidationResult with _$KeyValidationResult {
  /// 有效。可选附加账户信息（余额、配额）显示在设置页。
  const factory KeyValidationResult.valid({
    String? accountInfo,
  }) = KeyValid;

  /// 明确无效：401 / 402 / 内容策略等。
  const factory KeyValidationResult.invalid({
    required KeyInvalidReason reason,
    String? detail,
  }) = KeyInvalid;

  /// 网络层失败——无法判定 Key 本身是否有效，UI 应提示"稍后重试"。
  const factory KeyValidationResult.networkError({
    required String message,
  }) = KeyNetworkError;
}
