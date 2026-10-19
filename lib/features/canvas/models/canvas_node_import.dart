// CanvasNode 上与「导入的媒体」有关的派生属性（canvas_node.dart 是手写类，派生属性写成扩展，不改它）。
//
// 导入节点 = 用户自己选进来的图片 / 视频：role = result、sourceNodeId = null（没有来源配置节点），
// type_config 记 origin = import 与原文件名。键名常量在 core/constants/import_keys.dart。
import '../../../core/constants/import_keys.dart';
import 'canvas_node.dart';

extension CanvasNodeImport on CanvasNode {
  /// 是不是导入的媒体：type_config['origin'] == 'import'。
  bool get isImported => typeConfig[ImportKeys.origin] == ImportKeys.originImport;

  /// 导入时的原文件名（type_config['original_name']）；非空字符串才算，否则 null。
  String? get originalFileName {
    final Object? v = typeConfig[ImportKeys.originalName];
    return v is String && v.isNotEmpty ? v : null;
  }
}
