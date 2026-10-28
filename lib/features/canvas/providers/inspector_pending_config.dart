// inspectorPendingConfigProvider — 某个配置节点「本地已改、画布节点内存里还没反映」的 type_config 补丁（按 nodeId 分族）。
//
// 为什么要有它（W2 验收 #5）：检查器改服务商 / 画质 / 批量 / 时长只走 InspectorSubmitController.saveConfig
// 写库，不刷新画布节点控制器；提示词条估价读的是内存里的节点，两处金额就对不上。把这份补丁做成可监听的
// 状态，提示词条估价时并进 estimateNodeCost 的 pending——与检查器同一份「已存 typeConfig + 补丁」。
//
// 唯一写入者是同 nodeId 的 [InspectorSubmitController]：saveConfig / 防抖排队 / submit 的终稿发起时合进来
// （每键留最新值，与写入链同一条规则）。提示词条只读，不反过来写。
//
// 落盘成功时**不**清：saveConfig 只写库、不改画布节点内存，清掉就又读回内存里的旧值——那正是本 bug。
// 内存追上来（任务终态 / 预设 / 文本失焦等处让节点控制器重载）之后，补丁里的值与内存相等，并进去不改变任何
// 结果。补丁随控制器一起回收：控制器在 build 里订阅本 provider，选中切到别的节点、控制器没有挂起写入而
// 被 autoDispose 时，补丁一并清掉；有挂起写入（防抖未发射 / 写失败等重试）时控制器自己 keepAlive，补丁也
// 跟着留下——那正是用户还想要、但库里可能还没有的值。

import 'package:flutter_riverpod/flutter_riverpod.dart';

final inspectorPendingConfigProvider = AutoDisposeNotifierProviderFamily<
    InspectorPendingConfig, Map<String, Object?>, String>(
  InspectorPendingConfig.new,
  name: 'inspectorPendingConfigProvider',
);

class InspectorPendingConfig
    extends AutoDisposeFamilyNotifier<Map<String, Object?>, String> {
  @override
  Map<String, Object?> build(String configNodeId) => const <String, Object?>{};

  /// 按键合并（每键留最新值）。唯一调用方是同 nodeId 的 InspectorSubmitController。
  void merge(Map<String, Object?> patch) {
    if (patch.isEmpty) return;
    state = Map<String, Object?>.unmodifiable(<String, Object?>{...state, ...patch});
  }
}
