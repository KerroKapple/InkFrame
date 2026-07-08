// JobMediaPersister 单元测试（LB-03）：
//   - 回归钉：batchResults 注入但 fileResolver/nodeRepo 缺失时，slot 收敛仍生效
//     （证明 null-persister 折叠地雷已拆除——旧的 per-dep 独立性恢复）。
//   - convergeSlotsAfterTerminal 取消竞态语义（error vs cancelled）。
//   - NullJobMediaPersister 全方法 no-op。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/job_statuses.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/job_media_persister.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/services/job_queue/job_media_persister.dart';

import '../../_harness/fake_batch_result.dart';

/// 最小 CancelSignal 桩：只暴露实时取消位。
class _Cancel implements CancelSignal {
  _Cancel(this.cancelled);
  @override
  bool cancelled;
}

GenerationTask _task({int batchSize = 3, String jobId = 'j1'}) => GenerationTask(
      providerId: 'fake',
      jobId: jobId,
      projectId: 'p',
      canvasId: 'c',
      resultNodeId: 'n1',
      mode: GenerationMode.textToImage,
      prompt: 'x',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
      batchSize: batchSize,
    );

void main() {
  group('JobMediaPersisterImpl slot 收敛：仅注入 batchResults（无 fileResolver/nodeRepo）', () {
    late FakeBatchResultRepo batch;
    late JobMediaPersisterImpl media;

    setUp(() {
      batch = FakeBatchResultRepo();
      // 关键组合：batchResults 注入，file/node 依赖缺失——旧折叠会把 _media 变成
      // Null 而静默停收敛（地雷）。Impl 按 per-dep 守卫，convergeSlots 仍应生效。
      media = JobMediaPersisterImpl(batchResults: batch);
    });

    test('convergeSlots 仍收敛 generating slot（地雷回归钉）', () async {
      await batch.create(
          nodeId: 'n1', jobId: 'j1', slotIndex: 0, status: 'generating');
      await batch.create(
          nodeId: 'n1', jobId: 'j1', slotIndex: 1, status: 'generating');

      await media.convergeSlots('j1',
          toStatus: SlotStatuses.cancelled,
          errorCode: InkErrorCode.cancelledByUser.wire);

      final slots = await batch.listByNode('n1');
      expect(slots.map((s) => s['status']),
          everyElement(SlotStatuses.cancelled));
      expect(slots.map((s) => s['error_code']),
          everyElement(InkErrorCode.cancelledByUser.wire));
    });

    test('convergeSlotsAfterTerminal 非取消语境（rows==0 但未取消）→ slot 收敛 error',
        () async {
      await batch.create(
          nodeId: 'n1', jobId: 'j1', slotIndex: 0, status: 'generating');

      await media.convergeSlotsAfterTerminal(
          _task(), 0, _Cancel(false), const ProviderError(code: InkErrorCode.providerServer));

      final slot = (await batch.listByNode('n1')).single;
      expect(slot['status'], SlotStatuses.error);
      expect(slot['error_code'], InkErrorCode.providerServer.wire);
    });

    test('convergeSlotsAfterTerminal 取消竞态赢（cancelled + rows==0）→ slot 收敛 cancelled',
        () async {
      await batch.create(
          nodeId: 'n1', jobId: 'j1', slotIndex: 0, status: 'generating');

      await media.convergeSlotsAfterTerminal(
          _task(), 0, _Cancel(true), const ProviderError(code: InkErrorCode.providerServer));

      final slot = (await batch.listByNode('n1')).single;
      expect(slot['status'], SlotStatuses.cancelled);
      expect(slot['error_code'], InkErrorCode.cancelledByUser.wire);
    });

    test('convergeSlotsAfterTerminal batchSize<=1 → 不触碰 slot 表', () async {
      await batch.create(
          nodeId: 'n1', jobId: 'j1', slotIndex: 0, status: 'generating');

      await media.convergeSlotsAfterTerminal(_task(batchSize: 1), 0,
          _Cancel(true), const ProviderError(code: InkErrorCode.providerServer));

      final slot = (await batch.listByNode('n1')).single;
      expect(slot['status'], 'generating'); // 未被收敛
    });
  });

  group('NullJobMediaPersister 全方法 no-op', () {
    const media = NullJobMediaPersister();

    test('persistInlineBytes → null', () async {
      expect(
        await media.persistInlineBytes(_task(), <List<int>>[
          [1, 2, 3]
        ], _Cancel(false)),
        isNull,
      );
    });

    test('persistRemoteUrls → null', () async {
      expect(
        await media.persistRemoteUrls(
            _task(), <String>['https://x/a.png'], _Cancel(false)),
        isNull,
      );
    });

    test('convergeSlots → 正常完成、不抛', () async {
      await expectLater(
        media.convergeSlots('j1', toStatus: SlotStatuses.cancelled),
        completes,
      );
    });

    test('convergeSlotsAfterTerminal → 正常完成、不抛', () async {
      await expectLater(
        media.convergeSlotsAfterTerminal(_task(), 0, _Cancel(true),
            const ProviderError(code: InkErrorCode.providerServer)),
        completes,
      );
    });
  });
}
