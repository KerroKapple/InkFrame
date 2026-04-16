// GeminiImageProvider 单元测试：基于 http_mock_adapter 回放 fixture。

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/gemini_image_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';

Map<String, Object?> _loadFixture(String name) {
  final file = File(
    'test/fixtures/providers/gemini-image/$name.json',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

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
      expect(p.capabilities.supportsPolling, isFalse);
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
}
