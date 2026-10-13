// 风格泳道默认带厚（ON-2b 评审 P3②，BOARD 196）。
//
// 原来 400.0 这个字面量散落在仓储接口默认值 / 实现默认值 / 模型默认值 / 行解析
// 回落值四处，外加一句注释——改一处忘一处，示例种子和新建泳道就会厚薄不一。
//
// 【它还有一个 Dart 改不到的分身】`schema_v1.dart` 的 DDL：
//   size REAL NOT NULL DEFAULT 400.0
// 已发布的迁移不可改（ADR-0012），而 SQL 字面量也引用不了 Dart 常量。所以两者
// 的一致性由 test/quality/lane_size_default_test.dart 守：改了这里却没补一条
// 前向迁移改库默认，那条闸当场红——否则从此「不带 size 插入的行拿 400、
// Dart 侧回落拿新值」，两边悄悄对不上。
const double kDefaultLaneSize = 400.0;
