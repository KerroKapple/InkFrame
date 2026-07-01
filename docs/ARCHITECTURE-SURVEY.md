# InkFrame v2 架构梳理

> 本文由对 `lib/` 全量 181 个 Dart 文件（+169 个测试）逐层精读后整理，按"自底向上"组织，目的是给一直 vibe coding 的你一张能点开即看的全景地图。
> 生成日期：2026-06-26。

---

## 1. 全景与分层总览

InkFrame 是一个 **Flutter Desktop（macOS + Windows）AI 图像/视频生成工具**：用户在一张"节点画布"上摆放节点、用泳道管理风格、在右侧检查器里配置参数并提交，后台经统一的 Provider 适配器调外部 AI API（Gemini / OpenAI / Stability / 快手 Kling / 阿里万相），产物落盘后回写节点。数据全部存在**进程内嵌的 PostgreSQL**里。

### 依赖方向（上层依赖下层的"抽象"，绝不碰具体实现）

```
┌─────────────────────────────────────────────────────────────┐
│  features/  (UI 垂直切片)                                       │
│  studio (落地外壳) · canvas (画布) · generation (生成编排) · settings │
│        │  只 import core/interfaces + core/models + theme       │
│        ▼                                                        │
│  ───────────────  Riverpod DI (core/di/*)  ───────────────     │  ← 唯一接线层
│        │  把每个抽象绑定到具体实现                                  │
│        ▼                                                        │
│  core/interfaces (16 个抽象契约)   core/models (freezed 领域模型)  │
│        ▲                  ▲                  ▲                  │
│        │ 实现              │ 实现              │ 实现             │
│  storage/(PG 仓储)   providers/(AI 适配器)   services/(运行时服务) │
│        │                                                       │
│        ▼                                                       │
│  core/foundation: errors(InkError) · db(columns/row) · paths · logging · constants │
└─────────────────────────────────────────────────────────────┘
        theme/ (设计令牌 + 组件) 与 l10n/ 横切供整个 features 消费
```

**核心纪律**：features 层从不 `import` 具体的 `Postgres*Repository` / 具体 Provider，全部通过 Riverpod provider 拿抽象接口（DIP / SOLID-D）。这条在绝大多数层都守住了——是这个 vibe-coded 项目里最让人意外的优点。

### 层职责速查表

| 层 | 职责 | 量级 |
|---|---|---|
| `main.dart` / `app.dart` | 启动、ProviderContainer、退出回收、MaterialApp 路由/主题 | 2 文件 |
| `core/di/` | 唯一接线层：抽象→实现绑定，全 app-scoped keepAlive | 16 文件 |
| `core/`(foundation) | 常量 / DB 列名与行解码 / 路径 / InkError 密封类 / 日志 | 9 文件 |
| `core/interfaces/` | 仓储/服务/Provider 抽象契约（DIP 的抽象侧） | 16 文件 |
| `core/models/` | freezed 不可变领域模型（能力/任务/状态/计费） | 5 文件(+gen) |
| `storage/` | 内嵌 PG 生命周期 + 迁移 v1–v5 + 7 个仓储 + UnitOfWork | 18 文件 |
| `providers/` | 9 个 AI 适配器 + registry + 限流 + dio 错误映射 + 2 基类 | 14 文件 |
| `services/` | JobQueue 调度状态机 + 文件解析 + 下载/缩略图/播放器/安全存储 | 7 文件 |
| `theme/` + `l10n/` | 设计令牌 / Ink* 组件 / 主题扩展 / 本地化（219 键 zh=en） | 21 文件 |
| `features/canvas/` | 画布：模型+几何工具 / Riverpod 控制器 / 外壳与节点 widget | 43 文件 |
| `features/generation/` | 生成流水线编排 + job 状态镜像 | 7 文件 |
| `features/settings/` | API Key / 主题 / 语言 / 路径 / 关于 五个设置分区 | 7 文件 |
| `features/studio/` | 项目库落地外壳 + 打开画布 | 10 文件 |

---

## 2. 逐层精讲（自底向上）

### 2.1 入口与 DI 接线（`main.dart` / `app.dart` / `core/di/`）

**职责**：启动序列与"把每个抽象绑定到实现"的纯接线层。

- `lib/main.dart` — 初始化 binding/MediaKit/window_manager → 预建 `AppPaths` → **显式构造 `ProviderContainer`（override `appPaths`）** → 显示窗口前注册关闭/Cmd+Q 退出路径（防 PG 孤儿进程）→ `runApp`。
- `lib/app.dart` — `MaterialApp` 装配主题/locale/toast messenger，顶层 shell 三向路由 canvas/studio/settings，订阅系统亮度。
- `core/di/database.dart` — PG 三层 provider：`binaryLocator → pgController → pgPool → pgMigratedPool`（建 pgcrypto + 跑迁移）。
- `core/di/providers.dart` — 把 9 个 AI Provider 工厂注册进 `CachingProviderRegistry`，统一 keySource（SecureStorage）+ 每 provider 一个 RateLimiter。
- `core/di/repositories.dart` — 7 个仓储 + `unitOfWorkProvider`，全绑 `pgMigratedPool`。
- 其余 `clock / locale / logger / theme / secure_storage / thumbnail / video_*` 各注入一个抽象。

