# InkFrame 活看板（单一事实源）

> 这是"当前在做什么、做到哪"的唯一速查表。**接下来做什么**(到 1.0 的全部任务卡与决策项)见
> [`MASTERPLAN.md`](MASTERPLAN.md);**怎么做不踩坑**见 [`EXECUTION-PLAYBOOK.md`](EXECUTION-PLAYBOOK.md)。
> 背景分析/行业借鉴见
> [`STATUS-AND-ROADMAP-2026-06-30.md`](STATUS-AND-ROADMAP-2026-06-30.md)（快照，2026-06-30）。
> 旧的散落文档（PROGRESS / ARCHITECTURE-SURVEY / AUDIT-REPORT / PROGRESS-VERIFICATION /
> ROAD-TO-BETA）视为**归档快照**，不再更新；状态以本表为准。
>
> 状态图例：✅ 完成 · 🔵 进行中 · ⬜ 未开始 · 🅿️ 已延后（附因）
> 最近更新：2026-07-08 · 最新发布：**v0.1.0-alpha.10**（release.yml 首跑,双平台 unsigned 产物;
> 待 PG 分发源 PKG-2 + 签名 U1/U2 方为干净机可装）

## M1 —「能用起来」✅ 完成（已随 PR #133 合入 main）

| 功能 | 状态 | 证据 |
|---|---|---|
| 构建解封（重生 freezed + l10n + 修 import） | ✅ | 本地编译/analyze 干净 |
| 偏好持久化（主题/语言/对比度/缩放，重启不丢） | ✅ | `7dfcad6` + 测试 |
| 节点级实时进度 + 高级图像参数（宽高比/负向/种子/批量） | ✅ | `cd61520` + 测试 |
| 画布丝滑（改选中只重建涉及卡片） | ✅ | `b78a608` + 测试 |
| Provider 下拉直读 const（不实例化 9 provider） | ✅ | `a34fb2d` + 测试 |
| 项目重命名 + 删除（软删可恢复） | ✅ | `af5bde6` + 测试 |
| 画布 P0/P1 正确性簇（标题/JobQueue/边守卫/hash/泳道事务） | ✅ | `fe3c6c4`..`1073433` |

## M2 —「创作者要的」✅ 完成（2026-07-02，CI 全绿收官）

> 主体已随 PR #134 合入 main；参考图/首尾帧 UI 收尾（B1–B3 + 连线智能默认 role）随 PR #138 合入。
> 表中 hash 均为 main 主线提交。

| 功能 | 状态 | 优先级 | 备注 |
|---|---|---|---|
| 参考图 / 首尾帧 UI（Provider 已支持，缺界面） | ✅ | P0 | 共享 `NodeInputsSection`（image+video 均挂载，缩略图/role 按 `supportsFirstFrame/LastFrame` 门控/n-max 计数）；连线经画布 link 模式，image→video 智能默认 first_frame（PR #138 B1/B3） |
| 角色一致性（项目级角色参考，自动带入生成） | ✅ | P0 | characters 表/仓储/资产服务 + 生成按能力注入 + Inspector 角色区/存为角色（`528a3e9`/`eda2d7c`）。仅 image 节点、maxRefImages>0 且 imageToImage 生效 |
| 批量 / 变体（生产侧 + 消费侧全链路） | ✅ | P1 | 消费侧骨架（`854124b`）+ 生产侧：提交事务预建 slot 占位、JobQueue 逐 slot 落库、结果节点 Inspector 挂 `BatchResultsGrid`、取消/失败/孤儿收敛。拍板语义：≥1 成即 job success、取消保留已成 slot。经 3 路对抗评审,2×P1+4×P2 全修 |
| 提示词模板 / 预设库 | ✅ | P1 | 项目级 schema_v7 预设库 + Inspector 点选应用/存为预设（`8a28777`） |
| 成本估算 UI（CostModel 已定义，缺消费端） | ✅ | P2 | `estimateCostUsd` + 图像/视频 Inspector 实时预估（`1273522`/`d1dfc46`） |
| 视频 Inspector 接成本 | ✅ | P2 | `d1dfc46`。角色注入 v1 仍仅图像；视频首/尾帧语义已接通——video inspector 挂入边区 + role 切换，控制器建行前校验帧能力位不支持即显式拒绝（PR #138 B1/B2） |
| 文件系统导入参考图（file_selector） | ✅ | P2 | Characters 区「从文件导入」（`94e18ab`）。桌面需开发者模式，与 media_kit 同 |
| CI 烟测 + golden 首跑绿（beta DoD） | ✅ | P1 | run 28595968123 全绿（analyze/test+coverage 70% 闸/golden/secret-scan）。唯一 CI 红为 ME-31 测试自朽（坏迁移 v6 与真实链重号被跳过），已动态化修复 `5d519b7` |

## M3 —「差异化」🔵 起步（骨架设计见 `docs/M3-SKELETON.md`）

