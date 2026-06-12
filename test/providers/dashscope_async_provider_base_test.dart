// DashScopeAsyncProviderBase 单元测试：用 FakeDashScopeProvider 覆盖基类逻辑。

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/dashscope_async_provider_base.dart';
import 'package:inkframe/providers/rate_limiter.dart';

const String kFakeEndpoint = '/services/aigc/fake/generation';

class FakeDashScopeProvider extends DashScopeAsyncProviderBase {
  FakeDashScopeProvider({
    required super.keySource,
    required super.rateLimiter,
    super.dio,
  });

  @override
  String get submitEndpoint => kFakeEndpoint;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        providerId: 'fake-dashscope',
        region: ProviderRegion.cn,
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
        maxConcurrentJobs: 2,
        qps: 2,
        burst: 5,
      );

  @override
  Map<String, Object?> buildRequestBody(GenerationTask task) => {
        'model': 'fake-model',
        'input': {
          'prompt': task.prompt,
          if (task.refImagePaths.isNotEmpty)
            kDashScopeFieldRefImages: task.refImagePaths,
          if (task.firstFramePath != null)
            kDashScopeFieldImgUrl: task.firstFramePath,
          if (task.lastFramePath != null)
            kDashScopeFieldLastFrameUrl: task.lastFramePath,
        },
      };

  @override
  JobStatus parseSuccessOutput(Map<String, Object?> output) {
    final url = output['fake_url'] as String?;
    return JobStatus.success(
      remoteUrls: url != null ? [url] : const [],
    );
  }
}

