// BatchResult：批量/变体生成 slot 的 UI 模型（手写不可变，对齐 Character/StyleLane）。
//
// 一次批量生成（batch_size>1）在 batch_results 表落多行，每行一个 slot；本模型是其读侧投影。
import 'package:flutter/foundation.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';

@immutable
class BatchResult {
  const BatchResult({
    required this.id,
    required this.nodeId,
    required this.jobId,
    required this.slotIndex,
    this.status = 'generating',
    this.outputUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.seed,
    this.promoted = false,
    this.promotedNodeId,
    this.errorCode,
    this.errorMessage,
  });

  final String id;
  final String nodeId;
  final String jobId;
  final int slotIndex;

  /// generating | success | error | cancelled
  final String status;
  final String? outputUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? seed;
  final bool promoted;
  final String? promotedNodeId;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => status == 'success';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatchResult &&
          id == other.id &&
          nodeId == other.nodeId &&
          jobId == other.jobId &&
          slotIndex == other.slotIndex &&
          status == other.status &&
          outputUrl == other.outputUrl &&
          thumbnailUrl == other.thumbnailUrl &&
          promoted == other.promoted &&
          promotedNodeId == other.promotedNodeId;

  @override
  int get hashCode => Object.hash(
    id,
    nodeId,
    jobId,
    slotIndex,
    status,
    outputUrl,
    thumbnailUrl,
    promoted,
    promotedNodeId,
  );

  static BatchResult fromRow(Map<String, Object?> row) => BatchResult(
    id: row.reqId(BatchResultCol.id),
    nodeId: row.reqId(BatchResultCol.nodeId),
    jobId: row.reqId(BatchResultCol.jobId),
    slotIndex: row.optInt(BatchResultCol.slotIndex) ?? 0,
    status: row.optString(BatchResultCol.status) ?? 'generating',
    outputUrl: row.optString(BatchResultCol.outputUrl),
    thumbnailUrl: row.optString(BatchResultCol.thumbnailUrl),
    width: row.optInt(BatchResultCol.width),
    height: row.optInt(BatchResultCol.height),
    seed: row.optInt(BatchResultCol.seed),
    promoted: row.optBool(BatchResultCol.promoted) ?? false,
    promotedNodeId: row.optId(BatchResultCol.promotedNodeId),
    errorCode: row.optString(BatchResultCol.errorCode),
    errorMessage: row.optString(BatchResultCol.errorMessage),
  );
}
