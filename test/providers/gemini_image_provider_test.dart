// GeminiImageProvider 单元测试：基于 http_mock_adapter 回放 fixture。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/gemini_image_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';

import '../_harness/fixtures.dart';

Map<String, Object?> _loadFixture(String name) =>
    loadProviderFixture('gemini-image', name);

GeminiImageProvider _buildProvider(Dio dio, {String key = 'test-key'}) {
  return GeminiImageProvider(
    keySource: () async => key,
    rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    dio: dio,
  );
}

GenerationTask _task({String? prompt}) => GenerationTask(
      providerId: 'gemini-image',
      jobId: 'job-1',
      mode: GenerationMode.textToImage,
      prompt: prompt ?? 'an ink wash painting of mountains',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

void main() {
  group('GeminiImageProvider capabilities', () {
    test('providerId 与 PRD §10.2 对齐', () {
      final p = GeminiImageProvider(
        keySource: () async => 'x',
        rateLimiter: ProviderRateLimiter(qps: 2, burst: 10),
      );
      expect(p.capabilities.providerId, 'gemini-image');
      expect(p.capabilities.region, ProviderRegion.global);
      // 同步 Provider 走 Pollable + inlineBytes 通道（ADR-0004）。
      expect(p.capabilities.supportsPolling, isTrue);
      expect(p.capabilities.qps, 2);
    });
  });

  group('GeminiImageProvider.submit', () {
    test('成功返回 local:// JobId', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.reply(200, _loadFixture('submit_success')),
      );

      final jobId = await _buildProvider(dio).submit(_task());
      expect(jobId, startsWith(kGeminiLocalJobPrefix));
    });

    // LO-13 + HI-07 + HI-27：Key 走 x-goog-api-key 头（不进 URL）；
    // aspectRatio 接入 imageConfig；responseModalities 必须 TEXT+IMAGE。
    test('请求体/头：x-goog-api-key 头 + imageConfig.aspectRatio + TEXT,IMAGE',
        () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      Object? sentBody;
      Map<String, dynamic>? sentHeaders;
      Map<String, dynamic>? sentQuery;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) {
          sentBody = o.data;
          sentHeaders = o.headers;
          sentQuery = o.queryParameters;
          h.next(o);
        },
      ));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.reply(200, _loadFixture('submit_success')),
      );

      await _buildProvider(dio, key: 'secret-key').submit(const GenerationTask(
        providerId: 'gemini-image',
        jobId: 'job-1',
        mode: GenerationMode.textToImage,
        prompt: 'mountains',
        resolution: Resolution.p1080,
        aspectRatio: AspectRatio.r16x9,
      ));

      // LO-13：Key 只进请求头，绝不进 URL query（防日志/代理泄露）。
      expect(sentHeaders![kGeminiApiKeyHeader], 'secret-key');
      expect(sentQuery!.containsKey('key'), isFalse);

      final body = sentBody! as Map;
      final genCfg = body['generationConfig'] as Map;
      // HI-27：image-preview 模型要求 TEXT+IMAGE 双模态。
      expect(genCfg['responseModalities'], ['TEXT', 'IMAGE']);
      // HI-07：aspectRatio 不能被忽略。
      expect((genCfg['imageConfig'] as Map)['aspectRatio'], '16:9');
    });

    test('401 invalid_key → ProviderError.invalidKey', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.throws(
          401,
          DioException(
            requestOptions: RequestOptions(path: kGeminiSubmitPath),
            response: Response(
              statusCode: 401,
              data: _loadFixture('submit_invalid_key'),
              requestOptions: RequestOptions(path: kGeminiSubmitPath),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      await expectLater(
        _buildProvider(dio, key: 'bad-key').submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidKey)),
      );
    });

    test('400 SAFETY → ProviderError.contentPolicy', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.throws(
          400,
          DioException(
            requestOptions: RequestOptions(path: kGeminiSubmitPath),
            response: Response(
              statusCode: 400,
              data: _loadFixture('submit_content_policy'),
              requestOptions: RequestOptions(path: kGeminiSubmitPath),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.contentPolicy)),
      );
    });

    test('429 → ProviderError.providerBusy (可重试)', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.throws(
          429,
          DioException(
            requestOptions: RequestOptions(path: kGeminiSubmitPath),
            response: Response(
              statusCode: 429,
              data: const <String, Object?>{'error': 'busy'},
              requestOptions: RequestOptions(path: kGeminiSubmitPath),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerBusy)
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('500 → ProviderError.providerServer (可重试)', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.throws(
          503,
          DioException(
            requestOptions: RequestOptions(path: kGeminiSubmitPath),
            response: Response(
              statusCode: 503,
              data: const <String, Object?>{'error': 'unavailable'},
              requestOptions: RequestOptions(path: kGeminiSubmitPath),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)),
      );
    });

    test('空 prompt 本地拒绝，不发网络请求', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      // 不设任何 mock —— 应本地抛错
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.reply(200, _loadFixture('submit_success')),
      );

      await expectLater(
        _buildProvider(dio).submit(_task(prompt: '   ')),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('非 textToImage 模式本地拒绝', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      // ignore: unused_local_variable
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      final p = _buildProvider(dio);
      const t = GenerationTask(
        providerId: 'gemini-image',
        jobId: 'j',
        mode: GenerationMode.textToVideo, // 不支持
        prompt: 'x',
        resolution: Resolution.p1080,
        aspectRatio: AspectRatio.r1x1,
      );
      await expectLater(
        p.submit(t),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('candidates 空 → providerServer（服务端异常）', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.reply(200, {'candidates': <Object?>[]}),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)),
      );
    });
  });

  group('GeminiImageProvider.validateApiKey', () {
    test('200 → valid', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onGet(
        kGeminiValidatePath,
        (req) => req.reply(200, _loadFixture('models_list_success')),
      );

      final r = await _buildProvider(dio).validateApiKey('good');
      expect(r, isA<KeyValid>());
    });

    // LO-13：校验请求同样走 x-goog-api-key 头，不进 URL query。
    test('Key 经 x-goog-api-key 头发送，不出现在 query', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      Map<String, dynamic>? sentHeaders;
      Map<String, dynamic>? sentQuery;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) {
          sentHeaders = o.headers;
          sentQuery = o.queryParameters;
          h.next(o);
        },
      ));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onGet(
        kGeminiValidatePath,
        (req) => req.reply(200, _loadFixture('models_list_success')),
      );

      await _buildProvider(dio).validateApiKey('secret-key');
      expect(sentHeaders![kGeminiApiKeyHeader], 'secret-key');
      expect(sentQuery!.containsKey('key'), isFalse);
    });

    // ME-10：超时无法判定 Key 本身 → KeyNetworkError。
    test('connectionTimeout → KeyNetworkError', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onGet(
        kGeminiValidatePath,
        (req) => req.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: kGeminiValidatePath),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
    });

    test('401 → invalid(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(),
      );
      adapter.onGet(
        kGeminiValidatePath,
        (req) => req.throws(
          401,
          DioException(
            requestOptions: RequestOptions(path: kGeminiValidatePath),
            response: Response(
              statusCode: 401,
              data: _loadFixture('submit_invalid_key'),
              requestOptions: RequestOptions(path: kGeminiValidatePath),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });
  });

  // ADR-0004：同步 Provider 通过 Pollable + inlineBytes 通道返回结果。
  group('GeminiImageProvider.poll (sync provider channel)', () {
    test('submit→poll 一次成功返回 inlineBytes 且 remoteUrls 为空', () async {
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.reply(200, _loadFixture('submit_success')),
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
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.reply(200, _loadFixture('submit_success')),
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
      final dio = Dio(BaseOptions(baseUrl: kGeminiBaseUrl));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kGeminiSubmitPath,
        (req) => req.throws(
          500,
          DioException(
            requestOptions: RequestOptions(path: kGeminiSubmitPath),
            response: Response(
              statusCode: 500,
              data: const <String, Object?>{'error': 'boom'},
              requestOptions: RequestOptions(path: kGeminiSubmitPath),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      final p = _buildProvider(dio);
      await expectLater(p.submit(_task()), throwsA(isA<ProviderError>()));

      // 任意构造 local:// jobId 都不应命中 cache（submit 失败未写入）
      await expectLater(
        p.poll('${kGeminiLocalJobPrefix}any-id'),
        throwsA(isA<ProviderError>().having(
          (e) => e.extra['reason'],
          'reason',
          'cache_miss_or_consumed',
        )),
      );
    });
  });
}
