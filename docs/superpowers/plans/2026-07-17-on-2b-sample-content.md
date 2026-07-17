# ON-2b 示例项目演示内容 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** createSample 从「空项目+空画布」升级为「1 条示例泳道 + 1 个预填 prompt 的 image config 节点」，纯本地、不触发生成，让首启用户落地画布即见可玩内容。

**Architecture:** createSample 改走 UnitOfWork 单事务（project→canvas→lane→node 原子落库，半成品零残留）；示例文案经 ARB 由三个 UI 入口传入（SampleSeed 记录），控制器不触 l10n（保持 core/features 分层）。

**Tech Stack:** Riverpod（unitOfWorkProvider）、既有 StyleLaneRepository/NodeRepository、gen-l10n。

## Global Constraints

- ME-27：autoDispose provider 的所有 `_ref.read` 必须在首个 await 前同步完成。
- i18n：新增 4 个 ARB 键，en/zh 同 commit 全覆盖 + `flutter gen-l10n` 产物入库。
- 示例 prompt 是**用户数据**（可编辑字段预填值），不是系统 prompt——走 ARB 合法；系统 prompt 禁 i18n 的规则不适用（设计取舍，评审可复核）。
- 泳道带（horizontal 默认）：世界 Y ∈ [0, 400)；节点 260×220 @ (120, 90) 完全落带内。
- Zero-BC：createSample 签名直接改，3 个调用点 + 既有测试同步更新，无兼容层。

---

### Task 1: SampleSeed + createSample 种子化（UnitOfWork 单事务）

**Files:**
- Modify: `lib/features/canvas/providers/canvas_bootstrap_controller.dart`
- Modify: `test/_harness/fake_repositories.dart`（新增 InMemoryStyleLaneRepository）
- Test: `test/features/canvas/providers/canvas_bootstrap_controller_test.dart`

**Interfaces:**
- Produces: `typedef SampleSeed = ({String laneLabel, String laneStylePrompt, String nodeLabel, String nodePrompt})`；`createSample({required String projectName, required String canvasName, required SampleSeed seed})`（返回 canvasId 不变）。
- Consumes: `unitOfWorkProvider`（RepositoryScope.projects/canvas/styleLanes/nodes）。

- [ ] **Step 1: 红测** — 重写控制器测试为 FakeUnitOfWork + InMemory 仓储：断言 lane 落库（label/stylePrompt 来自 seed）、node 落库（type=image, node_role=config, lane_id=新 lane, type_config.prompt=seed.nodePrompt, positionY+height ≤ 400）、currentCanvasId 切换、二次调用累加。跑 `flutter test test/features/canvas/providers/canvas_bootstrap_controller_test.dart` 看它编译失败/断言失败。
- [ ] **Step 2: InMemoryStyleLaneRepository** — 仿 InMemoryNodeRepository 加进 `_harness/fake_repositories.dart`（create/findById/listByCanvas/update/softDelete/restore/hardDelete，内存 Map）。
- [ ] **Step 3: 实现** — 控制器加 `SampleSeed` typedef + 常量 `kSampleNodePosition = Offset(120, 90)`（画布模型已有 `defaultNodeSize`）；createSample 改 uow.run 单事务四步落库；ME-27 读序保持。
- [ ] **Step 4: 绿** — 上述测试过。
- [ ] **Step 5: commit** — `feat(canvas): ON-2b createSample 种子化——单事务 lane+预填节点`

### Task 2: ARB 文案 + 三入口接线

**Files:**
- Modify: `lib/l10n/app_en.arb` / `lib/l10n/app_zh.arb`（+4 键）+ `lib/l10n/generated/`（gen-l10n）
- Modify: `lib/features/studio/widgets/onboarding_dialog.dart`、`lib/features/studio/studio_home_screen.dart`、`lib/features/canvas/widgets/canvas_view.dart`
- Test: 既有 studio_home_test / onboarding 测试随签名修复

**Interfaces:**
- Produces: ARB 键 `canvasSampleLaneLabel`（"Ink Style"/"水墨风格"）、`canvasSampleLaneStylePrompt`（水墨风格 style prompt 示例）、`canvasSampleNodeLabel`（"First Shot"/"第一个镜头"）、`canvasSampleNodePrompt`（意境画面示例 prompt）。

- [ ] **Step 1:** en/zh ARB 各 +4 键，`flutter gen-l10n`，产物同 commit。
- [ ] **Step 2:** 三个调用点构造 seed（`(laneLabel: l10n.canvasSampleLaneLabel, ...)`）传入；受签名影响的既有测试补 seed 参数。
- [ ] **Step 3:** 全量闸门：`flutter analyze lib test` 0 issues + `flutter test --exclude-tags golden` 全绿。
- [ ] **Step 4: commit** — `feat(studio): ON-2b 三入口传示例 seed + ARB 文案`

### Task 3: docs 登记 + PR

- [ ] BOARD 近期落地表 + MASTERPLAN ON-2b 行登记（同 PR）。
- [ ] PR → 对抗评审（关注：事务边界、ME-27、i18n 取舍、泳道带坐标）→ 修 P1/P2 → CI 绿一次性核验 → squash merge。

## Self-Review

- 覆盖：MASTERPLAN「示例含演示内容」范围=1 lane+1 预填节点，无生成、无网络 ✓
- 类型一致：SampleSeed 四字段与 ARB 四键一一对应 ✓
- 无占位符 ✓
