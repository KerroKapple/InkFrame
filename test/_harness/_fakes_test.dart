// FakeDio + FakeProviders 自身契约测试。
//
// 命名规则同 _harness_test.dart：_ 前缀文件以 `_test.dart` 结尾仍被 runner 识别。

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';

import 'fake_dio.dart';
import 'fake_providers.dart';

GenerationTask _task() => const GenerationTask(
      providerId: 'fake-image',
      jobId: 'job-1',
      mode: GenerationMode.textToImage,
      prompt: 'an ink wash painting',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

void main() {
  group('FakeDio.fromFixture', () {
    test('200 + fixture body 可被 dio 调到', () async {
      final Dio dio = FakeDio.fromFixture(
        'gemini-image',
        'submit_success',
        baseUrl: 'https://example.com',
        path: '/api/submit',
      );
      final Response<Object?> resp =
          await dio.post<Object?>('/api/submit', data: <String, Object?>{});
      expect(resp.statusCode, 200);
      expect(resp.data, isA<Map<String, Object?>>());
    });
  });

  group('FakeDio.respondWith', () {
    test('自定义 status + body', () async {
      final Dio dio = FakeDio.respondWith(
        418,
        <String, Object?>{'msg': 'teapot'},
        baseUrl: 'https://example.com',
        path: '/teapot',
        method: HttpMethod.get,
      );
      try {
        await dio.get<Object?>('/teapot');
        fail('expected DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 418);
        expect(e.response?.data, <String, Object?>{'msg': 'teapot'});
      }
    });
  });

  group('FakeSubmittable', () {
    test('默认 submit 返回 local://fake-job-<count> 且累加 callCount', () async {
      final FakeSubmittable s = FakeSubmittable();
      final JobId a = await s.submit(_task());
      final JobId b = await s.submit(_task());
      expect(a, 'local://fake-job-1');
      expect(b, 'local://fake-job-2');
      expect(s.submitCallCount, 2);
      expect(s.submittedTasks, hasLength(2));
    });

    test('onSubmit 覆盖默认行为', () async {
      final FakeSubmittable s = FakeSubmittable(
        onSubmit: (task) async => 'custom-${task.prompt}',
      );
      expect(await s.submit(_task()), 'custom-an ink wash painting');
    });

    test('capabilities 是 fakeImageCapabilities() 默认值', () {
      final FakeSubmittable s = FakeSubmittable();
      expect(s.capabilities.providerId, 'fake-image');
      expect(s.capabilities.region, ProviderRegion.global);
    });
  });

  group('FakePollable', () {
    test('按 statuses 顺序消费', () async {
      final FakePollable p = FakePollable(statuses: const <JobStatus>[
        JobStatus.inProgress(progress: 0.1),
        JobStatus.inProgress(progress: 0.9),
        JobStatus.success(remoteUrls: <String>['x']),
      ]);
      expect((await p.poll('id')).runtimeType.toString(), 'JobInProgress');
      await p.poll('id');
      expect((await p.poll('id')).runtimeType.toString(), 'JobSuccess');
      expect(p.pollCallCount, 3);
      expect(p.polledIds, <String>['id', 'id', 'id']);
    });

    test('超长 poll 一直返回最后一个 status', () async {
      final FakePollable p = FakePollable(statuses: const <JobStatus>[
        JobStatus.success(remoteUrls: <String>['x']),
      ]);
      final JobStatus a = await p.poll('id');
      final JobStatus b = await p.poll('id');
      expect(a.runtimeType.toString(), 'JobSuccess');
      expect(b.runtimeType.toString(), 'JobSuccess');
    });
  });

  group('FakeKeyValidatable', () {
    test('默认 valid', () async {
      final FakeKeyValidatable v = FakeKeyValidatable();
      final KeyValidationResult r = await v.validateApiKey('any');
      expect(r, isA<KeyValid>());
      expect(v.validatedKeys, <String>['any']);
    });

    test('onValidate 覆盖', () async {
      final FakeKeyValidatable v = FakeKeyValidatable(
        onValidate: (k) async => const KeyValidationResult.invalid(
          reason: KeyInvalidReason.invalidKey,
        ),
      );
      final KeyValidationResult r = await v.validateApiKey('bad');
      expect(r, isA<KeyInvalid>());
    });
  });

  group('FakeProvider', () {
    test('三接口实现可被 LSP 识别', () {
      final FakeProvider fp = FakeProvider();
      expect(fp, isA<Submittable>());
      expect(fp, isA<Pollable>());
      expect(fp, isA<KeyValidatable>());
    });
  });
}
