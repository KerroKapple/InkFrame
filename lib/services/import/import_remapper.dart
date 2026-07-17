// 导入重映射器（LB-12 拍板 2/3/7/8）：纯函数，无 DB/IO 依赖，可穷测。
//
// 职责：data.json 全表旧→新 UUID、FK/JSONB 内引用重写、当前列白名单过滤
// （schemaVersion≤当前 的老包多余键丢弃）、jobs/slots 终态化、files/ 的
// canvases/{旧id} 改名映射。宽容策略（拍板 8）：可空引用悬空→NULL+计数；
// NOT NULL 引用悬空→整行丢弃+计数（防御第三方手工包；LB-11 全保真闭包下不触发）。
import '../../core/constants/job_statuses.dart';
import '../../core/db/columns.dart';
import '../../core/models/import_plan_data.dart';

export '../../core/models/import_plan_data.dart' show ImportPlanData;

/// 当前 schema 列白名单（columns.dart 单一真相源；NodeCol.projectId 是
/// join 派生列，刻意不入白名单）。
const Set<String> _projectCols = {
  ProjectCol.id, ProjectCol.name, ProjectCol.coverNodeId,
  ProjectCol.createdAt, ProjectCol.updatedAt, ProjectCol.deletedAt,
};
const Set<String> _canvasCols = {
  CanvasCol.id, CanvasCol.projectId, CanvasCol.name,
  CanvasCol.baseStylePrefix, CanvasCol.baseStyleSuffix,
  CanvasCol.viewportX, CanvasCol.viewportY, CanvasCol.viewportScale,
  CanvasCol.defaultNodeWidth, CanvasCol.laneDirection,
  CanvasCol.createdAt, CanvasCol.updatedAt, CanvasCol.deletedAt,
};
const Set<String> _laneCols = {
  StyleLaneCol.id, StyleLaneCol.canvasId, StyleLaneCol.label,
  StyleLaneCol.stylePrompt, StyleLaneCol.sortOrder, StyleLaneCol.tintColor,
  StyleLaneCol.size, StyleLaneCol.createdAt, StyleLaneCol.updatedAt,
  StyleLaneCol.deletedAt,
};
const Set<String> _nodeCols = {
  NodeCol.id, NodeCol.canvasId, NodeCol.type, NodeCol.label,
  NodeCol.nodeRole, NodeCol.status, NodeCol.sourceNodeId,
  NodeCol.positionX, NodeCol.positionY, NodeCol.width, NodeCol.height,
  NodeCol.zIndex, NodeCol.laneId, NodeCol.typeConfig,
  NodeCol.createdAt, NodeCol.updatedAt, NodeCol.deletedAt,
};
const Set<String> _edgeCols = {
  EdgeCol.id, EdgeCol.canvasId, EdgeCol.sourceNodeId, EdgeCol.targetNodeId,
  EdgeCol.edgeType, EdgeCol.role, EdgeCol.sortOrder,
  EdgeCol.createdAt, EdgeCol.deletedAt,
};
const Set<String> _characterCols = {
  CharacterCol.id, CharacterCol.projectId, CharacterCol.name,
  CharacterCol.referenceImagePaths, CharacterCol.description,
  CharacterCol.sortOrder, CharacterCol.createdAt, CharacterCol.updatedAt,
  CharacterCol.deletedAt,
};
const Set<String> _presetCols = {
  PromptPresetCol.id, PromptPresetCol.projectId, PromptPresetCol.name,
  PromptPresetCol.prompt, PromptPresetCol.prefix, PromptPresetCol.suffix,
  PromptPresetCol.negative, PromptPresetCol.sortOrder,
  PromptPresetCol.createdAt, PromptPresetCol.updatedAt,
  PromptPresetCol.deletedAt,
};
const Set<String> _jobCols = {
  JobCol.id, JobCol.canvasId, JobCol.sourceNodeId, JobCol.resultNodeId,
  JobCol.providerId, JobCol.jobType, JobCol.status, JobCol.remoteTaskId,
  JobCol.fullPrompt, JobCol.userPrompt, JobCol.parameters, JobCol.batchSize,
  JobCol.progress, JobCol.errorCode, JobCol.errorMessage, JobCol.timeoutAt,
  JobCol.createdAt, JobCol.submittedAt, JobCol.completedAt,
};
const Set<String> _batchCols = {
  BatchResultCol.id, BatchResultCol.nodeId, BatchResultCol.jobId,
  BatchResultCol.slotIndex, BatchResultCol.status, BatchResultCol.outputUrl,
  BatchResultCol.thumbnailUrl, BatchResultCol.width, BatchResultCol.height,
  BatchResultCol.fileSizeBytes, BatchResultCol.seed,
  BatchResultCol.errorCode, BatchResultCol.errorMessage,
  BatchResultCol.promoted, BatchResultCol.promotedNodeId,
  BatchResultCol.createdAt, BatchResultCol.completedAt,
};

