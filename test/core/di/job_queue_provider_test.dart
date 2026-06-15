import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/secure_storage.dart';
import 'package:inkframe/core/di/thumbnail.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/secure_storage_service.dart';
import 'package:inkframe/services/job_queue_service.dart';

import '../../helpers/recording_logger.dart';

class _NoopSecure implements SecureStorageService {
  @override
  Future<void> store(String k, String v) async {}
  @override
  Future<String?> retrieve(String k) async => null;
  @override
  Future<void> delete(String k) async {}
  @override
  Future<bool> exists(String k) async => false;
}

/// 只实现 init() 用到的方法，其余成员走 noSuchMethod 抛错（测试不应触达）。
class _FakeJobRepo implements JobRepository {
  _FakeJobRepo(this.orphans);
  final List<Map<String, Object?>> orphans;
  final List<String> transitioned = <String>[];

  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> statuses) async =>
      orphans;

  @override
  Future<int> transitionStatus({
    required String id,
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    transitioned.add('$id->$toStatus');
    return 1;
  }

  // init() 的 housekeeping 路径（ME-32）也会触达——no-op 即可。
  @override
  Future<int> purgeExpired({required Duration retention}) async => 0;

  @override
  Future<int> purgePerCanvasCap({required int cap}) async => 0;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeNodeRepo implements NodeRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeResolver implements FileResolverService {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  test('jobQueueServiceProvider 注入 repo 且解析时跑 init() 清理孤儿', () async {
    final fakeRepo = _FakeJobRepo(<Map<String, Object?>>[
      <String, Object?>{'id': 'orphan-1'},
    ]);
    final container = ProviderContainer(
      overrides: <Override>[
        secureStorageServiceProvider.overrideWithValue(_NoopSecure()),
        jobRepositoryProvider.overrideWith((ref) async => fakeRepo),
        nodeRepositoryProvider.overrideWith((ref) async => _FakeNodeRepo()),
        fileResolverServiceProvider.overrideWithValue(_FakeResolver()),
        thumbnailServiceProvider.overrideWithValue(null),
        loggerProvider.overrideWithValue(RecordingLogger()),
      ],
    );
    addTearDown(container.dispose);

    final service = await container.read(jobQueueServiceProvider.future);
    expect(service, isA<InMemoryJobQueueService>());
    // init() 应把 submitted/polling 孤儿转 cancelled —— 证明 repo 已被真正注入。
    expect(fakeRepo.transitioned, contains('orphan-1->cancelled'));
  });
}
