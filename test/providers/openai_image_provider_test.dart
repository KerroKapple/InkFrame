// OpenAIImageProvider 单元测试：基于 http_mock_adapter 回放，无真 Key。
//
// 三层测试（PROVIDER-API.md §12）：
//   - 单元错误矩阵（submit / validateApiKey / poll）—— mock Dio
//   - capabilities 契约 + ProviderContractSuite —— const 直读，零网络
//   - fixture-replay E2E —— BLOCKED-pending-key（真 Key 抓取后解封）

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/openai_image_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';

import '../_harness/fixtures.dart';

Map<String, Object?> _loadFixture(String name) =>
    loadProviderFixture('openai-image', name);

OpenAIImageProvider _buildProvider(Dio dio, {String key = 'test-key'}) {
  return OpenAIImageProvider(
    keySource: () async => key,
    rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    dio: dio,
  );
}

GenerationTask _task({String? prompt, GenerationMode? mode}) => GenerationTask(
      providerId: 'openai-image',
      jobId: 'job-1',
      mode: mode ?? GenerationMode.textToImage,
      prompt: prompt ?? 'an ink wash painting of mountains',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

/// 1×1 透明 PNG 的 base64——真 PNG 字节，仅作脱敏占位（与 Gemini fixture 同源）。
const String _kOnePxPngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// 内联构造的成功响应——用于单元层 mock，不落 fixture 文件。
Map<String, Object?> _inlineSubmitSuccess() => <String, Object?>{
      'created': 1718000000,
      'data': [
        {'b64_json': _kOnePxPngB64},
      ],
    };

/// 包装一个 badResponse DioException，便于 mock onPost/onGet.throws。
DioException _badResponse(
  String path,
  int status,
  Object? body,
) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        statusCode: status,
        data: body,
        requestOptions: RequestOptions(path: path),
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  // ---- Task 1 / Task 5：capabilities 契约（const 直读，零实例化即可访问） ----
  group('OpenAIImageProvider capabilities contract', () {
    test('providerId == openai-image', () {
      expect(kOpenAIImageCapabilities.providerId, 'openai-image');
    });
    test('region == global', () {
      expect(kOpenAIImageCapabilities.region, ProviderRegion.global);
    });
    test('supportsPolling == true（同步 Provider 走 Pollable）', () {
      expect(kOpenAIImageCapabilities.supportsPolling, isTrue);
    });
    test('supportsCancellation == false', () {
      expect(kOpenAIImageCapabilities.supportsCancellation, isFalse);
    });
    test('supportsSeed == false（gpt-image-1 无 seed）', () {
      expect(kOpenAIImageCapabilities.supportsSeed, isFalse);
    });
    test('supportsNegativePrompt == false', () {
      expect(kOpenAIImageCapabilities.supportsNegativePrompt, isFalse);
    });
    test('modes == [textToImage]', () {
      expect(kOpenAIImageCapabilities.modes, [GenerationMode.textToImage]);
    });
    test('supportedRatios 含 r1x1/r16x9/r9x16，不含 r4x3/r3x4/r21x9', () {
      final ratios = kOpenAIImageCapabilities.supportedRatios;
      expect(ratios, containsAll(<AspectRatio>[
        AspectRatio.r1x1,
        AspectRatio.r16x9,
        AspectRatio.r9x16,
      ]));
      expect(ratios, isNot(contains(AspectRatio.r4x3)));
      expect(ratios, isNot(contains(AspectRatio.r3x4)));
      expect(ratios, isNot(contains(AspectRatio.r21x9)));
    });
    test('qps == 2 / burst == 5', () {
      expect(kOpenAIImageCapabilities.qps, 2);
      expect(kOpenAIImageCapabilities.burst, 5);
    });
    test('maxBatchSize == 1', () {
      expect(kOpenAIImageCapabilities.maxBatchSize, 1);
    });
    test('costModel 是 PerCall 变体', () {
      expect(kOpenAIImageCapabilities.costModel, isA<PerCall>());
    });
    test('capabilities 字段经 instance 暴露与 const 一致', () {
      final p = _buildProvider(Dio(BaseOptions(baseUrl: kOpenAIBaseUrl)));
      expect(p.capabilities, same(kOpenAIImageCapabilities));
    });
  });

  // ---- Task 5：ProviderContractSuite 接口契约 ----
  group('ProviderContractSuite: openai-image', () {
    final p = _buildProvider(Dio(BaseOptions(baseUrl: kOpenAIBaseUrl)));

    test('implements Submittable', () {
      expect(p, isA<Submittable>());
    });
    test('implements Pollable', () {
      expect(p, isA<Pollable>());
    });
    test('implements KeyValidatable', () {
      expect(p, isA<KeyValidatable>());
    });
    test('does NOT implement Cancellable（同步无取消）', () {
      // supportsCancellation=false → 不实现 Cancellable 接口。
      expect(p, isNot(isA<Cancellable>()));
    });
  });

  // ---- Task 2：validateApiKey 错误矩阵 ----
  group('OpenAIImageProvider.validateApiKey', () {
    test('200 from GET /models → KeyValid', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.reply(200, {'object': 'list', 'data': <Object?>[]}),
      );

      final r = await _buildProvider(dio).validateApiKey('good');
      expect(r, isA<KeyValid>());
    });

    test('401 → KeyInvalid(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.throws(401, _badResponse(kOpenAIValidatePath, 401, null)),
      );

      final r = await _buildProvider(dio, key: 'bad').validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });

    test('402 → KeyInvalid(insufficientBalance)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.throws(402, _badResponse(kOpenAIValidatePath, 402, null)),
      );

      final r = await _buildProvider(dio).validateApiKey('broke');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.insufficientBalance);
    });

    // ME-10：超时/离线无法判定 Key 本身 → 统一 KeyNetworkError（对齐三态语义）。
    test('connectionTimeout → KeyNetworkError', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: kOpenAIValidatePath),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
    });

    test('connectionError → KeyNetworkError', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: kOpenAIValidatePath),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
    });

    test('500 → KeyNetworkError(message contains 500)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.throws(500, _badResponse(kOpenAIValidatePath, 500, null)),
      );

      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
      expect((r as KeyNetworkError).message, contains('500'));
    });
  });

  // ---- Task 3：submit 错误矩阵 ----
  group('OpenAIImageProvider.submit', () {
    test('成功返回 local:// JobId', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, _inlineSubmitSuccess()),
      );

      final jobId = await _buildProvider(dio).submit(_task());
      expect(jobId, startsWith(kOpenAILocalJobPrefix));
    });

    // HI-06：gpt-image-1 不接受 response_format 参数（带上即 400）。
    test('请求体不含 response_format（gpt-image-1 拒绝该参数）', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      Object? sentBody;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) {
          sentBody = o.data;
          h.next(o);
        },
      ));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, _inlineSubmitSuccess()),
      );

      await _buildProvider(dio).submit(_task());

      final body = sentBody! as Map;
      expect(body.containsKey('response_format'), isFalse);
      expect(body['model'], kOpenAIModel);
      expect(body['size'], '1024x1024');
    });

    test('401 → ProviderError(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          401,
          _badResponse(kOpenAIImagePath, 401, {
            'error': {'code': 'invalid_api_key'},
          }),
        ),
      );

      await expectLater(
        _buildProvider(dio, key: 'bad').submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidKey)),
      );
    });

    test('402 → ProviderError(insufficientBalance)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          402,
          _badResponse(kOpenAIImagePath, 402, {
            'error': {'code': 'insufficient_quota'},
          }),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.insufficientBalance)),
      );
    });

    test('429 → ProviderError(providerBusy)（可重试）', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          429,
          _badResponse(kOpenAIImagePath, 429, {
            'error': {'code': 'rate_limit_exceeded'},
          }),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerBusy)
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('400 content_policy_violation → ProviderError(contentPolicy)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          400,
          _badResponse(kOpenAIImagePath, 400, {
            'error': {'code': 'content_policy_violation'},
          }),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.contentPolicy)),
      );
    });

    test('400 other → ProviderError(invalidParameter)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          400,
          _badResponse(kOpenAIImagePath, 400, {
            'error': {'code': 'invalid_request_error'},
          }),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('503 → ProviderError(providerServer)（可重试）', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          503,
          _badResponse(kOpenAIImagePath, 503, {
            'error': {'code': 'server_error'},
          }),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('空 prompt 本地拒绝，不发网络请求', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, _inlineSubmitSuccess()),
      );

      await expectLater(
        _buildProvider(dio).submit(_task(prompt: '   ')),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('非 textToImage 模式本地拒绝', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      // ignore: unused_local_variable
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());

      await expectLater(
        _buildProvider(dio).submit(_task(mode: GenerationMode.textToVideo)),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('data 数组空 → ProviderError(providerServer)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, {'data': <Object?>[]}),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)),
      );
    });

    test('b64_json 字段缺失 → ProviderError(providerServer)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, {
          'data': [
            {'url': 'http://example.com/x.png'},
          ],
        }),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)),
      );
    });

    test('submit 失败后 cache 为空（poll 任意 id 报 cache_miss）', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          500,
          _badResponse(kOpenAIImagePath, 500, {'error': 'boom'}),
        ),
      );

      final p = _buildProvider(dio);
      await expectLater(p.submit(_task()), throwsA(isA<ProviderError>()));

      await expectLater(
        p.poll('${kOpenAILocalJobPrefix}any-id'),
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

  // ---- Task 4：poll 同步通道（ADR-0004） ----
  group('OpenAIImageProvider.poll (sync provider channel)', () {
    test('submit→poll 一次成功返回 inlineBytes 且 remoteUrls 为空', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, _inlineSubmitSuccess()),
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

    test('重复 poll 同一 jobId → ProviderError(cache_miss_or_consumed)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, _inlineSubmitSuccess()),
      );

      final p = _buildProvider(dio);
      final jobId = await p.submit(_task());
      await p.poll(jobId); // 第一次消费

      await expectLater(
        p.poll(jobId), // 第二次必须报错
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having(
              (e) => e.extra['reason'],
              'reason',
              'cache_miss_or_consumed',
            )),
      );
    });

    test('submit 失败时不在 cache 留任何 jobId', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          500,
          _badResponse(kOpenAIImagePath, 500, {'error': 'boom'}),
        ),
      );

      final p = _buildProvider(dio);
      await expectLater(p.submit(_task()), throwsA(isA<ProviderError>()));

      await expectLater(
        p.poll('${kOpenAILocalJobPrefix}any-id'),
        throwsA(isA<ProviderError>().having(
          (e) => e.extra['reason'],
          'reason',
          'cache_miss_or_consumed',
        )),
      );
    });
  });

  // ---- Task 6a：fixture-replay E2E —— 无 Key 即可采集的 4xx 真实载荷 ----
  // fixture 来源：以无效 Key 实拍 api.openai.com（2026-06-12 抓取，已脱敏：
  // Key 片段 → FIXTURE_REDACTED_KEY）。符合 §12.3 真实 API 调用采集要求。
  group('OpenAIImageProvider fixture-replay（keyless 可采集 4xx）', () {
    test('submit_invalid_key fixture → ProviderError(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          401,
          _badResponse(kOpenAIImagePath, 401, _loadFixture('submit_invalid_key')),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidKey)),
      );
    });

    test('validate_invalid_key fixture → validateApiKey returns KeyInvalid',
        () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.throws(
          401,
          _badResponse(
            kOpenAIValidatePath,
            401,
            _loadFixture('validate_invalid_key'),
          ),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
    });
  });

  // ---- Task 6b：fixture-replay E2E —— BLOCKED-pending-key ----
  // 余下场景（成功载荷 / content_policy / 429 / models 列表）必须持有效 Key
  // 实拍采集（PROVIDER-API.md §12.3 禁止手写成功载荷）。Key 到位前整组 skip。
  group('OpenAIImageProvider fixture-replay E2E（需有效 Key）', () {
    test('submit_success fixture → local:// JobId + inlineBytes round-trip',
        () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.reply(200, _loadFixture('submit_success')),
      );

      final p = _buildProvider(dio);
      final jobId = await p.submit(_task());
      expect(jobId, startsWith(kOpenAILocalJobPrefix));
      final status = await p.poll(jobId);
      expect(status, isA<JobSuccess>());
      expect((status as JobSuccess).inlineBytes!.first.isNotEmpty, isTrue);
    });

    test('submit_content_policy fixture → ProviderError(contentPolicy)',
        () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          400,
          _badResponse(
            kOpenAIImagePath,
            400,
            _loadFixture('submit_content_policy'),
          ),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.contentPolicy)),
      );
    });

    test('submit_rate_limited fixture → ProviderError(providerBusy)', () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAIImagePath,
        (req) => req.throws(
          429,
          _badResponse(
            kOpenAIImagePath,
            429,
            _loadFixture('submit_rate_limited'),
          ),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerBusy)),
      );
    });

    test('models_list_success fixture → validateApiKey returns KeyValid',
        () async {
      final dio = Dio(BaseOptions(baseUrl: kOpenAIBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAIValidatePath,
        (req) => req.reply(200, _loadFixture('models_list_success')),
      );

      final r = await _buildProvider(dio).validateApiKey('good');
      expect(r, isA<KeyValid>());
    });
  }, skip: 'BLOCKED-pending-key');
}
