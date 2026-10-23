// 导入媒体节点的派生属性（canvas_node_import.dart）：origin == 'import' 才算导入；
// 原文件名只认非空字符串。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/import_keys.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/models/canvas_node_import.dart';

CanvasNode _node(Map<String, Object?> typeConfig) => CanvasNode(
      id: 'n1',
      label: 'n1',
      type: CanvasNodeType.image,
      role: NodeRole.result,
      canvasId: 'c1',
      typeConfig: typeConfig,
    );

void main() {
  test('键名常量与库里的字面量一致', () {
    expect(ImportKeys.origin, 'origin');
    expect(ImportKeys.originalName, 'original_name');
    expect(ImportKeys.originImport, 'import');
  });

  test('isImported：只有 origin == import 才算', () {
    expect(_node(<String, Object?>{'origin': 'import'}).isImported, isTrue);
    expect(_node(const <String, Object?>{}).isImported, isFalse, reason: '缺键');
    expect(_node(<String, Object?>{'origin': null}).isImported, isFalse);
    expect(_node(<String, Object?>{'origin': 'generated'}).isImported, isFalse);
    expect(_node(<String, Object?>{'origin': 'Import'}).isImported, isFalse, reason: '取值区分大小写');
    expect(_node(<String, Object?>{'origin': 1}).isImported, isFalse);
  });

  test('originalFileName：非空字符串才算', () {
    expect(
      _node(<String, Object?>{'origin': 'import', 'original_name': '雾江.jpg'}).originalFileName,
      '雾江.jpg',
    );
    expect(_node(<String, Object?>{'origin': 'import'}).originalFileName, isNull, reason: '缺键');
    expect(_node(<String, Object?>{'original_name': ''}).originalFileName, isNull);
    expect(_node(<String, Object?>{'original_name': null}).originalFileName, isNull);
    expect(_node(<String, Object?>{'original_name': 42}).originalFileName, isNull);
  });
}
