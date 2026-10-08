// 打包资产 DI。
//
// 为什么要一个 provider 而不直接用 rootBundle：示例项目要把随应用打包的成片写进
// 用户的项目目录（P7：原「内置示例」并入短剧示例），测试得能注入假字节而不依赖
// 测试环境的 asset manifest。rootBundle 是全局单例，直接用就没有缝可测。
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final assetBundleProvider = Provider<AssetBundle>(
  (ref) => rootBundle,
  name: 'assetBundleProvider',
);
