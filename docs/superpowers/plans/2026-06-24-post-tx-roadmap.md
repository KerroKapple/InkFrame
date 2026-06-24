# InkFrame 后续开发路线图（P0#1 事务落地之后）

> 生成日期：2026-06-24 · 当前分支：`feat/backend-tx-unit-of-work`（超前 `main` 10 提交）
> 依据：`docs/review/2026-06-24-backend-deep-review.md`（当前权威）、`docs/review/REVIEW-2026-06-18.md`（部分已过期）、`docs/ROAD-TO-BETA.md`、`ROADMAP.md`，并经一轮**代码实地核对**修正了报告中的过期项。
> 这份文档回答：**P0#1（事务）落地后，接下来按什么顺序做、每件事的优先级/工作量/依赖/验收。**

---

## 0. 一句话结论

后端脊梁稳。最高杠杆的**未完成**工作不是「修一堆债」，而是**两块明确的后端抽象债（仓储边界类型化 P0#2、同步 provider 抽基类 P0#3）+ 几个定点 P1**。质量闸门与 Beta 基建在 PR #115/#121/#109 之后**大部分已落地**，旧报告里那批「闸门空转 / 硬编码债 / ARB 待整顿」多数**已过期**。前端按既定决策将来重做——因此 06-18 报告里的**控件级**样式/串债**大多无需现在修**（重做即废）。

---

## 1. 实地核对后的真实现状（修正过期报告）

> ✅=已落地  🟡=部分/待收口  ⬜=未开始（真实待办）

### 1.1 已落地（旧报告标为问题，实则已修）

| 项 | 证据 | 来源报告判定 |
|---|---|---|
| ✅ 质量闸门根治：bash hook → 阻塞式 Dart 测试 | `test/quality/{no_inline_styles,no_magic_strings,no_direct_instantiation,disposable_cleanup,updated_at,migration_registry}_test.dart`；PR #121（commit c041276） | 06-18 P0-1/P0-2 已修 |
| ✅ 迁移注册表完整性测试 | `test/quality/migration_registry_test.dart` | 06-18 S8-9 已修 |
| ✅ release 脚本进 CI | `.github/workflows/ci.yml` `release-scripts` job 跑 `release_tag_test.sh` | 06-18 S8-8 已修 |
| ✅ 覆盖率 70% 硬闸门 + lcov artifact | `ci.yml` `test` job（very_good_coverage min 70） | ROAD-TO-BETA DoD#7 已达 |
| ✅ E2E 主链路（生成→落盘→渲染） | `test/e2e/generation_pipeline_e2e_test.dart`、`generation_render_node_e2e_test.dart`；PR #115 | ROAD-TO-BETA DoD#4 已达 |
| ✅ ARB 整顿合并 | PR #109（de9118c）；`test/l10n/arb_hygiene_test.dart` 双向断言 184/184 | ROAD-TO-BETA P2 / 06-18 S8-11 已修 |
| ✅ DALL-E（gpt-image-1）+ Stable Image Core provider | `lib/providers/{openai_image,stability_image_core}_provider.dart` 已实现并注册（共 9 款） | ROAD-TO-BETA P1 代码完成 |
| ✅ Style Lanes 特性 | `style_lane*`、`canvas_lanes_controller`、`lane_collapse_controller`、`lane_geometry`、base-style presets 均在；PR #122 + deferred plan | 新特性 |
| ✅ P0#1 多步写入事务化（UnitOfWork） | `lib/core/interfaces/unit_of_work.dart`、`lib/storage/postgres_unit_of_work.dart`、3 处调用站点 | 深评 P0#1 ——本分支 |
| ✅ 跨平台烟测脚手架 | `.github/workflows/smoke.yml`、`scripts/smoke/{macos-smoke.sh,windows-smoke.ps1}` | ROAD-TO-BETA DoD#5 脚手架完成 |
| ✅ Golden 测试 + 基线守卫 | `ci.yml` `golden` job（基线守卫）、`test/.../node_card_golden_test.dart`、`update-goldens.yml` | ROAD-TO-BETA DoD#3 框架完成 |

### 1.2 真实待办（核对后确认仍 OPEN）

