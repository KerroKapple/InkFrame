// 示例成片资产的打包守卫（原 showcase_assets_test，P7 随「内置示例并入短剧示例」改名）。
//
// 为什么需要：成片加载失败是 best-effort 吞掉的（logger.warn + 少种两个节点），
// 界面上只是「示例项目里没有图」——analyze 与 widget 测全绿，坏产物照样发出去。
// 本测试把三条同时钉死：文件在磁盘上、pubspec 声明了目录、控制器引用的就是这两个。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/providers/canvas_bootstrap_controller.dart';

void main() {
  const String assetDir = 'assets/samples';

  test('示例成片文件存在且非空', () {
    for (final String asset in kSampleArtifactAssets) {
      final File f = File(asset);
      expect(f.existsSync(), isTrue, reason: '缺资产文件：$asset');
      expect(f.lengthSync(), greaterThan(1024), reason: '$asset 体积异常（疑似占位）');
    }
  });

  test('控制器引用的资产全在 $assetDir 下', () {
    expect(kSampleArtifactAssets, isNotEmpty);
    for (final String asset in kSampleArtifactAssets) {
      expect(asset, startsWith('$assetDir/'));
    }
  });

  test('pubspec.yaml 声明了 $assetDir/ 目录', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('- $assetDir/'),
      isTrue,
      reason: 'pubspec 未声明 $assetDir/ → 打包后示例项目里一张成片都没有',
    );
  });
}
