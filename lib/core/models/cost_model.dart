// CostModel：统一计费口径（PRD §10.1.1）。
//
// 不同 Provider 计费单位差异大（每次调用 / 每秒视频 / 每千字符），
// 内联面板统一展示"预估 USD 成本"。

import 'package:freezed_annotation/freezed_annotation.dart';

import 'provider_capabilities.dart';

part 'cost_model.freezed.dart';

@freezed
sealed class CostModel with _$CostModel {
  /// 按次计费（图片 Provider 常见）。
  const factory CostModel.perCall({
    required double usdPerCall,
  }) = PerCall;

  /// 按视频秒数计费，随分辨率缩放。
  const factory CostModel.perSecondVideo({
    required double usdPerSecondAt1080p,
    required Map<Resolution, double> resolutionMultiplier,
  }) = PerSecondVideo;

  /// 按输入字符 + 输出图片数量计费（Gemini 类）。
  const factory CostModel.perCharInput({
    required double usdPerKChar,
    required double usdPerImageOutput,
  }) = PerCharInput;
}
