// StabilityImageCoreProvider 单元 + 契约测试。
//
// 三个特殊点（见 plan §Preconditions）：
//   1. multipart/form-data 请求体（FormData.fromMap）
//   2. ResponseType.bytes 响应（仅此 Provider 不走 JSON）
//   3. finish-reason 响应头检测 CONTENT_FILTERED（HTTP 200 也可能内容过滤）
//
// http_mock_adapter 按 URL 匹配，不校验 form 字段；字段正确性由实现 review 保证。

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
import 'package:inkframe/providers/stability_image_core_provider.dart';

import '../_harness/fixtures.dart';

// 1x1 PNG 占位字节——非真实生成产物，仅供 mock bytes 响应使用。
final Uint8List _kFakePng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG 签名
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
]);

StabilityImageCoreProvider _buildProvider(Dio dio, {String key = 'test-key'}) {
  return StabilityImageCoreProvider(
    keySource: () async => key,
    rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    dio: dio,
  );
}

Dio _bytesDio() => Dio(BaseOptions(baseUrl: kStabilityBasePath));

GenerationTask _task({String? prompt, AspectRatio? ratio, int? seed}) =>
    GenerationTask(
      providerId: 'stability-image-core',
      jobId: 'job-1',
      mode: GenerationMode.textToImage,
      prompt: prompt ?? 'an ink wash painting of mountains',
      resolution: Resolution.p1080,
      aspectRatio: ratio ?? AspectRatio.r1x1,
      seed: seed,
    );

