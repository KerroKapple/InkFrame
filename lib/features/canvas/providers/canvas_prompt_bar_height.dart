// 底部提示词条此刻画出来的高度（逻辑像素；条子不显示 = 0），按画布分族。纯 UI 量，不落库。
//
// 条子自己量自己报上来（canvas_prompt_bar.dart），「适应全部 / 适应选中」读它算底部留白
// （canvas_tool_actions.canvasFitInsets）：条子只在恰好选中一张图像 / 视频配置时出现，高度随提示词行数变，
// 没法写成固定令牌。autoDispose：上报的那一层订阅着它，条子不在了就回收。
import 'package:flutter_riverpod/flutter_riverpod.dart';

final canvasPromptBarHeightProvider =
    AutoDisposeNotifierProviderFamily<CanvasPromptBarHeight, double, String>(
  CanvasPromptBarHeight.new,
  name: 'canvasPromptBarHeightProvider',
);

class CanvasPromptBarHeight extends AutoDisposeFamilyNotifier<double, String> {
  @override
  double build(String canvasId) => 0;

  void report(double height) {
    if (height == state) return;
    state = height;
  }
}