**亮点**：全部 app-scoped keepAlive（连接/HTTP/仓储该 app 级），异步资源走 `FutureProvider`，生命周期用 `ref.onDispose` 覆盖 pgController/pool/dio/logger/限流器；`appPathsProvider` 用"默认抛异常 + 强制 override"守门。

**问题**：
- 🔴 **真实 UX bug** — `app.dart:79` `CanvasScreen(canvasName: context.l10n.canvasDefaultName)`，无论打开哪个画布，标题永远是本地化的"默认名"，真实画布名被丢弃。
- ⚠️ `core/di/secure_storage.dart:28` `catch (_)` 吞所有异常（违 InkError 规则）。
- ⚠️ `database.dart:80-95` 把 `CREATE EXTENSION` + 迁移编排塞进"纯接线"provider body，并让 postgres 的 `ServerException` 类型泄漏进 DI（未映射成 InkError）。
- ⚠️ locale / theme / 高对比度 **全是内存态无持久化**，重启即丢（已自认 TODO）。
- 🟡 `Clock`/`SystemClock` 定义在 `logging/logger_service.dart` 却由 `di/clock.dart` 暴露，时钟与日志耦合。
- 🟡 多个 provider 漏传 `name:`，devtools 风格不统一；`app.dart` studio 分支裹 Scaffold、其余不裹，归属不一致。

### 2.2 Core foundation（常量 / DB 辅助 / 路径 / 错误 / 日志）

**职责**：无 Flutter 依赖（除少量 `@immutable`/平台判断）的横切原语。

- `core/errors/ink_error.dart` — **`InkError` 密封类层级**：6 个子类 `ProviderError / NetworkError / DownloadError / LocalIOError / CancelledError / UnknownError`，`InkErrorCode` 枚举（15 个 code，每个带 `wire` 串与 DB 列对齐），加 `kInkErrorMessageKeys`（code→ARB key）与 `_retryable`（可重试白名单）。设计扎实：assert 守卫不变量、`toLogJson()` 不含 cause 防泄漏。
- `core/db/columns.dart` — 每张表 snake_case 列名常量（`*Col` 类），由 pg 测试对真库 information_schema 校验。
- `core/db/row_reader.dart` — `Map<String,Object?>` 的 `DbRow` 扩展，类型安全列解码，失配抛 `LocalIOError`。
- `core/paths/app_paths.dart` — 文件系统路径单一出口（`AppPaths` 抽象 + `DefaultAppPaths`，`~/InkFrame/...`）。
- `core/logging/logger_service.dart` — 同步 JSON 行日志：轮转 / 磁盘预算回收 / 递归脱敏。
- `core/constants/*` — 默认 provider、job 清理策略、SecureStorage key 构造、快捷键文案。

**问题**：
- ⚠️ `InkErrorCode` 与各子类 assert、`_retryable`、`kInkErrorMessageKeys` **四处分散维护**——新增一个 code 要同步改 4 处，漏改 assert 运行期炸、漏改 map 触发 `!` NPE。
- 🟡 `secure_storage_keys.dart` 的 DashScope 家族成员集合与 `provider_registry` 注册表重复列举，漂移会导致用错 scope。
- 🟡 `shortcut_labels.dart` import `flutter/foundation`，破了"无 Flutter 依赖"的层定位（本质是 UI 文案）。
- ✅ 无可变模型、无 `catch(Exception)`、无全局单例；i18n 闸门有编译期测试。

### 2.3 Core contracts（抽象接口层）

**职责**：整个 app 依赖的抽象契约（DIP 的抽象侧），上层只 import 这些 `abstract class`。

- **教科书式 ISP**：`generation_provider.dart` 不是一个胖接口，而是拆成 4 个正交抽象 `Submittable`（必实现）/ `Pollable`（仅异步）/ `Cancellable`（仅支持取消的）/ `KeyValidatable`，消费侧用 `is Pollable` 判断转型。
- 7 个仓储接口 + `unit_of_work.dart`（`UnitOfWork.run` + `RepositoryScope`）+ secure_storage / thumbnail / video_download / video_player / provider_registry。

**问题**：
- ⚠️ **`JobRepository` 最接近胖接口**（10 方法）：把 CRUD + 状态机（transition/bulkTransition）+ 保留期 GC（purgeExpired/purgePerCanvasCap）三种职责混一起，可拆 `JobRetentionPolicy`。
- ⚠️ **契约不对称**：`StyleLaneRepository` 有 softDelete 却**缺 hardDelete**，而 canvas/node/edge 都齐；`RepositoryScope` 只含 nodes/edges/canvas/projects/jobs，**漏 batch_results 和 style_lanes** → 事务空洞（见 2.5）。getter 命名 `canvas` 单数、其余复数。
- 🟡 所有仓储 `create` 强类型具名参数，紧接一个 `update(id, Map<String,Object?> patch)` 又把类型安全泄掉（列名/类型错只能运行期炸），类型化没贯到契约边界。
- 🟡 `Cancellable` 接口**全仓无人实现**（所有 provider `supportsCancellation=false`）——接口存在但无落地。

### 2.4 Core models（freezed 领域模型）

**职责**：生成流水线的核心不可变模型，全 freezed。

- `provider_capabilities.dart` — Provider 能力声明（编译期 const 唯一事实源），含 5 个枚举 `ProviderRegion/GenerationMode/AspectRatio/Resolution/CameraMovement` + 24 个能力字段。
- `generation_task.dart` — 提交给 `Provider.submit` 的任务输入。
- `job_status.dart` — **sealed** `Provider.poll` 单次三态 `inProgress/success/failure`（注意：与持久化的 `jobs.status` 不是同一枚举）。
- `key_validation_result.dart` — **sealed** Key 校验三态（valid/invalid/networkError，刻意把网络错误剥离）。
- `cost_model.dart` — **sealed** 统一计费口径。

