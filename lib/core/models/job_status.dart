// JobStatus：Provider.poll 单次返回的状态（PRD §10.3）。
//
// 不等于 jobs.status 枚举——后者是 JobQueueService 持久化的完整状态机，
// 本 sealed 仅表达"本次 poll 看到了什么"。JobQueueService 负责把它
// 翻译成持久化状态。

import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../errors/ink_error.dart';

part 'job_status.freezed.dart';

@freezed
sealed class JobStatus with _$JobStatus {
  /// Provider 还在干活。progress ∈ [0,1]，无法提供则填 0。
  const factory JobStatus.inProgress({
    @Default(0.0) double progress,
  }) = JobInProgress;

  /// 成功：拿到远端产物 URL（可能多张）+ 可选过期时间。
  /// 下载是独立阶段，不在 Provider 层做。
  ///
  /// 同步 Provider（如 Gemini Image）通过 [inlineBytes] 直接携带原始字节数据，
  /// [remoteUrls] 为空列表。详见 ADR-0004。
  const factory JobStatus.success({
    required List<String> remoteUrls,
    DateTime? urlExpiresAt,
    List<Uint8List>? inlineBytes,
  }) = JobSuccess;

  /// 失败：带 InkError 子类，明确错误码与可重试性。
  const factory JobStatus.failure({
    required InkError error,
  }) = JobFailure;
}
