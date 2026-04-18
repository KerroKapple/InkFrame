// GenerationTask：提交给 Provider 的生成任务（PRD §10.3 流程的输入）。
//
// 经过参数验证 + 风格注入 + 参考图处理后才传给 Provider.submit。

import 'package:freezed_annotation/freezed_annotation.dart';

import 'provider_capabilities.dart';

part 'generation_task.freezed.dart';

@freezed
abstract class GenerationTask with _$GenerationTask {
  const factory GenerationTask({
    /// 目标 Provider ID（kebab-case，与 capabilities.providerId 一致）。
    required String providerId,

    /// 业务侧 jobId（对应 jobs.id）。Provider 层只读不写。
    required String jobId,

    /// 所属项目 id（生产 path 必填，单测可为 null）。落盘路径需要它。
    String? projectId,

    /// 所属画布 id（生产 path 必填，单测可为 null）。落盘路径需要它。
    String? canvasId,

    /// 结果节点 id（生产 path 必填，单测可为 null）。
    /// 写完盘后 NodeRepository.update({image_url: ...}) 用到。
    String? resultNodeId,

    /// 模式（决定调用哪个 Provider 端点）。
    required GenerationMode mode,

    /// 已完成风格注入的完整 prompt。
    required String prompt,

    /// 负向 prompt（若 Provider 支持）。
    String? negativePrompt,

    /// 分辨率。
    required Resolution resolution,

    /// 比例。
    required AspectRatio aspectRatio,

    /// 视频时长（秒）。图片 Provider 传 0。
    @Default(0) int durationSeconds,

    /// 运镜（视频）。
    CameraMovement? camera,

    /// 参考图绝对路径列表（首尾帧单独字段）。
    @Default(<String>[]) List<String> refImagePaths,

    /// 首帧图（视频）。
    String? firstFramePath,

    /// 末帧图（视频）。
    String? lastFramePath,

    /// 随机种子（若 Provider 支持）。
    int? seed,

    /// 批量张数（图片 Provider）。视频固定 1。
    @Default(1) int batchSize,
  }) = _GenerationTask;
}
