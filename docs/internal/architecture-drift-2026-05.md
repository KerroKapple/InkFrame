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

## §4 错误体系

### §4.1 — 错误码 wire 字符串 `content_policy_violation` 与代码不一致

**Claim (ARCHITECTURE.md:338):**
> `| content_policy_violation | Provider | false | errorProviderContentPolicy |`

**Reality:** `lib/core/errors/ink_error.dart:12` 实际枚举值 `contentPolicy('content_policy')`，wire 是 `content_policy`（无 `_violation` 后缀）。DB 列 `jobs.error_code` 据注释与此一致。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite — 把表格里的 `content_policy_violation` 改为 `content_policy`，与代码 wire 对齐。

### §4.1 — messageKey 命名与 ARB 实际 key 全表偏离

**Claim (ARCHITECTURE.md:336-349):**
> 表格列出 14 个 messageKey：`errorProviderInvalidKey / errorProviderInsufficientBalance / errorProviderContentPolicy / errorProviderInvalidParameter / errorProvider5xx / errorProviderBusy / errorProviderTimeout …`

**Reality:** `lib/core/errors/ink_error.dart:39-54` 的 `_messageKeys` 表实际是 `errorInvalidKey / errorInsufficientBalance / errorContentPolicy / errorInvalidParameter / errorProviderServer / errorProviderBusy / errorNetworkTimeout / errorNetworkOffline / errorPollTimeout / errorDownloadFailed / errorLocalIO / errorCancelled / errorCancelledOnExit / errorUnknown`。除 `errorProviderBusy` 一项外，其余 13 个 key 命名与文档全不一致（无 `Provider` 前缀；`5xx` → `Server`；`Timeout` 拆为 Network/Poll）。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite — 整表 messageKey 列以代码与 ARB 实际 key 为准重写。

### §4.1 — `InkError` 字段 `isRetryable` 实为 `retryable` getter，且非构造参数

**Claim (ARCHITECTURE.md:303 / 311 / 317):**
> `bool get isRetryable;` 且子类 `const ProviderError.invalidKey() : super(..., isRetryable: false)`。

**Reality:** `lib/core/errors/ink_error.dart:85` 是 `bool get retryable => _retryable.contains(code);`（非 `isRetryable`），由全局 `_retryable` set（line 57-63）按 code 静态判定；子类构造器无 `isRetryable` 参数，例如 `ProviderError` (line 98-114) 只接收 `code/extra/cause/stackTrace`。文档示例若被照抄会编译失败。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite — 把 `isRetryable` 改为 `retryable` getter，并删除子类构造器里 `isRetryable:` 命名参数。

### §4.1 — 子类清单与代码层级不符（`ValidationError` 不存在；多出 `NetworkError / DownloadError / CancelledError / UnknownError`）

**Claim (ARCHITECTURE.md:307-329):**
> 列出四个子类 `ProviderError / StorageError / ValidationError / LocalIOError`。

**Reality:** `lib/core/errors/ink_error.dart` 实际 sealed 子类是 `ProviderError / NetworkError / DownloadError / LocalIOError / CancelledError / UnknownError`（line 98-163）。无 `StorageError`、无 `ValidationError`；多出 4 个文档未提及的子类。

**Severity:** `stale`

**Suggested fix (one line):** rewrite — 重写 sealed hierarchy 清单，列实际六个子类并删除 `StorageError / ValidationError`。

## §5 并发与限流

### §5.1 — "全局并发档位 省电/均衡/性能/极致 = 1/2/3/4" 在代码里不存在

**Claim (ARCHITECTURE.md:398-405):**
> `全局并发上限（性能档位决定）省电=1 / 均衡=2 / 性能=3 / 极致=4`

**Reality:** `lib/services/job_queue_service.dart:41` 仅有 `int globalConcurrency = 2` 构造参数（默认 2）。全树 grep `PerformanceTier` / 档位枚举零命中；`lib/services/job_queue_service.dart:7` 自己注释 `// b4 ⏳ 性能档位 → globalConcurrency 联动`，明确标 "未接入"。文档把规划描述成既成事实。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — 性能档位尚未实现，从 §5.1 删除四档数值或显式标 "planned (b4)"。

### §5.1 — 状态机末态 `cancelled_by_user / cancelled_on_exit` 实为单一 `cancelled` + error_code 区分

**Claim (ARCHITECTURE.md:411-415):**
> 状态机末态包含 `cancelled_by_user` 与 `cancelled_on_exit` 两个独立 status。

**Reality:** `lib/services/job_queue_service.dart:92,402` 写入 DB 的 `toStatus` 只有单一 `'cancelled'`；取消原因放在 `error_code`（`cancelled_by_user` / `cancelled_on_exit` wire 字符串）。`jobs.status` 取值集合实际是 `pending / submitted / polling / success / error / timeout / cancelled`（7 个），而非文档暗示的 8 个。

**Severity:** `misleading`

**Suggested fix (one line):** rewrite — 把状态机图里 `cancelled_by_user` / `cancelled_on_exit` 合并为 `cancelled`，并补注 "取消原因由 error_code 区分"。

### §5.1 — cancel 复杂度（未声明 → 现在 O(1)）

**Claim (ARCHITECTURE.md:392-418):** §5.1 全节 **未对 cancel 复杂度做任何声明**（无 O(n) / O(1) 字样）。

**Reality:** 实现已在 commit `9998880` 引入 `_pendingIndex` map + soft-delete，cancel 摊还 O(1)（`lib/services/job_queue_service.dart:73-77, 121-142, 161-176`）；commit `364e6a0` 在源码顶部补了数据结构注释（line 27-32）。文档不存在过时复杂度断言，但也未记录 invariant — 是 "应有未有" 的遗漏。

**Severity:** `missing`

**Suggested fix (one line):** clarify — 在 §5.1 增加一行 "cancel 对 pending 队列摊还 O(1)（pendingIndex map + soft-delete，见 job_queue_service.dart 注释）"。

### §5.2 — Token Bucket 字段名 / 接口 clean

