// GenerationProvider 接口族（PROVIDER-API.md §2）。
//
// 按 ISP 原则拆成 5 个细粒度 abstract class，具体 Provider 选实现。
// 抛出的错误必须是 InkError 子类——禁止裸 Exception / String。
//
// 所有 Provider 必须暴露 `const ProviderCapabilities get capabilities`——
// 这是 Provider 的唯一事实源，UI / JobQueueService / estimateCost 都读这个。

import '../errors/ink_error.dart';
import '../models/generation_task.dart';
import '../models/job_status.dart';
import '../models/key_validation_result.dart';
import '../models/provider_capabilities.dart';

/// Provider 侧任务 ID（透传自 API 响应）。同步 Provider 允许 `local://` 前缀。
typedef JobId = String;

/// 所有 Provider 必须实现：基础生成能力。
abstract class Submittable {
  /// 静态能力声明——const 字段，编译期固定。
  ProviderCapabilities get capabilities;

  /// 提交生成任务。
  ///
  /// - 同步 Provider（如 Gemini）可在本方法内完成生成，返回合成的 JobId
  /// - 必须在发 HTTP 前 `await rateLimiter.acquire()`
  /// - 抛 [InkError] 子类（经 DioException 映射后）
  Future<JobId> submit(GenerationTask task);
}

/// 异步 Provider 必须实现：单次轮询查询。
///
/// 实现方**不要**自己循环——退避由 JobQueueService 统一控制。
abstract class Pollable {
  Future<JobStatus> poll(JobId id);
}

/// 支持取消的 Provider（`capabilities.supportsCancellation = true`）实现。
///
/// 不保证远端真的停止——UI 文案必须明示"可能已产生部分费用"。
/// 取消失败（网络超时 / task 已完成）静默吞掉，不抛错。
abstract class Cancellable {
  Future<void> cancel(JobId id);
}

/// 可验证 Key 的 Provider——所有 Provider 必须实现。
///
/// 用 Provider 最轻量端点，禁止消耗生成配额。
/// 禁止调 submit 然后立即 cancel 作为"验证"。
abstract class KeyValidatable {
  Future<KeyValidationResult> validateApiKey(String key);
}
