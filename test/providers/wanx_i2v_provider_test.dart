// WanxI2VProvider 单测：聚焦子类三个 override + fixture 回放。
// 公共行为（auth / 状态机 / 错误码）由基类测试覆盖。

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
import 'package:inkframe/providers/wanx_i2v_provider.dart';

import '../_harness/fixtures.dart';

GenerationTask _task({
  String? firstFrame = 'https://x/first.png',
  String? lastFrame,
  String? negative,
  int? seed,
  int duration = 5,
  Resolution resolution = Resolution.p720,
  AspectRatio ratio = AspectRatio.r16x9,
}) =>
    GenerationTask(
      providerId: 'wanx-i2v',
      jobId: 'job-x',
      mode: GenerationMode.imageToVideo,
      prompt: 'slow zoom-in with gentle camera shake',
      negativePrompt: negative,
      resolution: resolution,
      aspectRatio: ratio,
      durationSeconds: duration,
      firstFramePath: firstFrame,
      lastFramePath: lastFrame,
      seed: seed,
    );

WanxI2VProvider _build(Dio dio, {String key = 'sk-test'}) => WanxI2VProvider(
      keySource: () async => key,
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
      dio: dio,
    );

Future<Map<String, Object?>> _loadFixture(String name) async =>
    loadProviderFixture('wanx-i2v', name.replaceFirst(RegExp(r'\.json$'), ''));

void main() {
  group('WanxI2VProvider.capabilities', () {
    test('关键字段：I2V 模式 + 首末帧支持 + 计费模型', () {
      const c = kWanxI2VCapabilities;
      expect(c.providerId, 'wanx-i2v');
      expect(c.modes, [GenerationMode.imageToVideo]);
      expect(c.supportsFirstFrame, isTrue);
      expect(c.supportsLastFrame, isTrue);
      expect(c.maxRefImages, 0);
      expect(c.costModel, isA<PerSecondVideo>());
    });
  });

  group('WanxI2VProvider.buildRequestBody', () {
    final p = WanxI2VProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('基础映射：model + input.prompt + media[first_frame] + size + duration', () {
      final body = p.buildRequestBody(_task());
      expect(body['model'], kWanxI2VModel);
      final input = body['input'] as Map;
      expect(input['prompt'], isNotEmpty);
      final media = input['media'] as List;
      expect(media, hasLength(1));
      expect(media.single, {'type': 'first_frame', 'url': 'https://x/first.png'});
      final params = body['parameters'] as Map;
      expect(params['size'], '1280*720');
      expect(params['duration'], 5);
    });

    test('末帧图透传为 media[last_frame] 项', () {
      final body = p.buildRequestBody(_task(lastFrame: 'https://x/last.png'));
      final media = (body['input'] as Map)['media'] as List;
      expect(media, hasLength(2));
      expect(media[1], {'type': 'last_frame', 'url': 'https://x/last.png'});
    });

    test('缺首末帧图时 body 不包含 media 键（交由服务端校验）', () {
      final body = p.buildRequestBody(_task(firstFrame: null));
      expect((body['input'] as Map).containsKey('media'), isFalse);
    });

    test('size 矩阵：1080p × 9:16', () {
      final body = p.buildRequestBody(_task(
        resolution: Resolution.p1080,
        ratio: AspectRatio.r9x16,
      ));
      expect((body['parameters'] as Map)['size'], '1080*1920');
    });

    test('可选参数透传：negative_prompt + seed', () {
      final body = p.buildRequestBody(_task(negative: 'shaky', seed: 7));
      final params = body['parameters'] as Map;
      expect(params['negative_prompt'], 'shaky');
      expect(params['seed'], 7);
    });

    test('durationSeconds=0 → 默认 5s', () {
      final body = p.buildRequestBody(_task(duration: 0));
      expect((body['parameters'] as Map)['duration'], 5);
    });
  });

  group('WanxI2VProvider.parseSuccessOutput', () {
    final p = WanxI2VProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('解析 output.video_url', () {
      final s = p.parseSuccessOutput({'video_url': 'https://x/v.mp4'});
      expect((s as JobSuccess).remoteUrls, ['https://x/v.mp4']);
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

  group('WanxI2VProvider fixture 回放', () {
    test('submit → task_id', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('submit_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kWanxI2VSubmitPath,
        (req) => req.reply(200, fx),
      );
      final id = await _build(dio).submit(_task());
      expect(id, 'wanx-i2v-FIXTURE_JOB_ID');
    });

    test('poll → video_url', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('poll_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/wanx-i2v-FIXTURE_JOB_ID',
        (req) => req.reply(200, fx),
      );
      final s = await _build(dio).poll('wanx-i2v-FIXTURE_JOB_ID');
      expect((s as JobSuccess).remoteUrls.single, endsWith('.mp4'));
    });
  });
}