| ID | 项 | 证据（确认未做） | 优先级 | 工作量 |
|---|---|---|---|---|
| **P0#1-PR** | 当前分支收尾 + 合并 main | 分支超前 10 提交，计划 Task 8（verify+PR）未做 | P0 | S |
| **P0#2** | 仓储边界类型化（消灭裸 `Map`/字符串列名/散落强转） | 7 个 repo 全返回 `Map<String,Object?>`；无 `schema_columns.dart`；`fromRow` 里 `as String`/`!.toString()`/各自 `_asDouble` | **P0** | L |
| **P0#3** | 抽 `SyncProviderBase`（gemini/openai/stability 去重 ~40%） | 无 `SyncProviderBase`；仅有 `dashscope_async_provider_base.dart` | **P0** | M |
| **P1-4** | provider 响应解析防御（`(x as Map)['k']` → `ProviderError(providerInvalidResponse)`） | 同步 provider 解析未统一包裹 | P1 | M |
| **P1-5a** | 生成路径 `edges.listIncoming` 取一次复用（去重复往返） | `generation_controller.dart` | P1 | S |
| **P1-5b** | 启动孤儿恢复批量 UPDATE（`status = ANY(@from)`） | `job_queue_service.dart` 恢复路径 N+1 | P1 | S |
| **P1-5c** | 加复合索引 `idx_jobs_canvas_created ON jobs(canvas_id, created_at DESC)`（schema v5） | 当前 schema **v4**（`schema_v1..v4.dart` / `001..004.sql`），无该索引 | P1 | S |
| **P1-5d** | JobsRegistry 给「卡死非终态 job」加硬上限/兜底淘汰 | 长会话内存增长 | P1 | S |
| **P1-6** | 边角静默退化补 warn 日志（mode 推断、lane 查询）+ 孤儿 result 清理有限重试 | 当前静默 | P1 | S |
| **GATE-1** | custom_lint 从 `continue-on-error` → 硬阻断 | `ci.yml:47-49` 仍 `continue-on-error: true`（待 riverpod_lint/custom_lint 兼容 Dart 3.11 dot-shorthand AST） | P1 | M（受上游版本约束） |
| **BETA-1** | Golden 基线在 canonical ubuntu runner 实跑铸出并 CI 绿 | 本地仅见 `failures/`（已 gitignore），基线靠 `update-goldens.yml` 铸 | P1 | S |
| **BETA-2** | 性能基线守卫测试（节点 > 200 帧率阈值） | `docs/internal/perf-baseline.md` 有文档，无守卫测试 | P1 | M |
| **BETA-3** | Windows + macOS 烟测首次 CI 实跑绿 | `smoke.yml` 脚手架在，待首跑勾选 | P1 | S（依赖 CI 运行） |
| **DEBT-survive** | 存活于重做的跨切面债：S1-3 `secure_storage.dart:28` 裸 catch；S6-2 `purgeExpired` 对 `completed_at IS NULL` 恒假；S7-1/2 落盘后 DB 回写失败留孤儿文件 | core/storage/services 层，前端重做不影响 | P2 | S each |
| **P2** | 打磨：error-code↔i18n 编译期校验；`SELECT *` → 显式列；慢查询计时日志；`ProviderCapabilities` const assert；downgrade 友好退出 | 深评 P2 | P2 | S–M |
| **FE-REDO** | 前端重做（用户既定决策） | 深评：后端 P0/P1 落定后再开 | 大 | XL |

### 1.3 明确无需现在做（前端重做即废）

06-18 报告 S2/S3/S4 的**控件级**债——`ink_accent_chip`/`ink_dashed_slot`/`ink_surface_button` 硬编码间距、`canvas_inspector` mock 占位屏与硬编码串、`studio_home_screen:95 fontSize:32`、`library_sidebar` 归档计数 stub、`canvas_edges_controller`/`link_action_controller` 的 await-dispose 防护缺口——**若前端重做，这些都会被替换**。不要在重做前花预算清理纯 widget 层的样式/串债。例外：跨切面债（§1.2 DEBT-survive）存活于重做，照常修。

---

## 2. 排期策略（推荐）

> 交互式确认在本会话被禁用，故采用**文档强支持的推荐顺序**并在此显式标注；§5 列出需用户拍板的决策点。

**推荐顺序：收尾当前分支 → 后端 P0 硬化 → 后端 P1 + 闸门收口 → Beta DoD 收口 →（再开）前端重做。**

理由：
1. 深评（当前权威）明确建议「按 P0→P1 推进，约 2 个 sprint，前端在后端 P0/P1 落定后再开」。
2. P0#2（仓储类型化）是你感到「抽象薄」的**根因**，且是后续一切读路径的地基——先做收益最大、返工最少。
3. 质量闸门/Beta 基建大部分已落地（§1.1），不再是瓶颈；只剩 custom_lint 硬化与几项 CI 实跑收口。
4. 前端重做是 XL；在后端边界类型化稳定前重做前端，会让新前端再次贴着不安全的 `Map` 边界长——先把地基浇好。

---

## 3. 分阶段计划

### Sprint A — 后端 P0 硬化（地基）
**目标：** 仓储边界类型安全 + 同步 provider 去重；当前分支并入 main 作为干净起点。

| 顺序 | 项 | 工作量 | 依赖 | 详细计划 |
|---|---|---|---|---|
| A0 | P0#1-PR：当前分支 verify + PR 合并 | S | — | `docs/.../2026-06-24-backend-p0-transactions.md` Task 8 |
| A1 | **P0#2 仓储边界类型化** | L | A0 | **`docs/.../2026-06-24-backend-p0-2-repository-typing.md`（本次新建，见下）** |
| A2 | P0#3 抽 `SyncProviderBase` | M | A0（与 A1 文件不冲突，可并行） | 待写（参照 `dashscope_async_provider_base.dart` 形态） |