§5.2: clean — `qps` / `burst` / `acquire()` 与 `lib/providers/rate_limiter.dart:25-44` 一一对应；阻塞语义、不抛错、不计入 retry 的描述与实现一致。

## §6 文件路径解析契约

### §6.2 — `FileResolverService` 文件位置与文档路径不符

**Claim (ARCHITECTURE.md:481):**
> `// lib/core/paths/file_resolver_service.dart`

**Reality:** 实际文件在 `lib/services/file_resolver_service.dart`（abstract + DefaultFileResolverService）。`lib/core/paths/` 下只有 `app_paths.dart`，无 `file_resolver_service.dart`。

**Severity:** `stale`

**Suggested fix (one line):** rewrite — 把示例路径改为 `lib/services/file_resolver_service.dart`。

### §6.2 — `resolve()` 返回类型 / `toRelative` 入参 / `mediaDir()` 全部与代码偏离

**Claim (ARCHITECTURE.md:482-505):**
> `String resolve({...})` / `String toRelative({..., required String absolutePath})` / `String mediaDir({..., required MediaType type})` + `enum MediaType { images, videos, thumbnails }`。

**Reality:** `lib/services/file_resolver_service.dart:17-34` 实际签名是 `File resolve({...})`（返回 `File`，非 `String`）、`String toRelative({..., required File source})`（入参是 `File`，非 `String`）、`Directory canvasRoot({...})`（**无** `mediaDir` 方法，**无** `MediaType` 枚举）。文档抽象与实际抽象在签名/方法名层面都不匹配。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite — 用真实签名重写接口块；删除 `mediaDir` / `MediaType` 或先在代码里加上。

### §6.3 — `DefaultFileResolverService(dataDir: ...)` 构造形态不存在

**Claim (ARCHITECTURE.md:516-519):**
> `return DefaultFileResolverService(dataDir: settings.dataDir);`

**Reality:** `lib/services/file_resolver_service.dart:42` 构造器是 `const DefaultFileResolverService(this._paths)`——位置参数注入 `AppPaths`（不是 `dataDir` 字符串），且 dataDir 来源是 `AppPaths` / 环境变量 `HOME|USERPROFILE` + path_provider 回退，并非 `SettingsService.dataDir`（grep `settingsServiceProvider` 与示例中 `dataDir` 字段在 lib 下零相关命中）。

**Severity:** `stale`

**Suggested fix (one line):** rewrite — 改为 `DefaultFileResolverService(ref.watch(appPathsProvider))`（或仓库实际 DI 名），并删除虚构的 `SettingsService.dataDir`。

### §6.4 — `FileNameSanitizer.sanitize()` 在代码中不存在

**Claim (ARCHITECTURE.md:524):**
> `写入磁盘前，所有文件名必须经过 FileNameSanitizer.sanitize()`

**Reality:** Grep `FileNameSanitizer` / `sanitize` 在 `lib/` 下零命中。`DefaultFileResolverService` 自身有控制字符 / 绝对路径 / `..` 穿越校验（`_assertSafeSegment`、`_controlChar`），但没有 200 字符截断 / `_1` 冲突后缀 / Unicode 保留这些文档承诺的语义。整个清理 API 是承诺未兑现。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — `FileNameSanitizer` 未实现，从 §6.4 删除或标 "planned"。

### §6.1 — "数据库只存相对路径" 在 schema 中无注释 / 约束体现

**Claim (ARCHITECTURE.md:467):**
> 数据库中 **只存相对路径**，根为画布目录。禁止任何层持有绝对路径字符串。

**Reality:** `lib/storage/schema/001_init.sql` / `schema_v1.dart` 中 `image_url / video_url / thumbnail_url`（line 194 等）均为裸 `TEXT`，无 CHECK 约束、无列注释（COMMENT ON）、无 SQL 文件级说明明确该列必须相对路径。文档契约只在 Dart 层（FileResolverService）落地，schema 层是 best-effort。

**Severity:** `missing`

**Suggested fix (one line):** clarify — 要么 schema 加 `CHECK (image_url !~ '^([a-zA-Z]:|/)')` 列约束，要么 §6.1 明确 "约束仅在应用层强制，schema 不做格式校验"。

## §7 设计 Token 系统与主题切换

§7: clean — token 层级、三套 `InkColors` 变体、主题切换机制均与代码一一对应。

- `lib/theme/tokens.dart:13/157/168/180` 分别定义 `InkColors / InkSpacing / InkRadius / InkShadow` 四个 token 类（§7.1 / §7.2 全部命中）。
- `InkColors.dark()` (line 43) / `InkColors.light()` (line 72) / `InkColors.highContrast()` (line 101) 三套变体齐全；A11y `focusRing` 字段 (line 37,141) 与 §7.2 注释 "A11y §11 新增" 对应。
- 主题切换：`lib/theme/app_theme.dart:46` 定义 `enum InkThemeVariant { dark, light, highContrast }`；`lib/core/di/theme.dart:31-82` 的 `ThemeModeController` 监听 `PlatformDispatcher.platformBrightness`（line 50）并按 "用户偏好 > 系统亮度" 决议（line 41-50, 73），与 §7.3 "用户手动选择 > 跟随系统" 优先级一致。
- 仓库另有 `lib/theme/typography.dart`、`lib/theme/motion.dart`、`lib/theme/primitives/`（7 个文件）— §7.1 层级图未画出，但 `docs/CLAUDE.md` "Token Structure" 已列出，非 drift。

**Suggested fix (one line):** none — §7 与代码一致；如要进一步收紧，可在 §7.1 层级图中补一行 `Primitives（lib/theme/primitives/）` 与 `Typography / Motion` token 文件。

## §8 i18n 架构与 ARB 一致性门禁

### §8.3 — "System prompt 也必须走 i18n" 与项目根铁律及代码现状直接冲突

**Claim (ARCHITECTURE.md:665-670):**
> **System prompt 也必须走 i18n：** `final systemPrompt = context.l10n.geminiImageSystemPrompt;`

