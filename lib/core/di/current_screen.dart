// shell 路由：lock unlocked 后在 studio / settings / showcase 之间切换。
// canvas 入口仍由 currentCanvasIdProvider 判据（在 canvas screen 内自治）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppScreen { studio, settings, showcase }

final currentScreenProvider = StateProvider<AppScreen>(
  (_) => AppScreen.studio,
  name: 'currentScreenProvider',
);
