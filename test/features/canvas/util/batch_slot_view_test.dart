// batch_slot_view 纯函数：四态判定 + 图区比例。
// 两条收口是本次接线的实质决策，各自钉一例：cancelled 并入 error、
// 「success 但没有 output_url」也并入 error（没有产物就无从转正）。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/batch_result.dart';
import 'package:inkframe/features/canvas/util/batch_slot_view.dart';

BatchResult _slot({
  String status = 'success',
  String? outputUrl = 'images/a.png',
  bool promoted = false,
  int? width,
  int? height,
}) => BatchResult(
  id: 'b1',
  nodeId: 'n1',
  jobId: 'j1',
  slotIndex: 0,
  status: status,
  outputUrl: outputUrl,
  promoted: promoted,
  width: width,
  height: height,
);

void main() {
  group('batchSlotViewOf', () {
    test('success + 有产物 → success', () {
      expect(batchSlotViewOf(_slot()), BatchSlotView.success);
    });

    test('success + promoted → promoted', () {
      expect(
        batchSlotViewOf(_slot(promoted: true)),
        BatchSlotView.promoted,
      );
    });

    test('generating → generating', () {
      expect(
        batchSlotViewOf(_slot(status: 'generating', outputUrl: null)),
        BatchSlotView.generating,
      );
    });

    test('error → error', () {
      expect(
        batchSlotViewOf(_slot(status: 'error', outputUrl: null)),
        BatchSlotView.error,
      );
    });

    test('cancelled 并入 error（不画成生成中，不给取消已取消任务的死按钮）', () {
      expect(
        batchSlotViewOf(_slot(status: 'cancelled', outputUrl: null)),
        BatchSlotView.error,
      );
    });

    test('success 但 output_url 为空 → error（没产物就不该给「转正」）', () {
      expect(batchSlotViewOf(_slot(outputUrl: null)), BatchSlotView.error);
      expect(batchSlotViewOf(_slot(outputUrl: '')), BatchSlotView.error);
    });

    test('promoted 标记但产物为空 → 仍是 error，不显示「当前」', () {
      expect(
        batchSlotViewOf(_slot(outputUrl: null, promoted: true)),
        BatchSlotView.error,
      );
    });
  });

  group('batchSlotAspectRatio', () {
    test('有真实宽高 → 用真实比例', () {
      expect(batchSlotAspectRatio(_slot(width: 1024, height: 576)), 1024 / 576);
      expect(batchSlotAspectRatio(_slot(width: 1024, height: 1024)), 1.0);
      expect(batchSlotAspectRatio(_slot(width: 768, height: 1024)), 0.75);
    });

    test('缺任一维 / 非正值 → 回落 16:9', () {
      expect(batchSlotAspectRatio(_slot(width: 1024)), 16 / 9);
      expect(batchSlotAspectRatio(_slot(height: 576)), 16 / 9);
      expect(batchSlotAspectRatio(_slot()), 16 / 9);
      expect(batchSlotAspectRatio(_slot(width: 0, height: 0)), 16 / 9);
    });
  });

  group('batchSlotCanPromote', () {
    test('只有「成功且有产物且尚未转正」的格可转正', () {
      expect(batchSlotCanPromote(_slot()), isTrue);
      expect(batchSlotCanPromote(_slot(promoted: true)), isFalse);
      expect(batchSlotCanPromote(_slot(status: 'error')), isFalse);
      expect(batchSlotCanPromote(_slot(outputUrl: null)), isFalse);
    });
  });
}