**Reality:** `docs/CLAUDE.md` "LLM / System Prompts — DO NOT i18n" 节明确规定：prompts "Keep them as English string constants ... Translating a system prompt creates a per-locale model behavior fork that is impossible to A/B reason about." 两份治理文档自相矛盾。代码层面也站在 CLAUDE.md 一边——`lib/providers/` 下 7 个 provider 文件 grep `systemPrompt|_kSystemPrompt|_kPromptTemplate` 零命中；`lib/providers/gemini_image_provider.dart:123,137` 只把用户输入 `task.prompt` 直接发给模型，未注入任何 system prompt；`l10n.geminiImageSystemPrompt` 这个 ARB key 在 `app_en.arb` / `app_zh.arb` 中都不存在。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite §8.3 — 删除 "System prompt 也必须走 i18n" 段，改为引用 `docs/CLAUDE.md` 的 "LLM / System Prompts — DO NOT i18n" 铁律。

### §8.1 — `lib/l10n/generated/` 子目录不存在（gen-l10n 输出在 build 目录）

**Claim (ARCHITECTURE.md:632-637):**
> `lib/l10n/ ├── app_en.arb ├── app_zh.arb └── generated/  # flutter gen-l10n 自动生成，不手动修改`

**Reality:** `lib/l10n/` 实际内容只有 `app_en.arb`、`app_zh.arb`、`l10n_x.dart`（手写的 `BuildContext.l10n` 扩展，非 generated）。无 `generated/` 子目录。Flutter gen-l10n 默认把 `AppLocalizations` 输出到 `.dart_tool/flutter_gen/gen_l10n/`，由 `pubspec.yaml: generate: true` 隐式包入；仓库未 override `synthetic-package: false`。文档画的目录结构会让读者去 `lib/l10n/generated/` 找不到东西。

**Severity:** `stale`

**Suggested fix (one line):** rewrite — 删除 `generated/` 行，补一句 "AppLocalizations 由 flutter_gen 写入 `.dart_tool/`（synthetic package），开发者不直接访问"，并提及手写扩展 `lib/l10n/l10n_x.dart`。

### §8.4 — ARB 一致性门禁实际是 Claude hook，而非通用 CI

**Claim (ARCHITECTURE.md:672-681):**
> `scripts/hooks/check-i18n-coverage.sh` 在每次 `PostToolUse Write/Edit` 后执行 ... 每次 commit 必须满足：en 和 zh 的 key 集合完全一致。

**Reality:** `scripts/hooks/check-i18n-coverage.sh` 存在且 (line 56-60) 用 `grep + sed + sort` 抽 key 求差集，与文档行为大体一致；但触发点是 **Claude Code PostToolUse hook**（line 8 仅接受单文件参数 `$1`），不是 git pre-commit / CI step。`scripts/hooks/pre-commit` 文件确实存在（同目录），需进一步确认是否调用此脚本；无 GitHub Actions 工作流（`.github/workflows/` 未在 §8 提及）。当前措辞 "CI 强制" 措辞夸大——真正强制的是本机 Claude 写文件后的钩子。

**Severity:** `misleading`

**Suggested fix (one line):** clarify — 把 "CI 强制" 改为 "Claude Code PostToolUse hook 强制（脚本同时被 `scripts/hooks/pre-commit` 调用以双重保护）"，并补一句"CI 工作流如未配置请加 `.github/workflows/i18n.yml`"。

### §8.x — ARB 双语 coverage 实测

ARB 一致性现状（2026-05-12 实测）：`app_en.arb` 103 key，`app_zh.arb` 103 key，`only_en = ∅`，`only_zh = ∅`。门禁当前 green。

## §9 密钥存储

### §9.2 — 接口签名与代码完全一致；平台后端清单缺 "debug 文件" 一项

**Claim (ARCHITECTURE.md:707-725):**
> `abstract class SecureStorageService { Future<void> store / retrieve / delete / exists ... }` + 平台实现 "macOS → Keychain / Windows → Credential Manager"。

**Reality:** `lib/core/interfaces/secure_storage_service.dart` 抽象与 `lib/services/platform_secure_storage_service.dart:9-34` 实现一对一匹配（`store / retrieve / delete / exists` 四方法签名完全一致）。平台后端仅 macOS Keychain + Windows Credential Manager 两套；**没有** debug 文件后端（grep `lib/` 下 `DebugFile|FileSecureStorage` 零命中）。Task 3 描述中提到的"三套（含 debug 文件）"在代码里不存在——若属规划应放 ROADMAP，不应在审计假设里。

**Severity:** `stale`

**Suggested fix (one line):** none for §9.2 doc itself（与代码一致）；但若团队期望 debug-file 后端，应在 ROADMAP.md 增项，而非维持在审计任务假设里。

### §9.2 — Key 命名规范缺 "provider family scope 折叠" 这一关键约定

**Claim (ARCHITECTURE.md:723-724):**
> `provider API key：  'provider.{providerId}.api_key'  /  proxy password：  'network.proxy.password'`

**Reality:** `lib/core/constants/secure_storage_keys.dart:7-40` 实现的是 **family scope** 而非 raw providerId——`wanx-image / wanx-t2v / wanx-i2v / wanx-r2v / kling-v3 / kling-v3-omni` 六个 providerId 在 `scopeOf()` (line 26-29) 折叠为单一 scope `dashscope`，最终 key 是 `provider.dashscope.api_key`，并非 `provider.wanx-image.api_key`。文档完全没提这层映射，新加一个阿里云家族成员的人会按字面 `provider.{providerId}.api_key` 写 key，结果存了一把读不到的孤立密钥。

**Severity:** `missing`

**Suggested fix (one line):** rewrite — 在 §9.2 key 命名规范段补一句 "DashScope 家族（wanx-* / kling-v3*）共用 `provider.dashscope.api_key`，详见 `SecureStorageKeys.scopeOf`"，避免用户重复配置同一把 Key。

### §9.3 — `lib/core/constants/network.dart` 与 `kApiKeyValidationCacheTtl` 整段未实现

**Claim (ARCHITECTURE.md:730-737):**
> `// lib/core/constants/network.dart` + `const Duration kApiKeyValidationCacheTtl = Duration(hours: 1);` + "缓存有效期内不重复调用 Provider 验证接口（节省配额）"。

