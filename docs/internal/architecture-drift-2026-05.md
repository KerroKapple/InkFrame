# ARCHITECTURE.md Drift Audit — 2026-05

**Audited:** `docs/ARCHITECTURE.md` (1164 lines) + `docs/CLAUDE.md` (280 lines) @ commit 727a686
**Audit date:** 2026-05-12
**Scope:** every concrete claim in ARCHITECTURE.md §1–§14 + appendix, cross-checked against `lib/`, `test/`, `scripts/`, `pubspec.yaml`; plus ARCHITECTURE.md ↔ CLAUDE.md cross-doc contradictions.
**Outcome:** drift report only. **No code or doc changes** in this PR.

## Summary

| Section | Entries | contradiction | stale | missing | misleading |
|---------|--------:|--------------:|------:|--------:|-----------:|
| §1 分层架构 | — | — | — | — | — |
| §2 Riverpod DI | — | — | — | — | — |
| §3 SOLID | — | — | — | — | — |
| §4 错误体系 | — | — | — | — | — |
| §5 并发与限流 | — | — | — | — | — |
| §6 文件路径解析 | — | — | — | — | — |
| §7 设计 Token | — | — | — | — | — |
| §8 i18n | — | — | — | — | — |
| §9 密钥存储 | — | — | — | — | — |
| §10 性能降级 | — | — | — | — | — |
| §11 A11y | — | — | — | — | — |
| §12 测试策略 | — | — | — | — | — |
| §13 日志规范 | — | — | — | — | — |
| §14 构建发布 | — | — | — | — | — |
| 附录 checklist | — | — | — | — | — |
| Cross-doc (ARCH↔CLAUDE) | — | — | — | — | — |
| **Total** | — | — | — | — | — |

> 表格在 Task 8 填实数。Total drift entries 必须 ≥ 5（A1 acceptance #3 floor），若严格不到 5，在 Task 8 显式写一段 "ARCHITECTURE.md is in better shape than expected" 说明。

---

## Findings

<!-- Each sweep task appends its section findings here, in section order. -->

<!-- Clean section 写法示例： §N: clean — all referenced files exist, naming matches code. -->

## §1 分层架构

### §1.1 — Service Layer 目录 `lib/features/*/services/` 在代码中不存在

**Claim (ARCHITECTURE.md:44):**
> `lib/features/*/services/  lib/services/`
> 职责：领域业务逻辑。纯 Dart，零 Flutter import。

**Reality:** `lib/features/` 下五个 feature（canvas/debug/generation/settings/workspace）均无 `services/` 子目录。canvas 只有 `models/ providers/ util/ widgets/`；generation 直接是单文件 `generation_controller.dart`，无层级。所有"应用级 Service"集中在 `lib/services/`（job_queue_service.dart 等 6 个文件），feature-scoped Service 概念在仓库里没落地。参见 `lib/features/canvas/`、`lib/features/generation/generation_controller.dart`。

**Severity:** `stale`

**Suggested fix (one line):** rewrite §1.1 Service Layer 行删除 `lib/features/*/services/`，或在 ROADMAP.md 标注"feature-scoped service 目录尚未引入"。

### §1.2 — feature 子目录树缺少 `services/`，新增了 `util/`

**Claim (ARCHITECTURE.md:73-77):**
> `features/ └── {feature}/ ├── widgets/ ├── providers/ └── services/`

**Reality:** 实际 feature 子目录是 `models/ providers/ util/ widgets/`（见 `lib/features/canvas/`）。`services/` 不存在；文档未提及的 `util/` 与 `models/` 存在。

**Severity:** `stale`

**Suggested fix (one line):** rewrite — 把 `services/` 删除，补 `models/`、`util/`，与 docs/CLAUDE.md "Project Structure" 节对齐。

### §1.3 — `lib/services/event_bus.dart` 事件总线未实现

**Claim (ARCHITECTURE.md:92):**
> **事件总线**：`lib/services/event_bus.dart`，用于一对多广播（如"生成完成"通知画布刷新）。

**Reality:** `lib/services/` 下不存在 `event_bus.dart`（grep `event_bus` 在 `lib/` 下零命中）。跨 feature 通信目前实际只走"共享 Provider"一条路径。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — 事件总线尚未实现，从 ARCHITECTURE.md 移走或显式标"planned"。

### §1.3 — feature 之间"不得互相 import"但 canvas → generation 已发生

**Claim (ARCHITECTURE.md:89):**
> Feature 之间**不得互相 import**。

**Reality:** `lib/features/canvas/widgets/video_config_inspector.dart:18` 与 `lib/features/canvas/widgets/image_config_inspector.dart:22` 均 `import '../../../features/generation/generation_controller.dart';`。canvas widget 直接引用 generation 的 Controller，跨 feature import 真实发生。

