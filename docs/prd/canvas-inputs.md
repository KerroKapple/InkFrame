# PRD · 画布输入：连线跟随当前 take（B′）

- **状态**：已定稿，待开发（目标：W5 之前落地）
- **决策记录**：[ADR-0016](../adr/0016-data-edges-follow-current-take.md)
- **来源**：2026-11-20 工程审计 G1 / G2 / TOPO-2（`docs/review/2026-11-20-engineering-audit.md`）；TC-Q1 在 2026-11-21 改选 B′
- **取代**：`.worktrees/handoff/briefs/tc-take-edge-follow.md` 的方案 A（任务成功后改写连线）。该派工单按它自己第 6 行的说明作废，改成本文的「生成时解析」

> 这是按模块拆分的活 PRD 的第一篇（索引见 [README](README.md)）。每个功能固定写四节：行为 / 错误态 / 验收标准 / 状态。
> 验收标准带 ID（`IN-…`），对应测试的名字里要写上这个 ID。

## 术语

| 词 | 含义 |
|---|---|
| 配置节点 | 图像 / 视频 / 镜头配置卡，role = config，自身不带产物 |
| take | 配置节点名下的一个产物（role = result 的节点），名下有 N 个就是 take 1…N |
| 当前 take | `固定的 ?? 最新的`：`type_config.pinned_result_id` 指向的产物还在世就用它，否则用名下 `created_at` 最新、且有图或视频的那个。唯一判据是 `lib/features/canvas/util/node_artifacts.dart` 的 `currentResultFor` |
| 输入口 | 目标节点接收上游图的位置，就是数据边的 role：`reference` 参考图 / `first_frame` 首帧 / `last_frame` 尾帧 |
| 解析 | 把一条数据边换成这一次生成实际要用的一张图 |

## 1. 连线接在哪

### 行为

1. 数据边的两端是节点，不是某一个具体的 take：`source_node_id` 存上游节点 id，`role` 存输入口。线上不存 take id。
2. 上游是**配置节点**时，这条线的意思是「跟随它的当前 take」。
3. 上游是**产物节点**（某个具体 take）时，这条线的意思是「钉住这一个 take」。从历史里挑一张旧图来用，或者拿自己的产物做图生图，都走这一种。
4. 「设为当前」只改配置节点自己的 `pinned_result_id`，不改任何连线（与 #324 `SetCurrentTakeCommand` 一致：命令不碰边）。
5. 新出一个 take、删掉一个 take、撤销删除：都不改连线。当前 take 会按判据自然变化。

### 错误态

- 无。连线本身总是合法存储的；能不能用，到生成时再判（见第 2 节）。

### 验收标准

- **IN-1.1** Given 图像配置 A 有 take 1、take 2，A → 视频配置 V 连了一条 `first_frame`；When 对 A 执行「设为当前 · take 1」；Then `edges` 表里没有任何行变化，A 的 `pinned_result_id` = take 1。
- **IN-1.2** Given 同上；When A 又生成出 take 3（未固定）；Then `edges` 表没有任何行变化。
- **IN-1.3** Given A → V 的连线；When 删除 take 2 再撤销；Then `edges` 表没有任何行变化。

## 2. 生成时解析

### 行为

1. 点「生成」时，对目标节点的每一条数据入边各解析一次：
   - 上游是配置节点：取 `currentResultFor` 的结果；看是图还是视频由输入口决定，三个口都要图。
   - 上游是产物节点：取它自己此刻的 `image_url`。
   - 上游是文本节点：不出图，照旧把正文并进提示词，不在本篇范围内。
2. 只在点「生成」的那一刻解析，提交之后上游再出新 take，不影响已经提交的这一次。
3. 解析在一个函数里完成（`InputResolver`，放在 `lib/core/graph/`，纯 Dart）。生成侧（`GenerationController` 取参考图 / 首帧 / 尾帧、写快照）、检查器输入行、参考图计数、角色区配额，都只读它的结果，不再各自去读源节点的 `type_config.image_url`。

### 错误态