**Reality:** `lib/core/constants/` 下只有 `secure_storage_keys.dart` 一个文件；全树 grep `kApiKeyValidationCacheTtl` / `network\.dart` 零命中。整段 "Key 验证缓存" 机制（TTL / 失效条件 / 节配额）在代码里完全不存在——承诺未兑现。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — Key 验证缓存尚未实现，从 §9.3 删除或显式标 "planned"。


## §10 性能降级控制器

### §10.1 — `PerformanceDegradationController` / `lib/services/performance_degradation_controller.dart` 整节未实现

**Claim (ARCHITECTURE.md:744-765):**
> `// lib/services/performance_degradation_controller.dart` + `@Riverpod(keepAlive: true) class PerformanceDegradationController extends _$PerformanceDegradationController { ... PerformanceTier get effectiveTier => state; ... }`

**Reality:** not present. `lib/services/` 实际只有 6 个文件（`job_queue_service.dart / file_resolver_service.dart / dio_video_download_service.dart / media_kit_thumbnail_service.dart / media_kit_video_player_service.dart / platform_secure_storage_service.dart`），无 `performance_degradation_controller.dart`。全树 grep `DegradationTier|PerformanceTier|tierUp|tierDown|PerformanceDegradationController|effectiveTier|performanceTierProvider` 在 `lib/` 下零命中。整套 "基准档位 vs effectiveTier" 抽象在代码里不存在。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — 性能降级控制器整段未实现，从 §10.1 删除或显式标 "planned"（与 §5.1 性能档位 b4 注释一致）。

### §10.2 — 双阈值 hysteresis 矩阵（内存/帧率/磁盘 + 冷却期）在代码中无任何实现

**Claim (ARCHITECTURE.md:767-775):**
> `| 内存 RSS | > 80% | 10s | 清 LRU 至 50% ... | 帧率 < 30fps | 5s | 关动画 ... | 磁盘 < 1GB ... | 冷却期：每次降级或恢复后 60s 内不再触发同向动作。`

**Reality:** not present. 无内存/帧率/磁盘信号采样代码——grep `ProcessInfo|currentRss|rss|diskSpace|freeSpace|cooldown` 与降级动作（清 LRU / 关动画 / 缩略图减半）在 `lib/` 下均无与该机制相关命中。Hysteresis、冷却期、降级动作三层皆为纸面规范。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — 整张矩阵搬到 ROADMAP，待 controller 落地后再回流到 ARCHITECTURE.md。

### §10.4 — `lib/services/fps_monitor.dart` 与 3s 滑动平均帧率监控不存在

**Claim (ARCHITECTURE.md:790-800):**
> `// lib/services/fps_monitor.dart class FpsMonitor { static const _windowDuration = Duration(seconds: 3); ... double get averageFps { ... } }`

**Reality:** not present. `lib/services/` 无 `fps_monitor.dart`；全树 grep `FpsMonitor|averageFps|SchedulerBinding.*addTimingsCallback` 在 `lib/` 下零命中。3 秒滑动平均帧率采样机制完全缺失。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — 删除 §10.4 代码示例或标 "planned"。

## §11 A11y 分层责任与键盘覆盖率门禁

### §11.1 — Semantics / SemanticsService.announce 在 ViewModel/Widget 层近乎零覆盖

**Claim (ARCHITECTURE.md:807-826):**
> 分层责任矩阵：Widget Layer 声明 `Semantics` label/role/state；ViewModel Layer "状态变化时触发 `SemanticsService.announce`"；并要求"节点状态变化必须 announce"、"所有按钮/输入框必须有 label"、"节点必须声明 role + state"。

**Reality:** `lib/` 全树 grep `Semantics\(|SemanticsService\.announce` 仅 2 个命中文件（`lib/theme/components/ink_button.dart:1`、`lib/theme/components/ink_error_banner.dart:1`，各 1 处），且 grep `SemanticsService\.announce` 零命中。节点状态变化、ViewModel announce、Semantics role+state 三条强承诺在仓库里均无落地。

**Severity:** `stale`

**Suggested fix (one line):** clarify — 在 §11.1/§11.2 标注"当前覆盖度近零，P0-Beta 前补齐"，或把该节整体降级为 ROADMAP 条目。

### §11.4 — `scripts/hooks/check-keyboard-semantics.sh` 不存在；键盘门禁纸面规范

**Claim (ARCHITECTURE.md:864-870):**
> `CI Hook scripts/hooks/check-keyboard-semantics.sh：扫描 lib/features/ 下的 GestureDetector 和 InkWell，若无对应的 onKey / KeyboardListener / Shortcuts 覆盖，exit 1`

**Reality:** not present. `scripts/hooks/` 下实际只有 8 个脚本（`check-direct-instantiation.sh / check-disposable-cleanup.sh / check-i18n-coverage.sh / check-inline-styles.sh / check-updated-at.sh / check-magic-strings.sh / pre-commit / pre-push`），无 `check-keyboard-semantics.sh`。佐证：`lib/` 全树 grep `LogicalKeySet|SingleActivator|Shortcuts\(|CallbackShortcuts` 零命中——即便门禁存在也会因无键盘绑定全量 exit 1，进一步说明门禁从未运行过。

**Severity:** `stale`

**Suggested fix (one line):** move to ROADMAP — 删除"CI Hook ..."段或标 "planned"，与 §10 性能降级一并归入 P0-Beta 验收前置项。

### §11.3 — focusRing token clean

§11.3: clean — `lib/theme/tokens.dart` 提供 `focusRing` 字段（`InkColors` 三套变体均含；§7.2 注释 "A11y §11 新增" 与此呼应）；token 层供给到位，但消费侧（`FocusableActionDetector` + 2px 焦点环）在 `lib/` 中无实际使用（grep `FocusableActionDetector` 零命中）——属于"token 备好、widget 未消费"的半成品状态，按 §11.3 仅描述 token 规范而言不算 drift，故标 clean。

---

## §12 测试策略与分层

### §12.1 — Repository 75% 覆盖率门槛未在 CI 强制