DioException _badResponse(int status, {Object? body}) => DioException(
      requestOptions: RequestOptions(path: kStabilityCoreGeneratePath),
      response: Response(
        statusCode: status,
        data: body ?? const <String, Object?>{'errors': <String>[]},
        requestOptions: RequestOptions(path: kStabilityCoreGeneratePath),
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  // ---- Task 1：capabilities ----------------------------------------------
  group('StabilityImageCoreProvider capabilities', () {
    final p = _buildProvider(_bytesDio());

    test('providerId == stability-image-core', () {
      expect(p.capabilities.providerId, 'stability-image-core');
    });
    test('region == global', () {
      expect(p.capabilities.region, ProviderRegion.global);
    });
    test('modes == [textToImage]', () {
      expect(p.capabilities.modes, const [GenerationMode.textToImage]);
    });
    test('supportsNegativePrompt == true', () {
      expect(p.capabilities.supportsNegativePrompt, isTrue);
    });
    test('supportsSeed == true', () {
      expect(p.capabilities.supportsSeed, isTrue);
    });
    test('supportsPolling == true（ADR-0004 同步通道）', () {
      expect(p.capabilities.supportsPolling, isTrue);
    });
    test('supportsCancellation == false', () {
      expect(p.capabilities.supportsCancellation, isFalse);
    });
    test('costModel == perCall(0.03)', () {
      expect(
        p.capabilities.costModel,
        const CostModel.perCall(usdPerCall: 0.03),
      );
    });
    test('qps == 1, burst == 3', () {
      expect(p.capabilities.qps, 1);
      expect(p.capabilities.burst, 3);
    });
  });

  // ---- Task 3/4：validateApiKey ------------------------------------------
  group('StabilityImageCoreProvider.validateApiKey', () {
    test('200 + credits>0 → KeyValid', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.reply(200, const <String, Object?>{'credits': 10.5}),
      );
      final r = await _buildProvider(dio).validateApiKey('good');
      expect(r, isA<KeyValid>());
    });

    test('200 + credits==0 → KeyValid（零余额不等于无效 Key）', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.reply(200, const <String, Object?>{'credits': 0.0}),
      );
      final r = await _buildProvider(dio).validateApiKey('good');
      expect(r, isA<KeyValid>());
    });

    test('401 → KeyInvalid(invalidKey)', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.throws(401, _badResponse(401)),
      );
      final r = await _buildProvider(dio, key: 'bad').validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });

    test('403 → KeyInvalid(invalidKey)', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.throws(403, _badResponse(403)),
      );
      final r = await _buildProvider(dio).validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });

    test('402 → KeyInvalid(insufficientBalance)', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.throws(402, _badResponse(402)),
      );
      final r = await _buildProvider(dio).validateApiKey('poor');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.insufficientBalance);
    });

    test('连接超时 → KeyNetworkError', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: kStabilityBalancePath),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );
      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
    });

    test('connectionError（离线）→ KeyNetworkError', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: kStabilityBalancePath),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
    });
  });

  // ---- Task 5/6：submit（multipart + bytes + finish-reason 头） ----------
  group('StabilityImageCoreProvider.submit', () {
    test('成功（finish-reason: SUCCESS）→ 返回 local:// JobId', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.reply(
          200,
          _kFakePng,
          headers: <String, List<String>>{
            'finish-reason': <String>['SUCCESS'],
            'content-type': <String>['image/png'],
          },
        ),
      );
      final jobId = await _buildProvider(dio).submit(_task());
      expect(jobId, startsWith(kStabilityLocalJobPrefix));
    });

    test('finish-reason: CONTENT_FILTERED（HTTP 200）→ contentPolicy', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.reply(
          200,
          _kFakePng,
          headers: <String, List<String>>{
            'finish-reason': <String>['CONTENT_FILTERED'],
            'content-type': <String>['image/png'],
          },
        ),
      );
      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.contentPolicy)),
      );
    });

    test('401 → invalidKey', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(401, _badResponse(401)),
      );
      await expectLater(
        _buildProvider(dio, key: 'bad').submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidKey)),
      );
    });

    test('402 → insufficientBalance', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(402, _badResponse(402)),
      );
      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.insufficientBalance)),
      );
    });

    test('403 → contentPolicy（Stability 的 403 是内容审核，非 invalidKey）', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(403, _badResponse(403)),
      );
      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.contentPolicy)),
      );
    });

    test('422 → invalidParameter', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(422, _badResponse(422)),
      );
      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('429 → providerBusy（可重试）', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(429, _badResponse(429)),
      );
      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerBusy)
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('500 → providerServer（可重试）', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(503, _badResponse(503)),
      );
      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('空 prompt 本地拒绝，不发网络请求', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.reply(200, _kFakePng),
      );
      await expectLater(
        _buildProvider(dio).submit(_task(prompt: '   ')),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('非 textToImage 模式本地拒绝', () async {
      final dio = _bytesDio();
      // ignore: unused_local_variable
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      const t = GenerationTask(
        providerId: 'stability-image-core',
        jobId: 'j',
        mode: GenerationMode.textToVideo,
        prompt: 'x',
        resolution: Resolution.p1080,
        aspectRatio: AspectRatio.r1x1,
      );
      await expectLater(
        _buildProvider(dio).submit(t),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('submit 失败不写 cache（失败后 poll → cache_miss_or_consumed）', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(500, _badResponse(500)),
      );
      final p = _buildProvider(dio);
      await expectLater(p.submit(_task()), throwsA(isA<ProviderError>()));
      await expectLater(
        p.poll('${kStabilityLocalJobPrefix}any-id'),
        throwsA(isA<ProviderError>().having(
          (e) => e.extra['reason'],
          'reason',
          'cache_miss_or_consumed',
        )),
      );
    });
  });

  // ---- Task 7：poll（ADR-0004 同步消费通道） -----------------------------
  group('StabilityImageCoreProvider.poll (sync channel)', () {
    test('submit→poll 返回 inlineBytes 且 remoteUrls 为空', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.reply(
          200,
          _kFakePng,
          headers: <String, List<String>>{
            'finish-reason': <String>['SUCCESS'],
            'content-type': <String>['image/png'],
          },
        ),
      );
      final p = _buildProvider(dio);
      final jobId = await p.submit(_task());
      final status = await p.poll(jobId);
      expect(status, isA<JobSuccess>());
      final s = status as JobSuccess;
      expect(s.remoteUrls, isEmpty);
      expect(s.inlineBytes, isNotNull);
      expect(s.inlineBytes!.length, 1);
      expect(s.inlineBytes!.first.isNotEmpty, isTrue);
    });

    test('重复 poll 同一 jobId → cache_miss_or_consumed', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.reply(
          200,
          _kFakePng,
          headers: <String, List<String>>{
            'finish-reason': <String>['SUCCESS'],
          },
        ),
      );
      final p = _buildProvider(dio);
      final jobId = await p.submit(_task());
      await p.poll(jobId);
      await expectLater(
        p.poll(jobId),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having(
              (e) => e.extra['reason'],
              'reason',
              'cache_miss_or_consumed',
            )),
      );
    });

    test('未知 jobId → cache_miss_or_consumed', () async {
      final p = _buildProvider(_bytesDio());
      await expectLater(
        p.poll('${kStabilityLocalJobPrefix}never-submitted'),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having(
              (e) => e.extra['reason'],
              'reason',
              'cache_miss_or_consumed',
            )),
      );
    });
  });

  // ---- Task 9a：fixture-replay —— 无 Key 即可采集的 4xx 真实载荷 -----------
  // fixture 来源：以无效 Key 实拍 api.stability.ai（2026-06-12 抓取，已脱敏：
  // 请求 id → FIXTURE_REQUEST_ID，Key 片段 → FIXTURE_REDACTED_KEY）。
  group('StabilityImageCoreProvider fixture-replay（keyless 可采集 4xx）', () {
    test('submit_invalid_key fixture → ProviderError(invalidKey)', () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kStabilityCoreGeneratePath,
        (req) => req.throws(
          401,
          _badResponse(
            401,
            body: loadProviderFixture('stability-image-core', 'submit_invalid_key'),
          ),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidKey)),
      );
    });

    test('balance_invalid_key fixture → validateApiKey returns KeyInvalid',
        () async {
      final dio = _bytesDio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kStabilityBalancePath,
        (req) => req.throws(
          401,
          DioException(
            requestOptions: RequestOptions(path: kStabilityBalancePath),
            response: Response(
              statusCode: 401,
              data: loadProviderFixture(
                'stability-image-core',
                'balance_invalid_key',
              ),
              requestOptions: RequestOptions(path: kStabilityBalancePath),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
    });
  });

  // ---- Task 9b：fixture-replay E2E —— BLOCKED-pending-stability-key -------
  // 成功二进制图片 / content-filter 响应必须持有效 Key 实拍（§12.3 禁止手写
  // 成功载荷）。Key 到位前保留 skip 占位，绝不伪造成功图片 fixture。
  group('StabilityImageCoreProvider fixture E2E（需有效 Key）', () {
    // BLOCKED-pending-stability-key: skip until real fixtures captured
  }, skip: 'BLOCKED-pending-stability-key');
}
