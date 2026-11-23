// 参考库条目（本机下载的姿势 / 人像 / 服装图库里的一张图）。
//
// 手写不可变值对象而非 freezed（与 director.dart / shot_language.dart 同例外：
// build_runner 全量构建损坏，BOARD 161）。条目只活在内存里，不落库；
// 画布上用到哪张，就经媒体导入复制进项目，节点 type_config 里只记 id 与类别
// （ImportKeys.referenceItemId / referenceCategory）。
import 'package:flutter/foundation.dart';

/// 条目类别。[name] 就是写进导入节点 type_config 的取值（英文常量，不 i18n）。
enum ReferenceCategory { pose, portrait, costume }

@immutable
class ReferenceItem {
  const ReferenceItem({
    required this.id,
    required this.category,
    required this.name,
    required this.group,
    this.angle,
    required this.thumbPath,
    required this.originalPath,
    required this.searchText,
  });

  /// 图库自带的条目 id（同一图库内唯一）。
  final String id;

  final ReferenceCategory category;

  /// 显示名（内容数据，原样显示，不 i18n）。
  final String name;

  /// 子类：姿势取「分类」、人像取「分区」、服装取「分类」。
  final String group;

  /// 视角；只有姿势有。
  final String? angle;

  /// 缩略图绝对路径。
  final String thumbPath;

  /// 原图绝对路径（导入画布 / 存为角色用这张）。
  final String originalPath;

  /// 搜索用的全文（图库自带的「检索」字段）。
  final String searchText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferenceItem &&
          other.id == id &&
          other.category == category &&
          other.name == name &&
          other.group == group &&
          other.angle == angle &&
          other.thumbPath == thumbPath &&
          other.originalPath == originalPath &&
          other.searchText == searchText;

  @override
  int get hashCode => Object.hash(
      id, category, name, group, angle, thumbPath, originalPath, searchText);

  @override
  String toString() => 'ReferenceItem(${category.name}:$id $name)';
}
