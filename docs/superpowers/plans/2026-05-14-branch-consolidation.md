---
status: draft
created: 2026-05-14
owner: kerro
scope: 仓库分支收口（Phase 0），不含路线图重排
---

# Branch Consolidation Plan — 2026-05-14

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收口当前仓库的分支扇出与未推送债务——同步本地 main、清理 12 条已远端删除的本地分支、把 `feat/ui-amber-noir-rebrand` 的 26 commits 拆成 3 个可 review 的 PR、归位 3 个未追踪文档——为后续 v2 路线图推进腾出干净的工作面。

**Architecture:** 顺序四阶段，**Phase A 必须先做完**（同步基线），后面才有意义。Phase B/C/D 互相独立但建议按文档→分支拆分→untracked 顺序执行以降低冲突面。每步都有可验证命令；任何破坏性操作（删本地分支、reset）前先打 backup tag。

**Tech Stack:** git CLI（PowerShell 上运行），GitHub gh CLI（创建 PR）。

---

## Snapshot (执行前的真实状态)

```
* feat/ui-amber-noir-rebrand   [origin/main: ahead 26, behind 2]   <-- 本次主要拆分对象
  main                         [origin/main: ahead 24, behind 53]  <-- 本地 main 已失效
  backup/local-main-pre-sync   724ee22                              <-- 历史 backup，评估后删除

  # 以下 12 条 = 远程已删除（"gone"），本地 ref 待清理：
  chore/arch-i18n-prompt-rule
  chore/architecture-drift-audit
  chore/i18n-fix-duration
  chore/logger-redact-proxy-password
  claude/ai-architecture-learning-vqAib
  docs/arch-error-system-rewrite
  docs/arch-i18n-secure-storage-rewrite
  docs/arch-section5-concurrency
  docs/readme-trim
  fix/provider-registry-ratelimiter-78
  fix/workspace-new-project-controller
  perf/jobqueue-cancel-79

  # 这一条仍 alive（未 gone），需单独决策：
  docs/arch-section4-error-system [origin/main: ahead 1, behind 2]
```

Untracked docs（工作区）：
- `docs/internal/architecture-drift-decisions-2026-05.md`
- `docs/internal/promo-drafts.md`
- `docs/superpowers/plans/2026-05-11-jobqueue-cancel-o1.md`

---

## Phase A — 同步基线 + 安全网（必须最先做）

### Task A1: 创建安全 tag（任何破坏前的护栏）

**Files:** 无（git refs only）

- [ ] **Step 1: 给当前 HEAD 打 tag**

```bash
git tag safety/pre-consolidation-2026-05-14 HEAD
```

- [ ] **Step 2: 给本地 main 打 tag（保留那 24 个 ahead commits 以备追溯）**

```bash
git tag safety/local-main-pre-reset-2026-05-14 main
```

- [ ] **Step 3: 验证 tag 存在**

