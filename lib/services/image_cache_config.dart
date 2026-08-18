// LB-23：ImageCache 上限设定（main bootstrap 于 ensureInitialized 后调用一次）。
import 'package:flutter/painting.dart';

import '../core/constants/image_cache.dart';

void configureImageCache() {
  PaintingBinding.instance.imageCache.maximumSizeBytes = kImageCacheMaxBytes;
}
