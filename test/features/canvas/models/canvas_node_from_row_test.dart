// CanvasNode.fromRow 解析健壮性 + equality 字段级区分。
//
// 补 canvas_node_test.dart 未覆盖的边界：非法 type/role 抛错、type_config 的
// 非 Map<String,Object?> 与坏 JSON 分支、position/size 的 num/string 解析，
// 以及 operator== 在「仅末位字段不同」时的逐字段短路返回 false。
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

Map<String, Object?> _baseRow() => <String, Object?>{
      'id': 'n1',
      'type': 'image',
      'node_role': 'config',
      'canvas_id': 'c1',
    };

void main() {
  group('CanvasNode.fromRow 错误分支', () {
    test('非法 type → FormatException', () {
      final row = _baseRow()..['type'] = 'hologram';
      expect(
        () => CanvasNodeMapping.fromRow(row),
        throwsA(isA<FormatException>()),
      );
    });

    test('非法 node_role → FormatException', () {
      final row = _baseRow()..['node_role'] = 'overlord';
      expect(
        () => CanvasNodeMapping.fromRow(row),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CanvasNode.fromRow type_config 解析', () {
    test('非 Map<String,Object?> 的 Map<dynamic,dynamic> 也能解析并键转字符串', () {
      // PG 驱动有时回 Map<dynamic,dynamic>，命中 `raw is Map` 兜底分支。
      final row = _baseRow()
        ..['type_config'] = <dynamic, dynamic>{42: 'x', 'image_url': 'a.png'};
      final n = CanvasNodeMapping.fromRow(row);
      expect(n.typeConfig['42'], 'x'); // 键被 toString 归一
      expect(n.imageUrl, 'a.png');
    });

    test('坏 JSON 字符串 → 当空对象，不抛错', () {
      final row = _baseRow()..['type_config'] = '{not valid json';
      final n = CanvasNodeMapping.fromRow(row);
      expect(n.typeConfig, isEmpty);
      expect(n.imageUrl, isNull);
    });

    test('JSON 字符串解出非 Map（数组）→ 空对象', () {
      final row = _baseRow()..['type_config'] = '[1,2,3]';
      final n = CanvasNodeMapping.fromRow(row);
      expect(n.typeConfig, isEmpty);
    });
  });

  group('CanvasNode.fromRow 数值字段解析', () {
    test('position/size 从 int 与字符串解析为 double', () {
      final row = _baseRow()
        ..['position_x'] = 10 // int → toDouble
        ..['position_y'] = '20.5' // string → tryParse
        ..['width'] = 300
        ..['height'] = '180';
      final n = CanvasNodeMapping.fromRow(row);
      expect(n.position, const Offset(10, 20.5));
      expect(n.size, const Size(300, 180));
    });

    test('缺失数值 → position 归零、size 取 240 默认', () {
      final n = CanvasNodeMapping.fromRow(_baseRow());
      expect(n.position, Offset.zero);
      expect(n.size, const Size(240, 240));
    });
  });

  group('CanvasNode operator== 逐字段区分', () {
    // 每条改且仅改一个字段，验证 == 在对应短路臂返回 false。
    const base = CanvasNode(
      id: 'x',
      label: 'A',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      projectId: 'p',
      canvasId: 'c',
      sourceNodeId: 'cfg',
      typeConfig: <String, Object?>{'k': 'v'},
      position: Offset(1, 2),
      size: Size(10, 20),
    );

    test('label 不同 → 不等', () {
      expect(base == base.copyWith(label: 'B'), isFalse);
    });
    test('type 不同 → 不等', () {
      expect(base == base.copyWith(type: CanvasNodeType.video), isFalse);
    });
    test('projectId 不同 → 不等', () {
      expect(base == base.copyWith(projectId: 'p2'), isFalse);
    });
    test('canvasId 不同 → 不等', () {
      expect(base == base.copyWith(canvasId: 'c2'), isFalse);
    });
    test('typeConfig 内容不同 → 不等（mapEquals 生效）', () {
      expect(
        base == base.copyWith(typeConfig: <String, Object?>{'k': 'w'}),
        isFalse,
      );
    });
    test('position 不同 → 不等', () {
      expect(base == base.copyWith(position: const Offset(9, 9)), isFalse);
    });
    test('size 不同 → 不等', () {
      expect(base == base.copyWith(size: const Size(1, 1)), isFalse);
    });
    test('全字段相同 → 相等且 hashCode 一致', () {
      final clone = base.copyWith();
      expect(base == clone, isTrue);
      expect(base.hashCode, clone.hashCode);
    });
  });
}