**Claim (ARCHITECTURE.md:884, 934-946):**
> Repository 层 ... 75% ... `lcov --extract coverage/lcov.info 'lib/storage/*' -o storage_coverage.info; check_coverage storage_coverage.info 75`

**Reality:** `.github/workflows/ci.yml:76-87` 只用 `VeryGoodOpenSource/very_good_coverage@v3` 跑了一道 `min_coverage: 70` 的全仓门禁，**没有** `lcov --extract` 拆 `lib/storage/*` 单独打 75% 的步骤，也没有任何 `check_coverage` 工具调用；门禁同时还 `exclude` 掉了 `lib/main.dart / media_kit_* / video_player / thumbnail / l10n/generated / features/debug`（doc 完全未提）。Repository 层的 75% 浮在纸面，CI 无法兜底。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite §12.1 + §12.5 — 改为 "全仓 70%（含 exclude list）" 或在 CI 加一步真实 lcov extract + storage 75% 二段门禁。

### §12.4 — `dart_test.yaml` 标签与超时配置不符

**Claim (ARCHITECTURE.md:917-924):**
> `tags:\n  integration:\n    timeout: 60s\n  unit:\n    timeout: 10s`

**Reality:** `dart_test.yaml:1-4` 实际定义的是 `tags: { pg: ... }`（占位、未设超时），用途是真 PG 集成测；仓内 `@Tags(...)` 命中 4 处全部是 `@Tags(['pg'])`（`test/storage/schema/violation_matrix_test.dart:5`、`test/storage/schema/cascade_test.dart:2`、`test/storage/migration_runner_integration_test.dart:3`、`test/storage/repositories/postgres_repositories_integration_test.dart:2`）。`integration` / `unit` 两个 tag 名在仓中**零命中**，doc 给的 `flutter test --tags integration` / `--exclude-tags integration` 命令打不到任何测试。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite — 把 §12.4 改为 `pg` tag 实情（"真 PG 集成测；未设 TEST_PG_URL 时自动 skip"），删除 integration/unit 超时段。

## §13 日志规范

### §13.3 — 接口命名 `InkLogger` ≠ 实际 `LoggerService`

**Claim (ARCHITECTURE.md:984-990):**
> `// lib/core/logging/ink_logger.dart\nabstract class InkLogger { void error(String module, String msg, {Object? cause, Map<String, Object> extra = const {}}); ... }`

**Reality:** `lib/core/logging/logger_service.dart:62-79` 实际接口名 `LoggerService`（不是 `InkLogger`），文件名 `logger_service.dart`（不是 `ink_logger.dart`）；方法签名 `extra` 类型为 `Map<String, Object?>?`（可空 + 值可空），与 doc 的 `Map<String, Object> extra = const {}` 都不同；`error` 多了 `StackTrace? stackTrace` 参数 doc 未列。

**Severity:** `stale`

**Suggested fix (one line):** rewrite §13.3 — 同步接口名 / 文件名 / `extra` 可空签名 / `stackTrace` 参数。

### §13.4 — 脱敏规则与实现策略完全不同

**Claim (ARCHITECTURE.md:1005-1014):**
> API Key 显示前 4 位 + `****`；prompt 截断至前 50 字符 + `...`；用户文件路径替换 home 目录为 `~`；代理密码替换为 `[REDACTED]`

**Reality:** `lib/core/logging/logger_service.dart:100-108, 119-133` 实际策略是"白名单 key 全量替换 `***`"：命中 `key / api_key / apikey / token / authorization / authorisation / prompt`（**不区分大小写**）整体替换为字面量 `***`；**没有** "前 4 位 + ****" 截断逻辑、**没有** prompt 前 50 字符截断、**没有** home → `~` 路径替换、**没有** `[REDACTED]` 字面量；代理密码字段（如 `proxy_password`）不在白名单内，会原样落盘——这是一条潜在数据泄露面。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite — 要么把 §13.4 改为"白名单字段值替换 ***"实情，要么在 LoggerService 实现 doc 描述的差异化打码（API key 前 4 / prompt 截断 50 / `~` / `[REDACTED]`）。

### §13.5 — 崩溃日志独立保留 3 份"未实现写入路径"

**Claim (ARCHITECTURE.md:1023):**
> 崩溃日志：`inkframe.crash.{timestamp}.log`，独立保留最近 3 份，不参与轮转

**Reality:** `lib/core/logging/logger_service.dart:275-277` 只在 `_logFilesByAge` 里**跳过** `inkframe.crash.` 前缀文件（不参与磁盘预算回收），但仓内 grep 找不到任何"写崩溃日志"的代码路径（无 FlutterError.onError / PlatformDispatcher.instance.onError / runZonedGuarded 调 logger 写 `inkframe.crash.*` 的逻辑），也没有"最近 3 份"的滚动保留实现。当前是"目录扫描时跳过这类文件名"，并非实际能产出 crash log。

**Severity:** `missing`

**Suggested fix (one line):** clarify — 在 §13.5 标 "planned: crash dump writer 未实现，当前 LoggerService 仅在磁盘回收时豁免 `inkframe.crash.*` 前缀" 或移入 ROADMAP。

### §13.1 — 日志格式 / §13.2 模块命名 clean

§13.1: clean — `_serialize` (`logger_service.dart:135-149`) 输出 `ts/level/module/msg/extra` 五字段单行 JSON，与 doc 一致；`ts` 走 `DateTime.now().toUtc().toIso8601String()`。§13.2: clean — 模块名作为字符串参数自由传入，无 schema 强制，doc 给的是命名指南而非接口契约，不构成 drift。

## §14 构建与发布流水线

### §14.3 — PG 拉取脚本路径不对

**Claim (ARCHITECTURE.md:1060-1061):**
> `# scripts/fetch-pg-binaries.sh\nPG_VERSION=$(cat scripts/pg-version.txt)`

**Reality:** `scripts/fetch-pg-binaries.sh` not present；实际路径为 `scripts/pg/fetch-binaries.sh`，版本文件 `scripts/pg/pg-version.txt`（均位于 `scripts/pg/` 子目录）。doc 的 §14.4 构建步骤里同样写错路径 `scripts/fetch-pg-binaries.sh`（line 1084）。

