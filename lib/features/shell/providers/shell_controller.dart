// ShellNavigator：外壳状态的唯一写入口。
//
// 【抽象接口的豁免】docs/CLAUDE.md 的 "Every injectable must have an abstract
// interface" 针对的是注入的【服务】（lib/core/interfaces/ 下 38 个文件）。
// ShellNavigator 是 Notifier<ShellState>——状态而非服务，仓库既有先例是
// CanvasSelectionController / CanvasViewportSize，均无接口。给 Notifier 套接口
// 还会让 overrideWith(() => ShellNavigator(initial: ...)) 这条最有用的测试
// 播种通道失效。此处显式记录豁免理由，不沉默跳过。
//
// 写权限天然被收口：ShellState 字段全 final，迁移全在本类内，外部只有
// read(shellControllerProvider.notifier).<七个方法之一>。因此不需要任何
// 正则质量测试来"禁止绕过"。
//
// 导航器不做 IO：偏好落盘（lastCanvasId / lastProjectId）留在 open_canvas.dart
// 原处（SRP：导航器只管内存态，可纯单测、零 mock）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gallery/providers/gallery_controller.dart';
import '../models/shell_state.dart';

class ShellNavigator extends Notifier<ShellState> {
  ShellNavigator({ShellState initial = const ShellState()}) : _initial = initial;

  final ShellState _initial;

  @override
  ShellState build() => _initial;

  /// riverpod-2.6.1/lib/src/notifier.dart:113-115 的默认实现是
  /// `!identical(previous, next)`。外壳每次导航都构造新 ShellState，
  /// 不覆写就会在每次切标签时唤醒全体订阅者。
  @override
  bool updateShouldNotify(ShellState previous, ShellState next) =>
      previous != next;

  /// 第二道腰带：值相等直接短路，连 state setter 都不进。
  void _set(ShellState next) {
    if (next == state) return;
    state = next;
  }

  void goTab(ShellTab t) => _set(state.goTab(t));
  void openCanvas(String id, {ProjectRef? withProject}) =>
      _set(state.openCanvas(id, withProject: withProject));
  void openGallery(ProjectRef p) => _set(state.openGallery(p));
  void setProject(ProjectRef p) => _set(state.setProject(p));
  void openOverlay(ShellOverlay o) => _set(state.openOverlay(o));
  void closeOverlay() => _set(state.closeOverlay());

  /// 还原备份后：四项归零，并让画廊整族失效——保活后画廊标签会捧着
  /// 还原前那个库的产物继续显示，且 project.id 可能在新库里已不存在。
  void resetSession() {
    _set(state.resetSession());
    ref.invalidate(galleryControllerProvider);
  }
}

final shellControllerProvider =
    NotifierProvider<ShellNavigator, ShellState>(
      ShellNavigator.new,
      name: 'shellControllerProvider',
    );
