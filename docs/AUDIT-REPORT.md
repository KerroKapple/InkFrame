# InkFrame 只读全量审计报告

> ⚠️ **归档快照，不再更新**：本文冻结于 2026-06-27（基线 `a5ba6a0`）。其中 2 个 P0 与正确性簇 P1 已全部修复，
> 其余条目的追踪状态见 [BOARD.md](BOARD.md) 技术债表；勿以本文为现状依据。
>
> 审计类型：**只读**（除本报告外零文件改动）。
> 审计日期：2026-06-27。代码基线：`main` @ `a5ba6a0`。
> 方法：多 agent 编排（finder × 维度/层 → 对抗式 verifier 复核 → 合规探针 → 完整性批判）。所有发现均经"先证伪、默认拒绝"的独立复核，并由审计主控对 P0 与高影响 P1 逐条手工核验。

---

## 1. 概览

### 1.1 覆盖范围

| 维度 | 范围 |
|---|---|
| 代码量 | `lib/` 181 个 Dart（非生成 ~150），`test/` 169 个 Dart |
| 覆盖层 | main/app · core/di · core/foundation(errors/db/paths/logging/constants) · core/interfaces · core/models · storage(PG/迁移/仓储/UnitOfWork) · providers(9 适配器+2 基类+registry/限流/错误映射) · services · theme+l10n · features/canvas(models/util/providers/widgets) · features/generation · features/settings · features/studio · pubspec/analysis_options/CI |
| 审计维度 | 正确性 · 铁律合规(SOLID/i18n/令牌/freezed/InkError/零兼容) · 安全 · 数据层 · 死代码/重复 · 性能 · 测试质量 · 依赖卫生 |

### 1.2 静态分析地面真值

- `flutter analyze --no-pub` → **`No issues found!`**（133.8s，exit 0）。零警告基线成立 → 所有真实发现均为**语义/架构层**问题，分析器探测不到。
- 推论：CI 的 `flutter analyze` 闸门有效；`custom_lint` 在 CI 中为 `continue-on-error`（非阻断，见 `ci.yml:48`），根目录残留 `custom_lint.log`。

### 1.3 统计

| 严重度 | 计数（逻辑去重后） | 含义 |
|---|---|---|
| **P0** | **2** | 正确性/安全真 bug，必修 |
| **P1** | **18** | 架构债 / 真实但条件触发的正确性问题 |
| **P2** | **15** | 一致性 / 纪律 / 微优化 |

> 审计编排共运行 **222 个 agent**、约 **8.86M token**。verifier 对抗复核**拒绝 18 条**误报；审计主控在复核基础上**额外揪出 2 条假阳性**（详见 §5）。原始 169 条"confirmed"经逻辑去重（如 9 个 Provider displayName 合并为 1 条）+ 假阳性剔除 + 严重度再校准后，收敛为上表。

---

## 2. P0 — 正确性/安全（必修）

### P0-1　画布标题永远显示本地化"默认名"，真实画布名被丢弃
- **严重度**：P0（每次打开画布必触发）
- **位置**：`lib/app.dart:79`
- **证据**：
  ```dart
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId != null) {
      return CanvasScreen(canvasName: context.l10n.canvasDefaultName); // ← 写死默认名
    }
  ```
  `canvasId` 已拿到，却把 `canvasName` 无条件写成本地化常量 `canvasDefaultName`，真实画布名从不被读取。
- **为什么是问题**：用户打开**任意**画布，标题栏永远显示"默认画布/Default Canvas"——展示了错误数据。正确性 bug，100% 触发。
- **建议修法**：用 `canvasId` 读取真实画布名（如 `ref.watch(canvasRepositoryProvider.future)` → `findById(canvasId).name`，或让 `CanvasScreen` 自行按 id 读名），把真实 name 传入。
- **复核结论**：✅ confirmed（高置信，手工核验 `app.dart:60-87`）。

### P0-2　JobQueue 在关键 ID 为空时静默丢弃产物并标记"成功"
- **严重度**：P0（潜伏：仅当 task 带空 ID 进队列时触发，但后果为静默数据丢失 + 假成功）
- **位置**：`lib/services/job_queue_service.dart:549-554`（`_persistInlineBytes`）、`616-622`（`_persistRemoteUrls`）
- **证据**：
  ```dart
  // 注释：三个关键 ID 任一缺失或服务未注入 → 跳过落盘（认为是单测路径）。返回 null 表示成功。
  if (projectId == null || canvasId == null || resultNodeId == null ||
      fileResolver == null || nodeRepo == null) {
    return null;   // ← null = 成功；产物不落盘、节点不更新、job 仍标 success
  }
  ```
