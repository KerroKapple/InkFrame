# ADR-0007: 画布节点用 type × role 双维度建模，参数存 type_config JSONB

- **Status**: accepted
- **Date**: 2026-07-01
- **Deciders**: P9 (Tech Lead)
- **Related**: ADR-0001 (嵌入式 PostgreSQL) / ADR-0003 (Repository 层 Map) / `lib/features/canvas/models/canvas_node.dart` / `lib/storage/schema/001_init.sql`

---

## Context

画布上的"节点"承载多种语义：可编辑的生成配置、生成产物、纯文本、分镜占位。建模方式至少有三种候选：

1. 每种节点一张表 / 一个强类型类，字段各不相同
2. 一张 `nodes` 表 + 每类参数拆成强类型列
3. 一张 `nodes` 表 + 结构化维度（type/role）+ 一个 schemaless 参数袋

**约束：**

- **参数集频繁演进**：图像/视频生成参数会持续增减（如本迭代新增 `seed / negative_prompt / batch_size / aspect_ratio`），schema 每次都改列成本高
- **ADR-0003**：Repository 层暴露 `Map<String, Object?>`，模型转换在 Service 层——节点参数天然适合 Map/JSON 形态
- **ADR-0001**：底层是 PostgreSQL，JSONB 是一等公民（可索引、可 `||` 合并）
- 同一"结构类型"可以有两种"角色"：一个 `image` 节点既可能是**待生成的配置**，也可能是**已生成的结果**

**假设：**

- 节点参数的读写以整体 patch 为主，极少需要对单个参数做 SQL 层查询/约束
- UI 的 inspector 分发只需要 (role, type) 两个维度就能决定

---

## Decision

**决定：** 节点用两条正交维度建模，参数放进 JSONB。

| 维度 | 取值 | 定义 |
|---|---|---|
| `type`（结构类型，`CanvasNodeType`） | `image` / `text` / `video` / `shot` | 节点的结构种类 |
| `role`（角色，`NodeRole`） | `config` / `result` | 可编辑输入 vs 生成产物 |
| `type_config`（参数袋，JSONB 列） | 任意键值 | 该节点的全部参数，无固定 schema |

**理由：**

1. **加参数零迁移**：`nodes.type_config JSONB NOT NULL DEFAULT '{}'::jsonb`，新增参数只是往 JSONB 加键；写路径用 `PostgresNodeRepository.patchTypeConfig` 的 `type_config = type_config || @patch::jsonb` 浅合并（见 `lib/core/interfaces/node_repository.dart` 的 `patchTypeConfig`）。本迭代新增 4 个生成参数**未动 schema**即为红利。
2. **(role, type) 驱动 UI 分发**：`lib/features/canvas/widgets/node_inspector_router.dart` 只对 `role == config` 的节点渲染 inspector，再按 `type` 选 `ImageConfigInspector` / `VideoConfigInspector` / `ShotConfigInspector`；`text` 无 inspector。规则集中一处、穷举清晰。
3. **弱类型的安全阀**：`CanvasNode` 提供类型化 getter（`imageUrl` / `videoUrl` / `durationMs` / `cameraName` / `promptText` / `textContent` / `ignoreLaneStyle` 等）把 JSONB 弱类型收敛到少数受控访问点，widget 不散取字符串键。

> 术语区分：`type` 是**结构类型**；节点标签里展示的 `canvasNodeTypeCharacter/Scene/Camera/Prop/Shot/ImageGen`（l10n）是**语义类型**，属展示层概念，不进 schema。

---

## Consequences

**好的：**

- 生成参数演进与 DB schema 解耦——加 `seed/negative_prompt/batch_size/aspect_ratio` 仅需 UI 写键 + 生成层读键（见 ADR-0009 相关改动），零 migration
- inspector 分发逻辑单点、可穷举；result 节点的 pending/generating/missing 生命周期与 config 节点解耦
- 与 ADR-0003 的 Map-at-edge 一脉相承，测试用内存 Map 直接喂

**坏的 / 欠的债：**

- `type_config` 弱类型：键拼写错到运行时才暴露——靠 `CanvasNode` 的类型化 getter + 测试覆盖收敛
- 无法对单个参数做 DB 层 CHECK/索引（除已有的 `parent_grid_id`/grid 相关 CHECK）；目前不需要
- 参数语义只在代码里，DB 自解释性弱

**中性的（需观察）：**

- 若未来某参数需要跨节点聚合查询，可为其单独提列（JSONB + 生成列并存）
- `role` 目前是 `config`/`result` 两态；若引入更多角色需保持穷举 switch 更新

---

## Alternatives Considered

### 方案 A: 每类节点强类型列
- **优势**：类型安全、DB 自解释
- **否决理由**：每加一个生成参数就要 migration + 改所有实现；稀疏列泛滥；与参数高频演进的现实冲突

### 方案 B: 每种节点一张表
- **优势**：各表干净
- **否决理由**：画布要统一读一批异构节点，跨表 join/多态处理复杂；边（edge）引用节点也变复杂

### 方案 C: 单一 `kind` 枚举，不拆 config/result
- **优势**：模型更少
- **否决理由**：丢掉"可编辑输入 vs 生成产物"的区分，而 inspector 分发与 result 节点生命周期都依赖它

### 方案 D: 参数用 freezed 强类型对象序列化成 JSON 存
- **优势**：类型安全
- **否决理由**：又把 migration 耦合请回来了（改对象=改序列化=旧数据不兼容），恰恰抵消 JSONB 的好处

---

## Revisit Triggers

- 某个 `type_config` 参数需要 DB 层查询/约束/索引时，为其单独提列
- `NodeRole` / `CanvasNodeType` 取值大幅膨胀，穷举 switch 维护成本上升时
- 若引入正式的节点插件（ADR-0011），需重审 type/role 的开放边界
- 至迟在 v0.2.0 Sprint 启动前重审
