// KlingV3Provider 单测：聚焦子类三个 override + fixture 回放。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/dashscope_async_provider_base.dart';
import 'package:inkframe/providers/kling_v3_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';

import '../_harness/fixtures.dart';

GenerationTask _task({
  GenerationMode mode = GenerationMode.textToVideo,
  String? firstFrame,
  String? negative,
  int duration = 5,
  Resolution resolution = Resolution.p720,
  AspectRatio ratio = AspectRatio.r16x9,
}) =>
    GenerationTask(
      providerId: 'kling-v3',
      jobId: 'job-x',
      mode: mode,
      prompt: 'cinematic wide shot of a city at night',
      negativePrompt: negative,
      resolution: resolution,
      aspectRatio: ratio,
      durationSeconds: duration,
      firstFramePath: firstFrame,
    );

KlingV3Provider _build(Dio dio, {String key = 'sk-test'}) => KlingV3Provider(
      keySource: () async => key,
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
      dio: dio,
    );

Future<Map<String, Object?>> _loadFixture(String name) async =>
    loadProviderFixture('kling-v3', name.replaceFirst(RegExp(r'\.json$'), ''));

void main() {
  group('KlingV3Provider.capabilities', () {
    test('关键字段：T2V+I2V 双模式 + 首帧支持 + 计费', () {
      const c = kKlingV3Capabilities;
      expect(c.providerId, 'kling-v3');
      expect(c.modes,
          containsAll([GenerationMode.textToVideo, GenerationMode.imageToVideo]));
      expect(c.supportsFirstFrame, isTrue);
      expect(c.supportsLastFrame, isFalse);
      expect(c.supportsSeed, isFalse);
      expect(c.maxRefImages, 0);
      expect(c.costModel, isA<PerSecondVideo>());
    });

    test('model ID 含 "/"（DashScope 厂商命名空间）', () {
      expect(kKlingV3Model, 'kling/kling-v3-video-generation');
      expect(kKlingV3Model, contains('/'));
    });
  });

  group('KlingV3Provider.buildRequestBody', () {
    final p = KlingV3Provider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('T2V 基础映射：model 全路径 + input.prompt + 无 img_url', () {
      final body = p.buildRequestBody(_task());
      expect(body['model'], 'kling/kling-v3-video-generation');
      final input = body['input'] as Map;
      expect(input['prompt'], isNotEmpty);
      expect(input.containsKey('img_url'), isFalse);
      final params = body['parameters'] as Map;
      expect(params['size'], '1280*720');
      expect(params['duration'], 5);
    });

    test('I2V：有首帧时追加 img_url', () {
      final body = p.buildRequestBody(_task(
        mode: GenerationMode.imageToVideo,
        firstFrame: 'https://x/first.png',
      ));
      expect((body['input'] as Map)['img_url'], 'https://x/first.png');
    });

    test('seed 字段不存在（Kling v3 不支持）——task.seed 被忽略', () {
      final body = p.buildRequestBody(_task());
      expect((body['parameters'] as Map).containsKey('seed'), isFalse);
    });

    test('size 矩阵：1080p × 9:16', () {
      final body = p.buildRequestBody(_task(
        resolution: Resolution.p1080,
        ratio: AspectRatio.r9x16,
      ));
      expect((body['parameters'] as Map)['size'], '1080*1920');
    });

    test('negative_prompt 透传', () {
      final body = p.buildRequestBody(_task(negative: 'blurry'));
      expect((body['parameters'] as Map)['negative_prompt'], 'blurry');
    });

    test('durationSeconds=0 → 默认 5s', () {
      final body = p.buildRequestBody(_task(duration: 0));
      expect((body['parameters'] as Map)['duration'], 5);
    });
  });

  group('KlingV3Provider.parseSuccessOutput', () {
    final p = KlingV3Provider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('解析 output.video_url', () {
      final s = p.parseSuccessOutput({'video_url': 'https://x/v.mp4'});
      expect((s as JobSuccess).remoteUrls, ['https://x/v.mp4']);
    });

    test('video_url 缺失 → success(remoteUrls=[])', () {
      final s = p.parseSuccessOutput({});
      expect((s as JobSuccess).remoteUrls, isEmpty);
    });
  });

  group('KlingV3Provider fixture 回放', () {
    test('submit → task_id', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('submit_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kKlingV3SubmitPath,
        (req) => req.reply(200, fx),
      );
      final id = await _build(dio).submit(_task());
      expect(id, 'kling-v3-FIXTURE_JOB_ID');
    });

    test('poll → video_url', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('poll_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/kling-v3-FIXTURE_JOB_ID',
        (req) => req.reply(200, fx),
      );
      final s = await _build(dio).poll('kling-v3-FIXTURE_JOB_ID');
      expect((s as JobSuccess).remoteUrls.single, endsWith('.mp4'));
    });
  });
}
