// currentCanvasIdProvider — UI 当前打开的 canvasId。
//
// null 表示未选中任何 canvas；CanvasView 据此显示空态（含"新建示例画布"入口）。
// 真正的项目/画布管理 UI 后续 sprint 补齐。

import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentCanvasIdProvider = StateProvider<String?>(
  (ref) => null,
  name: 'currentCanvasIdProvider',
);