GenerationTask _task() => const GenerationTask(
      providerId: 'fake-dashscope',
      jobId: 'jx',
      mode: GenerationMode.textToImage,
      prompt: 'a fake prompt',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

FakeDashScopeProvider _build(Dio dio, {String key = 'sk-test'}) =>
    FakeDashScopeProvider(
      keySource: () async => key,
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
      dio: dio,
    );

void main() {
  group('DashScopeAsyncProviderBase.submit', () {
    test('成功提交返回 task_id', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kFakeEndpoint,
        (req) => req.reply(200, {
          'output': {'task_id': 'task-abc-123', 'task_status': 'PENDING'},
          'request_id': 'r1',
        }),
      );
      final id = await _build(dio).submit(_task());
      expect(id, 'task-abc-123');
    });

    test('响应缺 task_id → ProviderError(no_task_id)', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kFakeEndpoint,
        (req) => req.reply(200, {'output': {'task_status': 'PENDING'}}),
      );
      await expectLater(
        _build(dio).submit(_task()),
        throwsA(isA<ProviderError>().having(
          (e) => e.extra['reason'],
          'reason',
          'no_task_id',
        )),
      );
    });

    test('401 → InkErrorCode.invalidKey', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kFakeEndpoint,
        (req) => req.throws(
          401,
          DioException(
            requestOptions: RequestOptions(path: kFakeEndpoint),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: kFakeEndpoint),
              data: const {'code': 'InvalidApiKey'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );
      await expectLater(
        _build(dio, key: 'bad').submit(_task()),
        throwsA(isA<InkError>()
            .having((e) => e.code, 'code', InkErrorCode.invalidKey)),
      );
    });
  });

  // HI-05：本地绝对路径不许直发远端——submit 前转 base64 data URI。
  group('DashScopeAsyncProviderBase.submit 参考图内联', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('inkframe_ds_test');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    Dio captureDio(void Function(Object?) onBody) {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (o, h) {
          onBody(o.data);
          h.next(o);
        },
      ));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kFakeEndpoint,
        (req) => req.reply(200, {
          'output': {'task_id': 't1', 'task_status': 'PENDING'},
        }),
      );
      return dio;
    }

    test('本地文件路径 → data:image/png;base64 内联；URL 原样透传', () async {
      final f = File('${tmpDir.path}${Platform.pathSeparator}ref.png')
        ..writeAsBytesSync([1, 2, 3, 4]);
      Object? body;
      final dio = captureDio((b) => body = b);

      await _build(dio).submit(_task().copyWith(
        refImagePaths: [f.path, 'https://x/keep.png'],
        firstFramePath: f.path,
        lastFramePath: 'https://x/last.png',
      ));

      final input = (body! as Map)['input'] as Map;
      final refs = (input[kDashScopeFieldRefImages] as List).cast<String>();
      expect(refs.first, 'data:image/png;base64,${base64Encode([1, 2, 3, 4])}');
      expect(refs.last, 'https://x/keep.png');
      expect(input[kDashScopeFieldImgUrl], startsWith('data:image/png;base64,'));
      expect(input[kDashScopeFieldLastFrameUrl], 'https://x/last.png');
    });

    test('jpg 扩展名 → image/jpeg mime', () async {
      final f = File('${tmpDir.path}${Platform.pathSeparator}ref.jpg')
        ..writeAsBytesSync([9, 9]);
      Object? body;
      final dio = captureDio((b) => body = b);

      await _build(dio).submit(_task().copyWith(refImagePaths: [f.path]));

      final input = (body! as Map)['input'] as Map;
      final refs = (input[kDashScopeFieldRefImages] as List).cast<String>();
      expect(refs.single, startsWith('data:image/jpeg;base64,'));
    });

    test('data: URI 已内联 → 原样透传', () async {
      const uri = 'data:image/png;base64,AQID';
      Object? body;
      final dio = captureDio((b) => body = b);

      await _build(dio).submit(_task().copyWith(refImagePaths: [uri]));

      final input = (body! as Map)['input'] as Map;
      expect((input[kDashScopeFieldRefImages] as List).single, uri);
    });

    test('本地文件不可读 → LocalIOError，不发请求', () async {
      final missing = '${tmpDir.path}${Platform.pathSeparator}gone.png';
      var sent = false;
      final dio = captureDio((_) => sent = true);

      await expectLater(
        _build(dio).submit(_task().copyWith(refImagePaths: [missing])),
        throwsA(isA<LocalIOError>()),
      );
      expect(sent, isFalse);
    });
  });

  group('DashScopeAsyncProviderBase.poll', () {
    test('PENDING → JobStatus.inProgress', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/abc',
        (req) => req.reply(200, {
          'output': {'task_id': 'abc', 'task_status': 'PENDING'},
        }),
      );
      final s = await _build(dio).poll('abc');
      expect(s, isA<JobInProgress>());
    });

    test('RUNNING → JobStatus.inProgress', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/abc',
        (req) => req.reply(200, {
          'output': {'task_id': 'abc', 'task_status': 'RUNNING'},
        }),
      );
      final s = await _build(dio).poll('abc');
      expect(s, isA<JobInProgress>());
    });

    test('SUCCEEDED → 调子类 parseSuccessOutput', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/abc',
        (req) => req.reply(200, {
          'output': {
            'task_id': 'abc',
            'task_status': 'SUCCEEDED',
            'fake_url': 'https://x/y.png',
          },
        }),
      );
      final s = await _build(dio).poll('abc');
      expect(s, isA<JobSuccess>());
      expect((s as JobSuccess).remoteUrls, ['https://x/y.png']);
    });

    test('FAILED + InvalidApiKey → JobFailure(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/abc',
        (req) => req.reply(200, {
          'output': {
            'task_id': 'abc',
            'task_status': 'FAILED',
            'code': 'InvalidApiKey',
            'message': 'No API-key',
          },
        }),
      );
      final s = await _build(dio).poll('abc');
      expect(s, isA<JobFailure>());
      expect((s as JobFailure).error.code, InkErrorCode.invalidKey);
    });

    test('FAILED + IPInfringementSuspect → contentPolicy', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/abc',
        (req) => req.reply(200, {
          'output': {
            'task_id': 'abc',
            'task_status': 'FAILED',
            'code': 'IPInfringementSuspect',
          },
        }),
      );
      final s = await _build(dio).poll('abc');
      expect((s as JobFailure).error.code, InkErrorCode.contentPolicy);
    });

    test('CANCELED → JobFailure(cancelledByUser)', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/abc',
        (req) => req.reply(200, {
          'output': {'task_id': 'abc', 'task_status': 'CANCELED'},
        }),
      );
      final s = await _build(dio).poll('abc');
      expect((s as JobFailure).error.code, InkErrorCode.cancelledByUser);
    });

    test('UNKNOWN → JobFailure(providerServer)', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/expired',
        (req) => req.reply(200, {
          'output': {'task_id': 'expired', 'task_status': 'UNKNOWN'},
        }),
      );
      final s = await _build(dio).poll('expired');
      expect((s as JobFailure).error.code, InkErrorCode.providerServer);
    });
  });

  group('DashScopeAsyncProviderBase.validateApiKey', () {
    test('GET /tasks/bogus 200 → valid', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/inkframe-validation-bogus-id',
        (req) => req.reply(200, {
          'output': {'task_status': 'UNKNOWN'},
        }),
      );
      final r = await _build(dio).validateApiKey('sk-good');
      expect(r, isA<KeyValid>());
    });

    // HI-03：validateStatus<500 时 401/403 不抛 DioException，
    // 必须显式查 statusCode，否则坏 Key 被误判 valid。
    test('401 经 validateStatus 放行（不抛异常）→ invalid(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/inkframe-validation-bogus-id',
        (req) => req.reply(401, {'code': 'InvalidApiKey'}),
      );
      final r = await _build(dio, key: 'bad').validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });

    test('403 经 validateStatus 放行（不抛异常）→ invalid(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/inkframe-validation-bogus-id',
        (req) => req.reply(403, {'code': 'AccessDenied'}),
      );
      final r = await _build(dio, key: 'bad').validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });

    test('404（key 通过鉴权、task 不存在）→ valid', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/inkframe-validation-bogus-id',
        (req) => req.reply(404, {'code': 'TaskNotFound'}),
      );
      final r = await _build(dio).validateApiKey('sk-good');
      expect(r, isA<KeyValid>());
    });

    // ME-10：超时/离线统一 networkError——无法判定 Key 本身，不许说 invalid。
    test('connectionTimeout → KeyNetworkError', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/inkframe-validation-bogus-id',
        (req) => req.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/tasks/x'),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );
      final r = await _build(dio).validateApiKey('sk-good');
      expect(r, isA<KeyNetworkError>());
    });

    test('401 → invalid(invalidKey)', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/inkframe-validation-bogus-id',
        (req) => req.throws(
          401,
          DioException(
            requestOptions: RequestOptions(path: '/tasks/x'),
            response: Response(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/tasks/x'),
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );
      final r = await _build(dio, key: 'bad').validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
      expect((r as KeyInvalid).reason, KeyInvalidReason.invalidKey);
    });
  });
}