**问题**：
- ⚠️ `cost_model.dart ↔ provider_capabilities.dart` **循环 import**（cost 只为拿 `Resolution`）；共享枚举应抽到独立 `enums.dart`。
- 🟡 5 个模型**均无 `toJson/fromJson`**——序列化逻辑落在仓储层，枚举名↔DB 值一致性靠人工纪律（`CameraMovement.static_` 尾下划线、`Resolution.p720/k4` 这类映射易漂移）。
- 🟡 `GenerationTask` 的 `projectId/canvasId/resultNodeId` 为测试便利声明可空（"生产必填、单测可 null"），落盘前为 null 会在 IO 层才炸。

### 2.5 Storage（内嵌 PostgreSQL）

**职责**：PG 生命周期 + 版本化迁移 + 参数化仓储 + UnitOfWork 事务。

- `pg_controller.dart` — 嵌入式 PG 进程生命周期（initdb/start/stop/崩溃恢复/端口分配），`PgProcessRunner` 可注入。
- `pg_binary_locator.dart` — 三级策略定位 PG 二进制（环境变量→Bundle→源码）。
- `base_repository.dart` — 仓储共享 mixin：`guard`（`PgException`→`LocalIOError`）、`withUpdatedAt`/软删/恢复 patch、`buildUpdate` 通用 UPDATE。
- `postgres_unit_of_work.dart` — 基于 `runTx` 的事务工作单元（DIP：自身不 new 仓储，靠注入工厂装配 scope）。
- `migrations/` + `schema/v1–v5` — 单调版本化迁移，逐条独立事务 DDL+版本 UPSERT，含 `SchemaDowngradeError`（旧应用打开新库给友好提示）。
- 7 个 `postgres_*_repository.dart`。

**schema 演进**：v1 建全部 8 表（含软删、长度/九宫格 CHECK）→ v2 改 `jobs.result_node_id` FK 为 SET NULL → v3 edges 改部分唯一索引（修复删边重连撞 23505）+ 删死列 → v4 删死列 next_poll_at（恢复语义=重启即 cancel）→ v5 加 `(canvas_id, created_at DESC)` 复合索引。

**问题**：
- 🔴 **`columns.dart` 常量名存实亡**：仓储 SQL 的列名/表名**几乎全是裸字符串字面量**（如 `postgres_canvas_repository.dart:23`），常量只在 base_repository 的 patch 辅助里用到。typo 防护只覆盖一半，且表名在 SQL 与 `guard()`/`buildUpdate()` 第二参里**双写**易漂移。
- ⚠️ **动态 UPDATE 列名字符串插值**（`base_repository.dart:84` `'$k = @$p'`）：值参数化了但 **key 未对白名单校验**，若 patch key 来自外部输入即注入点。当前 key 来自内部模型，安全但"参数化做了一半"。
- ⚠️ **事务边界缺口**：`RepositoryScopeData` 不含 batch_results/style_lanes，"promote batch slot 为正式 node"这类跨表原子写无法走 UnitOfWork。
- 🟡 jobs/edges/batch_results 因无 `updated_at` 各自重写了几乎相同的 patch 循环（三处重复）；`node_repository` 用 `replaceAll` 字符串替换打 jsonb cast（脆，违"不要 patch around"）。
- 🟡 普遍 `SELECT *` + 返回裸 Map（加列鲁棒、删列/重排 brittle）；`.sql` 文件与 `.dart` 真相源双源可能漂移。
- ✅ 全层无泛型异常捕获（只捕 `PgException`/`ServerException` 翻成 InkError）、无连接泄漏、迁移原子性正确。

### 2.6 AI Provider 适配器

**职责**：把异构第三方 API 收敛到 `Submittable/Pollable/KeyValidatable` 接口族，经 registry 暴露。

- 两个基类（模板方法）抽走共性：`sync_provider_base.dart`（同步图片：限流+key+本地 `local://` jobId+inlineBytes 暂存）；`dashscope_async_provider_base.dart`（异步：submit→task_id→轮询状态机+本地图转 base64+阿里错误码映射）。
- 同步：Gemini / OpenAI / Stability（3 家只剩请求体构造+解码）。异步：4 个 WanX + 2 个 Kling（只填 endpoint/buildRequestBody/parseSuccessOutput）。
- `provider_registry.dart` `CachingProviderRegistry`、`rate_limiter.dart`（token bucket）、`dio_error_mapper.dart`（DioException→InkError + 脱敏）。

**亮点**：✅ 无硬编码 Key（全走 SecureStorage，Gemini 还把 key 放 header）；✅ 无 prompt 被 i18n（用户输入透传，endpoint/model 是英文 const）；✅ 错误全走 InkError + body 脱敏；"换 API = 换 key" 抽象贯彻到位。

