// CustomProviderStore：custom_providers.json 的编辑侧契约（GAP-1）。
//
// 与只读的 CustomProviderSource 分离——registry 消费的会话内快照不变，
// 本接口的写操作仅落盘，重启后生效（不做运行时 registry 变异）。
//
// 保真约束：写路径按 raw 条目操作，读侧剔除的非法/未知条目原位保留——
// 编辑一条绝不销毁用户手编的其他条目。文件损坏（不可解析/顶层非数组）时
// 写操作拒绝执行抛 LocalIOError，绝不覆盖用户可能想抢救的文件。

import '../models/custom_provider_config.dart';

abstract class CustomProviderStore {
  /// 全新读盘的合法条目列表（不影响、也不使用会话内快照）。
  Future<List<CustomProviderConfig>> list();

  /// raw 数组中首个 `id` 字段==目标者原位替换；无匹配则追加到末尾。
  Future<void> upsert(CustomProviderConfig config);

  /// 按 `id` 字段匹配删除；无匹配为 no-op。
  Future<void> remove(String id);
}
