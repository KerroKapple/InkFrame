// 画布工具态（canvas_tool_mode.dart）：选择 / 平移 + 空格临时平移，实际平移 = 二者取或。
//
// 「分开记」是这份 provider 存在的理由：松开空格要回到按下前的那个工具，而不是一律打回选择。
// 若把空格并进工具态（按下切平移、松开切选择），「平移工具中按住再松开空格」会把用户
// 踢回选择——第三条用例当场红。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';

/// 建容器并订阅 c1 的实际平移（连带把工具态与空格两个 autoDispose 源保活）。
(ProviderContainer, ProviderSubscription<bool>) _setUp() {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);
  final ProviderSubscription<bool> panning =
      container.listen(canvasPanActiveProvider('c1'), (_, _) {});
  addTearDown(panning.close);
  return (container, panning);
}

void main() {
  test('默认：选择工具、空格未按、不在平移', () {
    final (ProviderContainer container, ProviderSubscription<bool> panning) =
        _setUp();

    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);
    expect(container.read(canvasSpacePanProvider('c1')), isFalse);
    expect(panning.read(), isFalse);
  });

  test('togglePan 来回切；pan() / select() 直达且重复调用不变', () {
    final (ProviderContainer container, ProviderSubscription<bool> panning) =
        _setUp();
    final CanvasToolModeController tool =
        container.read(canvasToolModeProvider('c1').notifier);

    tool.togglePan();
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.pan);
    expect(panning.read(), isTrue);
    tool.togglePan();
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);

    tool
      ..pan()
      ..pan();
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.pan);
    tool
      ..select()
      ..select();
    expect(container.read(canvasToolModeProvider('c1')), CanvasToolMode.select);
    expect(panning.read(), isFalse);
  });

  test('空格按住 = 实际平移；松开回到按下前的工具（平移工具中松开空格仍在平移）', () {
    final (ProviderContainer container, ProviderSubscription<bool> panning) =
        _setUp();
    final CanvasSpacePanController space =
        container.read(canvasSpacePanProvider('c1').notifier);

    space
      ..hold()
      ..hold(); // 按住时的自动重复
    expect(panning.read(), isTrue);
    expect(
      container.read(canvasToolModeProvider('c1')),
      CanvasToolMode.select,
      reason: '空格不改工具态',
    );
    space.release();
    expect(panning.read(), isFalse);

    container.read(canvasToolModeProvider('c1').notifier).pan();
    space
      ..hold()
      ..release();
    expect(panning.read(), isTrue, reason: '本来就在平移工具：松开空格不该被踢回选择');
  });

  test('按画布分族：c1 的平移不串到 c2', () {
    final (ProviderContainer container, _) = _setUp();
    final ProviderSubscription<bool> c2 =
        container.listen(canvasPanActiveProvider('c2'), (_, _) {});
    addTearDown(c2.close);

    container.read(canvasToolModeProvider('c1').notifier).pan();
    container.read(canvasSpacePanProvider('c1').notifier).hold();

    expect(c2.read(), isFalse);
    expect(container.read(canvasToolModeProvider('c2')), CanvasToolMode.select);
  });
}
