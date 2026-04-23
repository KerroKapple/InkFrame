// ThumbnailService 的 Riverpod DI。
//
// S4：换 MediaKitThumbnailService 真实现。类型仍为可空，
// JobQueueService 在 `_thumbnail == null` 时跳过抽帧（测试覆盖）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/media_kit_thumbnail_service.dart';
import '../interfaces/thumbnail_service.dart';

final thumbnailServiceProvider = Provider<ThumbnailService?>(
  (ref) => MediaKitThumbnailService(),
);
