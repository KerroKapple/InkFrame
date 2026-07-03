// OpenAICompatibleImageProvider 单元测试：mock Dio，无真端点。
//
// 覆盖（PROVIDER-API §13.3）：
//   - 模板派生 capabilities 契约 + ProviderContractSuite
//   - submit 请求体（model 透传 / response_format=b64_json / size 映射 / Bearer）
//   - submit / validateApiKey 错误矩阵
//   - poll 同步 inlineBytes 通道（ADR-0004）

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/custom_provider_config.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/models/provider_protocol_template.dart';
import 'package:inkframe/providers/openai_compatible_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';

const _config = CustomProviderConfig(
  id: 'my-endpoint',
  displayName: 'My Endpoint',
  template: kOpenAIImageTemplateId,
  baseUrl: 'https://example.com/v1',
  modelId: 'flux-pro',
);

OpenAICompatibleImageProvider _buildProvider(Dio dio, {String key = 'test-key'}) {
  return OpenAICompatibleImageProvider(
    config: _config,
    keySource: () async => key,
    rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    dio: dio,
  );
}

Dio _dio() => Dio(BaseOptions(baseUrl: _config.baseUrl));

GenerationTask _task({
  String? prompt,
  GenerationMode? mode,
  AspectRatio ratio = AspectRatio.r1x1,
}) =>
    GenerationTask(
      providerId: 'custom:my-endpoint',
      jobId: 'job-1',
      mode: mode ?? GenerationMode.textToImage,
      prompt: prompt ?? 'an ink wash painting of mountains',
      resolution: Resolution.p1080,
      aspectRatio: ratio,
    );

/// 1×1 透明 PNG 的 base64——真 PNG 字节，仅作占位（与 openai 测试同源）。
const String _kOnePxPngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Map<String, Object?> _submitSuccess() => <String, Object?>{
      'created': 1718000000,
      'data': [
        {'b64_json': _kOnePxPngB64},
      ],
    };

