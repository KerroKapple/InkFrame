// 产物落点（util/result_placement.dart）：config 卡右侧一列，第 k 个往下错开 k 格。
//
// 原来生成路径不给坐标，成片全落在世界原点叠成一摞；示例项目则排成一横排，
// config → 第二张的产出线得从第一张卡底下穿过去。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/result_placement.dart';

void main() {
  const Offset config = Offset(120, 90);
  // 224 卡宽 + 64 列距；191 卡高 + 48 行距。
  const double column = 120 + 224 + 64.0;

  group('resultNodePosition', () {
    test('k = 0：紧贴 config 右侧，顶对齐', () {
      expect(
        resultNodePosition(configPosition: config, index: 0),
        const Offset(column, 90),
      );
    });

    test('k = 1：同一列往下一格', () {
      expect(
        resultNodePosition(configPosition: config, index: 1),
        const Offset(column, 90 + 191 + 48.0),
      );
    });

    test('k = 2：同一列往下两格', () {
      expect(
        resultNodePosition(configPosition: config, index: 2),
        const Offset(column, 90 + 2 * (191 + 48.0)),
      );
    });

    test('与卡片尺寸 / 间距常量同源：相邻两格之间正好隔开一个行距，同列不重叠', () {
      final Offset k0 = resultNodePosition(configPosition: config, index: 0);
      final Offset k1 = resultNodePosition(configPosition: config, index: 1);
      expect(k0.dx - (config.dx + kNodeCardSize.width), kResultColumnGap);
      expect(k1.dy - (k0.dy + kNodeCardSize.height), kResultRowGap);
      expect(k1.dx, k0.dx);
    });

    test('负坐标的 config 也照同一条规则（全向无限画布）', () {
      expect(
        resultNodePosition(configPosition: const Offset(-500, -300), index: 1),
        const Offset(-500 + 224 + 64.0, -300 + 191 + 48.0),
      );
    });
  });

  group('liveResultCount', () {
    Map<String, Object?> row(
      String id, {
      String role = 'result',
      String? source,
      Object? deletedAt,
    }) =>
        <String, Object?>{
          'id': id,
          'node_role': role,
          'source_node_id': source,
          'deleted_at': deletedAt,
        };

    test('只数指向这个 config 的现存 result', () {
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[
        row('cfg', role: 'config'),
        row('r1', source: 'cfg'),
        row('r2', source: 'cfg'),
        row('other', source: 'cfg-2'),
        row('orphan'),
        row('trashed', source: 'cfg', deletedAt: DateTime.utc(2026)),
      ];
      expect(liveResultCount(rows, 'cfg'), 2);
      expect(liveResultCount(rows, 'cfg-2'), 1);
      expect(liveResultCount(rows, 'nobody'), 0);
    });

    test('config 行带着 source_node_id（数据异常）也不算产物', () {
      expect(
        liveResultCount(<Map<String, Object?>>[
          row('weird', role: 'config', source: 'cfg'),
        ], 'cfg'),
        0,
      );
    });

    test('空表 → 0', () {
      expect(liveResultCount(const <Map<String, Object?>>[], 'cfg'), 0);
    });
  });
}
