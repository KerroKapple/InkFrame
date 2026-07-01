// 列名常量：消灭仓储/模型里散落的字符串列名 typo。
// 值 = 真实 snake_case 列名（真相源 lib/storage/schema/schema_v*.dart）。
// columns_schema_test.dart(pg) 把这些值对真库 information_schema 校验，写错即 CI 红。
//
// schema 演进已落地的列增删（务必与真库一致）：
//   v3 删除 jobs.retry_count / jobs.max_retries（重试由 JobQueue 内存退避负责）
//   v4 删除 jobs.next_poll_at（cancel-on-restart，不做续轮）
// 故 JobCol 不含 retry_count / max_retries / next_poll_at。

abstract final class ProjectCol {
  static const id = 'id';
  static const name = 'name';
  static const coverNodeId = 'cover_node_id';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class CanvasCol {
  static const id = 'id';
  static const projectId = 'project_id';
  static const name = 'name';
  static const baseStylePrefix = 'base_style_prefix';
  static const baseStyleSuffix = 'base_style_suffix';
  static const viewportX = 'viewport_x';
  static const viewportY = 'viewport_y';
  static const viewportScale = 'viewport_scale';
  static const defaultNodeWidth = 'default_node_width';
  static const laneDirection = 'lane_direction';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class StyleLaneCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const label = 'label';
  static const stylePrompt = 'style_prompt';
  static const sortOrder = 'sort_order';
  static const tintColor = 'tint_color';
  static const size = 'size';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class CharacterCol {
  static const id = 'id';
  static const projectId = 'project_id';
  static const name = 'name';
  static const referenceImagePaths = 'reference_image_paths';
  static const description = 'description';
  static const sortOrder = 'sort_order';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}

abstract final class NodeCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const type = 'type';
  static const label = 'label';
  static const nodeRole = 'node_role';
  static const status = 'status';
  static const sourceNodeId = 'source_node_id';
  static const positionX = 'position_x';
  static const positionY = 'position_y';
  static const width = 'width';
  static const height = 'height';
  static const zIndex = 'z_index';
  static const laneId = 'lane_id';
  static const typeConfig = 'type_config';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';

  /// 读路径 JOIN canvases 带出，非 nodes 表自身列；schema guard 不校验此列。
  static const projectId = 'project_id';
}

abstract final class EdgeCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const sourceNodeId = 'source_node_id';
  static const targetNodeId = 'target_node_id';
  static const edgeType = 'edge_type';
  static const role = 'role';
  static const sortOrder = 'sort_order';
  static const createdAt = 'created_at';
  static const deletedAt = 'deleted_at';
}

abstract final class JobCol {
  static const id = 'id';
  static const canvasId = 'canvas_id';
  static const sourceNodeId = 'source_node_id';
  static const resultNodeId = 'result_node_id';
  static const providerId = 'provider_id';
  static const jobType = 'job_type';
  static const status = 'status';
  static const remoteTaskId = 'remote_task_id';
  static const fullPrompt = 'full_prompt';
  static const userPrompt = 'user_prompt';
  static const parameters = 'parameters';
  static const batchSize = 'batch_size';
  static const progress = 'progress';
  static const errorCode = 'error_code';
  static const errorMessage = 'error_message';
  static const timeoutAt = 'timeout_at';
  static const createdAt = 'created_at';
  static const submittedAt = 'submitted_at';
  static const completedAt = 'completed_at';
}

abstract final class BatchResultCol {
  static const id = 'id';
  static const nodeId = 'node_id';
  static const jobId = 'job_id';
  static const slotIndex = 'slot_index';
  static const status = 'status';
  static const outputUrl = 'output_url';
  static const thumbnailUrl = 'thumbnail_url';
  static const width = 'width';
  static const height = 'height';
  static const fileSizeBytes = 'file_size_bytes';
  static const seed = 'seed';
  static const errorCode = 'error_code';
  static const errorMessage = 'error_message';
  static const promoted = 'promoted';
  static const promotedNodeId = 'promoted_node_id';
  static const createdAt = 'created_at';
  static const completedAt = 'completed_at';
}

abstract final class SchemaVersionCol {
  static const id = 'id';
  static const version = 'version';
  static const appliedAt = 'applied_at';
}

/// 跨表通用列（软删 / 时间戳维护），供 BaseRepository patch 与各表共用。
abstract final class CommonCol {
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
}