**问题**：
- ⚠️ **能力声明与提交路径未对齐**：`wanx_image_provider.dart:90` `maxRefImages=1` 但 `buildRequestBody` 塞全部参考图未 `.take(1)`（R2V/Omni 都裁了）；`batchSize` 未 clamp。
- ⚠️ DashScope 异步基类 `submit` **完全不校验** mode∈capabilities.modes / prompt 非空 / duration∈supported，全透传等服务端报错；而同步基类有校验。
- 🟡 `pollInterval/pollTimeout` 是**死配置**（9 个 provider 全 null，实际落在 JobQueue 默认值）。
- 🟡 `listCapabilities()` 为读编译期 const 能力**强制实例化全部 9 个 provider**（连带 9 Dio + 9 限流器），UI 下拉首建即触发。
- 🟡 同步 `inlineBytes` 仅在内存 Map，submit 与 poll 间 app 重启则 `local://` 任务必 cache miss（脆）；provider `displayName` 描述性后缀（"Text-to-Video"）未走 ARB。

### 2.7 App services（运行时服务）

**职责**：把"提交→调度/轮询/落库→下载→抽缩略图→回写节点→退出清理"全链路编排，以及路径解析/安全存储。

- `job_queue_service.dart`（791 行）— **JobQueue 内存调度器**：状态机 `pending→submitted→polling→{success/error/timeout/cancelled}`，每次转移走 `transitionStatus(fromStatuses,...)` 做乐观并发守卫；**双层并发**（全局 `_globalConcurrency`=2 + 每 provider `maxConcurrentJobs`）；可中断退避轮询（指数退避+jitter，cancel/dispose 立即唤醒）；`init()` 启动把遗留 job 全 cancel。
- `file_resolver_service.dart` — 相对↔绝对路径，防穿越/盘符/控制字符。
- `dio_video_download_service.dart` — 流式落盘，校验 https/2xx/非空/content-type/2GiB 上限。
- `media_kit_thumbnail_service.dart` / `media_kit_video_player_service.dart` / `platform_secure_storage_service.dart` / `app_teardown.dart`（有序幂等回收）。

**问题**：
- 🔴 **JobQueue 是上帝编排器（违 SRP）**：调度+状态机+inlineBytes 落盘+remoteUrls 下载+缩略图+节点 patchTypeConfig 全揉一类。`_persistInlineBytes`/`_persistRemoteUrls` 应抽成独立 `ResultMaterializer`。
- 🔴 **用生产代码探测"单测路径"是正确性风险**：`_persistInlineBytes`/`_persistRemoteUrls` 在 projectId/canvasId/resultNodeId 任一为空时**静默 return null 当成功**——真实任务若因上游 bug 缺 ID，产物被悄悄丢弃、节点不更新、job 仍标 success。
- ⚠️ 缩略图靠固定 `Future.delayed(300ms)` 等解码（慢机抽黑帧，flaky）；`player.open` 无超时遇损坏文件可能永久 await；下载无显式流超时（依赖注入的 Dio 是否配）。
- ⚠️ 多处 catch-all（thumbnail `catch(e)`、teardown 两处 `on Object`）。
- 🟡 `_globalConcurrency` 是 final，"性能档位联动"未接线；`toRelative` 隐式依赖 `Directory.current` 全局态。
- ✅ FileResolver 穿越防御全面、SecureStorage extra 不带明文、cancel 竞态裁决（affectedRows）+ handle 必终结处理细致。

### 2.8 Presentation foundation（设计令牌 / 主题 / 组件 / i18n）

**职责**：用语义化令牌 + ThemeExtension + Ink* 组件落地"零硬编码样式/字符串"。

- `tokens.dart` — 唯一允许裸色值的文件：`InkPalette`/`InkColors`(dark/light/highContrast 三态工厂)/`InkSpacing`/`InkRadius`/`InkShadow`/`InkMotion`。
- `typography.dart`/`motion.dart`/`app_theme.dart`（`AppThemeExtension` + `context.inkColors/inkTypography`）。
- `components/`（InkButton/Card/Input/...）与 `primitives/`（InkAmberButton/NoirCard/CompactTextField/...）。
- `l10n/` — `context.l10n` 扩展 + `l10nError` + 生成 delegate，**219 个真实键 zh=en 完全对齐**。

**问题**：
- 🔴 **components/ 与 primitives/ 是两套并行实现**（最大架构异味）：按钮（`InkButton.ghost`≈`InkGhostButton`、CTA≈`InkAmberButton`）、卡片（`InkCard`≈`InkNoirCard`）、输入（`InkInput`≈`InkCompactTextField`）全重叠，"低层/高层"分层在代码里不成立，是新旧两版并存。应收敛为单一组件族。
- ⚠️ **令牌缺"图标尺寸"和"控件高度"两档**，导致几乎每个组件散落裸数字（icon 14/16/18、高度 28/36/44/56）；`ink_button` 还拿 `InkSpacing.md` 当 icon 尺寸（语义误用）。
- 🟡 多处裸 `Colors.transparent`/`Color(0x00000000)`；`ink_window_chrome.dart` 把 `window_manager` 平台调用塞进主题层（违 DI），且是唯一 import l10n 的主题件。
- ✅ 令牌定义层（tokens/typography/app_theme/l10n）干净合规，i18n 键集对齐、无硬编码用户文案、a11y 缩放链路完整。

### 2.9 Feature: Canvas — data（模型与几何工具）

**职责**：画布领域模型（node/edge/lane）+ 纯函数几何工具。

