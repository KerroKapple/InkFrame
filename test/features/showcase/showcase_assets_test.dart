// 内置示例资产的打包守卫（评审 P2-1）。
//
// 为什么需要：页面用 Image.asset + errorBuilder 兜底,资产没声明进 pubspec 时
// 界面只是静默显示 broken 占位——analyze 与 widget 测全绿,坏产物照样发出去。
// 本测试把「文件在磁盘上」与「pubspec 声明了目录」两条同时钉死。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const assetDir = 'assets/showcase';
  const files = <String>[
    'ink-wash-mountains-square.jpg',
    'ink-wash-storyboard-wide.jpg',
  ];

  test('示例图文件存在且非空', () {
    for (final name in files) {
      final f = File('$assetDir/$name');
      expect(f.existsSync(), isTrue, reason: '缺资产文件：$assetDir/$name');
      expect(f.lengthSync(), greaterThan(1024), reason: '$name 体积异常（疑似占位）');
    }
  });

  test('pubspec.yaml 声明了 assets/showcase/ 目录', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('- $assetDir/'),
      isTrue,
      reason: 'pubspec 未声明 $assetDir/ → 打包后图全变 broken 占位',
    );
  });
}
