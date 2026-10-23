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

  test('isPriceUnknown：单价全为 0 才算', () {
    expect(isPriceUnknown(const CostModel.perCall(usdPerCall: 0)), isTrue);
    expect(
      isPriceUnknown(const CostModel.perSecondVideo(
        usdPerSecondAt1080p: 0,
        resolutionMultiplier: <Resolution, double>{},
      )),
      isTrue,
    );
    expect(
      isPriceUnknown(const CostModel.perCharInput(usdPerKChar: 0, usdPerImageOutput: 0)),
      isTrue,
    );
    expect(isPriceUnknown(const CostModel.perCall(usdPerCall: 0.032)), isFalse);
    expect(
      isPriceUnknown(const CostModel.perCharInput(usdPerKChar: 0, usdPerImageOutput: 0.039)),
      isFalse,
      reason: '只要有一项单价不为 0，就算得出',
    );
  });

  test('formatUnitPriceUsd 保留到 3 位小数', () {
    expect(formatUnitPriceUsd(0.032), r'$0.032');
    expect(formatUnitPriceUsd(0.3), r'$0.30');
    expect(formatUnitPriceUsd(0.041), r'$0.041');
    expect(formatUnitPriceUsd(1.5), r'$1.50');
    // Gemini 每千字 0.000075：舍成 $0.000 / $0.00 等于告诉用户「免费」（主 Agent 决定：写 <$0.001）。
    expect(formatUnitPriceUsd(0.000075), r'<$0.001');
  });

  test('formatCostMultiplier 去尾零', () {
    expect(formatCostMultiplier(0.5), '0.5');
    expect(formatCostMultiplier(2.0), '2');
    expect(formatCostMultiplier(1.25), '1.25');
  });
}
