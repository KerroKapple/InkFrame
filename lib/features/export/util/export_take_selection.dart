// 导出默认勾选 = 一镜一条：同一 source 节点名下只默认勾**最新**那个 take。
//
// EX-1′ 当年裁定「只改序不改候选集」，于是重跑过的镜在默认导出里重复出现，
// 用户必须手动取消勾选旧 take（BOARD 194）。本文件收的就是这条。
//
// ## 为什么是「最新」而不是「promoted」（这张卡的核心判断）
//
// 直觉上「用户显式转正过的那个该胜过时间上最新的」是对的——但在当前数据模型里，
// promoted **表达不了「哪个 take」**，所以它根本没有参与资格：
//
//   1. **promoted 是 slot 级，不是 take 级。** `batch_results.node_id` 指向的是
//      **容器 result 节点**；`BatchResultsController.promote` 一个事务里做的三件事
//      （写容器的 `image_url`、清**同一容器内**其余 promoted 行、给本行打标）
//      全部局限在一个容器内，`promoted_node_id` 还回指容器自己。它回答的是
//      「这一批四格里交付哪一格」，跨不过容器（= take）的边界。画廊
//      `gallery_meta._chosenArtifactOf` 的注释已经把这个事实记下来了：promoted
//      在 DB 上没有唯一约束，同一 config 重跑两次、两边各自转正就有**两行**
//      promoted，所以它那里取的也是「**最新容器**上的那一个」。
//   2. **导出候选上 promoted 恒不存在。** 批量在
//      `generation_controller.dart` 被硬收口成「仅图片节点」（`nodeType == 'image'`
//      才认 `batch_size`，video 强制单张），slot 占位行也只在 `batchSize > 1` 时建；
//      `promote()` 写的字段是 `image_url`。而导出候选恒为 video result 节点
//      （`exportableVideoNodes`：role=result + type=video + video_url 非空）。
//      ⇒ video take 在数据上**不可能**有 slot。promoted 在这条路径上不是
//      「优先级低」，而是**无定义**。
//
// 「一个镜既有 promoted 又有更新的未转正 take 时选哪个」因此在导出路径上不可达；
// 真要回答它（将来 video 也支持批量时），答案应与画廊同口径：**最新容器胜**——
// 因为「在旧容器里转正某一格」是关于那一批内部的选择，而不是「交付这一条」的声明，
// 而且 promoted 的单选语义只在容器内维持，旧容器上的标记是残留而非活选择。
// 真要让用户钉某个 take 作交付版，需要的是**节点级**的显式标记（新字段/新
// type_config 键 + 一个 UI 动作），不是复用 slot 级 promoted。记 BOARD 待定。
//
// ## 「最新」的判据复用 node_artifacts
//
// 全仓「一镜取哪一个产物」只有一个判官：`canvas/util/node_artifacts.dart` 的
// `resultsFor` / `latestResultFor`。序列播放（`storyboard/util/sequence_builder.dart`）、
// P6 交付计划（经 `SequenceLens`）、画廊的「选定产物」、⌘K 产物组全走它，
// **只有导出默认勾选是漏网的那一处**。所以这里是补齐既有口径，不是发明新规则。
// 顺带继承它那条坑：`listByCanvas` 的 ORDER BY 主序是 `z_index`（用户拖层级就能
// 改列表序），取最新必须按 `created_at` 比，绝不能取候选列表序末位。
import '../../canvas/models/canvas_node.dart';
import '../../canvas/util/node_artifacts.dart';

/// 候选集里「每镜最新 take」的节点 id 集合。
///
/// 两个消费点，同一个事实：
///   - 导出对话框的**默认勾选集**（旧 take 默认不勾）；
///   - 不在集合里的行 = 被更新 take 顶下去的旧 take，UI 给「旧 take」标记。
///
/// 注意这是**默认勾选**，不是候选集：旧 take 照样列在对话框里、照样能手动勾回去。
/// 候选集收窄会让「我就是想导出上一版」变成死路，而默认勾选只是省掉一次手动取消。
///
/// [candidates] 应为 `exportableVideoNodes` 过滤后的集合（本函数不再过滤）。
/// `sourceNodeId` 为 null 的孤儿产物（源 config 已删）彼此之间没有「同一镜」的
/// 依据，**各自成镜、全部入选**——按同一组处理会静默少导出几镜。
Set<String> latestTakeNodeIds(List<CanvasNode> candidates) {
  final selected = <String>{};
  final seenSources = <String>{};
  for (final node in candidates) {
    final source = node.sourceNodeId;
    if (source == null) {
      selected.add(node.id);
      continue;
    }
    if (!seenSources.add(source)) continue; // 这一镜已经定过了
    // 查不到只可能是传进来的节点不满足 resultsFor 的候选条件（非 result /
    // 无产物 url）——那种行本不该出现在导出列表里，退回「勾上它自己」而不是
    // 静默少一行。
    final latest = latestResultFor(sourceNodeId: source, nodes: candidates);
    selected.add((latest ?? node).id);
  }
  return selected;
}
