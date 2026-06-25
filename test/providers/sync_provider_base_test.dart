// SyncProviderBase 单测：用 _FakeSyncProvider 覆盖基类共享逻辑
// （submit 守卫/缓存、poll 消费、validate 开关、内容审核 hook）。
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/rate_limiter.dart';
import 'package:inkframe/providers/sync_provider_base.dart';

const String _kPrefix = 'local://fake-sync/';
const String _kValidatePath = '/validate';

class _FakeSyncProvider extends SyncProviderBase {
  _FakeSyncProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
    this.onGenerate,
    this.policyOnDio = false,
  });

  /// 注入 performGeneration 行为（返回 bytes 或抛异常）。
  final Future<Uint8List> Function()? onGenerate;

  /// 命中时把 submit 阶段的 DioException 翻成 contentPolicy。
  final bool policyOnDio;

  @override
  String get baseUrl => 'https://fake.test';

  @override
  String get localJobPrefix => _kPrefix;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        providerId: 'fake-sync',
        region: ProviderRegion.global,
        modes: [GenerationMode.textToImage],
        supportedRatios: [AspectRatio.r1x1],
        supportedResolutions: [Resolution.p1080],
        supportedDurations: [],
        supportedCameras: [],
        maxBatchSize: 1,
        maxRefImages: 0,
        refImagesIncludeKeyframes: false,
        supportsFirstFrame: false,
        supportsLastFrame: false,
        supportsNegativePrompt: false,
        supportsSeed: false,
        supportsSound: false,
        supportsBatch: false,
        supportsCancellation: false,
        supportsPolling: true,
        costModel: CostModel.perCall(usdPerCall: 0.01),
        maxConcurrentJobs: 1,
        qps: 2,
        burst: 5,
      );

  @override
  Future<Uint8List> performGeneration(GenerationTask task, String apiKey) =>
      (onGenerate ?? () async => Uint8List.fromList([1, 2, 3]))();

  @override
  Future<void> performKeyValidation(String apiKey) async {
    await dio.get<dynamic>(
      _kValidatePath,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );
  }

  @override
  InkError? contentPolicyFromDioError(DioException e) => policyOnDio
      ? ProviderError(
          code: InkErrorCode.contentPolicy,
          extra: {'provider_id': capabilities.providerId},
        )
      : null;
}

GenerationTask _task({
  GenerationMode mode = GenerationMode.textToImage,
  String prompt = 'hi',
}) =>
    GenerationTask(
      providerId: 'fake-sync',
      jobId: 'j1',
      mode: mode,
      prompt: prompt,
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

_FakeSyncProvider _build({
  Dio? dio,
  Future<Uint8List> Function()? onGenerate,
  bool policyOnDio = false,
}) =>
    _FakeSyncProvider(
      keySource: () async => 'k',
      rateLimiter: ProviderRateLimiter(qps: 50, burst: 50),
      dio: dio,
      onGenerate: onGenerate,
      policyOnDio: policyOnDio,
    );

void main() {
  group('SyncProviderBase.submit', () {
    test('成功 → 本地 JobId + poll 返回 inlineBytes', () async {
      final p = _build();
      final jobId = await p.submit(_task());
      expect(jobId, startsWith(_kPrefix));
      final status = await p.poll(jobId);
      expect(status, isA<JobSuccess>());
      expect((status as JobSuccess).inlineBytes, isNotEmpty);
    });

    test('mode != textToImage → invalidParameter(reason:mode)', () async {
      await expectLater(
        _build().submit(_task(mode: GenerationMode.imageToImage)),
        throwsA(isA<ProviderError>()
            .having((e) => e.extra['reason'], 'reason', 'mode')),
      );
    });

    test('空 prompt → invalidParameter(reason:empty_prompt)', () async {
      await expectLater(
        _build().submit(_task(prompt: '   ')),
        throwsA(isA<ProviderError>()
            .having((e) => e.extra['reason'], 'reason', 'empty_prompt')),
      );
    });

    test('contentPolicyFromDioError 命中 → submit 抛 contentPolicy（优先于 mapDioError）',
        () async {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
            requestOptions: RequestOptions(path: '/'), statusCode: 400),
      );
      final p = _build(onGenerate: () async => throw dioErr, policyOnDio: true);
      await expectLater(
        p.submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.contentPolicy)),
      );
    });
  });

  group('SyncProviderBase.poll', () {
    test('cache-miss → providerServer(cache_miss_or_consumed)', () async {
      await expectLater(
        _build().poll('nope'),
        throwsA(isA<ProviderError>().having(
            (e) => e.extra['reason'], 'reason', 'cache_miss_or_consumed')),
      );
    });

    test('重复 poll 同一 id → 第二次 cache-miss', () async {
      final p = _build();
      final jobId = await p.submit(_task());
      await p.poll(jobId);
      await expectLater(p.poll(jobId), throwsA(isA<ProviderError>()));
    });
  });

  group('SyncProviderBase.validateApiKey', () {
    Dio dioReplying(int status) {
      final dio = Dio(BaseOptions(baseUrl: 'https://fake.test'));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher())
          .onGet(_kValidatePath, (s) => s.reply(status, {'ok': true}));
      return dio;
    }

    test('200 → valid', () async {
      expect(await _build(dio: dioReplying(200)).validateApiKey('k'),
          isA<KeyValid>());
    });
    test('401 → invalid(invalidKey)', () async {
      final r = await _build(dio: dioReplying(401)).validateApiKey('k');
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });
    test('402 → invalid(insufficientBalance)', () async {
      final r = await _build(dio: dioReplying(402)).validateApiKey('k');
      expect((r as KeyInvalid).reason, KeyInvalidReason.insufficientBalance);
    });
    test('403 → invalid(invalidKey)', () async {
      final r = await _build(dio: dioReplying(403)).validateApiKey('k');
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });
    test('500 → networkError', () async {
      expect(await _build(dio: dioReplying(500)).validateApiKey('k'),
          isA<KeyNetworkError>());
    });
  });
}
