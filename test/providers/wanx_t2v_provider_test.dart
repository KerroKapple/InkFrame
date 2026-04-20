// WanxT2VProvider 单测：聚焦子类三个 override + fixture 回放。
//
// 公共行为（auth / 状态机 / 错误码 / validateApiKey）已在
// dashscope_async_provider_base_test.dart 覆盖，本文件不重复。

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/dashscope_async_provider_base.dart';
import 'package:inkframe/providers/rate_limiter.dart';
import 'package:inkframe/providers/wanx_t2v_provider.dart';

GenerationTask _task({
  Resolution resolution = Resolution.p720,
  AspectRatio ratio = AspectRatio.r16x9,
  int duration = 5,
  String? negative,
  int? seed,
}) =>
    GenerationTask(
      providerId: 'wanx-t2v',
      jobId: 'job-x',
      mode: GenerationMode.textToVideo,
      prompt: 'a cat surfing on a wave at sunset',
      negativePrompt: negative,
      resolution: resolution,
      aspectRatio: ratio,
      durationSeconds: duration,
      seed: seed,
    );

WanxT2VProvider _build(Dio dio, {String key = 'sk-test'}) => WanxT2VProvider(
      keySource: () async => key,
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
      dio: dio,
    );

Future<Map<String, Object?>> _loadFixture(String name) async {
  final file = File('test/fixtures/providers/wanx-t2v/$name');
  return jsonDecode(await file.readAsString()) as Map<String, Object?>;
}

void main() {
  group('WanxT2VProvider.capabilities', () {
    test('编译期常量字段齐全', () {
      const c = kWanxT2VCapabilities;
      expect(c.providerId, 'wanx-t2v');
      expect(c.region, ProviderRegion.cn);
      expect(c.modes, [GenerationMode.textToVideo]);
      expect(c.supportedResolutions,
          containsAll([Resolution.p720, Resolution.p1080]));
      expect(c.supportedDurations, [5, 10]);
      expect(c.supportsNegativePrompt, isTrue);
      expect(c.supportsSeed, isTrue);
      expect(c.supportsBatch, isFalse);
      expect(c.supportsCancellation, isFalse);
      expect(c.supportsPolling, isTrue);
      expect(c.supportsSound, isFalse);
      expect(c.costModel, isA<PerSecondVideo>());
      final cost = c.costModel as PerSecondVideo;
      expect(cost.resolutionMultiplier[Resolution.p720], 0.5);
      expect(cost.resolutionMultiplier[Resolution.p1080], 1.0);
    });
  });

  group('WanxT2VProvider.buildRequestBody', () {
    final p = WanxT2VProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('基础映射：model + input.prompt + size + duration', () {
      final body = p.buildRequestBody(_task());
      expect(body['model'], kWanxT2VModel);
      final input = body['input'] as Map;
      expect(input['prompt'], 'a cat surfing on a wave at sunset');
      final params = body['parameters'] as Map;
      expect(params['size'], '1280*720');
      expect(params['duration'], 5);
      expect(params.containsKey('negative_prompt'), isFalse);
      expect(params.containsKey('seed'), isFalse);
    });

    test('(resolution, ratio) → size 矩阵全覆盖', () {
      const cases = <(Resolution, AspectRatio), String>{
        (Resolution.p720, AspectRatio.r16x9): '1280*720',
        (Resolution.p720, AspectRatio.r9x16): '720*1280',
        (Resolution.p720, AspectRatio.r1x1): '720*720',
        (Resolution.p1080, AspectRatio.r16x9): '1920*1080',
        (Resolution.p1080, AspectRatio.r9x16): '1080*1920',
        (Resolution.p1080, AspectRatio.r1x1): '1080*1080',
      };
      cases.forEach((combo, expectedSize) {
        final body = p.buildRequestBody(_task(
          resolution: combo.$1,
          ratio: combo.$2,
        ));
        expect((body['parameters'] as Map)['size'], expectedSize,
            reason: '$combo → $expectedSize');
      });
    });

    test('durationSeconds=0 → 默认 5s', () {
      final body = p.buildRequestBody(_task(duration: 0));
      expect((body['parameters'] as Map)['duration'], 5);
    });

    test('durationSeconds=10 → 透传 10s', () {
      final body = p.buildRequestBody(_task(duration: 10));
      expect((body['parameters'] as Map)['duration'], 10);
    });

    test('可选参数透传：negative_prompt + seed', () {
      final body = p.buildRequestBody(_task(
        negative: 'blurry, low fps',
        seed: 99,
      ));
      final params = body['parameters'] as Map;
      expect(params['negative_prompt'], 'blurry, low fps');
      expect(params['seed'], 99);
    });

    test('空字符串 negative_prompt 不写入 body', () {
      final body = p.buildRequestBody(_task(negative: ''));
      expect((body['parameters'] as Map).containsKey('negative_prompt'),
          isFalse);
    });
  });

  group('WanxT2VProvider.parseSuccessOutput', () {
    final p = WanxT2VProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('解析 output.video_url 单一 URL', () {
      final s = p.parseSuccessOutput({
        'task_status': 'SUCCEEDED',
        'video_url': 'https://x/v.mp4',
      });
      expect(s, isA<JobSuccess>());
      expect((s as JobSuccess).remoteUrls, ['https://x/v.mp4']);
    });

    test('video_url 缺失 → success(remoteUrls=[])', () {
      final s = p.parseSuccessOutput({'task_status': 'SUCCEEDED'});
      expect(s, isA<JobSuccess>());
      expect((s as JobSuccess).remoteUrls, isEmpty);
    });

    test('空字符串 video_url 视为缺失', () {
      final s =
          p.parseSuccessOutput({'task_status': 'SUCCEEDED', 'video_url': ''});
      expect((s as JobSuccess).remoteUrls, isEmpty);
    });
  });

  group('WanxT2VProvider fixture 回放', () {
    test('submit fixture → 拿到 task_id', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('submit_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kWanxT2VSubmitPath,
        (req) => req.reply(200, fx),
      );
      final id = await _build(dio).submit(_task());
      expect(id, 'wanx-t2v-FIXTURE_JOB_ID');
    });

    test('poll fixture → 解析 video_url', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('poll_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/wanx-t2v-FIXTURE_JOB_ID',
        (req) => req.reply(200, fx),
      );
      final s = await _build(dio).poll('wanx-t2v-FIXTURE_JOB_ID');
      expect(s, isA<JobSuccess>());
      final urls = (s as JobSuccess).remoteUrls;
      expect(urls, hasLength(1));
      expect(urls.first, endsWith('.mp4'));
    });
  });
}