- `models/canvas_node.dart`（221 行）— 节点 UI 模型，`type: {image,text,video,shot}`、`role: {config,result}`、`typeConfig: Map`（JSONB 镜像）+ 一堆派生 getter + `fromRow`。
- `models/canvas_edge.dart` / `models/style_lane.dart` — 连线 / 风格泳道。
- `util/` — `edge_hit_test`（点到线段命中）、`lane_geometry`（布局/重排）、`lane_tint`（中英词表推断泳道色）、`node_position`（Random 注入可测）、`base_style_presets`（7 条英文 prompt 常量）、`canvas_job_effects`（纯函数 diff 判定是否重拉+收集 toast 错误）。

**问题**：
- ⚠️ **违"ALL models use freezed"**：三个模型都是手写 `@immutable`+手写 `==`/`hashCode`/`copyWith`（`style_lane.dart:1` 注释明说不引 freezed）——已知刻意偏离但未在规则文档登记例外。
- ⚠️ **hashCode/equals 契约疑似破坏**（`canvas_node.dart:139` vs `:153`）：`==` 用 `mapEquals`（顺序无关），`hashCode` 用 `Object.hashAll(entries)`（依赖 Map 顺序），内容相等但插入顺序不同 → `a==b` 但 hash 不等，作 Set/Map key 不可靠。
- 🟡 `typeConfig` 可变 Map 仅 fromRow 路径走 unmodifiable，普通构造/copyWith 不防御复制（可变性泄漏）；size 默认值两套魔法数（构造 200×160 vs fromRow 240×240）；`lane_tint` 5 组 `#RRGGBB` 硬编码绕过令牌；`canvas_job_effects` 反向依赖 generation/models（跨 feature 耦合）。

### 2.10 Feature: Canvas — state（Riverpod 控制器）

**职责**：把"一张画布"的运行时状态拆成单一职责控制器，统一"乐观更新+失败回滚"流回 repository。

- DB-backed：`canvas_nodes_controller` / `canvas_edges_controller` / `canvas_lanes_controller`（`AutoDisposeAsyncNotifierFamily`）。
- 纯 UI 态：`canvas_selection` / `selected_edge` / `link_mode` / `lane_collapse`。
- 编排：`link_action_controller`（读 linkMode→写边→产事件）、`inspector_submit_controller`（四态提交+防抖存盘）、`canvas_bootstrap`（dev 建样例）。
- `current_canvas_id`（唯一非 autoDispose 的 app 级态）、`canvas_base_style`、`playable_video_path`。

**亮点**：✅ D 原则在本层成立（只 import `core/interfaces`，无直接 import Postgres 仓储）；`removeNode` 用 UnitOfWork 事务级联软删边是规范样板；nodes/lanes 用 `_alive` 守卫防 dispose 后写 state。

**问题**：
- ⚠️ **`canvas_edges_controller` 缺 `_alive` 守卫**：头注释自称"与 nodes 对齐"，但 addEdge/removeEdge/updateRole 在 await 后无条件写 state，autoDispose 期间被 dispose 会抛 StateError（潜伏 bug）。
- ⚠️ **"乐观更新"注释名不副实 + 回滚是死代码**：addEdge/addNode 实际是 `await create` **成功后**才改 state，catch 里 `state=AsyncData(previous)` 设回从没变过的值——回滚分支 dead code。真正乐观的只有 remove/move。
- ⚠️ **`reorderLanes` 非事务**：循环逐条 `await update`，中途失败时 DB 半重排、内存整体回滚，二者漂移（应走 UoW，对比 removeNode 就用了）。
- 🟡 `inspector_submit` 的 `saveConfig` 用 `catch(_){}` 吞所有异常；`setBaseStyle`/`setLaneDirection` 是裸顶层函数吃 WidgetRef（与全员 Notifier 模式割裂）；`updateRole` 用魔法字符串列名 `{'role':...}`；删除节点/边不自动清选择态。

### 2.11 Feature: Canvas — shell widgets（外壳/泳道/边渲染）

**职责**：画布视觉脚手架与编排，数据获取全委托 controller。

- `canvas_screen.dart` — Scaffold + 左栏 56 / 中央 CanvasView / 右栏 320 渲染队列 + FAB。
- `canvas_view.dart`（**779 行，本层最重**）— viewport + 节点 tap 语义 + InteractiveViewer 4000×4000 舞台 + 泳道/边/Inspector 全编排。
- `edge_painter.dart` / `lane_background.dart`（两处 CustomPainter，几何外移到 util）、`canvas_top_chrome` / `left_toolbar` / `add_node_fab` / `empty_state` / `render_queue` / `lane_title_bar` / `lane_toolbar` / `lane_edit_dialog` / `canvas_job_listener`（副作用/决策分离的范例）。

**问题**：
- 🔴 **`canvas_view.dart` 779 行巨型 + 业务下沉**：`_CanvasStage.build` 单方法读 5+ provider、命中测试、六层 Stack；`_buildLaneTitleBars`/`_buildResizeDividers` 百行 helper 里塞了拖拽重排/resize/落点判定等**业务编排**（widget 里直接算 `laneIdAtPoint`→`moveNode`/`reorderLanes`）。应把泳道交互下沉到 controller。
- ⚠️ **大面积硬编码裸尺寸**：右栏 320、画布 4000（在 6 处重复）、minScale 0.1/maxScale 3.0、titleBar 32/200、删除按钮偏移、各处 icon size 14/16/18、`alpha:0.35` 等，散落几乎每个文件，违"零硬编码样式"。
- 🟡 `lane_edit_dialog.dart` 的 `_kLaneSwatches` 5 个 `#RRGGBB` **复刻** lane_tint 的色组（重复声明+硬编码）；`canvas_render_queue` 拼 `·`/`▾` 装饰字符；`add_node_fab` 与 `empty_state` 各自实现几乎一样的 `_pickPosition`+`_addNode`；build 里每帧线性扫 nodes/edges（重计算）。
- ✅ `edge_painter`/`lane_background`/`lane_title_bar`/`canvas_job_listener`/`canvas_render_queue` 几个小 widget 干净、令牌/i18n 合规。

