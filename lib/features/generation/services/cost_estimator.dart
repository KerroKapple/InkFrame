// estimateCostUsd：按 CostModel + 当前参数预估单次生成的 USD 成本（内联面板展示）。
//
// 纯函数、无副作用——三种计费口径各自算：
//   - PerCall：每次 × 批量
//   - PerCharInput：输入千字符 + 每张输出图 × 批量
//   - PerSecondVideo：每秒(1080p基准) × 时长 × 分辨率倍率
import '../../../core/models/cost_model.dart';
import '../../../core/models/provider_capabilities.dart';

double estimateCostUsd(
  CostModel model, {
  Resolution? resolution,
  int batchSize = 1,
  int durationSeconds = 0,
  int promptChars = 0,
}) {
  final batch = batchSize < 1 ? 1 : batchSize;
  return switch (model) {
    PerCall(:final usdPerCall) => usdPerCall * batch,
    PerCharInput(:final usdPerKChar, :final usdPerImageOutput) =>
      usdPerKChar * (promptChars / 1000.0) + usdPerImageOutput * batch,
    PerSecondVideo(:final usdPerSecondAt1080p, :final resolutionMultiplier) =>
      usdPerSecondAt1080p *
          durationSeconds *
          (resolution == null
              ? 1.0
              : (resolutionMultiplier[resolution] ?? 1.0)),
  };
}

/// 展示串：'$0.00' / '<$0.01' / '$1.20'。金额是格式量，非用户散文，不入 ARB。
String formatCostUsd(double usd) {
  if (usd <= 0) return r'$0.00';
  if (usd < 0.01) return r'<$0.01';
  return '\$${usd.toStringAsFixed(2)}';
}
