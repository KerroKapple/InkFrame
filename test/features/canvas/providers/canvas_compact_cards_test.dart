// 缩小态开关（提示词条与节点文字稿）：画布缩放跨过 0.6 才翻转，同侧缩放一律不通知——
// 卡片 watch 它而不是 watch 变换控制器，缩放的每一帧才不会把整画布的卡片拖进重建。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_compact_cards.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';

Matrix4 _scaled(double s) => Matrix4.identity()..scaleByDouble(s, s, 1.0, 1.0);

void main() {
  test('阈值：严格低于 0.6 才算缩小态', () {
    expect(isCompactCardScale(1.0), isFalse);
    expect(isCompactCardScale(kCompactCardScale), isFalse);
    expect(isCompactCardScale(0.59), isTrue);
    expect(isCompactCardScale(0.1), isTrue);
  });

  test('缩放跨过 0.6 才通知；同侧缩放不通知', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    final List<bool> seen = <bool>[];
    c.listen<bool>(
      canvasCompactCardsProvider('cv1'),
      (bool? previous, bool next) => seen.add(next),
      fireImmediately: true,
    );
    final TransformationController transform =
        c.read(canvasTransformControllerProvider('cv1'));

    expect(seen, <bool>[false], reason: '初始相机 scale = 1');

    transform.value = _scaled(0.9);
    transform.value = _scaled(0.7);
    expect(seen, <bool>[false], reason: '还在阈值上方，不通知');

    transform.value = _scaled(0.5);
    expect(seen, <bool>[false, true]);

    transform.value = _scaled(0.3);
    transform.value = _scaled(0.2);
    expect(seen, <bool>[false, true], reason: '已在阈值下方，继续缩小不通知');

    transform.value = _scaled(1.2);
    expect(seen, <bool>[false, true, false]);
  });

  test('读的是当前相机：已经缩小时新建的条目直接是缩小态', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    // 先把变换控制器的条目挂住，再缩小、再读开关。
    c.listen<TransformationController>(
      canvasTransformControllerProvider('cv1'),
      (TransformationController? previous, TransformationController next) {},
    );
    c.read(canvasTransformControllerProvider('cv1')).value = _scaled(0.4);

    expect(c.read(canvasCompactCardsProvider('cv1')), isTrue);
  });

  test('按 canvasId 分族：一个画布缩小不影响另一个', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen<bool>(canvasCompactCardsProvider('a'), (bool? previous, bool next) {});
    c.listen<bool>(canvasCompactCardsProvider('b'), (bool? previous, bool next) {});

    c.read(canvasTransformControllerProvider('a')).value = _scaled(0.4);

    expect(c.read(canvasCompactCardsProvider('a')), isTrue);
    expect(c.read(canvasCompactCardsProvider('b')), isFalse);
  });
}