### 2.12 Feature: Canvas — node & inspector widgets

**职责**：每个节点的卡片主体 + 右侧按类型分发的参数检查器（驱动生成）。

- `node_card.dart`（380 行）— **真实节点卡**：选中/连线/删除手势、拖拽、按 role/type 选 body。
- `node_inspector_router.dart` — 按 `node.type` 分流到 image/video 检查器。
- `image_config_inspector.dart`（451 行）/ `video_config_inspector.dart`（282 行）— 收集 prompt/provider/分辨率/时长/镜头 → 打包 Map 交给 `inspectorSubmitController.submit`。
- `inspector_status_panel.dart`（共用四态视图）、`base_style_editor_dialog`、`video_lightbox`、`video_node_body`。

**问题**：
- 🔴 **`canvas_node_card.dart` 是僵尸代码**：文件头自述"仅视觉、不接数据流、未来视觉基线"，grep 确认**生产无任何引用**（仅自身测试 + 一份 plan 文档）。它还定义了一个**同名** `enum CanvasNodeType { character, scene, camera, prop, shot, imageGen }`，与真实模型的 `CanvasNodeType {image,text,video,shot}` **语义完全不同**、只靠 import 区分，是命名污染地雷。**建议删除**。
- ⚠️ **`_PromptPreview`（image_config_inspector.dart:365）既取数又渲染又计算**：build 里 watch 4 个 provider + 过滤 data-edge + 调 `assemblePrompt` 拼预览——这段拼装与 `GenerationController` 真正提交时的拼装是**两套并行实现**，有 drift 风险，应抽到 controller 暴露"预览串"。
- ⚠️ **两个 Inspector 结构同构复制粘贴**（initState 解析/`_selectedCaps`/下拉 onChanged/`_submit` 仅字段从 resolution 换 duration/camera）；`node_card._ResultBody` 与 `video_node_body` 的占位/解码状态机高度重复。
- 🟡 散落硬编码尺寸；`video_lightbox.dart:164` 用裸 `TextStyle(color:...)` 绕过排版 token。
- ✅ router / status_panel（sealed exhaustive switch + ARB 映射）/ lightbox（防抖、可测）干净。

### 2.13 Feature: Generation（生成流水线编排）

**职责**：把"config 节点→提交→result 节点"串成 fire-and-forget 流水线，并把 job 状态镜像到 UI。

- `generation_controller.dart`（645 行）— 编排核心：校验 config 节点→取 Key→**uow.run 单事务**预创建 result 节点+jobs 行→组 prompt+参考图→`queue.submit`→`unawaited(_track())` 后台推状态机→失败带 1 次重试清孤儿。
- `models/job_state.dart` — **freezed sealed** 6 态（queued/submitting/running/succeeded/failed/cancelled）+ 派生 getter，widget 零业务逻辑。
- `providers/jobs_registry.dart` — keepAlive 内存镜像 `List<JobState>`，按 jobId upsert，超限剔除。
- `services/prompt_assembler.dart` — 纯函数五段拼接（PRD §7.4）。
- `services/toast_service.dart` — 无 BuildContext 的 Toast 出口（GlobalKey）。
- `widgets/job_queue_panel.dart` — 右侧队列面板。

**亮点**：✅ prompt 拼接是用户数据非代码常量（不违 i18n）；✅ toast 文案由调用方传入已 l10n 的串（service 不感知 ARB）；job_state 双状态机设计（UI 聚合态 vs provider 瞬时态）有意为之。

**问题**：
- ⚠️ **控制器职责过载**：645 行单类承担节点校验/枚举解析/Key/prompt 编排/参考图解析/关联文本/建行/submit/追踪/孤儿清理。`_assembleFullPrompt`/`_resolveRefImages`/`_resolveAssociatedTexts`（从节点图谱聚合上下文）可抽成 `GenerationContextResolver`。
- ⚠️ **`GenerationError` 游离于 InkError 体系**（自定义 sealed 实现 Exception，未纳入 InkError）；`_track:413` 和 submit 补偿块 `:311` 用裸 `catch(e,st)`（catch-all）。
- 🟡 取消逻辑不对称：`job_queue_panel:259` 直接 `queue.cancel` 绕过 controller，重试走回调；面板 `_errorMessage` 把 InkError.messageKey 手写 switch 映射 14 个 ARB key（新增 code 必须同步改，隐式契约）。

### 2.14 Feature: Settings

**职责**：API Keys / 主题 / 语言 / 路径 / 关于 五个分区组合，单 key scope 的"读存在性+写校验"收进一个状态机。

- `settings_screen.dart`（51 行薄壳）+ 5 个 section + `api_key_scope_controller.dart`（`AutoDisposeFamilyAsyncNotifier<bool>`：exists/save/validate/clear，DashScope 6 款折叠一把 Key）。

