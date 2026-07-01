import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/features/generation/services/cost_estimator.dart';

void main() {
  test('perCall × 批量', () {
    expect(
      estimateCostUsd(const CostModel.perCall(usdPerCall: 0.04), batchSize: 3),
      closeTo(0.12, 1e-9),
    );
  });

  test('perCharInput = 千字符 + 每图输出 × 批量', () {
    final c = estimateCostUsd(
      const CostModel.perCharInput(usdPerKChar: 0.001, usdPerImageOutput: 0.02),
      promptChars: 2000,
      batchSize: 2,
    );
    expect(c, closeTo(0.001 * 2 + 0.02 * 2, 1e-9)); // 0.042
  });

  test('perSecondVideo × 时长 × 分辨率倍率（缺失默认 1.0）', () {
    const model = CostModel.perSecondVideo(
      usdPerSecondAt1080p: 0.1,
      resolutionMultiplier: {Resolution.p1080: 1.0},
    );
    expect(
      estimateCostUsd(model, durationSeconds: 5, resolution: Resolution.p1080),
      closeTo(0.5, 1e-9),
    );
    expect(estimateCostUsd(model, durationSeconds: 4), closeTo(0.4, 1e-9));
  });

  test('batchSize < 1 视为 1', () {
    expect(
      estimateCostUsd(const CostModel.perCall(usdPerCall: 0.05), batchSize: 0),
      closeTo(0.05, 1e-9),
    );
  });

  test('formatCostUsd', () {
    expect(formatCostUsd(0), r'$0.00');
    expect(formatCostUsd(0.004), r'<$0.01');
    expect(formatCostUsd(0.12), r'$0.12');
  });
}
