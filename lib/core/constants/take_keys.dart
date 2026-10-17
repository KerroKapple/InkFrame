// take 相关的 type_config JSONB 键（只是键名常量，无副作用）。
//
// 放在 core 而不放 features/canvas：services 层（项目包导入的 import_remapper 要改写
// 这些键里的节点 id）也要用，services 不能反向 import features。
abstract final class TakeKeys {
  /// 配置节点上「固定为当前」的产物（result 节点）id。缺键 / 非字符串 / 空串 = 没固定，
  /// 当前 take 回落为最新的那个（见 canvas/util/node_artifacts.dart 的 currentResultFor）。
  /// 固定的产物被软删时不清这个键：撤销删除后它自然又是当前。
  static const String pinnedResultId = 'pinned_result_id';

  /// 产物生成时的输入快照。
  static const String genInputs = 'gen_inputs';
}