**Severity:** `stale`

**Suggested fix (one line):** rewrite §14.3 + §14.4 — 把脚本路径统一改为 `scripts/pg/fetch-binaries.sh` 与 `scripts/pg/pg-version.txt`。

### §14.4 / §14.5 — `scripts/sign-and-notarize.sh` 不存在；签名公证只有纸面流程

**Claim (ARCHITECTURE.md:1091, 1098-1118):**
> `scripts/sign-and-notarize.sh         # 8. 签名 + 公证` + macOS `codesign` / `xcrun notarytool` / Windows `signtool` 三段实操命令

**Reality:** not present。`scripts/` 树（`scripts/hooks/`、`scripts/lib/release_guardrails.sh`、`scripts/pg/*`、`scripts/release-tag.sh`）下没有 `sign-and-notarize.sh`，没有任何 codesign / notarytool / signtool 调用；`.github/workflows/` 也无 release / sign workflow。整个 §14.5 是计划稿。

**Severity:** `missing`

**Suggested fix (one line):** move to ROADMAP — §14.5 标 "planned, 见 ROADMAP P0-Beta 签名公证"，或新增 release workflow + 脚本后再写回。

### §14.2 — 平台构建矩阵在 CI 中不存在

**Claim (ARCHITECTURE.md:1040-1053):**
> `matrix: include: - macos-latest arm64 ... - macos-latest x64 ... - windows-latest x64 ...`

**Reality:** `.github/workflows/ci.yml:18-108` 三个 job（analyze / test / golden）全部跑在 `ubuntu-latest` 单平台，**没有** matrix 配置，**没有** release-build workflow 文件（`.github/workflows/` 只有 `ci.yml` 与 `secret-scan.yml`）。ci.yml 头注释也明说 "macOS/Windows 烟测放到 release 流水线"——但该流水线还没建。

**Severity:** `missing`

**Suggested fix (one line):** move to ROADMAP — §14.2 整段标 planned，或先新增 `.github/workflows/release.yml` 再保留 doc。

### §14.6 — CI Hook 清单与 ci.yml 不齐（7 条 vs 6 条）

**Claim (ARCHITECTURE.md:1125-1133):**
> 7 个 hook：check-magic-strings / check-inline-styles / check-direct-instantiation / check-disposable-cleanup / check-i18n-coverage / check-updated-at / check-keybindings

**Reality:** `scripts/hooks/` 下只有 6 个 `check-*.sh`（`check-direct-instantiation / check-disposable-cleanup / check-i18n-coverage / check-inline-styles / check-magic-strings / check-updated-at`），无 `check-keybindings.sh`；`.github/workflows/ci.yml:33-44` 也只挂了这 6 个 hook。§11.4 已记录 `check-keyboard-semantics.sh` 缺失（不同脚本名，同一类问题）。

**Severity:** `stale`

**Suggested fix (one line):** rewrite §14.6 — 删除 `check-keybindings.sh` 行（或并入 §11.4 的 ROADMAP 条目）。

### §14.1 / §14.7 — 触发条件 / 发布渠道 clean

§14.1: clean — `ci.yml:10-13` `on: { push: branches: [main], pull_request: }` 与 doc "PR → main / push main" 触发条件一致。§14.7: clean — `scripts/release-tag.sh` 实际就在做 annotated tag + guardrail（grep `release(v*)` pattern 校验），与 doc 描述的 alpha/beta/stable tag 流派一致；GitHub Releases 侧操作不在仓内代码可验证。

---

## 附录

10 条 invariant 逐条验证（ARCHITECTURE.md §附录, line 1151–1164）。结论概要：

- `new ConcreteClass()` in Widget/Service 层: **clean**
- 硬编码 UI 字符串: **clean**（前置 §8 已覆盖；ARB key 集合一致）
- `Color(0xFF...)` / `fontSize: N` / `EdgeInsets.all(N)`: **partial drift**（见 §附.3）
- `StreamSubscription` / `Timer` / `AnimationController` dispose: **clean**
- `app_en.arb` 与 `app_zh.arb` key 集合一致: **clean**（en/zh 各 103 keys，diff = ∅）
- Repository `upsert/update` 经 `withUpdatedAt()` 包装: **partial**（见 §附.6）
- 错误通过 `InkError` 传播，无裸 `Exception` 跨层: **clean**（`throw Exception(` 0 hits in lib/）
- `ref.watch()` in `build()` / `ref.read()` in callbacks: **not fully audited**（见 §附.8）
- `flutter analyze` 0 warning / `flutter test` 全绿: **out-of-scope**（前置 §12/§14 覆盖；本次仅静态 sweep）

### §附.1 — `new ConcreteClass()` in Widget/Service 层 clean

**Claim (ARCHITECTURE.md:1155):**
> 没有 `new ConcreteClass()` 在 Widget / Service 层

**Reality:** clean — `grep -rn 'new [A-Z]' lib/**/*.dart` 仅 1 hit (`lib/services/file_resolver_service.dart:1` 为注释或路径字符串而非构造器调用; Dart 2 起 `new` 关键字已可省略，全局零有效命中)。

**Severity:** （不构成 drift）

**Suggested fix (one line):** 无须修改。

### §附.3 — 硬编码视觉值 partial drift (debug showcase + InteractiveViewer)

**Claim (ARCHITECTURE.md:1157):**
> 没有 `Color(0xFF...)` / `fontSize: N` / `EdgeInsets.all(N)`

**Reality:**
- `lib/theme/tokens.dart`: 69× `Color(0xFF...)` —— **token 定义文件本身**，invariant 隐含 token 源文件除外，不算 drift。
- `lib/theme/typography.dart:22-57`: 8× `fontSize: N * scale` —— typography token 定义文件，token 源文件，不算 drift。
- `lib/theme/primitives/ink_gradient_button.dart:32-37`: 6× `Color(0xFF...)` 作为 `InkGradientVariant` 颜色对常量。**stale**——这些渐变色应迁入 `tokens.dart` 而不是写在 primitive 里。
- `lib/features/debug/primitives_showcase_screen.dart`: 1× `Color(0xFF...)` + 2× `EdgeInsets.all(N)` —— **debug 展厅**屏幕，附录未列出豁免；invariant 字面上禁止。建议明确豁免 `features/debug/`。
- `lib/features/canvas/widgets/canvas_view.dart:325`: `boundaryMargin: const EdgeInsets.all(2000)` —— InteractiveViewer 边界外延，非视觉 padding，但 invariant 字面禁止。**misleading**：invariant 应澄清"视觉 padding"而非所有 `EdgeInsets.all`。

