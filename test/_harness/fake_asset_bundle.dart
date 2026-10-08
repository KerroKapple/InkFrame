// 测试用 AssetBundle：按 key 直给字节，缺 key 时抛 AssetBundle 真实的那种错
// （FlutterError「Unable to load asset」）——示例项目的打包成片走这条路加载。

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FakeAssetBundle extends CachingAssetBundle {
  FakeAssetBundle(this.assets);

  /// assetPath → 字节。
  final Map<String, List<int>> assets;

  /// 被请求过的 key（顺序即请求序）。
  final List<String> requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final List<int>? bytes = assets[key];
    if (bytes == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
