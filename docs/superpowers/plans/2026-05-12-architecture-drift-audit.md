# ARCHITECTURE.md vs CLAUDE.md Drift Audit Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 审计 `docs/ARCHITECTURE.md`（1164 行）与当前代码 + `docs/CLAUDE.md`（280 行）的偏移，产出 `docs/internal/architecture-drift-2026-05.md` 报告。**只审，不修**——drift 修复是后续独立 PR。

**Architecture:** 7 个 sweep task：6 个按 ARCHITECTURE.md 章节切（doc ↔ code 对账），1 个跨文档对账（ARCHITECTURE.md ↔ CLAUDE.md 矛盾扫描）。每个 sweep 同一套 4 步流程——读 → 列 claim → 用 Grep/Read/Glob 验证 → 追加 entry。最后 Task 8 收尾（附录 + Summary + Top-N + AC 闭环），Task 9 推 PR。每个 sweep 单独 commit，方便中断恢复。

**Tech Stack:** Markdown only。验证手段：`Grep` / `Glob` / `Read`。零代码改动。

**Issue:** 待开（按 `docs/internal/new-issue-drafts.md` 的 A1 段落落成正式 issue，见 Task 0）

---

## File Structure

- **New** `docs/internal/architecture-drift-2026-05.md` — drift 报告本体；按 ARCHITECTURE.md 章节顺序组织，外加独立的"Cross-doc contradictions"节
- **No** 修改 `docs/ARCHITECTURE.md` / `docs/CLAUDE.md`（修复在另一个 PR）
- **No** 修改源代码

---

## Drift Entry Format（所有 sweep task 复用）

```markdown
### §<section>.<sub> — <one-line summary>

**Claim (ARCHITECTURE.md:<line>):**
> <verbatim quote, ≤2 lines>

**Reality:**
<what currently exists; cite file:line or "not present">

**Severity:** `contradiction | stale | missing | misleading`

**Suggested fix (one line):** <delete | rewrite | move to ROADMAP | clarify>
```

Severity 定义：
- `contradiction` — 文档说 X，代码做 Y，互斥
- `stale` — 曾经对，现在文件已重命名/删除
- `missing` — 文档没提，代码有重要的 invariant
- `misleading` — 字面没错，但读者按字面理解会写错代码

跨文档 entry 用同一格式，`Claim` 引 ARCHITECTURE.md，`Reality` 引 `docs/CLAUDE.md:<line>` 的对应矛盾段，severity 固定 `contradiction`。

**Clean section 约定：** 若整章逐条 claim 均命中，**不写多条 entry**，只在该章节占位写一行 `§N: clean — <一句话总结，例如"所有引用文件存在，命名一致">`。这是 A1 hint 明确许可的偷懒，不要 performative thorough。

---

## Task 0: 落 issue + 起分支 + 报告骨架

**Files:**
- Create: `docs/internal/architecture-drift-2026-05.md`

- [ ] **Step 1: 把 A1 草稿落成正式 issue**

A1 段在 `docs/internal/new-issue-drafts.md` line 8-50（标题 line 8，`---` 分隔符 line 51）。用 sed 抽取（前后边界由分隔符切，行号无关）：

```bash
gh issue create \
  --title "tech-debt: ARCHITECTURE.md vs CLAUDE.md drift audit" \
  --label chore --label documentation \
  --body "$(sed -n '/^## A1 /,/^---$/p' docs/internal/new-issue-drafts.md | sed '1d;$d')"
```

Expected: 输出新 issue URL `https://github.com/<owner>/InkFrame/issues/<N>`，记下 `<N>`，下文 PR body 用。

> 标题必须和草稿 line 8 一字不差对齐（包含 "vs CLAUDE.md"，不是 "vs codebase"）——A1 acceptance #4 明确要求跨文档对账，标题是 scope 抓手。

- [ ] **Step 2: 起分支**

```bash
git fetch origin main
git checkout -b chore/architecture-drift-audit origin/main
```

Expected: `Switched to a new branch 'chore/architecture-drift-audit'`，且 tracking origin/main。

- [ ] **Step 3: 拿当前 commit hash**

```bash
git rev-parse --short HEAD
```

记下输出（形如 `364e6a0`），下一步骨架里替换 `<SHA>`。

- [ ] **Step 4: 写报告骨架**