**亮点**：✅ **API key 落盘路径干净**——写读删一律经 `SecureStorageService` 接口，无任何落代码/配置/DB 痕迹；校验逻辑（取 Provider→validateApiKey→落盘决策）全在 controller，widget 只 read+toast；section 职责单一；i18n 覆盖好。

**问题**：
- 🟡 `api_keys_section.dart:177` 直接用 Material `FilledButton`/`OutlinedButton`，而同目录其余 section 一律用 `InkButton`（违"Components Over Primitives"，风格不统一）。
- 🟡 散落 magic number（`width:160`、`12×12`、`width:56`）；`about_section.dart:48` 探活用裸 `catch(e)`。

### 2.15 Feature: Studio（项目库落地外壳）

**职责**：用户进入 app 的落地外壳——项目库首屏、侧栏、建项目、跳画布、provider 未配置软提示。

- `studio_home_screen.dart`（458 行）— 顶栏+banner+侧栏+四态项目网格+新建对话框（校验空/超长/重名）。
- `open_canvas.dart` — 纯函数：有画布开第一个、无则建空白，写 `currentCanvasIdProvider`。
- `controllers/studio_projects_controller.dart` — **只有 create**（UnitOfWork 单事务建项目+首画布），无更新/删除/重命名/归档。
- `studio_state.dart`（两个 StateProvider）、`models/project_with_canvases.dart`（手写聚合模型）、`workspace_projects_provider.dart`（listAll+listByProjects 防 N+1）、4 个 widget。

**问题**：
- ⚠️ **首屏组件既取数又渲染**：`_ProjectGrid.onTap:426` 在 widget 里直接 `ref.read(canvasRepositoryProvider.future)` 并 `repo.create(...)`——数据访问泄进 UI，应收进 controller（如 `openProject`）。
- ⚠️ **错误处理两套不一致**：建项目失败用 `ScaffoldMessenger`+catch InkError；开画布失败用 `toastService`+裸 `catch(_)`（吞所有）。
- 🟡 **ARCHIVE / 底部 footer 四图标是死 stub**（`trailing:'0'` 写死占位计数、无 onTap）；`currentStudioProvider` 恒 null（studio 名功能未接持久化）；`ProjectWithCanvases` 未用 freezed；`open_canvas` 的 `canvases.first` 依赖 repository SQL 的 created_at ASC 隐式契约（provider 层无 ORDER BY 兜底）。

---

## 3. 端到端数据流（走通一条生成主线）

以"在画布上给一个图像 config 节点点击生成"为例，看请求如何穿过各层：

1. **Studio 落地** → 用户在 `studio_home_screen.dart` 点项目卡 → `open_canvas.dart` `openProjectCanvas()` 取 `project.canvases.first.id` 写 `currentCanvasIdProvider`。
2. **画布加载** → `canvas_view.dart` watch `currentCanvasIdProvider` → `canvas_nodes_controller`/`edges`/`lanes`（`AsyncNotifierFamily`）经 `core/di/repositories.dart` 注入的 `nodeRepositoryProvider` 等抽象 → `storage/repositories/postgres_node_repository.dart` 查 PG → `CanvasNode.fromRow` 映射 → 渲染节点卡 `node_card.dart`。
3. **配置参数** → 选中 config 节点 → `node_inspector_router.dart` 按 `node.type` 分发 `image_config_inspector.dart` → 用户填 prompt/选 provider/分辨率 → 下拉变更走 `inspectorSubmitController.saveConfig`（防抖 patchTypeConfig 落库）。
4. **提交** → 点生成 → `inspector_submit_controller` → `generation_controller.submitFromConfigNode()`：取 Key（`SecureStorageService`）→ `prompt_assembler.assemblePrompt` 拼五段 → `_resolveRefImages`（`FileResolverService` 解析路径）→ 按 refs 推断 `GenerationMode` → **`unitOfWorkProvider.run` 单事务**预创建 result 节点 + jobs 行（`postgres_unit_of_work.dart`）。
5. **入队调度** → `queue.submit(task)` → `services/job_queue_service.dart`：检查双层并发配额 → `_runJob` → `provider_registry.get(providerId)` 取适配器（`providers/gemini_image_provider.dart` 等）。
6. **调外部 API** → 适配器经 `rate_limiter` token bucket 限流 → dio 请求 → 失败经 `dio_error_mapper` 翻成 `InkError` → 同步 provider 返回 inlineBytes / 异步 provider 返回 task_id 后由 JobQueue 退避轮询 `poll`。
7. **物化产物** → JobQueue `_persistInlineBytes`/`_persistRemoteUrls`：（异步）经 `dio_video_download_service` 下载 → （视频）`media_kit_thumbnail_service` 抽首帧 → `nodeRepository.patchTypeConfig` 把 url/thumbnail 写回 result 节点 → `transitionStatus(...,success)`。
8. **UI 刷新** → `generation_controller._track` 监听 `handle.status`/`done` → upsert `jobs_registry`（keepAlive 内存镜像）→ `canvas_job_listener.dart` 经 `CanvasJobEffects.diff` 判定 → 重拉节点 / 失败弹 toast → `canvas_render_queue.dart` 显示进度。

> 注意第 7 步是当前 `JobQueueService` 上帝类的核心债务区，也是"projectId 为空静默丢产物"风险所在。

---

## 4. 设计纪律合规体检