**Severity:** `contradiction`

**Suggested fix (one line):** clarify — 要么把 `generation_controller` 提升到 `lib/core/di/` 或 `lib/services/`（共享 Provider 模式），要么放宽文档中"不得互相 import"的措辞。

## §2 Riverpod DI

### §2.1 — 示例用 `@Riverpod(keepAlive: true)` 代码生成注解，实际仓库未使用 riverpod_generator

**Claim (ARCHITECTURE.md:114-117):**
> `@Riverpod(keepAlive: true)`
> `NodeRepository nodeRepository(NodeRepositoryRef ref) { ... }`

**Reality:** `lib/core/di/` 下 13 个文件全部用 plain `Provider<>` / `FutureProvider<>`，没有任何 `@Riverpod` / `@riverpod` 注解（grep 全 `lib/` 零命中）。`nodeRepositoryProvider` 实际定义在 `lib/core/di/repositories.dart:38` 是 `FutureProvider<NodeRepository>(...)`。文档示例与代码风格完全不一致，读者照抄会引入 build_runner 依赖。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite §2.1 代码示例为 plain `Provider<>` 形式，或在 pubspec 引入 riverpod_generator 后保留注解。

### §2.1 — `databaseProvider` 名字在代码中不存在

**Claim (ARCHITECTURE.md:117 & 139):**
> `return PostgresNodeRepository(ref.watch(databaseProvider));`
> `DatabaseConnection database(DatabaseRef ref) { ... }`

**Reality:** `lib/core/di/database.dart` 提供的是 `pgBinaryLocatorProvider` / `pgControllerProvider` / `pgConnectionProvider` / `pgMigratedConnectionProvider`，名为 `databaseProvider` 的 Provider 不存在。Repository 实际 `ref.watch(pgMigratedConnectionProvider.future)`（repositories.dart:24 等）。`DatabaseConnection` 类亦不存在——实际类型是 `package:postgres` 的 `Connection`。

**Severity:** `stale`

**Suggested fix (one line):** rewrite — 把示例里的 `databaseProvider` 改为 `pgMigratedConnectionProvider`，`DatabaseConnection` 改为 `Connection`。

### §2.2 — 生命周期矩阵第 3 行 `.family` 参数化无任何代码使用

**Claim (ARCHITECTURE.md:131):**
> **参数化** `@riverpod` + `.family` ... `nodeProvider(nodeId)`, `providerClientProvider(providerId)`

**Reality:** `lib/` 全树 grep `\.family` 与 `providerFamily` 零命中；`nodeProvider` / `providerClientProvider` 均不存在。矩阵此行是规划性叙述。

**Severity:** `misleading`

**Suggested fix (one line):** clarify — 标注"planned"或移到 ROADMAP，避免读者按此模式硬造不存在的 Provider 名。

## §3 SOLID

### §3.S — 举例文件 `canvas_viewport_notifier.dart` / `node_generation_service.dart` 均不存在

**Claim (ARCHITECTURE.md:192-194):**
> `✅ canvas_viewport_notifier.dart   → 仅管视口状态（缩放/平移）`
> `✅ node_generation_service.dart    → 仅负责生成流程编排`

**Reality:** Grep `canvas_viewport` / `NodeGenerationService` 在 `lib/` 下零命中。视口状态实际由 `lib/features/canvas/providers/` 下的 controller 管理（命名不是 `canvas_viewport_notifier`）；生成编排目前在 `lib/features/generation/generation_controller.dart` 单文件 + `lib/services/job_queue_service.dart`，无 `node_generation_service`。

**Severity:** `stale`

**Suggested fix (one line):** rewrite — 用真实文件名 `generation_controller.dart`、`job_queue_service.dart` 等替换示例；或显式标"示意，非实际文件名"。

### §3.D — 依赖倒置示例类 `NodeGenerationService` 不存在

**Claim (ARCHITECTURE.md:262-266):**
> `class NodeGenerationService { final Submittable _provider; final NodeRepository _repo; ... }`

**Reality:** `lib/` 全树无 `NodeGenerationService` 定义。实际承担此角色的是 `lib/features/generation/generation_controller.dart`（Riverpod Controller，不是构造注入 POJO）。文档示例展示的构造器注入风格在仓库里没有任何实例。

**Severity:** `misleading`

**Suggested fix (one line):** rewrite — 换成 `generation_controller.dart` 真实片段，或注明"示意代码，本仓库改用 Riverpod Controller 形态"。


---

## Cross-doc contradictions (ARCHITECTURE.md ↔ docs/CLAUDE.md)

<!-- Task 7 填充。 -->