| 情况 | 处理 |
|---|---|
| 首帧 / 尾帧解析不出图（上游配置还没有任何成片；上游是视频；钉住的那个 take 已删） | **阻断生成**。「生成」按钮置灰，原因写在那一条输入行上；快捷键 ⌘↵ / Ctrl+↵ 同样不提交，并出一张说明卡。不许悄悄退化成文生视频 |
| 参考图解析不出图 | **也阻断**，与首帧同样处理。理由：用户特意连了参考，跳过它出来的结果和意图不符，而且照样收费 |
| 解析时上游节点读库失败 | 阻断，出错误卡（InkError 文案），记 warn，日志里带 `source_node_id` 和原因 |
| 模型不支持某个输入口（如不支持尾帧） | 维持现状：检查器里不让选这个口，已有的线标「此模型不使用」，不阻断 |

以上任何一种阻断都发生在提交之前：不建 job、不建产物占位、不扣费。

### 验收标准

- **IN-2.1** Given 图像配置 A 有 take 1、take 2（未固定），A → 视频配置 V `first_frame`；When 生成 V；Then 发给服务商的首帧是 take 2 的图，请求模式是图生视频。（这条就是审计 TOPO-2 的回归测试：拿掉解析器要变红。）
- **IN-2.2** Given 同上，A 固定在 take 1；When 生成 V；Then 首帧是 take 1。
- **IN-2.3** Given A 还没有任何 take，A → V `first_frame`；When 点生成；Then 不建 job，生成按钮置灰，输入行写「上游还没有成片」。
- **IN-2.4** Given A → 图像配置 B 连了 `reference`，A 没有 take；When 生成 B；Then 同 IN-2.3，被阻断。
- **IN-2.5** Given 产物节点 R（A 的 take 1）→ V `first_frame`，A 后来出了 take 2；When 生成 V；Then 首帧仍是 take 1（钉住语义）。
- **IN-2.6** Given V 提交后、服务商返回前，A 出了新 take；Then 这一次生成用的仍是提交时解析出的那张。
- **IN-2.7** 检查器参考图计数「N / max」只数解析得出图的线，与角色区配额提醒是同一个数（审计 TOPO-6）。

## 3. 记录这一次用了哪张

### 行为

1. 每个产物的 `type_config.gen_inputs.sources` 里，每条输入记下：输入口、上游节点 id、解析出的产物节点 id、**当时那张图的项目相对路径**。
2. 要记路径而不只是产物 id，是因为产物节点并非不可变：批量「转正」会改写它的 `image_url`（`batch_results_controller.dart` promote）。只记 id 的话，过后就复原不出当时用的是哪张。
3. 老产物没有这些字段，照常显示，不补写（ADR-0007：type_config 是 JSONB，不需要迁移）。

### 验收标准

- **IN-3.1** Given IN-2.1 的场景；When 生成成功；Then V 的新产物 `gen_inputs.sources` 里有一条 `{role: first_frame, source_node_id: A, resolved_result_id: take2, resolved_path: <take 2 的相对路径>}`。
- **IN-3.2** 产物检查器的参数组里显示「首帧 · 来自 A · take 2」，点它定位到 take 2。

## 4. 提交前就能看到会用哪张

### 行为

1. 检查器「输入」区每一行显示**此刻解析出的**那张图的缩略图和 take 号（「A · take 2」；名下只有一个时写「成片」）。上游换了当前 take，缩略图立刻跟着变。
2. 解析不出图的行不显示缩略图，改写原因（与第 2 节错误态同一份文案）。
3. 画布上的连线外观不变。线不画到具体的 take 上，画在两张卡之间。

### 验收标准

- **IN-4.1** Given A → V 首帧，A 当前是 take 2；Then V 的检查器输入行显示 take 2 的缩略图和「take 2」。When 对 A「设为当前 · take 1」；Then 那一行当场变成 take 1，不用重新打开检查器。
- **IN-4.2** Given A 没有 take；Then 那一行显示「上游还没有成片」，没有缩略图。

## 5. 不在本篇范围

- 批量运行时把缺图的上游一起生成（「跑这个 + 缺的上游」）：另见 batch-run-planner。本篇只负责「解析不出来就明确拒绝」。
- 过期标记（上游换了 take 后，下游产物显示「输入已变」）：要靠第 3 节记的数据，单独立项。
- 端口注册表和统一连接规则表（审计 G3，图层阶段 1）。本篇的 `InputResolver` 就是阶段 0，要放在以后那个图层模块里，不要写进 widget 或 controller。

## 6. 变更记录

| 日期 | 变更 |
|---|---|
| 2026-11-21 | 初稿：TC-Q1 定 B′，写下行为、错误态、验收标准 |