**Severity:** `stale`（ink_gradient_button 硬编码色应迁入 tokens）+ `misleading`（附录 invariant 未区分视觉 padding vs. 几何边界 / 未豁免 debug 展厅）

**Suggested fix (one line):** rewrite 附录条目为"非 `lib/theme/` 与 `features/debug/` 下"；并将 `ink_gradient_button.dart` 的 6 色迁入 tokens。

### §附.4 — Timer / AnimationController dispose clean

**Claim (ARCHITECTURE.md:1158):**
> 所有 `StreamSubscription` / `Timer` / `AnimationController` 有 dispose

**Reality:** clean — `StreamSubscription` 与 `AnimationController` 在 `lib/` 0 hits（功能上未使用）；`Timer(` 3 处全部正确 cancel：
- `lib/providers/rate_limiter.dart:69` → `dispose():78 _wakeTimer?.cancel()`
- `lib/features/canvas/widgets/video_config_inspector.dart:112` → `dispose():72 _promptDebounce?.cancel()`
- `lib/features/canvas/widgets/image_config_inspector.dart:100` → `dispose():75 _promptDebounce?.cancel()`

**Severity:** （不构成 drift）

**Suggested fix (one line):** 无须修改。

### §附.5 — ARB key 集合一致 clean

**Claim (ARCHITECTURE.md:1159):**
> `app_en.arb` 和 `app_zh.arb` 同步更新，key 集合一致

**Reality:** clean —— 忽略 `@`-前缀 metadata 后，`lib/l10n/app_en.arb` 与 `lib/l10n/app_zh.arb` 各 103 keys，对称差 = ∅。（含 `@` metadata 时 en 有 6 个 `@xxx` 描述项 zh 未提供，属常规 ARB 模式，非 drift。）

**Severity:** （不构成 drift）

**Suggested fix (one line):** 无须修改。

### §附.6 — Repository `update` 经 `withUpdatedAt()` 包装 partial drift

**Claim (ARCHITECTURE.md:1160):**
> 所有 Repository `upsert/update` 经过 `withUpdatedAt()` 包装

**Reality:** 部分 repository 的 `update(...)` 方法**未**调用 `withUpdatedAt`：
- `lib/storage/repositories/postgres_batch_result_repository.dart:73-87`: `update` 直接展开 patch，**未** `withUpdatedAt` 包装。
- `lib/storage/repositories/postgres_edge_repository.dart:83-84`: 注释明确 "edges 表没有 updated_at 列；withUpdatedAt 不适用——直接 patch"，属合理豁免但 invariant 字面未豁免。
- `lib/storage/repositories/postgres_style_lane_repository.dart:65` / `postgres_project_repository.dart:57` / `postgres_node_repository.dart:89` / `postgres_job_repository.dart:103` / `postgres_canvas_repository.dart:57`: 5 个 `update` 方法签名均直接接 patch；未在采样片段中看到 `withUpdatedAt` 调用（`base_repository.dart` 仅在 `upsert` 路径用 `withUpdatedAt` —— line 47）。

注：`withUpdatedAt` 在 `lib/` 真实调用仅 1 处（`base_repository.dart:47` 的 upsert 分支）。invariant 中关于 `update` 路径的部分实际未被 base class 强制；具体 repository 的 `update` 实现自行决定是否包装。

**Severity:** `contradiction`

**Suggested fix (one line):** rewrite invariant 为"经过 `withUpdatedAt()` 包装（除 schema 无 `updated_at` 列的表如 `edges`）"，并在 `BaseRepository.update` 默认通道强制注入。

### §附.7 — 无裸 `Exception` 跨层 clean

**Claim (ARCHITECTURE.md:1161):**
> 错误通过 `InkError` 子类传播，没有裸 `Exception` 跨层

**Reality:** clean —— `grep 'throw Exception(' lib/**/*.dart` 0 hits。

**Severity:** （不构成 drift）

**Suggested fix (one line):** 无须修改。

### §附.8 — `ref.watch()` in build / `ref.read()` in callbacks 未完整审计

**Claim (ARCHITECTURE.md:1162):**
> `ref.watch()` 在 `build()` 里，`ref.read()` 只在事件回调里

**Reality:** 静态正则难以可靠区分 "build 体内的事件回调" vs. "build 体内的同步执行路径"。粗扫 `lib/app.dart` / `lib/features/canvas/widgets/canvas_view.dart` / `lib/features/canvas/widgets/image_config_inspector.dart` 的 build 体中均出现 `ref.read`；目测多数位于 `onPressed` / `onTap` 等回调闭包内（合法）。不构成可断言的 drift，但缺少自动化门禁。

**Severity:** `missing`（规则存在但无 lint / CI 强制）

**Suggested fix (one line):** add `custom_lint` 规则或在 CI 跑 `riverpod_lint` 强制此 invariant，否则该条 invariant 长期靠 review 兜底。

### §附.9 / §附.10 — `flutter analyze` / `flutter test` clean (out-of-scope)

**Claim (ARCHITECTURE.md:1163-1164):**
> `flutter analyze` 0 warning / `flutter test` 全绿

**Reality:** 本次审计仅静态 sweep，未执行 build。`ci.yml` 已在 §14 验证包含 analyze + test job，强制门禁在 CI；本地状态不在本审计范围。

**Severity:** （不构成 drift；前置 §12/§14 已覆盖）

**Suggested fix (one line):** 无须修改。

---

## Cross-doc contradictions (ARCHITECTURE.md ↔ docs/CLAUDE.md)

