// LB-23：ImageCache 字节上限必须显式设定（默认 100MB 贴画廊工作集，滚动抖动淘汰）。
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/image_cache.dart';
import 'package:inkframe/services/image_cache_config.dart';

void main() {
  testWidgets('imageCache 上限 = 256MB', (tester) async {
    expect(kImageCacheMaxBytes, 256 << 20);
    configureImageCache();
    expect(
      PaintingBinding.instance.imageCache.maximumSizeBytes,
      kImageCacheMaxBytes,
    );
  });
}