- **为什么是问题**：用**生产代码探测"单测路径"**是正确性陷阱。一旦真实任务因上游 bug 带着空 `projectId/canvasId/resultNodeId` 到达此处，产物（inlineBytes / 下载的视频）被悄悄丢弃、result 节点不更新，而 job 仍被判定 success——用户看到"生成成功"但画布上没有产物，且无任何错误线索。Happy path 下这些 ID 由 `GenerationController` 的 UoW 事务预填，故当前潜伏；但失败模式是最坏的一类（静默数据丢失 + 假成功）。
- **建议修法**：区分两种语义——测试注入用显式可注入标志/独立 fake，而生产路径下"关键 ID 为空"必须转 `failure`（返回 `InkError`），绝不当成功。或把 `_persist*` 抽到独立 `ResultMaterializer` 并在构造期断言依赖齐全。
- **复核结论**：✅ confirmed（高置信，手工核验 `job_queue_service.dart:535-623`）。

---

## 3. P1 — 架构债 / 条件触发正确性

### P1-1　`CanvasEdgesController` 缺 `_alive` 守卫：await 后写已销毁 state → StateError
- **位置**：`lib/features/canvas/providers/canvas_edges_controller.dart:65, 68, 79, 98`
- **证据**：该控制器 `build()` **既无 `bool _alive` 字段也无 `ref.onDispose`**；`addEdge`/`removeEdge`/`updateRole` 在 `await _repo.*` 之后无条件 `state = AsyncData(...)`。对照同族 `CanvasLanesController`（`canvas_lanes_controller.dart:21,25-26,65,105,130,142`）每个 await 后的 `state=` 都有 `if (_alive)` 守卫。
- **为什么是问题**：`AutoDisposeFamilyAsyncNotifier` 可能在 await 期间被框架 dispose（用户关闭画布/切换时）；之后写 `state` 抛 `StateError`。这正是团队在 nodes/lanes 控制器里专门用 ME-27 模式封堵、并有回归测试（`canvas_nodes_controller_test.dart:339`）守护的 bug 类——edges 控制器漏了。
- **建议修法**：加 `bool _alive=false`，`build` 内 `_alive=true; ref.onDispose(()=>_alive=false)`，所有 await 后 `state=` 包 `if (_alive)`。
- **复核结论**：✅ confirmed（高置信，手工核验全文件）。

### P1-2　`CanvasNode` hashCode/equals 契约破坏
- **位置**：`lib/features/canvas/models/canvas_node.dart:139` vs `153-154`
- **证据**：`==` 用 `mapEquals(typeConfig, other.typeConfig)`（**顺序无关**）；`hashCode` 用 `Object.hashAll(typeConfig.entries.map((e)=>Object.hash(e.key,e.value)))`（**顺序相关**）。
- **为什么是问题**：内容相同但 Map 插入顺序不同的两个 `CanvasNode` → `a==b` 为 true 但 `a.hashCode != b.hashCode`，破坏 Dart hashCode/equals 契约，作 `Set`/`Map` key 行为不可靠。实际触发概率低（`typeConfig` 多经同一 `fromRow` 路径构造，顺序稳定），故定 P1 而非 P0。
- **建议修法**：hash 改顺序无关聚合（如把 entries 的逐项 hash 用**异或/求和**而非 `hashAll`），或迁 freezed（见 P1-12）。
- **复核结论**：✅ confirmed（高置信，手工核验）。

### P1-3　三大上帝类违 SOLID-S + 首屏 widget 取数
- **位置**：`job_queue_service.dart`（**790 行**）、`canvas_view.dart`（**778 行**，`_CanvasStage` build 内 7 个 `ref.watch` + 命中测试/拖拽/泳道重排/resize 业务编排，见 `:365-753`）、`generation_controller.dart`（**644 行**）、`studio_home_screen.dart` `_ProjectGrid.onTap`（`:435` 在 widget 内直接 `ref.read(canvasRepositoryProvider.future)` + `repo.create`）。
- **为什么是问题**：违反 `docs/CLAUDE.md` "S：每个类/widget 单一职责；取数+渲染同体=违例"。JobQueue 同时管调度/状态机/inlineBytes 落盘/远程下载/缩略图/节点 patch；GenerationController 同时做校验/枚举解析/Key/prompt/参考图/建行/submit/追踪/孤儿清理。
- **建议修法**：JobQueue 抽 `ResultMaterializer`（落盘/下载/缩略图/回写）；GenerationController 抽 `GenerationContextResolver`；CanvasView 把泳道交互下沉到 controller；studio 加 `StudioProjectsController.openProject`。
- **复核结论**：✅ confirmed（行数手工核验：790/778/644/457）。

