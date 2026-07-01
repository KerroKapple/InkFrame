// PromptPreset：项目级提示词预设 UI 模型（手写不可变，对齐 Character/StyleLane，无 freezed）。
import 'package:flutter/foundation.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';

@immutable
class PromptPreset {
  const PromptPreset({
    required this.id,
    required this.projectId,
    this.name = '',
    this.prompt = '',
    this.prefix = '',
    this.suffix = '',
    this.negative = '',
    this.sortOrder = 0,
  });

  final String id;
  final String projectId;
  final String name;
  final String prompt;
  final String prefix;
  final String suffix;
  final String negative;
  final int sortOrder;

  PromptPreset copyWith({
    String? name,
    String? prompt,
    String? prefix,
    String? suffix,
    String? negative,
    int? sortOrder,
  }) => PromptPreset(
    id: id,
    projectId: projectId,
    name: name ?? this.name,
    prompt: prompt ?? this.prompt,
    prefix: prefix ?? this.prefix,
    suffix: suffix ?? this.suffix,
    negative: negative ?? this.negative,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptPreset &&
          id == other.id &&
          projectId == other.projectId &&
          name == other.name &&
          prompt == other.prompt &&
          prefix == other.prefix &&
          suffix == other.suffix &&
          negative == other.negative &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    name,
    prompt,
    prefix,
    suffix,
    negative,
    sortOrder,
  );

  static PromptPreset fromRow(Map<String, Object?> row) => PromptPreset(
    id: row.reqId(PromptPresetCol.id),
    projectId: row.reqId(PromptPresetCol.projectId),
    name: row.optString(PromptPresetCol.name) ?? '',
    prompt: row.optString(PromptPresetCol.prompt) ?? '',
    prefix: row.optString(PromptPresetCol.prefix) ?? '',
    suffix: row.optString(PromptPresetCol.suffix) ?? '',
    negative: row.optString(PromptPresetCol.negative) ?? '',
    sortOrder: row.optInt(PromptPresetCol.sortOrder) ?? 0,
  );
}
