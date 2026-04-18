// ProviderQuota：Provider 账户配额信息（QuotaAware 接口返回值）。
//
// 面向设置页 / 任务中心展示；业务流不依赖这个字段做调度。

import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_quota.freezed.dart';

@freezed
abstract class ProviderQuota with _$ProviderQuota {
  const factory ProviderQuota({
    /// 原始币种（USD / CNY / credits 等）。
    required String currency,

    /// 剩余额度（可能是金额，也可能是 credits）。null 表示 Provider 未暴露。
    double? remaining,

    /// 总额度（周期内）。null 表示无此概念。
    double? total,

    /// 额度重置时间（若 Provider 返回）。
    DateTime? resetAt,

    /// Provider 原始响应的人类可读摘要，UI 直接展示。
    String? rawSummary,
  }) = _ProviderQuota;
}
