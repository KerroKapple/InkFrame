// currentGalleryProjectProvider —— 画廊浏览目标（项目 id + 显示名）。
//
// null 表示未打开画廊；路由语义与 currentCanvasIdProvider 一致（app.dart 顶层切换）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef GalleryProject = ({String id, String name});

final currentGalleryProjectProvider = StateProvider<GalleryProject?>(
  (ref) => null,
  name: 'currentGalleryProjectProvider',
);