把以下内容写入 `docs/internal/architecture-drift-2026-05.md`，把 `<SHA>` 替换成 Step 3 实测值：

```markdown
# ARCHITECTURE.md Drift Audit — 2026-05

**Audited:** `docs/ARCHITECTURE.md` (1164 lines) + `docs/CLAUDE.md` (280 lines) @ commit <SHA>
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

---

## Cross-doc contradictions (ARCHITECTURE.md ↔ docs/CLAUDE.md)

<!-- Task 7 填充。 -->
```

- [ ] **Step 5: Commit 骨架**

```bash
git add docs/superpowers/plans/2026-05-12-architecture-drift-audit.md \
        docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): scaffold ARCHITECTURE.md drift report (#<N>)"
```

把 `<N>` 替换成 Step 1 拿到的 issue 编号。

---

## Task 1: Sweep §1–§3（分层 / DI / SOLID）

**Files:**
- Read: `docs/ARCHITECTURE.md` line 28–281（§1=28-96, §2=97-184, §3=185-281）
- Verify against: `lib/` 树结构、`lib/core/di/`、`lib/core/interfaces/`、`lib/providers/`、`lib/storage/`
- Append to: `docs/internal/architecture-drift-2026-05.md` Findings

- [ ] **Step 1: 读 §1 分层架构与依赖方向（line 28-96）**

用 Read tool 一次性读完 line 28-96。把每条具体 claim 列出来，重点：
- "五层模型"命名（Widget / ViewModel / Service / Repository / Infrastructure）—— `lib/` 是否真这样组织
- "依赖只能向下流动" —— grep 反向 import：
  ```bash
  grep -rn "import.*features/" lib/services/ lib/storage/ lib/core/ --include="*.dart"
  ```
  期望：空输出。任何命中 → `contradiction` entry。
- 引用的具体文件路径全部用 `Glob` 验证存在

- [ ] **Step 2: 验证 §1 每条 claim，不命中写 entry**

每条 claim 一次 grep。例：
```bash
grep -rn "databaseProvider" lib/ --include="*.dart" | grep -v "lib/core/di/"
# 期望：只有消费方 import，没有第二处定义
```

命中即 clean，不命中 → 按 Drift Entry Format 写到 Findings 的 `## §1` 子节。若全章 clean，写一行 `§1: clean — ...`。

- [ ] **Step 3: 读 §2 Riverpod DI 模式与生命周期矩阵（line 97-184）**

重点验证：
- "DI 矩阵"表格里的每个 provider 是否真在 `lib/core/di/` 下存在
- 生命周期标注（autoDispose / keepAlive）是否和代码一致
  ```bash
  grep -rn "Provider\|@riverpod\|autoDispose\|keepAlive" lib/core/di/
  ```
- "禁止模式"列的反例（静态单例、ServiceLocator）是否真不存在：
  ```bash
  grep -rn "static.*= \|ServiceLocator" lib/ --include="*.dart"
  ```

- [ ] **Step 4: 读 §3 SOLID 五条落地举例（line 185-281）**

每条 SOLID 都引用了具体类名（如 `Submittable / Pollable / Cancellable`、`ProjectRepository`）。逐个 grep：
```bash
grep -rn "class Submittable\|abstract class Submittable" lib/ --include="*.dart"
```

被引用但不存在的类 → `stale`；存在但用法不一致 → `misleading`。

- [ ] **Step 5: 把 §1–§3 entries 追加到 Findings**

格式严格走 Drift Entry Format。Clean 章节就写一行。