### P1-4　错误处理大面积逃逸 InkError 体系
合并多处同类违例（`docs/CLAUDE.md`：禁 `catch(Exception)/catch(_)/on Object`，统一走 InkError）：
- **`GenerationError` 游离体系外**：`generation_controller.dart:87` `sealed class GenerationError implements Exception`（**非** InkError 子类）；`:311`、`:413` 裸 `catch(e,st)`；`inspector_submit_controller.dart:141-148` 捕获 `GenerationError`。
- **`FormatException` 直抛而非 InkError**：`canvas_edge.dart:88,95`、`canvas_node.dart:175,179`（枚举解析失败抛裸 `FormatException`）。
- **catch-all 群**：`core/di/secure_storage.dart:28 catch(_)`、`about_section.dart:48 catch(e)`、`inspector_submit_controller.dart:111 catch(_){}`、`studio_home_screen.dart:442 catch(_)`、`canvas_view.dart:506,664 .catchError((Object _){})`、`image_config_inspector.dart:346,355`、`canvas_add_node_fab.dart:40`、`canvas_empty_state.dart:50`、`playable_video_path.dart:29-30`（捕 `PathSecurityError` 未包 InkError）。
- **为什么是问题**：吞异常 + 类型擦除使错误无法分类/上抛 UI，违统一错误契约；`saveConfig` 的 `catch(_){}` 会让配置存盘失败完全静默。
- **建议修法**：`GenerationError` 并入 InkError（如 `MissingApiKeyError→ProviderError(invalidKey)`）；枚举解析失败抛 `UnknownError(cause: FormatException(...))`；所有 catch-all 收窄到 `on InkError`/具体子类，需吞则至少 `logger.warn`。
- **复核结论**：✅ confirmed（多点手工抽核；`GenerationError implements Exception` 已 grep 证实）。

### P1-5　`pgMigratedPoolProvider` 泄漏原始 `ServerException` + 纯接线层跑 DDL/迁移
- **位置**：`lib/core/di/database.dart:80-95`
- **证据**：`:88` `if (e.code != '23505') rethrow;` 把非 23505 的 `ServerException` 原样重抛出 provider；`:90-91` 在 provider body 内执行 `CREATE EXTENSION` 与 `runner.migrate()`。
- **为什么是问题**：违 `ARCHITECTURE.md §4.1`（基础设施层须抛 InkError，不泄露 PostgreSQL 原生异常——`base_repository.guard` 正是为此存在）；且把 DDL+迁移编排塞进"纯接线" DI provider，职责越界。
- **建议修法**：用 `try/on PgException` 把 `pool.execute`/`runner.migrate` 的异常映射成 `LocalIOError` 再上抛；迁移编排移出 DI body。
- **复核结论**：✅ confirmed（手工核验全文件）。

### P1-6　`RepositoryScope` 缺 batch_results / style_lanes → 事务空洞；`reorderLanes` 非事务
- **位置**：`lib/core/interfaces/unit_of_work.dart:15-21`；`canvas_lanes_controller.dart:123-127`
- **证据**：`RepositoryScope` 仅含 `nodes/edges/canvas/projects/jobs`（手工核验），**缺 `BatchResultRepository` 与 `StyleLaneRepository`**。直接后果：`reorderLanes` 只能循环 `await repo.update(...)` 逐条提交（非原子）；中途失败时 DB 半重排、内存整体回滚（`:130`），二者漂移。
- **为什么是问题**："promote batch slot 为正式 node"、原子泳道重排等跨表写无法走 UnitOfWork，破坏 ACID 边界。
- **建议修法**：`RepositoryScope` 补这两个仓储；`reorderLanes` 改走 `UnitOfWork.run`（对照已正确使用 UoW 的 `removeNode`）。
- **复核结论**：✅ confirmed（手工核验；并裁决了 verifier 间"是否 intentional"的矛盾——接口/注释无任何"刻意排除"证据，`reorderLanes` 的非事务即真实后果，故认定为真实缺口）。

