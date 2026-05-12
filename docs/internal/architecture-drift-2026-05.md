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


---

## Cross-doc contradictions (ARCHITECTURE.md ↔ docs/CLAUDE.md)

<!-- Task 7 填充。 -->
