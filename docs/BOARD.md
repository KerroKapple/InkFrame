# InkFrame 活看板（单一事实源）

> 这是"当前在做什么、做到哪"的唯一速查表。详细现状/路线图/行业借鉴见
> [`STATUS-AND-ROADMAP-2026-06-30.md`](STATUS-AND-ROADMAP-2026-06-30.md)。
> 旧的散落文档（PROGRESS / ARCHITECTURE-SURVEY / AUDIT-REPORT / PROGRESS-VERIFICATION）
> 视为**归档快照**，不再更新；状态以本表为准。
>
> 状态图例：✅ 完成 · 🔵 进行中 · ⬜ 未开始 · 🅿️ 已延后（附因）
> 最近更新：2026-07-02

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

## M2 —「创作者要的」✅ 完成（2026-07-02，CI 全绿收官）

> 分支 `feat/m2-creator`（在 PR #133 合并后 rebase 到 main）。

| 功能 | 状态 | 优先级 | 备注 |
|---|---|---|---|
| 参考图 / 首尾帧 UI（Provider 已支持，缺界面） | ✅ | P0 | Inspector `_InputsSection` 已在（看/切 role/删）；连线经画布 link 模式 |
| 角色一致性（项目级角色参考，自动带入生成） | ✅ | P0 | characters 表/仓储/资产服务 + 生成按能力注入 + Inspector 角色区/存为角色（`69be6a9`/`295bf72`）。仅 image 节点、maxRefImages>0 且 imageToImage 生效 |
| 批量 / 变体（生产侧 + 消费侧全链路） | ✅ | P1 | 消费侧骨架（`dfa04e5`）+ 生产侧：提交事务预建 slot 占位、JobQueue 逐 slot 落库、结果节点 Inspector 挂 `BatchResultsGrid`、取消/失败/孤儿收敛。拍板语义：≥1 成即 job success、取消保留已成 slot。经 3 路对抗评审,2×P1+4×P2 全修 |
| 提示词模板 / 预设库 | ✅ | P1 | 项目级 schema_v7 预设库 + Inspector 点选应用/存为预设（`1fe16aa`） |
| 成本估算 UI（CostModel 已定义，缺消费端） | ✅ | P2 | `estimateCostUsd` + 图像/视频 Inspector 实时预估（`d8fc9f3`/`79c45bf`） |
| 视频 Inspector 接成本 | ✅ | P2 | `79c45bf`。角色注入 v1 仅图像（视频首/尾帧语义待接） |
| 文件系统导入参考图（file_selector） | ✅ | P2 | Characters 区「从文件导入」（`1d2f555`）。桌面需开发者模式，与 media_kit 同 |
| CI 烟测 + golden 首跑绿（beta DoD） | ✅ | P1 | run 28595968123 全绿（analyze/test+coverage 70% 闸/golden/secret-scan）。唯一 CI 红为 ME-31 测试自朽（坏迁移 v6 与真实链重号被跳过），已动态化修复 `309902b` |

## M3 —「差异化」🔵 起步（骨架设计见 `docs/M3-SKELETON.md`）

| 功能 | 状态 | 备注 |
|---|---|---|
| 分镜 / Shot 节点（脚本→分镜→序列） | 🔵 | Shot 编辑器（分镜备注）落地 + 接入 router（`8dbf2fa`）；流水线设计见 M3-SKELETON |
| 视频导出 / 拼接 | ⬜ | |
| 本地素材 / 产物画廊（借鉴 InvokeAI） | ⬜ | |
| 模型扩展（自定义 Provider，BYO-key） | ⬜ | 2026-07-02 拍板：`custom_providers.json` 文件存储 + **协议白名单模板**派生 capabilities（PROVIDER-API §13 现稿方向）；开工时重写 §13 为单一方案并小修 ADR-0009 |
| 定位落地（README/官网：你的数据/Key/工作室） | ⬜ | |

## 已延后 / 技术债

| 项 | 状态 | 原因 |
|---|---|---|
| T6 生成 N+1（findByIds） | 🅿️ | 接口加方法强制 15 个实现体同步改、收益边际；单独 PR |
| 三大上帝类拆分（JobQueue/GenController/CanvasView） | 🅿️ | 非阻塞，随功能演进逐步拆 |
| 补两档设计令牌（图标尺寸/控件高度） | 🅿️ | P2 一致性 |
| **build_runner 全量构建损坏**（analyzer 7.4.5 无法序列化 Dart 3.11 dot-shorthand,riverpod_generator 崩溃挂死;靠 asset graph 缓存掩盖,定向 `--build-filter` 可用） | 🅿️ | 根修需升级 freezed/riverpod_generator/custom_lint 主版本至 analyzer≥9,单独立项（2026-07-02 发现） |
| M2 各 Inspector 区 widget 级测试（参考图/预设/角色/成本文案,覆盖停在控制器层） | 🅿️ | 2026-07-02 审计发现;随 UI 稳定补 |
| characters / prompt_presets 仓储真库 CRUD 集成测试 | 🅿️ | 仅作 UoW 装配件出现;对齐 postgres_repositories_integration_test |
| `image_config_inspector.dart` `_importFromFile` 一处 `on Exception` 违规 | 🅿️ | 改捕具体 InkError 子类;顺带清 `batch_results_grid` 裸 catch + AsyncValue error 态吞没(两处镜像模式统一改 `.when`) |
| 软删项目「可恢复」无 UI 入口（restore/listTrashed 仓储层已就绪） | 🅿️ | 产品面缺口,M3 排期 |
| slot 状态字符串常量化（'generating' 等散落约 10+ 处,全仓既有约定） | 🅿️ | 收口到 core/constants 一次性改 |