| 维度 | 状态 | 证据 |
|---|---|---|
| **SOLID-D（依赖抽象+DI）** | ✅ 良好 | features 经 Riverpod 拿 `core/interfaces`，未见直接 import 具体仓储/provider；ISP 四拆 generation_provider |
| **SOLID-S（单一职责）** | ⚠️ 多处违例 | `JobQueueService`(791) / `generation_controller`(645) / `canvas_view`(779) 三大上帝类；studio 首屏 widget 取数 |
| **i18n 零硬编码字符串** | ✅ 大体合规 | 219 键 zh=en 完全对齐；用户文案走 `context.l10n`；prompt 不 i18n 正确。少数：provider displayName 后缀、装饰符 `›·▾`、ARCHIVE `'0'` 占位 |
| **设计令牌零硬编码样式** | ❌ 系统性缺口 | 缺"图标尺寸/控件高度"两档令牌 → 画布/组件层大面积裸数字；4000/320/icon 14-18 散落；lane 色板复刻硬编码 |
| **DI 无全局单例** | ✅ 良好 | 全 app-scoped Riverpod，无 ServiceLocator/static 单例；生命周期 onDispose 覆盖 |
| **freezed 不可变模型** | ⚠️ 部分偏离 | core/models + job_state 用 freezed；但 canvas 三模型 + studio 聚合模型手写（已知刻意偏离，未登记例外）；canvas_node hash/equals 契约疑破 |
| **错误处理走 InkError** | ⚠️ 边界泄漏 | InkError 密封层级设计扎实、storage/providers 严格遵守；但 ≥6 处 catch-all（`catch(_)`/`on Object`），`GenerationError`/低层 service 错误游离体系外 |
| **零向后兼容** | ✅ 符合 | schema 向前单调迁移 v1→v5，删死列而非保留 legacy；无迁移兼容代码 |

---

## 5. 风险与改进建议（按优先级）

**P0 — 正确性/真 bug（建议尽快）**

1. **画布标题永远显示"默认名"** — `app.dart:79` 把 `canvasName` 写死成 `l10n.canvasDefaultName`，真实画布名丢失。应从当前画布读真实 name。
2. **JobQueue 静默丢产物风险** — `job_queue_service.dart` 的 `_persistInlineBytes`/`_persistRemoteUrls` 在 ID 为空时静默当成功，会让真实任务"成功但无产物"。应区分"测试 null 路径"与"生产缺 ID 故障"，后者必须报错。
3. **`canvas_edges_controller` 缺 `_alive` 守卫** — autoDispose 期间 await 后写 state 抛 StateError。补齐与 nodes/lanes 一致的守卫。
4. **`canvas_node` hash/equals 契约破坏** — `==` 顺序无关、`hashCode` 顺序相关，作 Set/Map key 不可靠。改顺序无关 hash。

**P1 — 架构债（影响可维护性）**

5. **删除僵尸文件 `canvas_node_card.dart`** — 生产无引用，且其同名 `CanvasNodeType` 枚举是命名污染地雷。删掉或移入 storybook。
6. **拆分三大上帝类** — `JobQueueService` 抽 `ResultMaterializer`（产物落盘/下载/缩略图/回写）；`GenerationController` 抽 `GenerationContextResolver`（prompt/refImages/关联文本聚合）；`canvas_view.dart` 把泳道拖拽/重排/resize 下沉到 lane-interaction controller。
7. **补全事务边界** — `RepositoryScope` 加入 batch_results + style_lanes；`reorderLanes` 改用 UnitOfWork 原子化。
8. **修正"乐观更新"语义** — canvas create 路径要么真乐观（await 前改 state + 真回滚），要么删掉误导注释和死回滚分支。
9. **收敛 components/ 与 primitives/** — 按钮/卡片/输入各保留一套；统一 settings 的 Material 原生按钮为 InkButton。

**P2 — 一致性/纪律（打磨）**

10. **补两档设计令牌**（图标尺寸 / 控件高度），清掉画布与组件层的裸数字；lane 色板统一到单一数据源。
11. **统一错误处理** — 收窄所有 catch-all 到 InkError；决定 `GenerationError` 是否纳入 InkError 层级；DI 层 `database.dart` 把 ServerException 映射成 InkError。
12. **`columns.dart` 常量贯穿到仓储 SQL**（或反过来删常量），消除列名/表名双写漂移；给 `buildUpdate` 的 patch key 加白名单校验。
13. **统一枚举单点维护** — InkErrorCode 的 assert/map/retryable 四处分散；cost_model↔capabilities 循环 import 抽 `enums.dart`。
14. **接通待完成功能** — locale/theme/高对比度/textScale 持久化；studio ARCHIVE + footer stub + studio 名；inspector running progress 接 JobState；能力声明（maxRefImages/batchSize/pollTimeout）在提交路径真正生效。

---

### 一句话总结

这套代码的**骨架明显比一般 vibe coding 干净**：DIP/ISP/UnitOfWork/InkError 密封层级/迁移版本化/限流与错误映射都是认真设计过的，i18n 键集对齐、API key 安全边界、并发状态机的竞态处理都达标。**债务高度集中**在三个地方：① 几个随功能堆大的上帝类（JobQueue/GenerationController/CanvasView），② 设计令牌缺两档导致的大面积硬编码尺寸，③ 一批未完成功能与僵尸代码（canvas_node_card、ARCHIVE stub、偏好无持久化）。先清 P0 的 4 个正确性问题，再按 P1 拆类，整体质量就能上一个台阶。
