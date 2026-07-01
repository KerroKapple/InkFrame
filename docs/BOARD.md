# InkFrame 活看板（单一事实源）

> 这是"当前在做什么、做到哪"的唯一速查表。详细现状/路线图/行业借鉴见
> [`STATUS-AND-ROADMAP-2026-06-30.md`](STATUS-AND-ROADMAP-2026-06-30.md)。
> 旧的散落文档（PROGRESS / ARCHITECTURE-SURVEY / AUDIT-REPORT / PROGRESS-VERIFICATION）
> 视为**归档快照**，不再更新；状态以本表为准。
>
> 状态图例：✅ 完成 · 🔵 进行中 · ⬜ 未开始 · 🅿️ 已延后（附因）
> 最近更新：2026-07-01

## M1 —「能用起来」✅ 完成（分支 feat/m1-usable，待 PR）

| 功能 | 状态 | 证据 |
|---|---|---|
| 构建解封（重生 freezed + l10n + 修 import） | ✅ | 本地编译/analyze 干净 |
| 偏好持久化（主题/语言/对比度/缩放，重启不丢） | ✅ | `2d5d4ca` + 测试 |
| 节点级实时进度 + 高级图像参数（宽高比/负向/种子/批量） | ✅ | `4bd310b` + 测试 |
| 画布丝滑（改选中只重建涉及卡片） | ✅ | `adf48e6` + 测试 |
| Provider 下拉直读 const（不实例化 9 provider） | ✅ | `bba520a` + 测试 |
| 项目重命名 + 删除（软删可恢复） | ✅ | `3a3c035` + 测试 |
| 画布 P0/P1 正确性簇（标题/JobQueue/边守卫/hash/泳道事务） | ✅ | `6e0f362`..`46a8fe4` |

## M2 —「创作者要的」🔵 进行中

> 分支 `feat/m2-creator`（在 PR #133 合并后 rebase 到 main）。

| 功能 | 状态 | 优先级 | 备注 |
|---|---|---|---|
| 参考图 / 首尾帧 UI（Provider 已支持，缺界面） | ✅ | P0 | Inspector `_InputsSection` 已在（看/切 role/删）；连线经画布 link 模式 |
| 角色一致性（项目级角色参考，自动带入生成） | ✅ | P0 | characters 表/仓储/资产服务 + 生成按能力注入 + Inspector 角色区/存为角色（`69be6a9`/`295bf72`）。仅 image 节点、maxRefImages>0 且 imageToImage 生效 |
| 批量 / 变体（batch_results 表已在，缺 UI） | ⬜ | P1 | |
| 提示词模板 / 预设库 | ⬜ | P1 | base style 预设扩展 |
| 成本估算 UI（CostModel 已定义，缺消费端） | ✅ | P2 | `estimateCostUsd` + Inspector 实时预估（`d8fc9f3`） |
| 视频 Inspector 接成本 / 角色（估算器已支持 PerSecondVideo） | ⬜ | P2 | 角色注入 v1 仅图像；视频首/尾帧语义待接 |
| 文件系统导入参考图（file_picker 依赖） | ⬜ | P2 | v1 角色图源自应用内结果，外部导入为快随 |
| CI 烟测 + golden 首跑绿（beta DoD） | ⬜ | P1 | golden 本地 Windows 假阳性，CI ubuntu 为准 |

## M3 —「差异化」⬜ 未开始

| 功能 | 状态 | 备注 |
|---|---|---|
| 分镜 / Shot 节点（脚本→分镜→序列） | ⬜ | Shot 现仅模型层 |
| 视频导出 / 拼接 | ⬜ | |
| 本地素材 / 产物画廊（借鉴 InvokeAI） | ⬜ | |
| 模型扩展（fal/OpenRouter 式聚合器 或 custom_providers.json） | ⬜ | 已设计未建 |
| 定位落地（README/官网：你的数据/Key/工作室） | ⬜ | |

## 已延后 / 技术债

| 项 | 状态 | 原因 |
|---|---|---|
| T6 生成 N+1（findByIds） | 🅿️ | 接口加方法强制 15 个实现体同步改、收益边际；单独 PR |
| 三大上帝类拆分（JobQueue/GenController/CanvasView） | 🅿️ | 非阻塞，随功能演进逐步拆 |
| 补两档设计令牌（图标尺寸/控件高度） | 🅿️ | P2 一致性 |
