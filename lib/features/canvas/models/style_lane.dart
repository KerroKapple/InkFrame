// StyleLane：风格泳道 UI 模型（手写不可变，对齐 CanvasNode 风格，不引 freezed）。
import 'package:flutter/foundation.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';

@immutable
class StyleLane {
  const StyleLane({
    required this.id,
    required this.canvasId,
    this.label = '',
    this.stylePrompt = '',
    this.sortOrder = 0,
    this.tintColor,
    this.size = 400.0,
  });

  final String id;
  final String canvasId;
  final String label;
  final String stylePrompt;
  final int sortOrder;
  final String? tintColor;
  final double size;

  StyleLane copyWith({
    String? label,
    String? stylePrompt,
    int? sortOrder,
    String? tintColor,
    bool clearTint = false,
    double? size,
  }) =>
      StyleLane(
        id: id,
        canvasId: canvasId,
        label: label ?? this.label,
        stylePrompt: stylePrompt ?? this.stylePrompt,
        sortOrder: sortOrder ?? this.sortOrder,
        tintColor: clearTint ? null : (tintColor ?? this.tintColor),
        size: size ?? this.size,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyleLane &&
          id == other.id &&
          canvasId == other.canvasId &&
          label == other.label &&
          stylePrompt == other.stylePrompt &&
          sortOrder == other.sortOrder &&
          tintColor == other.tintColor &&
          size == other.size;

  @override
  int get hashCode =>
      Object.hash(id, canvasId, label, stylePrompt, sortOrder, tintColor, size);

  static StyleLane fromRow(Map<String, Object?> row) => StyleLane(
        id: row.reqId(StyleLaneCol.id),
        canvasId: row.reqId(StyleLaneCol.canvasId),
        label: row.optString(StyleLaneCol.label) ?? '',
        stylePrompt: row.optString(StyleLaneCol.stylePrompt) ?? '',
        sortOrder: row.optInt(StyleLaneCol.sortOrder) ?? 0,
        tintColor: row.optString(StyleLaneCol.tintColor),
        size: row.optDouble(StyleLaneCol.size) ?? 400.0,
      );
}