### P1-7　9 个 Provider 的 `displayName` 硬编码，违 i18n
- **位置**：`gemini_image_provider.dart:38`、`openai_image_provider.dart:35`、`stability_image_core_provider.dart:39`、`wanx_image_provider.dart:35`、`wanx_t2v_provider.dart:31`、`wanx_i2v_provider.dart:31`、`wanx_r2v_provider.dart:34`、`kling_v3_provider.dart:33`、`kling_v3_omni_provider.dart:34`
- **证据**：`displayName: 'Gemini Image'` 等英文常量，直接渲染于 `image_config_inspector.dart:158` / `video_config_inspector.dart:178` 的下拉 `Text(c.displayName ?? c.providerId)`。ARB 中无对应键。
- **为什么是问题**：违 `docs/CLAUDE.md §i18n` 规则 1（屏幕可读文案必须走 ARB）。这是 LLM prompt 豁免之外的真实用户文案。
- **建议修法**：把 displayName 移到 ARB（按 providerId 映射的本地化键），UI 渲染时经 `context.l10n` 解析。
- **复核结论**：✅ confirmed（手工核验 displayName 渲染链路）。

### P1-8　核心 freezed 纪律偏离（手写模型 + 缺 JSON 注解）
- **位置**：手写模型 `canvas_node.dart`、`canvas_edge.dart:37-65`、`style_lane.dart`（均 `@immutable`+手写 `==/hashCode/copyWith`）、`studio/models/project_with_canvases.dart:6-27`；`core/models` 5 个 freezed 模型缺 `@JsonSerializable`（`cost_model.dart:12` 等）。
- **为什么是问题**：违 `docs/CLAUDE.md:265`"ALL models use freezed"。canvas 三模型是**已知刻意偏离**（`style_lane.dart` 注释自述），但规则文档未登记该例外；其手写实现已诱发 P1-2 的 hash/equals bug。
- **建议修法**：二选一并执行到底——(a) 迁 freezed 消灭手写 `==/hashCode`；或 (b) 在 `docs/CLAUDE.md` 正式登记 canvas/studio 模型的手写例外并补单测护契约。core/models 的 JSON 序列化若确需则补 `@JsonSerializable`，否则更新规则措辞（当前序列化逻辑落在仓储层）。
- **复核结论**：✅ confirmed（手工核验 canvas_node 手写实现 + grep 模型定义）。

### P1-9　设计令牌系统性缺口：无"图标尺寸/控件高度"两档 → theme 组件层大面积裸数字
- **位置（代表）**：`ink_button.dart:29,48`（裸 `Color(0x00000000)`）、`ink_amber_button.dart:34,45`、`ink_ghost_button.dart:44`、`ink_surface_button.dart:61-62,64`、`ink_window_chrome.dart:26,123-124,127`
- **为什么是问题**：违 `docs/CLAUDE.md` "零硬编码样式"。`tokens.dart` 是唯一允许裸色值的文件，但缺图标尺寸/控件高度两档令牌，导致**连设计系统组件自身**都散落 28/36/44/56 高度与 14/16/18 图标尺寸。这是合规体检里唯一判 ❌ 的维度的根因。
- **建议修法**：在 `tokens.dart` 补 `InkIconSize` 与 `InkControlHeight` 两档令牌，回填所有组件/primitive 的裸数字；`Color(0x00000000)` 改 `Colors.transparent` 或新增透明令牌。
- **复核结论**：✅ confirmed（多点手工抽核）。

### P1-10　僵尸文件 `canvas_node_card.dart` + `CanvasNodeType` 枚举命名冲突
- **位置**：`lib/features/canvas/widgets/canvas_node_card.dart`（整文件）；冲突枚举 `:13`
- **证据**：`grep CanvasNodeCard lib/`（排除自身/测试/文档）**零生产引用**；该文件 `:13` 定义 `enum CanvasNodeType { character, scene, camera, prop, shot, imageGen }`，与真实模型 `canvas_node.dart:160` 的 `enum CanvasNodeType { image, text, video, shot }` **同名异义**，仅靠 import 路径区分。
- **为什么是问题**：死代码 + 命名污染地雷；该文件内的若干裸尺寸违例（`:75,84`）也因此无修复价值。
- **建议修法**：删除 `canvas_node_card.dart`（及其测试），或移入 storybook 并重命名枚举为 `CanvasNodeVisualType`。**其内部的设计令牌违例随删除一并消除，不应单列。**
- **复核结论**：✅ confirmed（grep 手工核验零引用 + 双枚举定义）。

