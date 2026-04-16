// ProviderCapabilities：Provider 能力声明（PRD §10.1）。
//
// 每个 Provider 通过一个 const 实例声明自己支持的参数组合。
// UI 内联面板、JobQueueService、estimateCost 都只依赖这个字段。
// 禁止从 .env / DB / 网络下发——必须 const，编译期固定。

import 'package:freezed_annotation/freezed_annotation.dart';

import 'cost_model.dart';

part 'provider_capabilities.freezed.dart';

/// 区域：决定 UI 币种展示 / 代理策略。
enum ProviderRegion { cn, global }

/// 生成模式。
enum GenerationMode { textToImage, imageToImage, textToVideo, imageToVideo }

/// 比例枚举（PRD §10.1）。
enum AspectRatio { r1x1, r16x9, r9x16, r4x3, r3x4, r21x9 }

/// 分辨率枚举（PRD §10.1）。
enum Resolution { p720, p1080, k2, k4 }

/// 运镜枚举（PRD §10.1）。
enum CameraMovement {
  static_,
  pushIn,
  pullOut,
  panLeft,
  panRight,
  tiltUp,
  tiltDown,
  orbit,
  handheld,
}

@freezed
abstract class ProviderCapabilities with _$ProviderCapabilities {
  const factory ProviderCapabilities({
    required String providerId,
    required ProviderRegion region,
    required List<GenerationMode> modes,
    required List<AspectRatio> supportedRatios,
    required List<Resolution> supportedResolutions,
    required List<int> supportedDurations,
    required List<CameraMovement> supportedCameras,
    required int maxBatchSize,
    required int maxRefImages,
    required bool refImagesIncludeKeyframes,
    required bool supportsFirstFrame,
    required bool supportsLastFrame,
    required bool supportsNegativePrompt,
    required bool supportsSeed,
    required bool supportsSound,
    required bool supportsBatch,
    required bool supportsCancellation,
    required bool supportsPolling,
    required CostModel costModel,
    required int maxConcurrentJobs,
    required int qps,
    required int burst,
    Duration? pollInterval,
    Duration? pollTimeout,
  }) = _ProviderCapabilities;
}