| 功能 | 状态 | 备注 |
|---|---|---|
| 分镜 / Shot 节点（脚本→分镜→序列） | 🔵 | Shot 编辑器落地（`3ba33d3`）；**首切片完成**：「用本镜备注生成图像」（shot_notes→image config 节点+narrative 边）+ FAB/空态 shot 创建入口 + addNode typeConfig 透传。后续：脚本解析、镜头级参数、序列预览 |
| 视频导出 / 拼接 | 🔵 | **服务层落地**：`VideoExportService.concat`（项目相对路径进出）→ `FfmpegVideoExportService`（concat demuxer 流拷贝 `-c copy`，不转码，要求输入同编码参数）+ `FfmpegLocator`（INKFRAME_FFMPEG env → PATH 探测，命中缓存）+ 最小 `ProcessRunner` 抽象（fake 可注入）；`FileResolverService.resolveInProject`（项目根边界安全校验，导出落 `exports/`）。**不打包 ffmpeg 二进制**（体积/许可评估延后）：系统有 ffmpeg 才真拼接，没有 → `LocalIOError(reason=ffmpeg_not_found)`。真 ffmpeg 集成测 `@Tags(['ffmpeg'])` TEST_FFMPEG=1 门控。**UI 入口落地**：`features/export`——画布顶栏「导出视频」按钮（无 video result 时禁用+说明 tooltip）→ 导出对话框（按 position.x 升序默认全选、复选/上下移手动排序、输出名本地预校验同 `_assertPlainFileName` 规则、busy 态 indeterminate、成功 snackbar+复制绝对路径、ffmpeg_not_found 专门文案 `exportVideoFfmpegMissing`）；`ExportController` 承担画布相对→项目相对路径换算（补 `canvases/<canvasId>/` 前缀）。后续：narrative 链自动排序、转码/分辨率归一、打包二进制评估 |
| 本地素材 / 产物画廊（借鉴 InvokeAI） | 🔵 | **首切片落地**：`features/gallery`——project 维度只读聚合（result 节点 image_url/video_url + batch_results 成功 slot，`listSuccessByProject` 一次跨画布查询 + 与节点主图同路径去重，createdAt 倒序）→ 网格 UI（图片 tile 走 fileResolver + 图片 lightbox；视频 tile 图标+时长占位）；入口=Studio 项目卡菜单「Gallery」，路由走 `currentGalleryProjectProvider`（同 canvasId 语义）。后续：拖入画布、存为角色、筛选/搜索、视频缩略图/播放、删除；**视频时长需写侧接入**（生成链路不落 result 节点 `duration_ms`，tile 时长当前恒占位）；fake `listSuccessByProject` join 派生列由种子行提供（契约见注释，PG 集成测兜真语义） |
| 模型扩展（自定义 Provider，BYO-key） | 🔵 | **首切片落地**：`custom_providers.json`（逐条校验 + 损坏兜底）→ 协议模板 `openai-image` 派生 capabilities → `OpenAICompatibleImageProvider`(extends SyncProviderBase) → 启动期一次性注册（改 json 重启生效）；key 复用 `provider.custom:<id>.api_key`，设置页/门控/banner 零改动生效。PROVIDER-API §13 已重写为唯一方案，ADR-0009 已修订（2026-07-02）。后续：设置页编辑 UI、运行时增删（registry 变异非 invalidate）、更多协议模板 |
| 定位落地（README/官网：你的数据/Key/工作室） | 🔵 | README 一翼已随 PR #136 落地：双语 README + 真实画布截图/生成 GIF，文案即 local-first/your disk/OS Keychain；官网未动 |

## 近期落地（非里程碑）

| 事项 | PR / commit |
|---|---|
| 内嵌 PostgreSQL 装进 app bundle（macOS+Windows，发布线首件） | #135 |
| 双语 README + 定位文案 | #136 |
| wanx-i2v 对齐 wan2.7 服务端契约（`input.media` 数组；旧 `img_url` 被拒致 i2v 全线 400）+ macOS 标题栏平台惯例 | #137 |
| 参考图/首尾帧 UI 收尾（B1–B3）+ 连线智能默认 role；i2v media×fail-fast 语义整合 | #138 |
| 快修簇：暗色 on-color 对比度（colorScheme+InkButton）/ base64 守卫统一 / 捕获收窄 / 吞错补提示 / 僵尸清理 | #140 |
| M1 补遗四项落地（见下表） | #141 |

## M1 补遗（审计发现的悬空项）

| 项 | 状态 | 备注 |
|---|---|---|
| 记住上次使用的 provider（新节点默认选中） | ✅ | 偏好 `lastImage/VideoProviderId`（按节点类型分记）；默认链=节点已存 > 上次使用（校验仍在能力列表）> first（#141） |
| 重启回上次打开的画布 | ✅ | 偏好记 `lastCanvasId/lastProjectId`；启动 `restoreLastSessionProvider` 校验画布/项目均未软删才恢复，主动回首页即清记录（#141） |
| 画布级重命名/删除 | ✅ | 项目卡菜单「管理画布」对话框，controller 走 canvasRepo update/softDelete（#141） |
| 设置页按钮统一设计系统组件 + onPrimary 暗色 bug | ✅ | onPrimary/onSecondary/onError → surfaceCanvas + InkButton 禁用态（#140）；api_keys 两个 Material 裸按钮换 InkButton（#141） |
| 项目复制 | 🅿️ | 设计已勘明（sprint 级）：需旧→新 id 映射含 nodes JSONB 内引用重写、仓储批量复制能力、projects/{id} 磁盘目录整体复制与失败补偿、jobs/batch_results 取舍拍板；单独立项 |