### P1-11　SQL 列名/表名插值无白名单（防御纵深缺口，非当前可利用注入）
- **位置**：`base_repository.dart:84,91`（`buildUpdate`：`'$key = @$param'` + `'UPDATE $table ...'`）；`postgres_job_repository.dart:110-119`；`postgres_batch_result_repository.dart:88`
- **证据**：值已参数化（`@$param`），但 patch 的 **key（列名）与 table 名直接字符串插值**进 SQL，无白名单校验。
- **为什么是问题**：**当前不可利用**——所有 key 来自内部 `*Col` 常量/字面量，table 名硬编码。但类型化在 `update(id, Map patch)` 边界被泄掉，若未来有调用方传入外部派生 key 即成注入面。属防御纵深/架构纪律缺口。（注：verifier 正确拒绝了"table 名注入"误报——表名是内部常量。）
- **建议修法**：`buildUpdate` 对 key 做按表白名单校验（或正则 `^[a-z_][a-z0-9_]*$`），或贯彻 `*Col` 常量到所有仓储 SQL。
- **复核结论**：✅ confirmed（手工核验 `base_repository.dart:80-93`，按"防御纵深"而非"严重漏洞"定级）。

### P1-12　`components/` 与 `primitives/` 两套并行组件族未文档化
- **位置**：`theme/components/ink_button.dart` vs `theme/primitives/ink_ghost_button.dart`；`ink_card.dart` vs `ink_noir_card.dart`；`ink_input.dart` vs `ink_compact_text_field.dart`
- **为什么是问题**：按钮/卡片/输入三类在两个目录重叠实现，交互模型不同但分层意图（"低层/高层"）在代码里不成立、文档无解释，新人易误用、风格漂移。
- **建议修法**：要么收敛为单一组件族，要么在 `docs/CLAUDE.md` 明确两族边界与选用准则。
- **复核结论**：✅ confirmed。

### P1-13　`window_manager` 平台耦合塞进 theme 层（违 SOLID-D）
- **位置**：`lib/theme/components/ink_window_chrome.dart:4,63,69,70,72,79`
- **为什么是问题**：theme 组件直接 import 并调用具体平台包 `window_manager`，违"依赖抽象经 DI"。
- **建议修法**：抽 `WindowManagerService` 接口经 Riverpod 注入，theme 组件依赖抽象。
- **复核结论**：✅ confirmed（verifier 修正：是平台耦合而非 l10n 耦合）。

### P1-14　能力声明与提交路径不对齐
- **位置**：`wanx_image_provider.dart:88-109`（`maxRefImages=1` 声明但 `buildRequestBody` 未 `.take(1)`；`batchSize` 未 `clamp`）；`dashscope_async_provider_base.dart:105-139`（async `submit` 完全不校验 mode∈capabilities / prompt 非空 / duration 受支持，而同步基类有校验）
- **为什么是问题**：契约声明的能力上限在提交路径未生效，违 SOLID-O 的扩展意图；非法输入直透服务端才报错，错误定位差。
- **建议修法**：`buildRequestBody` 用 `take(maxRefImages)` + `batchSize.clamp(1, maxBatchSize)`；async 基类 submit 起始补与同步基类一致的校验。
- **复核结论**：✅ confirmed。

### P1-15　`GenerationController` N+1 查询
- **位置**：`generation_controller.dart:478`（`_resolveRefImages`）、`:590`（`_resolveAssociatedTexts`）
- **证据**：循环内逐 `nodes.findById()`，N 条边 → 1+N 次查询；`NodeRepository` 无批量接口。
- **建议修法**：加 `findByIds(List<String>)`（`WHERE id = ANY(@ids)`）批量查询。
- **复核结论**：✅ confirmed。

### P1-16　缩略图固定 `Future.delayed(300ms)` + `open` 无超时（flaky + 潜在永久 await）
- **位置**：`lib/services/media_kit_thumbnail_service.dart:21,23`
- **为什么是问题**：固定 300ms 等解码——慢机/大文件抽到黑帧；`open()`/`seek()` 无 `timeout`，损坏文件可能永久 await。
- **建议修法**：用解码就绪事件替代固定延时；`open/seek` 包 `Future.timeout`。
- **复核结论**：✅ confirmed。

### P1-17　`_PromptPreview` 重复实现 prompt 拼装，与提交路径 drift
- **位置**：`lib/features/canvas/widgets/image_config_inspector.dart:365`
- **证据**：`_PromptPreview` 在 build 内 watch 4 个 provider + 调 `assemblePrompt` 拼预览，与 `GenerationController` 真正提交时的拼装是两套并行实现，关联文本顺序已观察到不一致。
- **建议修法**：抽共享 `PromptPreviewProvider`，预览与提交共用同一拼装逻辑。
- **复核结论**：✅ confirmed。

