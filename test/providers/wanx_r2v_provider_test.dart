// WanxR2VProvider 单测：聚焦子类三个 override + fixture 回放。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/dashscope_async_provider_base.dart';
import 'package:inkframe/providers/rate_limiter.dart';
import 'package:inkframe/providers/wanx_r2v_provider.dart';

import '../_harness/fixtures.dart';

GenerationTask _task({
  List<String> refs = const ['https://x/ref1.png'],
  String? negative,
  int? seed,
  int duration = 5,
  Resolution resolution = Resolution.p720,
  AspectRatio ratio = AspectRatio.r16x9,
}) =>
    GenerationTask(
      providerId: 'wanx-r2v',
      jobId: 'job-x',
      mode: GenerationMode.textToVideo,
      prompt: 'the character walks through a misty forest',
      negativePrompt: negative,
      resolution: resolution,
      aspectRatio: ratio,
      durationSeconds: duration,
      refImagePaths: refs,
      seed: seed,
    );

WanxR2VProvider _build(Dio dio, {String key = 'sk-test'}) => WanxR2VProvider(
      keySource: () async => key,
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
      dio: dio,
    );

Future<Map<String, Object?>> _loadFixture(String name) async =>
    loadProviderFixture('wanx-r2v', name.replaceFirst(RegExp(r'\.json$'), ''));

void main() {
  group('WanxR2VProvider.capabilities', () {
    test('关键字段：T2V 模式 + maxRefImages=3 + 无首末帧', () {
      const c = kWanxR2VCapabilities;
      expect(c.providerId, 'wanx-r2v');
      expect(c.modes, [GenerationMode.textToVideo]);
      expect(c.maxRefImages, kWanxR2VMaxRefImages);
      expect(c.supportsFirstFrame, isFalse);
      expect(c.supportsLastFrame, isFalse);
      expect(c.costModel, isA<PerSecondVideo>());
    });
  });

  group('WanxR2VProvider.buildRequestBody', () {
    final p = WanxR2VProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('基础映射：model + input.prompt + ref_images + size + duration', () {
      final body = p.buildRequestBody(_task());
      expect(body['model'], kWanxR2VModel);
      final input = body['input'] as Map;
      expect(input['prompt'], isNotEmpty);
      expect(input['ref_images'], ['https://x/ref1.png']);
      final params = body['parameters'] as Map;
      expect(params['size'], '1280*720');
      expect(params['duration'], 5);
    });

    test('多张参考图按顺序透传', () {
      final body = p.buildRequestBody(_task(refs: [
        'https://x/1.png',
        'https://x/2.png',
        'https://x/3.png',
      ]));
      expect(
        (body['input'] as Map)['ref_images'],
        ['https://x/1.png', 'https://x/2.png', 'https://x/3.png'],
      );
    });

    test('参考图超过 3 张时裁到 3', () {
      final body = p.buildRequestBody(_task(refs: [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]));
      final refs = (body['input'] as Map)['ref_images'] as List;
      expect(refs, hasLength(kWanxR2VMaxRefImages));
      expect(refs, ['a', 'b', 'c']);
    });

    test('0 张参考图时 body 不写 ref_images 键', () {
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

    test('可选参数透传：negative_prompt + seed + duration=10', () {
      final body = p.buildRequestBody(_task(
        negative: 'blurry',
        seed: 123,
        duration: 10,
      ));
      final params = body['parameters'] as Map;
      expect(params['negative_prompt'], 'blurry');
      expect(params['seed'], 123);
      expect(params['duration'], 10);
    });
  });

  group('WanxR2VProvider.parseSuccessOutput', () {
    final p = WanxR2VProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('解析 output.video_url', () {
      final s = p.parseSuccessOutput({'video_url': 'https://x/r.mp4'});
      expect((s as JobSuccess).remoteUrls, ['https://x/r.mp4']);
    });

    // HI-04：SUCCEEDED 但缺产物 URL 不许标 success——抛 ProviderError。
    test('video_url 缺失 → ProviderError(empty_output_url)', () {
      expect(
        () => p.parseSuccessOutput({}),
        throwsA(isA<ProviderError>().having(
          (e) => e.extra['reason'],
          'reason',
          'empty_output_url',
        )),
      );
    });
  });

  group('WanxR2VProvider fixture 回放', () {
    test('submit → task_id', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('submit_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kWanxR2VSubmitPath,
        (req) => req.reply(200, fx),
      );
      final id = await _build(dio).submit(_task());
      expect(id, 'wanx-r2v-FIXTURE_JOB_ID');
    });

    test('poll → video_url', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('poll_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/wanx-r2v-FIXTURE_JOB_ID',
        (req) => req.reply(200, fx),
      );
      final s = await _build(dio).poll('wanx-r2v-FIXTURE_JOB_ID');
      expect((s as JobSuccess).remoteUrls.single, endsWith('.mp4'));
    });
  });
}