- [ ] **Step 6: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): §1-§3 sweep — layering / DI / SOLID drift"
```

---

## Task 2: Sweep §4–§6（错误 / 并发 / 路径）

**Files:**
- Read: `docs/ARCHITECTURE.md` line 282–532（§4=282-391, §5=392-462, §6=463-532）
- Verify against: `lib/core/errors/`、`lib/services/job_queue_service.dart`、`lib/providers/rate_limiter.dart`、`lib/providers/dio_error_mapper.dart`、`lib/services/file_resolver_service.dart`、`lib/storage/schema/`

- [ ] **Step 1: 读 §4 错误体系（line 282-391）**

验证：
- "N 种 InkErrorCode" 的数字（文档原文是几就数几）：
  ```bash
  grep -cE "^\s+[a-zA-Z]+\s*[,(]" lib/core/errors/ink_error_code.dart
  ```
  不等 → `contradiction`。
- 抽查 3 条错误码"映射来源 Provider/HTTP status"，看 `lib/providers/dio_error_mapper.dart` 实际映射是否一致。

- [ ] **Step 2: 读 §5 并发与限流（line 392-462）**

验证：
- "全局并发档位"档数 —— grep `globalConcurrency` / `PerformanceTier`
- "JobQueue 状态机"状态枚举 —— `lib/services/job_queue_service.dart` 顶部的 enum
- "Token Bucket per-provider" QPS/Burst 字段名 —— `lib/providers/rate_limiter.dart`
- **特别关注 §5.1 cancel 复杂度**：刚 merge 的 #79 把 cancel 从 O(n) 改成 O(1)（commit `9998880` 引入 `_pendingIndex` map + soft-delete）。文档若仍描述 O(n) 重建队列 → `stale`。验证：
  ```bash
  grep -n "pendingIndex\|cancel" lib/services/job_queue_service.dart
  ```

- [ ] **Step 3: 读 §6 文件路径解析契约（line 463-532）**

验证：
- "数据库只存相对路径"：
  ```bash
  grep -nE "image_path|video_path|thumbnail_path|file_path" lib/storage/schema/*.sql
  ```
  看注释/约束是否强制相对路径
- `FileResolverService` 方法签名 —— `lib/services/file_resolver_service.dart` 实际公开了哪些方法，文档列的 `resolve()` / `relativize()` 是否都存在

- [ ] **Step 4: 追加 §4–§6 entries 到 Findings**

- [ ] **Step 5: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): §4-§6 sweep — errors / concurrency / paths drift"
```

---

## Task 3: Sweep §7–§9（设计 Token / i18n / 密钥）

**Files:**
- Read: `docs/ARCHITECTURE.md` line 533–741（§7=533-627, §8=628-694, §9=695-741）
- Verify against: `lib/theme/`、`lib/l10n/`、`lib/providers/`（system prompt 常量）、`lib/services/platform_secure_storage_service.dart`、`lib/core/constants/`

- [ ] **Step 1: 读 §7 设计 Token 系统与主题切换（line 533-627）**

验证：
- token 目录结构 —— 文档列的 vs 实际：
  ```bash
  find lib/theme -type f -name "*.dart" | sort
  ```
- `InkColors / InkSpacing / InkRadius / InkShadow` 类是否都存在：
  ```bash
  grep -rn "class InkColors\|class InkSpacing\|class InkRadius\|class InkShadow" lib/theme/
  ```
- 主题数（dark / light / highContrast）—— grep `AppTheme` / `ThemeMode`

- [ ] **Step 2: 读 §8 i18n 架构与 ARB 一致性门禁（line 628-694）**

验证：
- "100% 双语 coverage" —— 跑一致性脚本：
  ```bash
  python -c "import json; en=set(json.load(open('lib/l10n/app_en.arb')).keys()); zh=set(json.load(open('lib/l10n/app_zh.arb')).keys()); print('only_en:', en-zh); print('only_zh:', zh-en)"
  ```
  任一非空（除掉以 `@@` 开头的 metadata key）→ `contradiction`。
- CI 门禁脚本：文档若提到 `scripts/hooks/check-i18n-coverage.sh` 之类，用 `Glob` 验证存在。
- "system prompts 是英文常量"：
  ```bash
  grep -rn "_kSystemPrompt\|_kPromptTemplate\|systemPrompt" lib/providers/ --include="*.dart"
  ```
  抽查 1-2 条 prompt 内容，看是否真是英文常量、是否真没走 `context.l10n`。

- [ ] **Step 3: 读 §9 密钥存储（line 695-741）**

验证：
- 后端表（macOS Keychain / Windows Credential Manager / debug 文件）—— 看 `lib/services/platform_secure_storage_service.dart` 是否真有三套
- secure storage key 名 —— 对照 `lib/core/constants/secure_storage_keys.dart`（或文档指向的实际位置）：
  ```bash
  find lib/core/constants -name "*.dart" | xargs grep -l "SecureStorageKey\|secureStorageKey"
  ```

- [ ] **Step 4: 追加 §7–§9 entries 到 Findings**

- [ ] **Step 5: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): §7-§9 sweep — theme / i18n / secrets drift"
```

---

## Task 4: Sweep §10–§11（性能降级 / A11y）

**Files:**
- Read: `docs/ARCHITECTURE.md` line 742–875（§10=742-804, §11=805-875）
- Verify against: `lib/services/`（degradation controller）、`lib/features/`（shortcut 注册处）、`scripts/hooks/`

- [ ] **Step 1: 读 §10 性能降级控制器（line 742-804）**

验证：
- "4 档位 + 双阈值 hysteresis" —— 看实现：
  ```bash
  grep -rn "DegradationTier\|PerformanceTier\|tierUp\|tierDown" lib/ --include="*.dart"
  ```
- 输入信号（内存 / FPS / 磁盘）—— 看实际采样源
- 文档若描述了一个不存在的 Service 文件名 → `stale`

- [ ] **Step 2: 读 §11 A11y 分层责任与键盘覆盖率门禁（line 805-875）**

验证：
- "键盘覆盖率门禁" —— 找文档说的脚本是否存在：
  ```bash
  ls scripts/hooks/ 2>&1
  ```
- 文档列的快捷键表 —— grep 代码里实际注册的 `LogicalKeySet` / `SingleActivator`：
  ```bash
  grep -rn "LogicalKeySet\|SingleActivator" lib/ --include="*.dart"
  ```
- VoiceOver / Narrator claim —— grep `Semantics(` 在 widget 里的覆盖度

- [ ] **Step 3: 追加 §10–§11 entries 到 Findings**

- [ ] **Step 4: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): §10-§11 sweep — degradation / a11y drift"
```

---

## Task 5: Sweep §12–§14（测试 / 日志 / 构建）

**Files:**
- Read: `docs/ARCHITECTURE.md` line 876–1150（§12=876-949, §13=950-1027, §14=1028-1150）
- Verify against: `test/`、`lib/core/logging/`、`scripts/`、`.github/workflows/`、`pubspec.yaml`、`dart_test.yaml`

- [ ] **Step 1: 读 §12 测试策略与分层（line 876-949）**

验证：
- 测试分层（unit / widget / integration / golden）—— 对照 `test/` 实际目录：
  ```bash
  find test -type d | sort
  ```
- "覆盖率门槛 70% / repo 75%" —— 看 `.github/workflows/ci.yml` 和任何 `lcov` 配置
- `dart_test.yaml` 配置文档（line 918）—— 看真有这个文件：
  ```bash
  cat dart_test.yaml 2>&1 | head -30
  ```
- "test tag 约定" —— grep `@Tags(` 在 `test/` 下用法

- [ ] **Step 2: 读 §13 日志规范（line 950-1027）**

验证：
- `InkLogger` 接口 —— `lib/core/logging/`：
  ```bash
  find lib/core/logging -type f -name "*.dart"
  ```
- 日志文件路径 / 滚动策略 —— grep 实际实现
- 脱敏规则（API key 前 4 字符 / prompt 截断 50 字 / 路径 ~）—— grep sanitizer 实现，看规则常数是否和文档一致：
  ```bash
  grep -rn "sanitize\|redact\|mask" lib/core/logging/ lib/providers/ --include="*.dart"
  ```

- [ ] **Step 3: 读 §14 构建与发布流水线（line 1028-1150）**

验证：
- 文档列的脚本（`scripts/release-tag.sh`、`scripts/fetch-pg-binaries.sh` 等）：
  ```bash
  ls scripts/
  ```
- CI workflow 名 —— `ls .github/workflows/`
- "签名/公证流程" 是否真在 CI 里

- [ ] **Step 4: 追加 §12–§14 entries 到 Findings**

- [ ] **Step 5: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): §12-§14 sweep — testing / logging / CI drift"
```

---

## Task 6: Sweep 附录快速检查清单

**Files:**
- Read: `docs/ARCHITECTURE.md` line 1151-1164
- Append to: Findings 的 `## 附录` 节

- [ ] **Step 1: 读附录（line 1151-1164），逐条 invariant 验证**

附录通常列 5-10 条 invariant。逐个 grep。示例：
- "每个 Provider 实现都注册到 ProviderRegistry"：
  ```bash
  grep -rn "class.*Provider " lib/providers/ --include="*.dart" | grep -v "_base\|prompts\|registry\|mapper\|rate_limiter"
  # 拿到 Provider 实现类列表
  grep -n "register\|providerId" lib/providers/provider_registry.dart
  # 比对是否每个实现都在 registry 里
  ```
- "每个 freezed model 都有 .freezed.dart"：
  ```bash
  comm -23 \
    <(grep -rln "@freezed\|@Freezed" lib/ --include="*.dart" | sort) \
    <(find lib -name "*.freezed.dart" | sed 's/\.freezed\.dart$/.dart/' | sort)
  ```
  非空 → `contradiction`。

- [ ] **Step 2: 把附录 entries 追加到 Findings 的 `## 附录` 节**

clean 就一行 `附录: clean — all invariants hold`。

- [ ] **Step 3: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): appendix sweep — invariants drift"
```

---

## Task 7: Cross-doc 对账（ARCHITECTURE.md ↔ docs/CLAUDE.md）

**Files:**
- Read: `docs/ARCHITECTURE.md`（全篇，可借前面 sweep 的笔记）
- Read: `docs/CLAUDE.md`（280 行，全篇）
- Append to: `docs/internal/architecture-drift-2026-05.md` 的 `## Cross-doc contradictions` 节

> A1 acceptance #4 强制项：必须 flag 两个 doc 之间的矛盾。这一步是单独的对账闭环，不能并到章节 sweep 里——章节 sweep 是 doc ↔ code，这里是 doc ↔ doc。

- [ ] **Step 1: 全读 `docs/CLAUDE.md`（280 行）**

把 CLAUDE.md 的"规则型陈述"提炼成一张清单。CLAUDE.md 的典型规则话题：
- 技术栈枚举（Flutter / Riverpod / 嵌入式 PG / dio / media_kit / flutter_secure_storage）
- SOLID 五条
- DI / IoC / Lifecycle（autoDispose vs keepAlive 矩阵）
- Zero backward compatibility
- i18n（ARB 双语门禁、LLM prompt 必须英文、ARB key 命名约定）
- Design Token（无硬编码颜色/字号/间距/圆角/阴影）
- 项目目录树（lib/ 结构）
- Models（freezed 强制）
- 错误处理（自定义 exception type，禁 catch Exception/dynamic）
- 测试（TDD、每个 public method 有 test）
- Git（commit 必过测试 + 100% i18n、无 --no-verify）
- API Key 存储（platform-secure、不入代码/配置/DB）

每条规则用 Grep 在 `docs/ARCHITECTURE.md` 找对应章节，比对话术 / 数字 / 文件路径是否一致。

- [ ] **Step 2: 跑批量交叉 grep，定位易冲突段**

```bash
# 例：i18n 规则两边话术对账
grep -nE "i18n|ARB|app_en|app_zh|locale" docs/ARCHITECTURE.md docs/CLAUDE.md

# 例：DI / 单例话术
grep -nE "singleton|ServiceLocator|autoDispose|keepAlive|Provider" docs/ARCHITECTURE.md docs/CLAUDE.md

# 例：目录结构话术
grep -nE "^lib/|^├──|^└──" docs/ARCHITECTURE.md docs/CLAUDE.md

# 例：测试策略
grep -nE "TDD|coverage|integration|widget test|golden" docs/ARCHITECTURE.md docs/CLAUDE.md

# 例：错误处理
grep -nE "InkError|exception|catch" docs/ARCHITECTURE.md docs/CLAUDE.md
```

任何两边数字 / 文件名 / 类名不一致 → entry（`contradiction`）。两边都对但口径不同（例如 ARCH 说 "5 层"，CLAUDE 说 "4 层"）→ entry。

- [ ] **Step 3: 把矛盾点写到 `## Cross-doc contradictions` 节**

每条 entry 同时引两边的 line：

```markdown
### ARCH §N.M vs CLAUDE §X — <one-line summary>

**ARCHITECTURE.md:<line>:**
> <quote>

**docs/CLAUDE.md:<line>:**
> <quote>

**Severity:** `contradiction`

**Suggested fix:** <which doc is the source of truth, or "both need rewrite to match code">
```

若整张表完全自洽：写 `Cross-doc: clean — no contradictions between ARCHITECTURE.md and docs/CLAUDE.md detected.`

- [ ] **Step 4: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): cross-doc sweep — ARCHITECTURE.md vs CLAUDE.md contradictions"
```

---

## Task 8: 收尾汇总（Summary 表格 + Top-N + AC 闭环）

**Files:**
- Modify: `docs/internal/architecture-drift-2026-05.md` 顶部 Summary 表格 + 末尾追加 Top-N + AC checklist

- [ ] **Step 1: 数 entries，填 Summary 表格**

```bash
# 抓所有 entry 标题 + severity 行
awk '/^## Findings/,/^## Cross-doc/' docs/internal/architecture-drift-2026-05.md \
  | grep -E "^### §|^\*\*Severity:\*\*"

# Cross-doc 节单独数
awk '/^## Cross-doc/,0' docs/internal/architecture-drift-2026-05.md \
  | grep -E "^### |^\*\*Severity:\*\*"
```

把每个章节的 `Entries / contradiction / stale / missing / misleading` 4 列 + Total 行填上具体数字。

- [ ] **Step 2: 检查 Total ≥ 5（A1 acceptance #3 floor）**

若 Total < 5：在表格下追加一段：

```markdown
> **Note:** Total drift count is <N> (< 5). ARCHITECTURE.md is in better shape than the issue draft anticipated. Sections written as "clean" were verified end-to-end; remaining low entry count reflects actual state, not audit fatigue.
```

若 Total ≥ 5：跳过这一段。

- [ ] **Step 3: 在 Findings + Cross-doc 之后追加 Top-N 优先级**

```markdown
---

## Top-N Priority Drift（建议优先修）

按 `severity = contradiction` 优先 → `misleading` → `stale` → `missing`，每类最多 3 条最关键。

### Critical (contradiction × up to 3)
1. <link to anchor> — <one-line why this misleads new contributors>
2. ...
3. ...

### High (misleading × up to 3)
...

### Medium (stale × up to 3)
...

### Low (missing × up to 3)
...
```

只列 entry 标题 + 一句话 why；不展开内容。每类 entry 不足 3 条就写实际数量。

- [ ] **Step 4: 在文件末尾追加 A1 Acceptance Criteria 闭环 checklist**

```markdown
---

## A1 Acceptance Criteria 闭环

对应 `docs/internal/new-issue-drafts.md` line 39-44：

- [x] Drift report covers all 1164 lines — Task 1-6 commits 按 §1-§3 / §4-§6 / §7-§9 / §10-§11 / §12-§14 / 附录顺序逐段覆盖，git log 可追溯
- [x] Each finding cites: section reference + current claim + actual repo state + file:line evidence — Drift Entry Format 4 字段强制
- [x] At least 5 concrete drift items found (or explicit "better shape than expected" note) — Step 2 兜底
- [x] Report flags any contradictions between ARCHITECTURE.md and CLAUDE.md — Task 7 专项
- [ ] CI is green — Task 9 Step 3 验证后勾掉
```

- [ ] **Step 5: Commit**

```bash
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): summary table + top-N + AC closure"
```

---

## Task 9: 推 PR

**Files:** none

- [ ] **Step 1: Push**

```bash
git push -u origin chore/architecture-drift-audit
```

- [ ] **Step 2: 开 PR**

```bash
gh pr create --base main --head chore/architecture-drift-audit \
  --title "docs(audit): ARCHITECTURE.md vs CLAUDE.md drift report (closes #<N>)" \
  --body "$(cat <<'EOF'
Closes #<N>

## What

Audit of `docs/ARCHITECTURE.md` (1164 lines, §1–§14 + appendix) against:
1. Current `lib/` / `test/` / `scripts/` state (doc ↔ code)
2. `docs/CLAUDE.md` (280 lines) for cross-doc contradictions (doc ↔ doc)

**Read-only** — no docs or code changed.

## Output

`docs/internal/architecture-drift-2026-05.md` — drift report with:

- One entry per drifted claim (verbatim quote + reality + severity + suggested fix)
- Dedicated `Cross-doc contradictions` section for ARCH ↔ CLAUDE conflicts
- Per-section count table (contradictions / stale / missing / misleading)
- Top-N priority list for follow-up cleanup
- A1 acceptance criteria checklist closed at file tail

## Why this is one PR (not many)

The audit needs to span the full doc to be coherent. **Fixes are explicitly out of scope** — each follow-up will be a small targeted PR by section, allowing review focus.

## How to read

1. Open the report, jump to **Top-N Priority Drift**
2. For anything you disagree with, comment on the entry anchor
3. After merge, follow-up PRs reference entry IDs

## Test plan

- [x] Every §<n> in ARCHITECTURE.md visited (git log: §1-§3, §4-§6, §7-§9, §10-§11, §12-§14, appendix, cross-doc each one commit)
- [x] Summary table totals match Findings + Cross-doc entry counts
- [x] No source files modified (`git diff main..HEAD -- lib/ test/ scripts/` empty)
- [x] A1 acceptance criteria all checked at report file tail
EOF
)"
```

把 `<N>` 替换成 Task 0 拿到的 issue 编号。

- [ ] **Step 3: 等 CI**

```bash
gh pr checks <PR#>
```

预期：CI 全绿。CI 通过后，回到报告文件勾掉最后一条 AC：

```bash
sed -i 's/- \[ \] CI is green/- [x] CI is green/' docs/internal/architecture-drift-2026-05.md
git add docs/internal/architecture-drift-2026-05.md
git commit -m "docs(audit): close CI-green AC after PR CI passes"
git push
```

---

## Self-Review

**Spec coverage（对照 A1 issue 草稿 acceptance criteria）：**
- ✅ "Drift report covers all 1164 lines" — Task 1-6 六个 sweep 覆盖 §1-§14 + 附录，git log 可追溯
- ✅ "Each finding cites: section reference + current claim + actual repo state + file:line evidence" — Drift Entry Format 4 字段强制
- ✅ "At least 5 concrete drift items found (else explicit note)" — Task 8 Step 2 兜底逻辑
- ✅ "Report flags any contradictions between ARCHITECTURE.md and CLAUDE.md" — Task 7 专项 sweep + 独立报告段
- ✅ "CI is green" — Task 9 Step 3 闭环

**Placeholder scan：**
- `<N>` issue 编号、`<SHA>` commit hash、`<PR#>` 三个 placeholder 是运行时实测填入的真数据，不是 plan 自身 TODO
- 无 "TBD / implement later / handle edge cases" 类空话

**Type / 命名 / 路径一致性：**
- 报告路径 `docs/internal/architecture-drift-2026-05.md` 全 plan 一致
- 分支名 `chore/architecture-drift-audit` 全 plan 一致
- Issue 标题 `tech-debt: ARCHITECTURE.md vs CLAUDE.md drift audit` 与 A1 草稿 line 8 一字不差
- Drift Entry Format 4 字段（Claim / Reality / Severity / Suggested fix）在所有 sweep 复用，未漂移
- Severity 枚举（`contradiction | stale | missing | misleading`）从 Format 段贯穿到 Summary 表格到 Top-N 分桶

**与旧版 plan 的关键差异（修掉的偏移）：**
1. Issue 标题 `vs codebase` → `vs CLAUDE.md`，对齐 A1 line 8
2. 新增 Task 7 跨文档对账，对齐 A1 acceptance #4
3. Task 8 Step 2 加 ≥5 entries 兜底，对齐 A1 acceptance #3
4. Task 8 Step 4 加 AC 闭环 checklist，把 5 条 acceptance 显式打勾在产物里
5. Task 0 Step 1 sed 用 `^## A1 ` 锚定（行号无关），不再标错的"line 1-56"
6. Task 9 Step 3 加 CI-green AC 回填，闭环最后一条 acceptance

**风险 / 已知 trade-off：**
- Plan 估时 = 7 个 sweep × 30-60min + 收尾 30min ≈ 4-7h，比 A1 草稿的 "2-3h" 高。底层逻辑：草稿按"扫一眼"估，逐 claim grep + 跨文档对账实际需要这个量。中途超时可中断，每 sweep 独立 commit。
- Sweep 颗粒度按章节切，不按"每条 claim 一个 task"——后者会爆 100+ tasks，反向破坏可执行性。
- Clean section 允许一行带过（A1 hint 明确许可），避免 performative thorough。
- 未用 worktree——audit 只读，且当前 perf 分支已收尾，Task 0 从 origin/main 切干净分支即可。