### P1-18　`JobRepository` 胖接口违 ISP
- **位置**：`lib/core/interfaces/job_repository.dart`
- **证据**：~10 方法把 CRUD + 状态机（transition/bulkTransition）+ 保留期 GC（purgeExpired/purgePerCanvasCap）混一接口；不同客户端只用不相交子集。
- **建议修法**：拆 `JobCrudRepository` / `JobStateMachineRepository` / `JobRetentionPolicy`。
- **复核结论**：✅ confirmed。

> **其余 P1（已复核确认，从简列出，证据见对应文件）**：
> - **`provider_registry.dart:58-59`**：`listCapabilities()` 为读编译期 const 能力**强制实例化全部 9 个 provider**（连带 9 Dio + 9 限流器）。建议把 capabilities 解耦为独立 Map 预计算。
> - **`job_queue_panel.dart:288-308`**：`_errorMessage` 手写错误→文案映射，与规范 `l10nError()` 重复且漏 `errorProviderInvalidResponse` 分支。建议直接调 `l10nError`。
> - **`library_sidebar.dart:57-63,274-307` + `studio_state.dart:6`**：ARCHIVE 与 footer 图标是死 stub（`trailing:'0'` 写死、无 onTap），`currentStudioProvider` 恒未初始化。
> - **`job_queue_service.dart:46-49,298` + `provider_capabilities.dart:64-65`**：pollTimeout/backoff 为死配置（per-provider 字段存在但 JobQueue 全用全局默认）。
> - **`app_teardown.dart:43-57`**：`stop()` 仅捕 `PgLifecycleError`，其余异常逃逸会阻止 `container.dispose()` 执行（清理不完整）。
> - **`image_config_inspector.dart:411` / `node_card.dart:283`**：`typeConfig[...] as String?` 无 `is String` 前置校验，非 String 值会 runtime CastError。
> - **`canvas_edges_controller.dart:37-70`**：addEdge/addNode 注释自称"乐观更新"但实为 await-create-后才改 state，catch 里回滚到从未变过的值 → 死回滚分支 + 误导注释。

---

## 4. P2 — 一致性 / 纪律 / 微优化

> 均经对抗复核确认，按主题归并；逐条均有 file:line 证据。

### P2-1　设计令牌纪律（图标尺寸/容器尺寸/间距散落裸数字）
- `studio_home_screen.dart:236-237,246`、`library_sidebar.dart:150,218`、`studio_top_chrome.dart:213`、`canvas_empty_state.dart:127-149`、`ink_window_chrome.dart:127`、`ink_amber_button.dart:45`、`job_queue_panel.dart:96`、`inspector_status_panel.dart:232` 等多处裸 icon size / 尺寸 / `SizedBox` 间距。**根因同 P1-9（缺两档令牌）。**

### P2-2　i18n 纪律（边界/装饰性，价值偏低）
- **品牌字 'Ink/Frame' 硬编码**：`studio_top_chrome.dart:59-61`、`canvas_top_chrome.dart:60-62`。*注：品牌专有名词按惯例通常豁免 i18n，此处按字面规则记录，价值低，已从 verifier 的 P1 下调为 P2。*
- **装饰性分隔符**：`canvas_top_chrome.dart:174` 面包屑 `'›'` 等硬编码字符。
- **ARB 元数据不对称**：`app_zh.arb` 缺 11 条 `@`-描述（en 20 / zh 9）。*键集本身由 `arb_hygiene_test` 强制对齐，非键缺失，仅元数据。*

### P2-3　错误处理纪律（吞错无日志）
- `generation_controller.dart:589-593`（关联文本查询失败静默吞）、`:168-170`（resolution/aspect 解析失败静默回落默认值无告警）。建议吞错处至少 `logger.warn`。

### P2-4　数据层纪律
- **`columns.dart` 常量未贯穿仓储**：`postgres_canvas_repository.dart:23` 等仓储 SQL 用裸列名字符串，`*Col` 常量名存实亡，列名双源易漂移。
- **`postgres_node_repository.dart:120-122`**：用 `replaceAll` 字符串替换打 jsonb cast，脆，违"不要 patch around"。

### P2-5　安全（防御纵深，本地桌面单用户风险低）
- **`file_resolver_service.dart:51-95`**：路径边界检查用 `normalize()`+`startsWith`，未解析符号链接 → 符号链接可绕过边界。*本地单用户桌面，需攻击者预置恶意 symlink，风险低，从 P1 下调 P2。*
- **`pg_controller.dart:207,246,304`**：`PgLifecycleError` 把 PostgreSQL stderr（可能含路径/配置）放进异常消息并可能上抛 UI。
- **`logger_service.dart:124-132`**：脱敏正则可能漏掉部分凭据格式（AWS/GitHub/Slack token 模式）。建议扩充 `_valuePatterns`。

