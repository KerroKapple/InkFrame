// 泳道默认带厚的两个分身必须一致（ON-2b 评审 P3②，BOARD 196）。
//
// `kDefaultLaneSize` 是 Dart 侧的唯一出处；但库里还有一个 Dart 改不到的分身——
// `schema_v1.dart` 的 DDL `size REAL NOT NULL DEFAULT 400.0`。已发布的迁移不可改
// （ADR-0012），SQL 字面量也引用不了 Dart 常量。两边一旦对不上，「不带 size
// 插入的行」拿 DDL 默认、Dart 侧回落拿常量，泳道就悄悄厚薄不一。
//
// 所以：改了常量，必须补一条前向迁移改库默认，并把下面的判据指向那条迁移。
//
// 口径限制：逐文件正则，不是 SQL 解析器。抓得到 `CREATE TABLE style_lanes` 块里
// 的 `size … DEFAULT <数>`，以及后续迁移里任何同时出现 `style_lanes` 与
// `size` + `DEFAULT` 的 ALTER；一条 ALTER 拆成多段拼接字符串写的抓不到。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/lane_defaults.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_bootstrap_controller.dart';
import 'package:inkframe/features/canvas/util/result_placement.dart';

void main() {
  test('schema_v1 里 style_lanes.size 的 DDL 默认值 == kDefaultLaneSize', () {
    final String v1 =
        File('lib/storage/schema/schema_v1.dart').readAsStringSync();
    final RegExpMatch? m = RegExp(
      r'CREATE TABLE style_lanes \([\s\S]*?\bsize\s+REAL\s+NOT NULL\s+DEFAULT\s+([0-9.]+)',
    ).firstMatch(v1);

    // 正控：抽不到就是正则失效，不是"两边一致"。
    expect(m, isNotNull, reason: 'schema_v1 里没抽到 style_lanes.size 的默认值 ⇒ 本闸失效');
    expect(
      double.parse(m!.group(1)!),
      kDefaultLaneSize,
      reason: '库默认与 Dart 常量对不上：改了 kDefaultLaneSize 就必须补前向迁移改库默认',
    );
  });

  // 自证：上一条只看 v1，前提是「之后没有迁移改过这一列的默认值」。有人补了
  // 那条迁移，这里当场红，提醒把上一条的判据改成指向它——否则上一条就在
  // 拿一个过期的默认值和常量比，绿得毫无意义。
  test('v2 起没有任何迁移改过 style_lanes.size 的默认值', () {
    final List<File> later = Directory('lib/storage/schema')
        .listSync()
        .whereType<File>()
        .where((File f) =>
            RegExp(r'schema_v(\d+)\.dart$').hasMatch(f.path) &&
            int.parse(RegExp(r'schema_v(\d+)\.dart$').firstMatch(f.path)!.group(1)!) > 1)
        .toList();
    expect(later, isNotEmpty, reason: '一条后续迁移都没扫到 ⇒ 目录或正则失效');

    final RegExp altersSize = RegExp(
      r'ALTER TABLE\s+style_lanes[^;]*\bsize\b[^;]*DEFAULT',
      caseSensitive: false,
    );
    final List<String> offenders = <String>[
      for (final File f in later)
        if (altersSize.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: '这些迁移改了 style_lanes.size 的默认值，上一条闸的判据要改成指向'
          '最新那一条：\n${offenders.join('\n')}',
    );
  });

  // 示例节点的落点依赖带厚：横向泳道的带是 Y ∈ [0, kDefaultLaneSize)，卡片按
  // kNodeCardSize 渲染。把带厚改小，示例节点就会溢出第一条泳道——首启第一眼
  // 看到的就是一张压在泳道边上的卡。这条关系原来只写在注释里（而且那句注释
  // 引用的卡片尺寸早就过期了）。
  test('示例节点整张卡片落在第一条默认泳道带内', () {
    expect(kSampleNodePosition.dy, greaterThanOrEqualTo(0));
    expect(
      kSampleNodePosition.dy + kNodeCardSize.height,
      lessThanOrEqualTo(kDefaultLaneSize),
      reason: '示例卡片纵向溢出了默认泳道带',
    );
  });

  // 示例成片按生成同一条规则排在 config 右侧一列、往下错开；示例泳道的带厚
  // kSampleLaneSize 必须把整列都装下——否则首启就看到成片压在泳道下沿上。
  test('示例 config 与全部示例成片都落在示例泳道带内', () {
    expect(kSampleLaneSize, greaterThanOrEqualTo(kDefaultLaneSize));
    for (int k = 0; k < kSampleArtifactAssets.length; k++) {
      final Offset p = resultNodePosition(configPosition: kSampleNodePosition, index: k);
      expect(p.dy, greaterThanOrEqualTo(0));
      expect(
        p.dy + kNodeCardSize.height,
        lessThanOrEqualTo(kSampleLaneSize),
        reason: '第 $k 张示例成片纵向溢出了示例泳道带',
      );
    }
  });
}
