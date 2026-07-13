// CanvasStyleController：画布连线 / 卡片自定义颜色（null = 跟随主题默认）。
//
// 与 ThemeModeController 同模式：启动从持久化偏好 seed，setter 改内存态并
// fire-and-forget 落盘。颜色以 ARGB int 持久化，状态层暴露 Color?。
import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences.dart';

class CanvasStyleState {
  const CanvasStyleState({this.edgeColor, this.cardColor});

  /// 连线（data 边主色）自定义色；null = 主题 accent。
  final Color? edgeColor;

  /// 卡片背景自定义色；null = 主题 surface2。
  final Color? cardColor;
}

class CanvasStyleController extends Notifier<CanvasStyleState> {
  @override
  CanvasStyleState build() {
    final prefs = ref.read(preferencesServiceProvider).current;
    return CanvasStyleState(
      edgeColor: _fromArgb(prefs.canvasEdgeColor),
      cardColor: _fromArgb(prefs.canvasCardColor),
    );
  }

  static Color? _fromArgb(int? v) => v == null ? null : Color(v);

  void setEdgeColor(Color? color) {
    state = CanvasStyleState(edgeColor: color, cardColor: state.cardColor);
    unawaited(
      ref.read(preferencesServiceProvider).update(
            (p) => p.copyWith(
              canvasEdgeColor: color?.toARGB32(),
              clearCanvasEdgeColor: color == null,
            ),
          ),
    );
  }

  void setCardColor(Color? color) {
    state = CanvasStyleState(edgeColor: state.edgeColor, cardColor: color);
    unawaited(
      ref.read(preferencesServiceProvider).update(
            (p) => p.copyWith(
              canvasCardColor: color?.toARGB32(),
              clearCanvasCardColor: color == null,
            ),
          ),
    );
  }
}

final canvasStyleControllerProvider =
    NotifierProvider<CanvasStyleController, CanvasStyleState>(
  CanvasStyleController.new,
  name: 'canvasStyleControllerProvider',
);