### P2-6　性能（线性扫/迭代器开销，多在 build 热路径）
- `canvas_view.dart:320-323`（`.where().cast().firstWhere((_)=>true)` 找单元素）、`:772-775`（解析选中边几何无提前终止）、`canvas_render_queue.dart:24-30`（两遍扫 + `whereType().length`）、`jobs_registry.dart:61,72`（双遍扫驱逐/查存在）、`canvas_edges_controller.dart:88-91`（O(n) 更新单边 role）、`canvas_lanes_controller.dart:123-128`（`reorderLanes` 嵌套 `firstWhere` O(n²)）、`logger_service.dart:327`（排序时重复 `statSync`）。
- **`lane_background.dart:28`**：`CustomPaint` 未包 `RepaintBoundary`（对照 canvas_view 的 HI-15 模式）。
- **`sync_provider_base.dart:42`**：job 在 poll 前被 cancel 时 `_inlineCache` 条目永不清理（有界内存泄漏）。

### P2-7　测试质量
- **真 `Future.delayed` 替代 fakeAsync**：`inspector_submit_controller_test.dart:174-176`、`rate_limiter_test.dart:136`、`app_teardown_test.dart:89`——与项目声明的"零 wall-clock 依赖"原则冲突，flaky 风险。
- **`migration_runner_integration_test.dart:32`**：集成测试仅显式覆盖 v1，多版本升级链仅在单测/harness 隐式覆盖（建议补显式升级链集成测试）。

### P2-8　可维护性 / 死代码 / 重复
- **`ink_error.dart:10-169` + `l10n_x.dart:14-30`**：`InkErrorCode` 不变量分散 5+ 处（枚举/子类 assert/`_retryable`/`kInkErrorMessageKeys`/`l10nError` switch），新增 code 需同步改多处，漏改 map 触发 `!` NPE。
- **`cost_model.dart:8`**：`cost_model ↔ provider_capabilities` 循环 import（仅为共享 `Resolution`）。建议抽 `core/constants/provider_enums.dart`。
- **`generation_provider.dart:42-44`**：`Cancellable` 接口零生产实现（9 provider 全 `supportsCancellation=false`）。
- **`lane_tint.dart:5-9` 与 `lane_edit_dialog.dart:25-31`**：5 个 `#RRGGBB` 色板重复声明 + 绕过令牌。
- **`api_keys_section.dart:177`**：用 Material `FilledButton`/`OutlinedButton` 而非 `InkButton`（违 Components-Over-Primitives）。
- **`dashscope_async_provider_base.dart:242-245`**：`validateApiKey` 中 401/403 检查不可达（`validateStatus<500` 已把它们当正常响应），死代码。

### P2-9　健壮性细节
- `edge_hit_test.dart:50-51`（浮点 `==0` 应用 epsilon）、`:53`（`clamp` 后多余 `.toDouble()`）、`lane_geometry.dart:33-34`（size clamp 上界 `double.infinity` 形同无上限）、`lane_tint.dart:16-17`（子串匹配无词边界，"rainbow" 误命中 "rain"）、`base_style_presets.dart:2`（多余 lint ignore 指令）、`dio_video_download_service.dart:79-87`（Windows 取消恢复重试不足且静默）。

---

## 5. 复核与假阳性（透明度）

本审计的核心红线是"宁可漏报不要误报"。除 verifier 对抗复核**主动拒绝 18 条**外，审计主控对照地面真值额外揪出并**剔除 2 条假阳性**：

| 被剔除项 | 位置 | 为何是假阳性 |
|---|---|---|
| "集合字面量中非法 `?` 空安全运算符（语法错误）" | `ink_window_chrome.dart:38,42` | `?leading,`/`?trailing,` 是 **Dart 3.8+ 空安全集合元素**合法语法（SDK `^3.11.0`）。`flutter analyze` 全绿即铁证。verifier 受知识截止误判。 |
| "Map 字面量前缀 `?` 非法（语法错误，无法编译）" | `canvas_lanes_controller.dart:80-86` | `StyleLaneCol.label: ?label,` 是 **Dart 3.8+ 空安全 Map 条目**合法语法。同上。 |

> 经验教训：对抗 verifier 在"语言新特性"类判断上会出现知识截止误报；用编译器/分析器地面真值交叉校验是必要的最后一道闸。

verifier 正确拒绝的代表性误报：表名插值注入（表名是内部常量）、dashscope 路径穿越、`StyleLaneRepository` 缺 hardDelete（被判为可接受的契约非对称）、`migration_runner` 版本号插值（内部整数）等。

---