class _Counters {
  int droppedColumns = 0;
  int nulledRefs = 0;
  int droppedRows = 0;
}

List<Map<String, Object?>> _tableOf(Map<String, dynamic> data, String key) {
  final Object? v = data[key];
  if (v is! List) return const [];
  return <Map<String, Object?>>[
    for (final e in v)
      if (e is Map) <String, Object?>{...e.cast<String, Object?>()},
  ];
}

/// 行→白名单过滤 + 计数。
Map<String, Object?> _filterCols(
  Map<String, Object?> row,
  Set<String> allow,
  _Counters c,
) {
  final out = <String, Object?>{};
  for (final e in row.entries) {
    if (allow.contains(e.key)) {
      out[e.key] = e.value;
    } else {
      c.droppedColumns++;
    }
  }
  return out;
}

/// 主入口：dataJson=LB-11 data.json 顶层；newId=UUID 工厂（测试注入确定序列）。
ImportPlanData remapArchiveData(
  Map<String, dynamic> dataJson, {
  required String Function() newId,
}) {
  final c = _Counters();

  final Map<String, Object?> projectRaw =
      (dataJson['project'] is Map)
          ? (dataJson['project'] as Map).cast<String, Object?>()
          : <String, Object?>{};
  final canvasesRaw = _tableOf(dataJson, 'canvases');
  final lanesRaw = _tableOf(dataJson, 'lanes');
  final nodesRaw = _tableOf(dataJson, 'nodes');
  final edgesRaw = _tableOf(dataJson, 'edges');
  final charactersRaw = _tableOf(dataJson, 'characters');
  final presetsRaw = _tableOf(dataJson, 'prompt_presets');
  final jobsRaw = _tableOf(dataJson, 'jobs');
  final batchRaw = _tableOf(dataJson, 'batch_results');

  // 1) 全表 id 映射。
  final String newProjectId = newId();
  Map<String, String> mapOf(List<Map<String, Object?>> rows) => {
        for (final r in rows)
          if (r['id'] != null) r['id'].toString(): newId(),
      };
  final canvasMap = mapOf(canvasesRaw);
  final laneMap = mapOf(lanesRaw);
  final nodeMap = mapOf(nodesRaw);
  final edgeMap = mapOf(edgesRaw);
  final characterMap = mapOf(charactersRaw);
  final presetMap = mapOf(presetsRaw);
  final jobMap = mapOf(jobsRaw);
  final batchMap = mapOf(batchRaw);

  // 可空引用：悬空→NULL+计数。
  Object? optRef(Object? old, Map<String, String> m) {
    if (old == null) return null;
    final String? mapped = m[old.toString()];
    if (mapped == null) c.nulledRefs++;
    return mapped;
  }

  // NOT NULL 引用：悬空→null 信号（调用方丢整行）。
  String? reqRef(Object? old, Map<String, String> m) {
    if (old == null) return null;
    return m[old.toString()];
  }

  // 2) project。
  final project = _filterCols(projectRaw, _projectCols, c);
  project[ProjectCol.id] = newProjectId;
  project[ProjectCol.coverNodeId] =
      optRef(project[ProjectCol.coverNodeId], nodeMap);

  // 3) canvases / lanes。
  final canvases = <Map<String, Object?>>[];
  for (final r in canvasesRaw) {
    final row = _filterCols(r, _canvasCols, c);
    final String? id = canvasMap[r['id']?.toString()];
    if (id == null) {
      c.droppedRows++;
      continue;
    }
    row[CanvasCol.id] = id;
    row[CanvasCol.projectId] = newProjectId; // 单项目包：一律强写。
    canvases.add(row);
  }
  final lanes = <Map<String, Object?>>[];
  for (final r in lanesRaw) {
    final row = _filterCols(r, _laneCols, c);
    final String? id = laneMap[r['id']?.toString()];
    final String? cid = reqRef(r[StyleLaneCol.canvasId], canvasMap);
    if (id == null || cid == null) {
      c.droppedRows++;
      continue;
    }
    row[StyleLaneCol.id] = id;
    row[StyleLaneCol.canvasId] = cid;
    lanes.add(row);
  }

  // 4) nodes（source_node_id/lane_id 为可空引用；character_ids 在 type_config 内）。
  final nodes = <Map<String, Object?>>[];
  for (final r in nodesRaw) {
    final row = _filterCols(r, _nodeCols, c);
    final String? id = nodeMap[r['id']?.toString()];
    final String? cid = reqRef(r[NodeCol.canvasId], canvasMap);
    if (id == null || cid == null) {
      c.droppedRows++;
      continue;
    }
    row[NodeCol.id] = id;
    row[NodeCol.canvasId] = cid;
    row[NodeCol.sourceNodeId] = optRef(r[NodeCol.sourceNodeId], nodeMap);
    row[NodeCol.laneId] = optRef(r[NodeCol.laneId], laneMap);
    // 拍板 8：type_config.character_ids 经 characterMap；悬空条目丢弃+计数。
    final Object? cfg = row[NodeCol.typeConfig];
    if (cfg is Map) {
      final cfgMap = cfg.cast<String, Object?>();
      final Object? charIds = cfgMap['character_ids'];
      if (charIds is List) {
        final remapped = <String>[];
        for (final e in charIds) {
          final String? m = characterMap[e.toString()];
          if (m != null) {
            remapped.add(m);
          } else {
            c.nulledRefs++;
          }
        }
        cfgMap['character_ids'] = remapped;
      }
      row[NodeCol.typeConfig] = cfgMap;
    }
    nodes.add(row);
  }

  // 5) edges（双端 NOT NULL）。
  final edges = <Map<String, Object?>>[];
  for (final r in edgesRaw) {
    final row = _filterCols(r, _edgeCols, c);
    final String? id = edgeMap[r['id']?.toString()];
    final String? cid = reqRef(r[EdgeCol.canvasId], canvasMap);
    final String? src = reqRef(r[EdgeCol.sourceNodeId], nodeMap);
    final String? dst = reqRef(r[EdgeCol.targetNodeId], nodeMap);
    if (id == null || cid == null || src == null || dst == null) {
      c.droppedRows++;
      continue;
    }
    row[EdgeCol.id] = id;
    row[EdgeCol.canvasId] = cid;
    row[EdgeCol.sourceNodeId] = src;
    row[EdgeCol.targetNodeId] = dst;
    edges.add(row);
  }

  // 6) characters（reference_image_paths 防御性重写 canvases/{旧}/ 前缀）。
  final characters = <Map<String, Object?>>[];
  for (final r in charactersRaw) {
    final row = _filterCols(r, _characterCols, c);
    final String? id = characterMap[r['id']?.toString()];
    if (id == null) {
      c.droppedRows++;
      continue;
    }
    row[CharacterCol.id] = id;
    row[CharacterCol.projectId] = newProjectId;
    final Object? paths = row[CharacterCol.referenceImagePaths];
    if (paths is List) {
      row[CharacterCol.referenceImagePaths] = <String>[
        for (final p in paths) _rewriteCanvasPrefix(p.toString(), canvasMap),
      ];
    }
    characters.add(row);
  }

  // 7) presets。
  final presets = <Map<String, Object?>>[];
  for (final r in presetsRaw) {
    final row = _filterCols(r, _presetCols, c);
    final String? id = presetMap[r['id']?.toString()];
    if (id == null) {
      c.droppedRows++;
      continue;
    }
    row[PromptPresetCol.id] = id;
    row[PromptPresetCol.projectId] = newProjectId;
    presets.add(row);
  }

  // 8) jobs（拍板 7：非终态→cancelled+补 completed_at）。
  final jobs = <Map<String, Object?>>[];
  final Set<String> keptJobIds = <String>{};
  for (final r in jobsRaw) {
    final row = _filterCols(r, _jobCols, c);
    final String? id = jobMap[r['id']?.toString()];
    final String? cid = reqRef(r[JobCol.canvasId], canvasMap);
    final String? src = reqRef(r[JobCol.sourceNodeId], nodeMap);
    if (id == null || cid == null || src == null) {
      c.droppedRows++;
      continue;
    }
    row[JobCol.id] = id;
    row[JobCol.canvasId] = cid;
    row[JobCol.sourceNodeId] = src;
    row[JobCol.resultNodeId] = optRef(r[JobCol.resultNodeId], nodeMap);
    final String? status = row[JobCol.status]?.toString();
    if (status == null || !JobStatuses.terminal.contains(status)) {
      row[JobCol.status] = JobStatuses.cancelled;
      row[JobCol.completedAt] ??= row[JobCol.createdAt];
    }
    keptJobIds.add(r['id'].toString());
    jobs.add(row);
  }

  // 9) batch_results（node/job NOT NULL；promoted_node_id 可空）。
  final batchResults = <Map<String, Object?>>[];
  for (final r in batchRaw) {
    final row = _filterCols(r, _batchCols, c);
    final String? id = batchMap[r['id']?.toString()];
    final String? nid = reqRef(r[BatchResultCol.nodeId], nodeMap);
    final String? oldJob = r[BatchResultCol.jobId]?.toString();
    final String? jid =
        (oldJob != null && keptJobIds.contains(oldJob)) ? jobMap[oldJob] : null;
    if (id == null || nid == null || jid == null) {
      c.droppedRows++;
      continue;
    }
    row[BatchResultCol.id] = id;
    row[BatchResultCol.nodeId] = nid;
    row[BatchResultCol.jobId] = jid;
    row[BatchResultCol.promotedNodeId] =
        optRef(r[BatchResultCol.promotedNodeId], nodeMap);
    final String? status = row[BatchResultCol.status]?.toString();
    if (status == SlotStatuses.generating || status == null) {
      row[BatchResultCol.status] = SlotStatuses.cancelled;
      row[BatchResultCol.completedAt] ??= row[BatchResultCol.createdAt];
    }
    batchResults.add(row);
  }

  return ImportPlanData(
    newProjectId: newProjectId,
    canvasIdMap: canvasMap,
    project: project,
    canvases: canvases,
    lanes: lanes,
    nodes: nodes,
    edges: edges,
    characters: characters,
    presets: presets,
    jobs: jobs,
    batchResults: batchResults,
    droppedColumnCount: c.droppedColumns,
    nulledRefCount: c.nulledRefs,
    droppedRowCount: c.droppedRows,
  );
}

/// `canvases/{旧id}/...` 前缀重写（角色资产常规形态为 `characters/<file>`，
/// 本函数只防御可能的画布相对形态）。
String _rewriteCanvasPrefix(String path, Map<String, String> canvasMap) {
  const prefix = 'canvases/';
  if (!path.startsWith(prefix)) return path;
  final rest = path.substring(prefix.length);
  final slash = rest.indexOf('/');
  if (slash <= 0) return path;
  final String oldId = rest.substring(0, slash);
  final String? mapped = canvasMap[oldId];
  if (mapped == null) return path;
  return '$prefix$mapped${rest.substring(slash)}';
}
