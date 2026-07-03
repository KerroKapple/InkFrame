// WanxImageProvider 单测：聚焦子类三个 override（capabilities / buildRequestBody /
// parseSuccessOutput）+ 一条 fixture 回放贯通 submit→poll。
//
// 公共行为（auth header / 状态机 6 分支 / 错误码映射 / validateApiKey）已在
// dashscope_async_provider_base_test.dart 覆盖，本文件不重复。

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
import 'package:inkframe/providers/wanx_image_provider.dart';

import '../_harness/fixtures.dart';

GenerationTask _t2iTask({
  AspectRatio ratio = AspectRatio.r16x9,
  int batch = 1,
  String? negative,
  int? seed,
  List<String> refs = const [],
}) =>
    GenerationTask(
      providerId: 'wanx-image',
      jobId: 'job-x',
      mode: refs.isEmpty
          ? GenerationMode.textToImage
          : GenerationMode.imageToImage,
      prompt: 'a calm lake at dawn',
      negativePrompt: negative,
      resolution: Resolution.p1080,
      aspectRatio: ratio,
      seed: seed,
      batchSize: batch,
      refImagePaths: refs,
    );

WanxImageProvider _build(Dio dio, {String key = 'sk-test'}) =>
    WanxImageProvider(
      keySource: () async => key,
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
      dio: dio,
    );

Future<Map<String, Object?>> _loadFixture(String name) async =>
    loadProviderFixture(
        'wanx-image', name.replaceFirst(RegExp(r'\.json$'), ''));