## 6. 铁律合规体检表

| 铁律维度 | 结论 | 证据 |
|---|---|---|
| **SOLID-D（依赖抽象 + DI）** | ✅ pass | features 经 Riverpod 拿 `core/interfaces`，未见直 import 具体仓储/provider；`generation_provider` ISP 四拆。**例外**：`ink_window_chrome` 平台耦合（P1-13）、studio `_ProjectGrid` 取数（P1-3）。 |
| **SOLID-S（单一职责）** | ⚠️ warn | 三大上帝类 790/778/644 行（P1-3）；首屏 widget 取数。 |
| **i18n 零硬编码用户文案** | ⚠️ warn | ARB 键集 zh=en 由 `arb_hygiene_test` 强制对齐、prompt 正确不 i18n；但 9 个 provider displayName 硬编码（P1-7）+ 品牌字/分隔符（P2-2）。 |
| **设计令牌零硬编码样式** | ❌ fail | 缺图标尺寸/控件高度两档令牌 → 连设计系统组件自身都散落裸数字（P1-9、P2-1）。 |
| **全模型 freezed 不可变** | ⚠️ warn | core/models + job_state 用 freezed；canvas 三模型 + studio 聚合模型手写（刻意但未登记例外），并诱发 hash/equals bug（P1-2、P1-8）。 |
| **错误统一走 InkError** | ⚠️ warn | InkError 密封层级设计扎实、storage/providers 严守；但 ≥10 处 catch-all、`GenerationError`/`FormatException`/`ServerException` 逃逸体系（P1-4、P1-5）。 |
| **零向后兼容** | ✅ pass | schema v1→v5 向前单调、删死列不留 legacy；无迁移兼容代码。 |
| **DI / 无全局单例** | ✅ pass | 全 app-scoped Riverpod，无 ServiceLocator/static 单例；`onDispose` 覆盖生命周期。 |
| **API Key 安全边界** | ✅ pass | Key 读写删一律经 `SecureStorageService`，无落代码/配置/DB；SQL 值参数化。（残留防御纵深项见 P1-11、P2-5。） |

---

## 7. 盲区与未覆盖项（诚实声明）

1. **未执行测试套件**：本次为只读静态审计——读文件 + grep + `flutter analyze`（全绿已确认）。**未运行 `flutter test`**（PG 集成测试需库、media_kit 需 GPU/native）。故"测试是否真通过/是否 flaky"未实测，P2-7 的 flaky 风险为静态推断。
2. **运行时/视觉未验证**：golden 基线、真实渲染、并发竞态的运行时行为、media_kit 播放路径均未动态验证。
3. **完整性批判提示但未深挖的维度**：a11y/语义（`Semantics`/屏幕阅读器标签）在 theme/primitives 与交互 widget 未系统审计——完整性 agent 标记为潜在 WCAG 缺口，但因 token 预算耗尽（gap 轮被预算闸门跳过，`gapFindersRun=0`）未展开。
4. **finder 可能未深读的文件（约 52 个，多为薄封装/常量/测试装置）**：`theme/tokens.dart`、`theme/typography.dart`、`theme/motion.dart`、多个 `theme/primitives/*`、`core/di/*`（clock/current_screen/locale/logger/package_info/paths/theme/thumbnail/video_*）、`core/db/row_reader.dart`、`core/logging/logger_service.dart`、`core/constants/*`、`features/canvas/util/{node_position,canvas_job_effects,base_style_presets}.dart`、若干 canvas widget（edge_painter/lane_toolbar/lane_title_bar 等）、settings 三个 section、`studio/controllers/studio_projects_controller.dart`、`workspace_projects_provider.dart`、`prompt_assembler.dart`、`l10n_x.dart` 及全部 `test/_harness/*`、`test/helpers/*`。这些层有局部发现命中，但未保证逐行覆盖。
5. **若干中置信发现需产品/架构拍板**：`canvas_nodes_controller.dart:63-66` 的 assertion 是否"误防孤儿 result"取决于 PRD 对 result 节点的定义；`providers.dart:61-65` 的 RateLimiter lazy dispose race 较隐蔽，建议结合对应近期 commit 复核。
6. **依赖卫生**：pubspec 依赖未逐个做"未用"扫描（analyze 全绿仅证明无未用 import，不等于无未用 dependency）；`custom_lint` 在 CI 非阻断这一既有事实已记录，但未实跑 `dart run custom_lint` 验证其当前是否零规则空转。

---

*报告结束。除本文件外，审计全程零文件改动；未执行任何写入/提交/网络发布/状态变更命令；未回显任何密钥明文。*
