// EdgeRepository 契约：edges 表（data / narrative / generation_source）。
abstract class EdgeRepository {
  /// 创建连线。若 (source, target, type) 已存在则抛 UniqueViolationException（CHECK 约束）。
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    required String targetNodeId,
    required String edgeType,
    String role = 'reference',
    int sortOrder = 0,
  });

  Future<Map<String, Object?>?> findById(String id);

  /// 列出画布下未软删除连线。
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId);

  /// 列出某节点所有出边。顺序契约同 [listIncoming]。
  Future<List<Map<String, Object?>>> listOutgoing(String sourceNodeId);

  /// 列出某节点所有入边，按 `sort_order, created_at, id` 升序。
  ///
  /// 【确定序是契约，不是实现细节】生成侧 `_resolveRefImages` 对首帧 / 尾帧取
  /// 「遇到的第一条」。无序的话，同一个节点上万一有两条同角色入边（存量数据，
  /// 或「撤销删除」与「把另一条改成首帧」撞在一起），到底把哪张图当首帧发给
  /// provider 会在两次运行之间漂——比稳定地用错一张更难查。写侧的单选约束见
  /// `CanvasEdgesController.updateRole`；这里兜的是写侧管不到的存量与夹缝。
  Future<List<Map<String, Object?>>> listIncoming(String targetNodeId);

  Future<int> update(String id, Map<String, Object?> patch);
  Future<int> softDelete(String id);
  Future<int> restore(String id);
  Future<int> hardDelete(String id);
}
