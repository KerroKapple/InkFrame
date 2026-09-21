// ShellKeepLastCanvasController：启动恢复上次画布的偏好开关（T11，默认开）。
//
// 与 UpdateCheckPrefController / LocaleController 同模式：build() 自偏好播种，
// setter 即时更新内存态并 fire-and-forget 落盘。控制器只管开关本身——
// 关掉【不清】lastCanvasId/lastProjectId：那是记录，不是意愿。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';

class ShellKeepLastCanvasController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(preferencesServiceProvider).current.shellKeepLastCanvas;

  void setEnabled(bool enabled) {
    state = enabled;
    unawaited(
      ref
          .read(preferencesServiceProvider)
          .update((p) => p.copyWith(shellKeepLastCanvas: enabled)),
    );
  }
}

final shellKeepLastCanvasControllerProvider =
    NotifierProvider<ShellKeepLastCanvasController, bool>(
  ShellKeepLastCanvasController.new,
  name: 'shellKeepLastCanvasControllerProvider',
);