void main() {
  group('WanxImageProvider.capabilities', () {
    test('编译期常量字段齐全', () {
      const c = kWanxImageCapabilities;
      expect(c.providerId, 'wanx-image');
      expect(c.region, ProviderRegion.cn);
      expect(c.modes,
          containsAll([GenerationMode.textToImage, GenerationMode.imageToImage]));
      expect(c.supportedRatios, contains(AspectRatio.r16x9));
      expect(c.supportsNegativePrompt, isTrue);
      expect(c.supportsSeed, isTrue);
      expect(c.supportsBatch, isTrue);
      expect(c.supportsCancellation, isFalse);
      expect(c.supportsPolling, isTrue);
      expect(c.maxRefImages, 1);
      expect(c.costModel, isA<PerCall>());
    });
  });

  group('WanxImageProvider.buildRequestBody', () {
    final p = WanxImageProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('T2I 基础映射：model + size + n + 单个 text content', () {
      final body = p.buildRequestBody(_t2iTask());
      expect(body['model'], kWanxImageModel);
      final input = body['input'] as Map;
      final messages = input['messages'] as List;
      expect(messages, hasLength(1));
      final firstMsg = messages.first as Map;
      expect(firstMsg['role'], 'user');
      final content = firstMsg['content'] as List;
      expect(content, hasLength(1));
      expect((content.first as Map)['text'], 'a calm lake at dawn');
      final params = body['parameters'] as Map;
      expect(params['size'], '1280*720');
      expect(params['n'], 1);
      expect(params.containsKey('negative_prompt'), isFalse);
      expect(params.containsKey('seed'), isFalse);
    });

    test('AspectRatio → size 映射全覆盖', () {
      const cases = {
        AspectRatio.r1x1: '1024*1024',
        AspectRatio.r16x9: '1280*720',
        AspectRatio.r9x16: '720*1280',
        AspectRatio.r4x3: '1024*768',
        AspectRatio.r3x4: '768*1024',
      };
      cases.forEach((ratio, expectedSize) {
        final body = p.buildRequestBody(_t2iTask(ratio: ratio));
        expect((body['parameters'] as Map)['size'], expectedSize,
            reason: '$ratio → $expectedSize');
      });
    });

    test('I2I：refImagePaths 追加到 content 末尾', () {
      final body = p.buildRequestBody(_t2iTask(refs: ['/abs/ref.png']));
      final content = ((body['input'] as Map)['messages'] as List).first
          as Map;
      final parts = content['content'] as List;
      expect(parts, hasLength(2));
      expect((parts[0] as Map)['text'], isNotNull);
      expect((parts[1] as Map)['image'], '/abs/ref.png');
    });

    // 控制器合并边连参考图 + 角色图后不截断（截断责任约定在 provider——
    // generation_controller._injectCharacterRefs 注释明确），此处必须收口。
    test('refImagePaths 超出 maxRefImages(1) → 按能力截断只取首张', () {
      final body = p.buildRequestBody(
        _t2iTask(refs: ['/a.png', '/b.png', '/c.png']),
      );
      final content = ((body['input'] as Map)['messages'] as List).first
          as Map;
      final parts = content['content'] as List;
      expect(parts, hasLength(2)); // text + 1 image
      expect((parts[1] as Map)['image'], '/a.png');
    });

    test('可选参数透传：negative_prompt + seed + batchSize', () {
      final body = p.buildRequestBody(_t2iTask(
        batch: 4,
        negative: 'low quality, blurry',
        seed: 42,
      ));
      final params = body['parameters'] as Map;
      expect(params['n'], 4);
      expect(params['negative_prompt'], 'low quality, blurry');
      expect(params['seed'], 42);
    });

    test('空字符串 negative_prompt 不写入 body', () {
      final body = p.buildRequestBody(_t2iTask(negative: ''));
      expect((body['parameters'] as Map).containsKey('negative_prompt'), isFalse);
    });
  });

  group('WanxImageProvider.parseSuccessOutput', () {
    final p = WanxImageProvider(
      keySource: () async => 'sk-test',
      rateLimiter: ProviderRateLimiter(qps: 20, burst: 50),
    );

    test('解析 choices[0].message.content[].image 多张', () {
      final s = p.parseSuccessOutput({
        'task_status': 'SUCCEEDED',
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': [
                {'image': 'https://x/1.png'},
                {'image': 'https://x/2.png'},
              ],
            }
          }
        ],
      });
      expect(s, isA<JobSuccess>());
      expect((s as JobSuccess).remoteUrls, ['https://x/1.png', 'https://x/2.png']);
    });

    // HI-04：SUCCEEDED 但解析不出任何图片 URL 不许标 success——抛 ProviderError。
    test('choices 缺失 → ProviderError(empty_output_url)', () {
      expect(
        () => p.parseSuccessOutput({'task_status': 'SUCCEEDED'}),
        throwsA(isA<ProviderError>().having(
          (e) => e.extra['reason'],
          'reason',
          'empty_output_url',
        )),
      );
    });

    test('content 中混有非 image 字段时跳过', () {
      final s = p.parseSuccessOutput({
        'choices': [
          {
            'message': {
              'content': [
                {'text': 'irrelevant'},
                {'image': ''},
                {'image': 'https://x/ok.png'},
              ],
            }
          }
        ],
      });
      expect((s as JobSuccess).remoteUrls, ['https://x/ok.png']);
    });
  });

  group('WanxImageProvider fixture 回放', () {
    test('submit fixture → 拿到 task_id', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('submit_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onPost(
        kWanxImageSubmitPath,
        (req) => req.reply(200, fx),
      );
      final id = await _build(dio).submit(_t2iTask());
      expect(id, 'wanx-task-FIXTURE_JOB_ID');
    });

    test('poll fixture → 解析两张图 URL', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('poll_success.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/wanx-task-FIXTURE_JOB_ID',
        (req) => req.reply(200, fx),
      );
      final s = await _build(dio).poll('wanx-task-FIXTURE_JOB_ID');
      expect(s, isA<JobSuccess>());
      final urls = (s as JobSuccess).remoteUrls;
      expect(urls, hasLength(2));
      expect(urls.first, startsWith('https://dashscope-result-bj.oss'));
    });

    test('poll fixture FAILED+DataInspectionFailed → contentPolicy', () async {
      final dio = Dio(BaseOptions(baseUrl: kDashScopeBaseUrl));
      final fx = await _loadFixture('poll_failed_content_policy.json');
      DioAdapter(dio: dio, matcher: const UrlRequestMatcher()).onGet(
        '/tasks/wanx-task-FIXTURE_JOB_ID',
        (req) => req.reply(200, fx),
      );
      final s = await _build(dio).poll('wanx-task-FIXTURE_JOB_ID');
      expect(s, isA<JobFailure>());
    });
  });
}