**DoD：** `flutter analyze` 0 issue；全测绿（pg-tagged 在 CI 跑）；7 个 repo + 全部 `fromRow` 走类型化访问器与列名常量；gemini/openai/stability 各降至 ~80 行并继承 `SyncProviderBase`。

### Sprint B — 后端 P1 + 闸门收口（健壮性/性能）
**目标：** 关掉远端 schema 漂移炸点、定点性能、把最后一道闸门转硬。

| 项 | 工作量 | 备注 |
|---|---|---|
| P1-4 provider 响应解析防御 | M | 依赖 A2（在 `SyncProviderBase` 里统一解析入口最省） |
| P1-5a listIncoming 取一次 | S | |
| P1-5b 孤儿恢复批量 UPDATE | S | |
| P1-5c schema v5 + `idx_jobs_canvas_created` | S | 走 MigrationRunner，写 `schema_v5.dart` + `005_*.sql` + 注册表 + chain 测试 |
| P1-5d JobsRegistry 硬上限 | S | |
| P1-6 静默退化补 warn + 孤儿清理重试 | S | |
| GATE-1 custom_lint 转硬阻断 | M | 受 riverpod_lint/custom_lint 上游版本约束，先验本地 `dart run custom_lint` 无 throw |

**DoD：** 远端 schema 漂移 → `ProviderError(providerInvalidResponse)` 而非 `UnknownError`（有测试）；schema v5 迁移 chain 测试绿；`ci.yml` custom_lint 去掉 `continue-on-error`。

### Sprint C — Beta DoD 收口
**目标：** 把 ROAD-TO-BETA 剩余 DoD 全部点亮，打 beta tag。

| 项 | 工作量 | 备注 |
|---|---|---|
| BETA-1 Golden 基线 ubuntu 铸出 + CI 绿 | S | 跑 `update-goldens.yml`（workflow_dispatch）铸基线并提交 |
| BETA-2 性能基线守卫测试（>200 节点帧率阈值） | M | 量化 + 阈值断言，文档化进 `perf-baseline.md` |
| BETA-3 Windows+macOS 烟测首次 CI 绿 | S | 依赖 CI 实跑 `smoke.yml` |
| DEBT-survive（S1-3 / S6-2 / S7-1·2） | S each | 存活于重做的跨切面债，顺手清 |

**Beta 资格（ROAD-TO-BETA §3）= 全绿：** analyze 0 / test 全绿 / golden 基线 CI 校验 / ≥1 E2E（已达）/ 双平台烟测 / 性能基线文档化 / 覆盖率≥70%（已达）/ 无 P0 open bug。

### Phase D — 前端重做（XL，独立立项）
后端 P0/P1 落定后开。需单独 brainstorming + spec + 自己的实施计划。届时新前端**直接消费 Sprint A 的类型化仓储边界**，不再贴 `Map`。控件级旧债随重做一并清除。

---

## 4. 关键风险 / 约束

- **Provider fixture-E2E 需真实 API key**（`PROVIDER-API.md §12.3` 禁手写 fixture）：DALL-E/SD 代码完成，fixture-E2E 在无 key 时 pending。
- **custom_lint 硬化受上游版本约束**：riverpod_lint/custom_lint 需兼容 Dart 3.11 dot-shorthand AST 后才能转硬阻断（已用 `test/quality/*` Dart 测试兜底，无防护真空）。
- **Flutter 不在 PATH**：命令走 `C:\Users\Kerro\flutter\bin\flutter.bat`。
- **PR 创建**：`git push` 可用（GCM 缓存）；`gh` 已登录（KerroKapple）。
- **本机无 PG**：pg-tagged 测试本地跳过，CI（postgres:17）实跑。

---

## 5. 需用户拍板的决策点（本会话无法交互询问，先按推荐默认）

1. **排期策略**（§2）：默认「后端 P0 优先，前端押后」。若想 Beta 优先冲刺或前端立即重做，请指明。
2. **P0#3 与 P0#2 是否并行**：二者文件域不冲突，可双线并行（A1 改 storage/models，A2 改 providers）。默认顺序做（A0→A1→A2）。
3. **前端重做范围**：全量重写还是渐进替换？影响 §1.3「控件级债是否值得清」的判断。默认全量重写 → 控件级债不清。
4. **custom_lint 硬化时机**：是否现在投入升级 riverpod_lint/custom_lint，还是等上游。默认放 Sprint B 末，受上游约束可顺延。

---

## 6. 立即下一步

1. **A0**：在当前分支跑 `flutter analyze` + `flutter test --exclude-tags pg` → code-review → PR 合并 `feat/backend-tx-unit-of-work` 到 main（完成 `2026-06-24-backend-p0-transactions.md` Task 8）。
2. **A1**：按 `docs/superpowers/plans/2026-06-24-backend-p0-2-repository-typing.md`（本次新建）执行仓储类型化。
