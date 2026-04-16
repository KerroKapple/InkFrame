// freezed 模型 sealed union / copyWith 行为单测。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/models/provider_quota.dart';

void main() {
  group('CostModel sealed', () {
    test('三种计费模型可区分', () {
      const a = CostModel.perCall(usdPerCall: 0.028);
      const b = CostModel.perSecondVideo(
        usdPerSecondAt1080p: 0.14,
        resolutionMultiplier: {Resolution.p720: 0.6, Resolution.k2: 2.0},
      );
      const c = CostModel.perCharInput(
        usdPerKChar: 0.000075,
        usdPerImageOutput: 0.039,
      );
      expect(a, isA<PerCall>());
      expect(b, isA<PerSecondVideo>());
      expect(c, isA<PerCharInput>());
    });

    test('exhaustive switch 覆盖三种', () {
      const m = CostModel.perCall(usdPerCall: 0.01);
      final label = switch (m) {
        PerCall() => 'per-call',
        PerSecondVideo() => 'per-second',
        PerCharInput() => 'per-char',
      };
      expect(label, 'per-call');
    });
  });

  group('JobStatus sealed', () {
    test('三态构造 + 默认进度', () {
      const a = JobStatus.inProgress();
      const b = JobStatus.success(remoteUrls: ['https://cdn.x/1.png']);
      const c = JobStatus.failure(
        error: ProviderError(code: InkErrorCode.providerBusy),
      );
      expect(a, isA<JobInProgress>());
      expect((a as JobInProgress).progress, 0.0);
      expect((b as JobSuccess).remoteUrls, ['https://cdn.x/1.png']);
      expect((c as JobFailure).error.code, InkErrorCode.providerBusy);
    });

    test('InProgress progress 可指定', () {
      const s = JobStatus.inProgress(progress: 0.5);
      expect((s as JobInProgress).progress, 0.5);
    });
  });

  group('KeyValidationResult sealed', () {
    test('三态', () {
      const a = KeyValidationResult.valid(accountInfo: '余额 \$12');
      const b = KeyValidationResult.invalid(
        reason: KeyInvalidReason.invalidKey,
      );
      const c = KeyValidationResult.networkError(message: 'timeout');
      expect(a, isA<KeyValid>());
      expect(b, isA<KeyInvalid>());
      expect((b as KeyInvalid).reason, KeyInvalidReason.invalidKey);
      expect(c, isA<KeyNetworkError>());
    });
  });

  group('ProviderCapabilities', () {
    test('const 构造 + copyWith 切换支持列表', () {
      const c = ProviderCapabilities(
        providerId: 'gemini-image',
        region: ProviderRegion.global,
        modes: [GenerationMode.textToImage],
        supportedRatios: [AspectRatio.r1x1, AspectRatio.r16x9],
        supportedResolutions: [Resolution.p1080],
        supportedDurations: [],
        supportedCameras: [],
        maxBatchSize: 1,
        maxRefImages: 0,
        refImagesIncludeKeyframes: false,
        supportsFirstFrame: false,
        supportsLastFrame: false,
        supportsNegativePrompt: false,
        supportsSeed: true,
        supportsSound: false,
        supportsBatch: false,
        supportsCancellation: false,
        supportsPolling: false,
        costModel: CostModel.perCharInput(
          usdPerKChar: 0.000075,
          usdPerImageOutput: 0.039,
        ),
        maxConcurrentJobs: 1,
        qps: 2,
        burst: 10,
      );
      expect(c.providerId, 'gemini-image');
      expect(c.supportedRatios, hasLength(2));
      final c2 = c.copyWith(qps: 5);
      expect(c2.qps, 5);
      expect(c2.providerId, c.providerId);
    });
  });

  group('GenerationTask', () {
    test('默认值', () {
      const t = GenerationTask(
        providerId: 'gemini-image',
        jobId: 'job-1',
        mode: GenerationMode.textToImage,
        prompt: 'an ink wash painting',
        resolution: Resolution.p1080,
        aspectRatio: AspectRatio.r1x1,
      );
      expect(t.durationSeconds, 0);
      expect(t.batchSize, 1);
      expect(t.refImagePaths, isEmpty);
      expect(t.negativePrompt, isNull);
    });
  });

  group('ProviderQuota', () {
    test('可空字段', () {
      const q = ProviderQuota(currency: 'USD');
      expect(q.remaining, isNull);
      expect(q.total, isNull);
      expect(q.currency, 'USD');
    });
  });
}