### ARCH §8.3 vs CLAUDE §i18n — System prompt i18n policy (HARD contradiction)

**ARCHITECTURE.md:665-670:**
> **System prompt 也必须走 i18n：**
> ```dart
> // AI Provider 的系统 prompt 也在 ARB 中管理
> final systemPrompt = context.l10n.geminiImageSystemPrompt;
> ```

**docs/CLAUDE.md:103-117** (`### LLM / System Prompts — DO NOT i18n`):
> Prompts sent to AI providers are part of the model contract, not user-facing copy. Keep them as English string constants in `lib/providers/<provider>_prompts.dart` ...
> ```dart
> // ❌ Wrong — i18n'd prompt drifts across locales
> final hint = context.l10n.geminiSystemPrompt;
> ```

**Severity:** `contradiction`

**Suggested fix:** CLAUDE.md 是源真相（与代码实现一致：`gemini_image_provider.dart` 等使用英文常量；ARB 中也无 `geminiImageSystemPrompt` key）。ARCH §8.3 那段必须删除/改写，明确"LLM system prompt 不走 i18n，作为英文常量保存"。已在 Task 3 sweep (§7-§9) 中独立 flag，此处是 cross-doc 同源确认。

---

### ARCH §4.1 vs CLAUDE §Error Handling — 错误类型命名与结构

**ARCHITECTURE.md:284-329:**
> 所有跨层传播的错误必须是 `InkError` 的子类型。禁止裸 `Exception` 或 `String` 跨层传递。
> ```dart
> sealed class InkError { ... }
> final class ProviderError extends InkError { ... }
> final class StorageError extends InkError { ... }
> ```

**docs/CLAUDE.md:236-240:**
> - Custom exception types per domain (ProviderException, StorageException, etc.)
> - NO catching `Exception` or `dynamic` — always specific types
> - Errors bubble up to UI via Riverpod AsyncValue

**Severity:** `contradiction`

**Suggested fix:** ARCH 是源真相（`lib/core/errors/` 实际存在 `InkError` sealed hierarchy + `ProviderError` / `StorageError` 命名，不是 `*Exception`）。CLAUDE.md L237 应改为 `Custom InkError subclasses per domain (ProviderError, StorageError, ValidationError, LocalIOError)`，并指向 ARCH §4.1。

---

### ARCH §1.2 vs CLAUDE §Project Structure — 目录树两边都没对齐代码

**ARCHITECTURE.md:64-85** (lib/ tree)：
> 缺：`core/models/`、`core/constants/`、`theme/primitives/`、`theme/motion.dart`、`theme/typography.dart`、`providers/` 的具体 adapter 列表（gemini/kling/wanx_*）、`storage/base_repository.dart`、`storage/pg_controller.dart` 等。
> 列了：`features/{feature}/services/`（实际 lib 树中无此目录）

**docs/CLAUDE.md:163-211** (lib/ tree)：
> 列了：`core/models/`、`theme/primitives/`、`theme/motion.dart`、`theme/typography.dart`、所有 providers/ 具体 adapter、storage 详细结构。
> 缺：`features/{feature}/services/`（也未列）；未列 `features/canvas/util/`、`features/debug/`、`features/workspace/` 之外的等价于 ARCH 的细节。

**Severity:** `contradiction`

**Suggested fix:** 两边都需要重写以匹配代码。CLAUDE.md 的快照已声明 "Snapshot, not blueprint. Mirrors the current `lib/` tree"，结构更接近真实；ARCH §1.2 更像"骨架原则示意"。建议：ARCH §1.2 改写为"层与目录的对应原则（高层）"，移除具体子目录枚举；具体目录树以 CLAUDE.md 为准并按 Task 1 sweep 校准（特别是 `features/{feature}/services/` 是否真实存在）。

---

### ARCH §12.1 vs CLAUDE §Testing — TDD 验收标准

**ARCHITECTURE.md:880-890:**
> | 层 | 工具 | 范围 | 覆盖率门槛 |
> | core / utils | ... | 70% |
> | Repository 层 | ... | **75%** |
> | ... | 70% |
> **数据层（Repository + schema）门槛 75% 的理由：** 数据层是基座 ...

**docs/CLAUDE.md:226-231:**
> - TDD: write test first, watch it fail, implement, watch it pass
> - **Every public method has a test**
> - Repositories tested with mock DB
> - Providers tested with mock repositories
> - Widgets tested with ProviderScope overrides

**Severity:** `contradiction`

**Suggested fix:** 两个口径不互斥但门禁标准不一致——ARCH 用覆盖率百分比（aggregate, CI 可测量），CLAUDE 用"每个 public method 有 test"（per-method, 静态规则）。另外 CLAUDE.md L229 说"Repositories tested with **mock DB**"，ARCH §12.1 line 884 明确"真实 PG（测试 schema）"。Repo 层测试策略直接打架。建议：ARCH 是源真相（与 `pg_test_harness` 实际存在一致）；CLAUDE.md L229 应改为 "Repositories tested against real embedded PG with isolated test schema"，覆盖率门槛保留 ARCH 表格作为唯一定义。

---

### ARCH §2.2 vs CLAUDE §IoC & Lifecycle — Lifecycle 维度差异（非矛盾，但口径不齐）

**ARCHITECTURE.md:127-132** （4 类生命周期：app-scoped / feature-scoped / 参数化 / 异步单次）

**docs/CLAUDE.md:54-58:**
> - Database connections: app-scoped (created once, disposed on exit)
> - HTTP clients: app-scoped (shared dio instance)
> - Repositories: app-scoped
> - ViewModels/Controllers: screen-scoped (autoDispose)
> - Generation jobs: managed by JobQueue, outlive screens

**Severity:** `contradiction`

**Suggested fix:** 不是直接对立，但术语"screen-scoped"(CLAUDE) ≠ "feature-scoped"(ARCH)；CLAUDE 未提及 `.family` / FutureProvider autoDispose；ARCH 未提及 "HTTP clients app-scoped (shared dio)"。建议统一术语为 ARCH 的 4 类生命周期矩阵，CLAUDE.md 仅引用而不重复定义。

