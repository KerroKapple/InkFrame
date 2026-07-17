// ImportPlanData：导入重映射产物（LB-12）。纯模型——remapper 产出、Writer 消费；
// 放 core/models 保证 core/interfaces 的 Writer 契约不反向依赖 services 层。

/// 重映射产物：已重写的行集 + files 改名映射 + 宽容策略计数。
class ImportPlanData {
  const ImportPlanData({
    required this.newProjectId,
    required this.canvasIdMap,
    required this.project,
    required this.canvases,
    required this.lanes,
    required this.nodes,
    required this.edges,
    required this.characters,
    required this.presets,
    required this.jobs,
    required this.batchResults,
    required this.droppedColumnCount,
    required this.nulledRefCount,
    required this.droppedRowCount,
  });

  final String newProjectId;

  /// 旧 canvas id → 新 id（files/canvases/{旧} 目录改名用）。
  final Map<String, String> canvasIdMap;
  final Map<String, Object?> project;
  final List<Map<String, Object?>> canvases;
  final List<Map<String, Object?>> lanes;
  final List<Map<String, Object?>> nodes;
  final List<Map<String, Object?>> edges;
  final List<Map<String, Object?>> characters;
  final List<Map<String, Object?>> presets;
  final List<Map<String, Object?>> jobs;
  final List<Map<String, Object?>> batchResults;
  final int droppedColumnCount;
  final int nulledRefCount;
  final int droppedRowCount;
}
