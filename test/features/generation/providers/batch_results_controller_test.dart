import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/generation/providers/batch_results_controller.dart';

import '../../../_harness/fake_batch_result.dart';

void main() {
  late FakeBatchResultRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeBatchResultRepo();
    container = ProviderContainer(
      overrides: <Override>[
        batchResultRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<BatchResultsController> boot(String nodeId) async {
    final sub = container.listen(
      batchResultsControllerProvider(nodeId),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(batchResultsControllerProvider(nodeId).future);
    return container.read(batchResultsControllerProvider(nodeId).notifier);
  }

  test('build 列出 slot（slot_index 升序，按 node 过滤）', () async {
    await repo.create(
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 1,
      status: 'success',
    );
    await repo.create(
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 0,
      status: 'success',
    );
    await repo.create(
      nodeId: 'other',
      jobId: 'j2',
      slotIndex: 0,
      status: 'generating',
    );
    await boot('n1');
    final list = container
        .read(batchResultsControllerProvider('n1'))
        .valueOrNull!;
    expect(list, hasLength(2));
    expect(list.first.slotIndex, 0);
    expect(list.every((s) => s.nodeId == 'n1'), isTrue);
  });

  test('refresh 反映新 slot', () async {
    final notifier = await boot('n1');
    await repo.create(
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 0,
      status: 'success',
    );
    await notifier.refresh();
    final list = container
        .read(batchResultsControllerProvider('n1'))
        .valueOrNull!;
    expect(list, hasLength(1));
    expect(list.single.isSuccess, isTrue);
  });
}