## 已延后 / 技术债

| 项 | 状态 | 原因 |
|---|---|---|
| T6 生成 N+1（findByIds） | 🅿️ | 接口加方法强制 15 个实现体同步改、收益边际；单独 PR |
| 三大上帝类拆分（JobQueue/GenController/CanvasView） | 🅿️ | 非阻塞但**仍在膨胀**（JobQueue 790→1168 行）；拆分触发线：单文件 >1500 行或并行改动冲突频发 |
| DI 层泄漏 ServerException + 迁移 DDL 编排在 provider body（AUDIT P1-5） | 🅿️ | 影响面小；随 storage 下次改动收口 |
| buildUpdate 无列名白名单（AUDIT P1-11） | 🅿️ | 列名全部来自 core/db/columns.dart 常量，注入面受控；加白名单属加固 |
| components/primitives 双组件族无收敛文档（AUDIT P1-12） | 🅿️ | 需一篇 ADR 定分层规则 |
| InkWindowChrome 直依赖 window_manager（AUDIT P1-13） | 🅿️ | 单点依赖，抽象收益低；随 chrome 重构顺带 |
| 缩略图 300ms 固定延时 + open 无超时（AUDIT P1-16） | 🅿️ | media_kit 行为依赖，需真机回归验证 |
| _PromptPreview 双份拼装（AUDIT P1-17） | 🅿️ | 随 image_config_inspector 拆分处理 |
| JobRepository 胖接口拆分（AUDIT P1-18） | 🅿️ | 与 findByIds 同窗处理 |
| job_queue_panel 手写错误映射与 ink_error messageKey 双源（AUDIT P1-x2，缺 providerInvalidResponse 分支走 unknown 兜底） | 🅿️ | 统一改读 messageKey 映射表，单独小 PR |
| ARCHIVE/footer 死 stub（AUDIT P1-x3） | 🅿️ | 产品定义未决 |
| capabilities.pollTimeout 全仓零消费（AUDIT P1-x4） | 🅿️ | 接入 JobQueue 或删字段，二选一 |
| provider displayName 英文常量（AUDIT P1-7） | 🅿️ | 品牌名不译是有意为之；若要本地化需过 l10n 例外评审 |
| canvas_nodes_controller 乐观新增基于 previous 快照重建（丢更新竞态，VERIFICATION §5.3） | 🅿️ | 需要改并发模型，非一行修；排 M3 稳定期 |
| 未消费依赖卫生（riverpod_annotation/json_annotation/logging/uuid，VERIFICATION §5.4） | 🅿️ | 待 build_runner 卡点解除后一并清（codegen 链相关） |
| 嵌入式 PG `-A trust` 认证（AUDIT 安全附录） | 🅿️ | **调研已完成**（[BLOCKERS-2026-07-06.md](BLOCKERS-2026-07-06.md) §3）：单用户桌面现状与 Postgres.app/Supabase local 同水位,可接受;多用户共享机器是真实边际风险。推荐 SCRAM+随机密码进 Keychain（约 1–2 人日,实施路径已给）;多用户/局域网功能立项即升必须 |
| 补两档设计令牌（图标尺寸/控件高度） | 🅿️ | P2 一致性 |
| **build_runner 全量构建损坏**（analyzer 7.4.5 无法序列化 Dart 3.11 dot-shorthand,riverpod_generator 崩溃挂死;靠 asset graph 缓存掩盖,定向 `--build-filter` 可用） | 🅿️ | **调研已完成**（[BLOCKERS-2026-07-06.md](BLOCKERS-2026-07-06.md) §2）：唯一瓶颈 freezed 3.2.5 与 riverpod_generator 4.0.4 的 analyzer 约束相斥,freezed 3.2.6 stable 一出即与 Riverpod 3 迁移合并立项（同时解掉 custom_lint 卡点,见 §1）;盯 freezed#1353 |
| M2 Inspector 区 widget 级测试——参考图区/角色区/失败提示已补（PR #138）,仍欠预设点选应用与成本文案断言 | 🅿️ | 2026-07-02 审计发现;剩余随 UI 稳定补 |
| characters / prompt_presets 仓储真库 CRUD 集成测试 | 🅿️ | 仅作 UoW 装配件出现;对齐 postgres_repositories_integration_test |
| Inspector/网格 AsyncValue error 态吞没（镜像模式统一改 `.when`） | 🅿️ | 原捆绑的 3 处 `on Exception` 吞错与 `batch_results_grid` 裸 catch 已修（PR #138 B3）,仅剩 error 态展示 |
| 软删项目「可恢复」无 UI 入口（restore/listTrashed 仓储层已就绪） | 🅿️ | 产品面缺口,M3 排期 |
| slot 状态字符串常量化（'generating' 等散落约 10+ 处,全仓既有约定） | 🅿️ | 收口到 core/constants 一次性改 |
