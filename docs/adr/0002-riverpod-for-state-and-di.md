# ADR-0002: 使用 Riverpod 统一状态管理与依赖注入

- **Status**: accepted
- **Date**: 2026-04-15
- **Deciders**: P9 (Tech Lead)
- **Related**: CLAUDE.md §Dependency Injection / ARCHITECTURE §2 / PRD §3.2

---

## Context

InkFrame 需要同时解决两个问题，且必须是同一套机制：

1. **UI 状态管理**：节点选中、视口变换、任务中心、流式 AI 对话
2. **依赖注入**：Repository / Service / Provider 客户端 / 数据库连接的生命周期

**约束：**

- **SOLID D** 硬约束（CLAUDE.md）：Widget 不得 import 具体实现，必须通过接口
- **无全局可变状态**：禁止 `ServiceLocator` / static singleton / global mutable
- **生命周期分层**：
  - app-scoped（DB 连接、HTTP 客户端、Repository、JobQueueService）
  - screen-scoped（ViewModel、查询缓存）
  - task-scoped（单次 Job 的上下文）
- **可测性**：替换任何依赖都只改注入点，测试 1 行 override 即可

**假设：**

- 团队对 Riverpod 的 `@riverpod` 代码生成模式接受度足够
- Flutter 生态后续仍以 Riverpod 为主流 DI（观察 2024-2025 PR 生态）

---

## Decision

**决定：** 全局统一使用 Riverpod（`riverpod_generator` + `@riverpod`），所有 `abstract class` 依赖通过 `Provider` 绑定；禁止 `Bloc` / `GetIt` / 自写 ServiceLocator。

**生命周期矩阵**（详见 ARCHITECTURE §2）：

| 作用域 | 语法 | 典型例子 |
|---|---|---|
| app-scoped | `@Riverpod(keepAlive: true)` | `databaseProvider`, `dioProvider`, `nodeRepositoryProvider`, `jobQueueServiceProvider` |
| screen-scoped | `@riverpod` (autoDispose) | `canvasViewModelProvider`, `scriptEditorStateProvider` |
| 参数化 | `@riverpod` + `.family` | `nodeProvider(nodeId)`, `providerClientProvider(providerId)` |
| 异步单次 | `FutureProvider` autoDispose | 单个节点详情加载 |

**理由：**

1. **状态与 DI 同构**：Riverpod 的 Provider 既是 DI 容器又是状态源——不必同时维护两套抽象（Bloc + GetIt = 两套心智负担）
2. **编译期依赖图**：`@riverpod` 代码生成让"谁依赖谁"进入静态可分析状态——IDE 跳转、测试 override、Ref 泄漏检测都可靠
3. **autoDispose 语义精确**：screen-scoped 依赖自动释放，解决了 Provider (of `package:provider`) 生命周期靠 BuildContext 的脆弱性
4. **测试替换成本 = 1 行**：`ProviderScope(overrides: [nodeRepositoryProvider.overrideWithValue(Fake())])`

---

## Consequences

**好的：**

- T1 widget_test 成功 override 真实依赖跑通（`InkFrameApp boots` 用例证据）
- 所有 Repository 接口已落 `lib/core/interfaces/` + Riverpod 绑定，零静态单例
- `keepAlive` 显式标注，生命周期一目了然，onDispose 有对应章节约束
- 代码生成减少样板：`@riverpod` 一个注解 = 一个 Provider + 一个 Ref 类型

**坏的 / 欠的债：**

- 学习曲线：`@riverpod` vs 老式 `Provider<T>((ref) => ...)` 两种风格并存初期，团队需要对齐
- `build_runner` 成本：每次改 provider 签名要跑代码生成；CI 已加 `dart run build_runner build`
- Flutter hot reload 偶发 Provider 状态漂移——ARCHITECTURE §2 的"keepAlive onDispose"约束就是为解决这个
- 锁定 Riverpod 生态；后续若官方推荐变更（如 Riverpod 3.x 大改），需统一迁移

**中性的（需观察）：**

- `autoDispose` + `keepAlive` 的组合选择全凭开发者判断力——需要 CR 审查 vigilance
- Provider 数量会很多（~100+），需要目录组织纪律（`lib/core/di/` + `lib/features/*/providers/`）

---

## Alternatives Considered

### 方案 A: Bloc + GetIt

- **优势**：Bloc 状态机语义严格，GetIt 极简
- **否决理由**：
  - 两套抽象，维护 + 学习成本 double
  - GetIt 是 service locator 反模式——违反 CLAUDE.md 明令禁止的"no static singletons"
  - Bloc 的 event-driven 对画布交互（实时拖拽、流式 diff）过重

### 方案 B: `package:provider` + `get_it`

- **优势**：生态老牌
- **否决理由**：
  - `provider` 的 Ref 基于 BuildContext，跨 Widget 树传递脆弱
  - 没有 autoDispose、family 的一等支持
  - 现代 Flutter 社区已基本转向 Riverpod

### 方案 C: 自写 DI 容器

- **优势**：完全可控
- **否决理由**：重复造轮子，无收益；状态管理仍要挑一个 = 两套维护

### 方案 D: InheritedWidget 直接用

- **优势**：Flutter 原生
- **否决理由**：复杂依赖图无组织，泄漏风险高；大型应用不可行

---

## Revisit Triggers

- Riverpod 3.x 发布且有重大 API 变更
- 发现 `autoDispose` 与长连接（WebSocket 生成任务）有不可调和冲突
- 团队反馈代码生成成本超出收益
- 至迟在 v0.2.0 Sprint 启动前重审
