// estimateCostUsd：按 CostModel + 当前参数预估单次生成的 USD 成本（内联面板展示）。
//
// 纯函数、无副作用——三种计费口径各自算：
//   - PerCall：每次 × 批量
//   - PerCharInput：输入千字符 + 每张输出图 × 批量
//   - PerSecondVideo：每秒(1080p基准) × 时长 × 分辨率倍率
// 另有「价目全为 0 = 价格未知」的判据与明细卡用的单价 / 倍率写法；按节点取参在 node_cost.dart。
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

/// 价目全为 0 ⇒ 算不出：PerCall(0)、PerSecondVideo(0)、PerCharInput(0, 0)。
///
/// 自定义接口模板就是 PerCall(0)（端点真实计费未知，按零占位）。「价目已知但确实免费」板上没区分，
/// 一律当价格未知——写「—」比写 $0.00 诚实。
bool isPriceUnknown(CostModel model) => switch (model) {
      PerCall(:final usdPerCall) => usdPerCall <= 0,
      PerSecondVideo(:final usdPerSecondAt1080p) => usdPerSecondAt1080p <= 0,
      PerCharInput(:final usdPerKChar, :final usdPerImageOutput) =>
        usdPerKChar <= 0 && usdPerImageOutput <= 0,
    };

/// 单价展示（明细计价式里的「$0.032」「$0.30」）：最多 3 位小数、至少 2 位。
///
/// 大于 0 但不到 0.001 的单价（Gemini 每千字 0.000075）写「<$0.001」——舍成 $0.000 等于说免费。
/// 格式量，不入 ARB。
String formatUnitPriceUsd(double usd) {
  if (usd > 0 && usd < 0.001) return r'<$0.001';
  if (usd <= 0) return r'$0.00';
  String s = usd.toStringAsFixed(3);
  // 去掉第 3 位小数的尾零（0.300 → 0.30），第 2 位起保留。
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return '\$$s';
}

/// 倍率展示（「× 0.5」）：去尾零，整数不带小数点（0.5 → '0.5'，2.0 → '2'）。格式量，不入 ARB。
String formatCostMultiplier(double m) {
  String s = m.toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