DioException _badResponse(String path, int status, Object? body) =>
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
  group('OpenAICompatibleImageProvider capabilities contract', () {
    final p = _buildProvider(_dio());

    test('capabilities == 模板派生结果', () {
      expect(p.capabilities, deriveCustomProviderCapabilities(_config));
    });
    test('providerId == custom:my-endpoint / displayName 来自配置', () {
      expect(p.capabilities.providerId, 'custom:my-endpoint');
      expect(p.capabilities.displayName, 'My Endpoint');
    });
    test('supportsPolling == true（同步 Provider 走 Pollable）', () {
      expect(p.capabilities.supportsPolling, isTrue);
    });
    test('baseUrl 来自配置', () {
      expect(p.baseUrl, 'https://example.com/v1');
    });
  });

  group('ProviderContractSuite: custom openai-compatible', () {
    final p = _buildProvider(_dio());

    test('implements Submittable', () {
      expect(p, isA<Submittable>());
    });
    test('implements Pollable', () {
      expect(p, isA<Pollable>());
    });
    test('implements KeyValidatable', () {
      expect(p, isA<KeyValidatable>());
    });
    test('does NOT implement Cancellable', () {
      expect(p, isNot(isA<Cancellable>()));
    });
  });

  group('OpenAICompatibleImageProvider.submit', () {
    test('成功返回 local://custom:<id>/ 前缀 JobId', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, _submitSuccess()),
      );

      final jobId = await _buildProvider(dio).submit(_task());
      expect(jobId, startsWith('local://custom:my-endpoint/'));
    });

    test('请求体：model 透传 + response_format=b64_json + size 映射 + Bearer',
        () async {
      final dio = _dio();
      Object? sentBody;
      Object? sentAuth;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) {
          sentBody = o.data;
          sentAuth = o.headers['Authorization'];
          h.next(o);
        },
      ));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, _submitSuccess()),
      );

      await _buildProvider(dio).submit(_task(ratio: AspectRatio.r16x9));

      final body = sentBody! as Map;
      expect(body['model'], 'flux-pro');
      expect(body['response_format'], 'b64_json');
      expect(body['size'], '1536x1024');
      expect(body['n'], 1);
      expect(sentAuth, 'Bearer test-key');
    });

    test('size 映射：1:1 → 1024x1024，9:16 → 1024x1536', () async {
      final dio = _dio();
      final sizes = <Object?>[];
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) {
          sizes.add((o.data as Map)['size']);
          h.next(o);
        },
      ));
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, _submitSuccess()),
      );

      final p = _buildProvider(dio);
      await p.submit(_task());
      await p.submit(_task(ratio: AspectRatio.r9x16));
      expect(sizes, ['1024x1024', '1024x1536']);
    });

    test('401 → ProviderError(invalidKey)', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.throws(
          401,
          _badResponse(kOpenAICompatibleImagePath, 401, {
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
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.throws(
          402,
          _badResponse(kOpenAICompatibleImagePath, 402, null),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.insufficientBalance)),
      );
    });

    test('429 → ProviderError(providerBusy)（可重试）', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.throws(
          429,
          _badResponse(kOpenAICompatibleImagePath, 429, null),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerBusy)
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('503 → ProviderError(providerServer)（可重试）', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.throws(
          503,
          _badResponse(kOpenAICompatibleImagePath, 503, null),
        ),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having((e) => e.retryable, 'retryable', isTrue)),
      );
    });

    test('400 → ProviderError(invalidParameter)', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.throws(
          400,
          _badResponse(kOpenAICompatibleImagePath, 400, {
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

    test('空 prompt 本地拒绝，不发网络请求', () async {
      final dio = _dio();
      // ignore: unused_local_variable
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());

      await expectLater(
        _buildProvider(dio).submit(_task(prompt: '   ')),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('非 textToImage 模式本地拒绝', () async {
      final dio = _dio();
      // ignore: unused_local_variable
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());

      await expectLater(
        _buildProvider(dio).submit(_task(mode: GenerationMode.textToVideo)),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidParameter)),
      );
    });

    test('data 数组空 → ProviderError(providerServer, no_data)', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, {'data': <Object?>[]}),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having((e) => e.extra['reason'], 'reason', 'no_data')),
      );
    });

    test('b64_json 缺失（端点回 url）→ ProviderError(no_b64_json)', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, {
          'data': [
            {'url': 'http://example.com/x.png'},
          ],
        }),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having((e) => e.extra['reason'], 'reason', 'no_b64_json')),
      );
    });

    test('b64_json 非 String 类型 → ProviderError(no_b64_json)，不裸抛', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, {
          'data': [
            {'b64_json': 12345},
          ],
        }),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having((e) => e.extra['reason'], 'reason', 'no_b64_json')),
      );
    });

    test('b64_json 损坏 → ProviderError(malformed_b64_json)，不裸抛', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, {
          'data': [
            {'b64_json': '!!!not-base64!!!'},
          ],
        }),
      );

      await expectLater(
        _buildProvider(dio).submit(_task()),
        throwsA(isA<ProviderError>()
            .having((e) => e.code, 'code', InkErrorCode.providerServer)
            .having(
              (e) => e.extra['reason'],
              'reason',
              'malformed_b64_json',
            )),
      );
    });
  });

  group('OpenAICompatibleImageProvider.poll (sync provider channel)', () {
    test('submit→poll 一次成功返回 inlineBytes 且 remoteUrls 为空', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, _submitSuccess()),
      );

      final p = _buildProvider(dio);
      final jobId = await p.submit(_task());
      final status = await p.poll(jobId);

      expect(status, isA<JobSuccess>());
      final s = status as JobSuccess;
      expect(s.remoteUrls, isEmpty);
      expect(s.inlineBytes, isNotNull);
      expect(s.inlineBytes!.single.isNotEmpty, isTrue);
    });

    test('重复 poll 同一 jobId → ProviderError(cache_miss_or_consumed)',
        () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onPost(
        kOpenAICompatibleImagePath,
        (req) => req.reply(200, _submitSuccess()),
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
  });

  group('OpenAICompatibleImageProvider.validateApiKey', () {
    test('200 from GET /models → KeyValid', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAICompatibleValidatePath,
        (req) => req.reply(200, {'object': 'list', 'data': <Object?>[]}),
      );

      final r = await _buildProvider(dio).validateApiKey('good');
      expect(r, isA<KeyValid>());
    });

    test('401 → KeyInvalid(invalidKey)', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAICompatibleValidatePath,
        (req) => req.throws(
          401,
          _badResponse(kOpenAICompatibleValidatePath, 401, null),
        ),
      );

      final r = await _buildProvider(dio, key: 'bad').validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });

    test('402 → KeyInvalid(insufficientBalance)', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAICompatibleValidatePath,
        (req) => req.throws(
          402,
          _badResponse(kOpenAICompatibleValidatePath, 402, null),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('broke');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.insufficientBalance);
    });

    test('connectionTimeout → KeyNetworkError', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAICompatibleValidatePath,
        (req) => req.throws(
          0,
          DioException(
            requestOptions:
                RequestOptions(path: kOpenAICompatibleValidatePath),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
    });

    test('500 → KeyNetworkError(message contains 500)', () async {
      final dio = _dio();
      final adapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      adapter.onGet(
        kOpenAICompatibleValidatePath,
        (req) => req.throws(
          500,
          _badResponse(kOpenAICompatibleValidatePath, 500, null),
        ),
      );

      final r = await _buildProvider(dio).validateApiKey('x');
      expect(r, isA<KeyNetworkError>());
      expect((r as KeyNetworkError).message, contains('500'));
    });
  });
}
