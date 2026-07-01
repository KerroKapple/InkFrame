// Character：项目级角色一致性 UI 模型（手写不可变，对齐 StyleLane 风格，不引 freezed）。
//
// referenceImagePaths 存项目相对路径（characters/{uuid}.ext），由 CharacterAssetService
// 解析为绝对路径后注入生成。顺序有意义（注入次序），故等值/哈希按序。
import 'package:flutter/foundation.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';

@immutable
class Character {
  const Character({
    required this.id,
    required this.projectId,
    this.name = '',
    this.description = '',
    this.referenceImagePaths = const <String>[],
    this.sortOrder = 0,
  });

  final String id;
  final String projectId;
  final String name;
  final String description;
  final List<String> referenceImagePaths;
  final int sortOrder;

  Character copyWith({
    String? name,
    String? description,
    List<String>? referenceImagePaths,
    int? sortOrder,
  }) =>
      Character(
        id: id,
        projectId: projectId,
        name: name ?? this.name,
        description: description ?? this.description,
        referenceImagePaths: referenceImagePaths ?? this.referenceImagePaths,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Character &&
          id == other.id &&
          projectId == other.projectId &&
          name == other.name &&
          description == other.description &&
          listEquals(referenceImagePaths, other.referenceImagePaths) &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(
        id,
        projectId,
        name,
        description,
        Object.hashAll(referenceImagePaths),
        sortOrder,
      );

  static Character fromRow(Map<String, Object?> row) => Character(
        id: row.reqId(CharacterCol.id),
        projectId: row.reqId(CharacterCol.projectId),
        name: row.optString(CharacterCol.name) ?? '',
        description: row.optString(CharacterCol.description) ?? '',
        referenceImagePaths: row.stringList(CharacterCol.referenceImagePaths),
        sortOrder: row.optInt(CharacterCol.sortOrder) ?? 0,
      );
}
