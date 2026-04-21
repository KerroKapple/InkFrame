// KlingV3OmniProvider 单测：聚焦子类三个 override + fixture 回放。

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
import 'package:inkframe/providers/kling_v3_omni_provider.dart';
import 'package:inkframe/providers/rate_limiter.dart';

GenerationTask _task({
  List<String> refs = const ['https://x/ref1.png'],
  String? negative,
  int duration = 5,
  Resolution resolution = Resolution.p720,
  AspectRatio ratio = AspectRatio.r16x9,
}) =>
    GenerationTask(
      providerId: 'kling-v3-omni',
      jobId: 'job-x',
      mode: GenerationMode.textToVideo,
      prompt: 'the characters walk through the marketplace',
      negativePrompt: negative,
      resolution: resolution,
      aspectRatio: ratio,
      durationSeconds: duration,
      refImagePaths: refs,
    );

KlingV3OmniProvider _build(Dio dio, {String key = 'sk-test'}) =>
    KlingV3OmniProvider(
      keySource: () async => key,
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
      dio: dio,
    );

Future<Map<String, Object?>> _loadFixture(String name) async {
  final file = File('test/fixtures/providers/kling-v3-omni/$name');
  return jsonDecode(await file.readAsString()) as Map<String, Object?>;
}

void main() {
  group('KlingV3OmniProvider.capabilities', () {
    test('关键字段：多素材参考 + T2V 模式 + 计费', () {
      const c = kKlingV3OmniCapabilities;
      expect(c.providerId, 'kling-v3-omni');
      expect(c.modes, [GenerationMode.textToVideo]);
      expect(c.maxRefImages, kKlingV3OmniMaxRefImages);
      expect(c.supportsFirstFrame, isFalse);
      expect(c.supportsLastFrame, isFalse);
      expect(c.costModel, isA<PerSecondVideo>());
    });

    test('model ID 含 "/"（DashScope 厂商命名空间）', () {
      expect(kKlingV3OmniModel, 'kling/kling-v3-omni-video-generation');
      expect(kKlingV3OmniModel, contains('/'));
    });
  });

  group('KlingV3OmniProvider.buildRequestBody', () {
    final p = KlingV3OmniProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('基础映射：model 全路径 + input.prompt + ref_images + size', () {
      final body = p.buildRequestBody(_task());
      expect(body['model'], 'kling/kling-v3-omni-video-generation');
      final input = body['input'] as Map;
      expect(input['ref_images'], ['https://x/ref1.png']);
      final params = body['parameters'] as Map;
      expect(params['size'], '1280*720');
      expect(params['duration'], 5);
    });

    test('多张参考图按顺序透传', () {
      final body = p.buildRequestBody(_task(refs: [
        'a',
        'b',
        'c',
      ]));
      expect((body['input'] as Map)['ref_images'], ['a', 'b', 'c']);
    });

    test('参考图超过 4 张时裁到 4', () {
      final body = p.buildRequestBody(_task(refs: [
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
      ]));
      final refs = (body['input'] as Map)['ref_images'] as List;
      expect(refs, hasLength(kKlingV3OmniMaxRefImages));
      expect(refs, ['a', 'b', 'c', 'd']);
    });

    test('0 张参考图时不写 ref_images 键', () {
      final body = p.buildRequestBody(_task(refs: const []));
      expect((body['input'] as Map).containsKey('ref_images'), isFalse);
    });

    test('size 矩阵：1080p × 1:1', () {
      final body = p.buildRequestBody(_task(
        resolution: Resolution.p1080,
        ratio: AspectRatio.r1x1,
      ));
      expect((body['parameters'] as Map)['size'], '1080*1080');
    });

    test('negative_prompt 透传 + duration=10', () {
      final body = p.buildRequestBody(_task(
        negative: 'low detail',
        duration: 10,
      ));
      final params = body['parameters'] as Map;
      expect(params['negative_prompt'], 'low detail');
      expect(params['duration'], 10);
    });
  });

  group('KlingV3OmniProvider.parseSuccessOutput', () {
    final p = KlingV3OmniProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('解析 output.video_url', () {
      final s = p.parseSuccessOutput({'video_url': 'https://x/o.mp4'});
      expect((s as JobSuccess).remoteUrls, ['https://x/o.mp4']);
    });

    test('video_url 缺失 → success(remoteUrls=[])', () {
      final s = p.parseSuccessOutput({});
      expect((s as JobSuccess).remoteUrls, isEmpty);
    });
  });

  group('KlingV3OmniProvider fixture 回放', () {
    test('submit → task_id', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('submit_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kKlingV3OmniSubmitPath,
        (req) => req.reply(200, fx),
      );
      final id = await _build(dio).submit(_task());
      expect(id, 'kling-v3-omni-FIXTURE_JOB_ID');
    });

    test('poll → video_url', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('poll_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/kling-v3-omni-FIXTURE_JOB_ID',
        (req) => req.reply(200, fx),
      );
      final s = await _build(dio).poll('kling-v3-omni-FIXTURE_JOB_ID');
      expect((s as JobSuccess).remoteUrls.single, endsWith('.mp4'));
    });
  });
}
