// ThumbnailService 的 Riverpod DI。
//
// S3 阶段返回 null —— JobQueueService 在 `_thumbnail == null` 时跳过抽帧，
// 视频仍能落盘，只是没有 thumbnail_url。
// S4 会把 Provider 换成 MediaKitThumbnailService 真实现。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/thumbnail_service.dart';

final thumbnailServiceProvider = Provider<ThumbnailService?>((ref) => null);