Run: `git tag -l "safety/*"`
Expected: 列出两个 safety/* tag。

### Task A2: 刷新远程引用（已在调研阶段执行，幂等再跑一次）

- [ ] **Step 1: fetch + prune**

```bash
git fetch --all --prune
```

- [ ] **Step 2: 验证 origin/main 是最新**

Run: `git log -1 --format="%H %s" origin/main`
Expected: 输出 origin/main 最新 commit，且与 GitHub 网页一致。

### Task A3: 把本地 main reset 到 origin/main

> 本地 main 当前 ahead 24 / behind 53——这 24 个 ahead 全部是历史误操作（早期直接 commit 到 main 后再开 feature 分支留下的）。已被 safety/local-main-pre-reset tag 保留，可放心 reset。

- [ ] **Step 1: 切到 main**

```bash
git checkout main
```

- [ ] **Step 2: hard reset 到 origin/main**

```bash
git reset --hard origin/main
```

- [ ] **Step 3: 验证**

Run: `git status -sb`
Expected: `## main...origin/main`（没有 ahead/behind）。

- [ ] **Step 4: 切回工作分支**

```bash
git checkout feat/ui-amber-noir-rebrand
```

---

## Phase B — 清理已远端删除的本地分支（12 条）

### Task B1: 列出所有 "gone" 分支并人工确认

- [ ] **Step 1: 打印 gone 列表**

```bash
git branch -vv | findstr ": gone]"
```

Expected: 12 行，全部对应已合并/已废弃的远程分支。

- [ ] **Step 2: 人工确认每条都不再需要**

肉眼核对清单（与本 plan Snapshot 段一致）。如发现意外的本地未推 commit，跳过该条并在 Task B3 单独处理。

### Task B2: 批量删除 12 条 gone 本地分支

- [ ] **Step 1: 删除（PowerShell 一行）**

```powershell
git branch -vv | Select-String ": gone\]" | ForEach-Object { ($_ -split '\s+')[1] } | ForEach-Object { git branch -D $_ }
```

- [ ] **Step 2: 验证只剩活跃分支**

Run: `git branch -vv | findstr ": gone]"`
Expected: 空输出。

Run: `git branch`
Expected: 仅剩 `backup/local-main-pre-sync`、`docs/arch-section4-error-system`、`feat/ui-amber-noir-rebrand`、`main`。

### Task B3: 处置 backup/local-main-pre-sync

> 该 backup 创建于上次本地 main 重排前，现已被 Phase A 的 safety tag 覆盖语义。

- [ ] **Step 1: 对比与 safety tag 是否同 HEAD**

Run: `git rev-parse backup/local-main-pre-sync safety/local-main-pre-reset-2026-05-14`
Expected: 两个 SHA 一致（或确认 backup 的 HEAD 在 safety tag 的可达祖先中）。

- [ ] **Step 2: 一致则删除 backup 分支**

```bash
git branch -D backup/local-main-pre-sync
```

如果不一致：保留分支，在 plan 末尾的 "Open Decisions" 添加条目并停止删除。

### Task B4: 处置 docs/arch-section4-error-system

> 这是唯一还 alive 的旧分支（ahead 1, behind 2）。检查 commit 是否已通过其他途径合入。

- [ ] **Step 1: 查看该分支独有的 commit**

```bash
git log origin/main..docs/arch-section4-error-system --oneline
```

- [ ] **Step 2: 在 origin/main 中搜同名/同内容 commit**

```bash
git log origin/main --grep="align Error Handling section with InkError" --oneline
```

如有命中 → 直接 `git branch -D docs/arch-section4-error-system`。
如无命中 → 保留分支，在 Open Decisions 记录"需评估是否仍要 PR"。

- [ ] **Step 3: 提交 Phase B 完成状态到 plan 的 Decisions 段**

在本文件末尾的 "Open Decisions" 表格手动追加 B3/B4 的处置结果（commit by tag）。

---

## Phase C — 拆分 feat/ui-amber-noir-rebrand（26 commits → 3 个 PR）

### 拆分设计（基于 commit 实际颗粒度）

| PR | 名称 | 包含的 commit 范围 | 风险 |
|---|---|---|---|
| PR-1 | `docs/ui-amber-noir-spec` | a283956, e6583f1, ecc3650 | 零代码，纯 docs |
| PR-2 | `feat/theme-amber-noir-foundation` | 3234aea, 97c449d, a50a3ad, b1b1b5b, b0ceb5d, 1c0c95a, 639063f, 438666d, 0a62f78 | 主题底座 + primitives，不动业务页面 |
| PR-3 | `feat/ui-amber-noir-shell` | 96eb04c, 57888d3, fe2878f, b5c97f9, 2bc3ecb, 32547a7, b4f1b29, 2bbf9bc, e96e619, eb3afbe, a94d010, acaf4dc, 9f3e4ff, 63ed467 | window chrome + Lock + Studio + Canvas + cleanup |

> 拆分顺序遵循依赖：docs → 主题/primitives → 用 primitives 搭出的业务壳。PR-3 依赖 PR-2 的 primitives 存在，所以 PR-2 必须先合。

### Task C1: 准备 PR-1 (docs only)

**Files:** 无修改（cherry-pick 现有 commits）

- [ ] **Step 1: 从 origin/main 开新分支**

```bash
git checkout -b docs/ui-amber-noir-spec origin/main
```

- [ ] **Step 2: cherry-pick 3 个 docs commit（按时间顺序）**

```bash
git cherry-pick a283956 e6583f1 ecc3650
```

- [ ] **Step 3: 验证只动了 docs**

Run: `git diff --stat origin/main..HEAD`
Expected: 所有改动文件都在 `docs/` 下，且 lib/ tests/ 无任何改动。

- [ ] **Step 4: 推分支 + 开 PR**

```bash
git push -u origin docs/ui-amber-noir-spec
gh pr create --base main --title "docs: UI Amber Noir spec + mockups + plan" --body "Spec/mockup/plan from feat/ui-amber-noir-rebrand. Pure docs, zero code risk. Splits the 26-commit feature branch (1/3)."
```

- [ ] **Step 5: 等待 CI + merge**

CI 通过后 squash-merge 到 main。然后：

```bash
git checkout main && git pull --ff-only && git branch -D docs/ui-amber-noir-spec
```

### Task C2: 准备 PR-2 (主题底座 + primitives)

**Files:** 仅 `lib/theme/**` 与 `pubspec.yaml`（字体/window_manager 依赖）+ 对应 tests

- [ ] **Step 1: 从最新 main 开分支**

```bash
git checkout main && git pull --ff-only
git checkout -b feat/theme-amber-noir-foundation
```

- [ ] **Step 2: cherry-pick 主题底座 9 个 commit（按原顺序）**

```bash
git cherry-pick 3234aea 97c449d a50a3ad b1b1b5b b0ceb5d 1c0c95a 639063f 438666d 0a62f78
```

- [ ] **Step 3: 解决 cherry-pick 冲突（若有）**

每次冲突：检查冲突文件，保留新 token 体系（Amber Noir），解决后 `git add` + `git cherry-pick --continue`。

- [ ] **Step 4: 验证范围**

Run: `git diff --stat origin/main..HEAD`
Expected: 改动文件局限在 `lib/theme/`、`pubspec.yaml`、`pubspec.lock`、`test/theme/`、`assets/fonts/` 范围内。如有溢出（如 lib/features/）说明 cherry-pick 误拉，回退到 Step 2 用更细颗粒度。

- [ ] **Step 5: 跑测试**

```bash
flutter test test/theme/
```

Expected: 全绿。

- [ ] **Step 6: 推 + 开 PR**

```bash
git push -u origin feat/theme-amber-noir-foundation
gh pr create --base main --title "feat(theme): Amber Noir foundation — palette, fonts, primitives" --body "Theme base for Amber Noir UI rebrand. Adds palette/fonts/InkNoirCard/InkAmberButton/InkGhostButton primitives. No business UI changes. (2/3) of feat/ui-amber-noir-rebrand split."
```

- [ ] **Step 7: 合并并清理**

合后：

```bash
git checkout main && git pull --ff-only && git branch -D feat/theme-amber-noir-foundation
```

### Task C3: 准备 PR-3 (window chrome + Lock + Studio + Canvas)

**Files:** `lib/main.dart`, `lib/app.dart`, `lib/features/canvas/**`, `lib/features/workspace/**`, `lib/features/lock/**`（若存在）, `lib/theme/components/ink_window_chrome*`, 对应 tests, l10n ARB

- [ ] **Step 1: 从最新 main 开分支**

```bash
git checkout main && git pull --ff-only
git checkout -b feat/ui-amber-noir-shell
```

- [ ] **Step 2: cherry-pick 剩余 14 个 commit（按原顺序）**

```bash
git cherry-pick 96eb04c 57888d3 fe2878f b5c97f9 2bc3ecb 32547a7 b4f1b29 2bbf9bc e96e619 eb3afbe a94d010 acaf4dc 9f3e4ff 63ed467
```

- [ ] **Step 3: 解决冲突 + 跑全量测试**

```bash
flutter test
```

Expected: 全绿。如失败：单独修复、单独 commit（不要塞回 cherry-pick 的某条里）。

- [ ] **Step 4: 跑 i18n 检查**

Run: `flutter gen-l10n` 然后 `git diff lib/l10n/`
Expected: 无未提交的 diff（说明 ARB 与生成代码同步）。

- [ ] **Step 5: 推 + 开 PR**

```bash
git push -u origin feat/ui-amber-noir-shell
gh pr create --base main --title "feat(ui): Amber Noir shell — frameless chrome + Lock + Studio + Canvas rewrite" --body "Business UI layer of the Amber Noir rebrand, depends on PR-2 (foundation). Includes frameless window chrome, Lock gate, Studio Home, Canvas visual rewrite. (3/3) of feat/ui-amber-noir-rebrand split."
```

- [ ] **Step 6: 合并 + 删除原分支**

合后：

```bash
git checkout main && git pull --ff-only
git branch -D feat/ui-amber-noir-shell
git branch -D feat/ui-amber-noir-rebrand
git push origin --delete feat/ui-amber-noir-rebrand 2>$null
```

（最后一条若远程不存在该分支则会报错——可忽略。）

---

## Phase D — 归位 3 个 untracked docs

### Task D1: 评估并归位 `docs/internal/architecture-drift-decisions-2026-05.md`

- [ ] **Step 1: 看内容是否仍有效**

Read `docs/internal/architecture-drift-decisions-2026-05.md`。判断：
- 决策仍未落地 → 保留 + commit
- 决策已落地（搜代码验证）→ 删除
- 决策已被其他 doc 取代 → 删除

- [ ] **Step 2: 按判断执行**

```bash
# 保留：
git add docs/internal/architecture-drift-decisions-2026-05.md
git commit -m "docs(internal): record architecture drift decisions 2026-05"

# 或删除：
del docs\internal\architecture-drift-decisions-2026-05.md
```

### Task D2: 评估并归位 `docs/internal/promo-drafts.md`

- [ ] **Step 1: 内容仍有用？**

Read 该文件。promo drafts 类临时素材若已用过，删除即可。

- [ ] **Step 2: 执行**

保留则 commit 到 `docs/internal/`；否则删除。

### Task D3: 评估 `docs/superpowers/plans/2026-05-11-jobqueue-cancel-o1.md`

- [ ] **Step 1: 检查 plan 是否已执行**

```bash
git log --all --grep="jobqueue.*cancel" --oneline
```

如已有执行 commit → 在 plan 顶部加 `status: executed` 然后 commit。
如未执行且仍要做 → commit 为 `status: draft`。
如废弃 → 删除文件。

- [ ] **Step 2: 执行决策**

```bash
git add docs/superpowers/plans/2026-05-11-jobqueue-cancel-o1.md
git commit -m "docs(plans): track jobqueue cancel O(1) plan"
```

---

## Phase E — 远程仓库其他分支审计（只评估，不动手）

> origin 上还有 7 条非本人活跃分支：`chore/docs-layout`, `docs/git-linear-history`, `docs/provider-api-and-adr`, `docs/testing-and-build`, `feature/canvas-ui-skeleton`, `feature/gemini-image-provider`, `feature/provider-layer-skeleton`。本 plan 不直接处置（owner 可能不是你），只产出审计清单。

### Task E1: 产出远程分支审计表

- [ ] **Step 1: 对每条远程分支查 ahead/behind**

```bash
git fetch
for /f %b in ('git branch -r ^| findstr /v "HEAD" ^| findstr /v "origin/main$"') do @echo %b && git rev-list --left-right --count origin/main...%b
```

（PowerShell 等价：`git branch -r | Where-Object { $_ -notmatch 'HEAD|main$' } | ForEach-Object { $b=$_.Trim(); "$b -> $(git rev-list --left-right --count origin/main...$b)" }`）

- [ ] **Step 2: 把结果写入 `docs/internal/remote-branch-audit-2026-05-14.md`**

格式：

```markdown
| Branch | Ahead | Behind | Last commit | Decision |
|---|---|---|---|---|
| chore/docs-layout | ? | ? | ? | TBD |
...
```

- [ ] **Step 3: commit**

```bash
git add docs/internal/remote-branch-audit-2026-05-14.md
git commit -m "docs(internal): audit 7 stale remote branches"
```

后续处置（合/弃）不属于本 plan 范围，进入 Phase 1 路线图讨论。

---

## Open Decisions（执行过程中追加）

| Date | Item | Decision |
|---|---|---|
| 2026-05-14 | A3 reset 本地 main 到 origin/main | **跳过**。用户选择保留本地 main 不动；safety/local-main-pre-reset-2026-05-14 已锁定 724ee22；后续 feature 分支直接 rebase 到 origin/main，本地 main 失同步可接受。 |
| 2026-05-14 | backup/local-main-pre-sync 是否删除 | **已删除**。backup / main / safety tag 三者 SHA 完全一致（724ee22），safety tag 完全覆盖语义。 |
| 2026-05-14 | docs/arch-section4-error-system 是否还需 PR | **已开 PR #98**。Rebase origin/main 零冲突（新 SHA 4a5474e），3 行 docs 改动，等待 review/merge。 |
| 2026-05-14 | architecture-drift-decisions-2026-05.md 保留？ | （Task D1 填写） |
| 2026-05-14 | promo-drafts.md 保留？ | （Task D2 填写） |
| 2026-05-14 | jobqueue-cancel plan 是否已执行？ | （Task D3 填写） |

---

## Definition of Done

- [ ] 本地仅剩 `main`、最多 3 条进行中的 PR 分支（视拆分阶段）
- [ ] `git branch -vv` 输出无 `: gone]`
- [ ] `git status -sb` 在 main 上显示 `## main...origin/main`
- [ ] 工作区无 untracked 文件
- [ ] 3 个 PR 已合并或在 review 中（不必全合，但必须都已开）
- [ ] `docs/internal/remote-branch-audit-2026-05-14.md` 已产出

---

## Rollback

如任一阶段出错：

```bash
# 回到 plan 执行前的状态
git checkout safety/pre-consolidation-2026-05-14
git checkout -B feat/ui-amber-noir-rebrand
# 本地 main 回滚
git branch -f main safety/local-main-pre-reset-2026-05-14
```

Safety tags 在 DoD 全部通过后 30 天可删除（手动）。
