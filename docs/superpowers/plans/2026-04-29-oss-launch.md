# InkFrame Open-Source Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 InkFrame 从 PRIVATE 单维护者仓库变成 PUBLIC 可贡献的开源项目，三个 PR 串行落地。

**Architecture:** 三段式串行 PR——(1) Pre-launch hygiene 把脏东西扫干净；(2) Contributor on-ramp 让 fork PR 跑得通、外部贡献者找得到入口；(3) Public launch 翻 visibility + 公告。每个 PR 独立可 review、可回滚。

**Tech Stack:** GitHub（issues / actions / discussions / branch protection）、gitleaks（git history secret 扫描）、Flutter 3.41.6（已存 CI）、shell 脚本（沿用 `scripts/hooks/*.sh`）。

---

## 现状盘点（写 plan 时已核对）

- Repo: `KerroKapple/InkFrame`，当前 PRIVATE
- 当前分支: `chore/oss-onboarding`（已铺基础工作）
- License: MIT（根目录 `LICENSE`，已就绪）
- README EN + zh-CN：449 行 / 448 行，分量足
- CONTRIBUTING.md：已从 `docs/` 移到根（staged 待 commit），218 行，含分支模型 / 命名规范 / Conventional Commits
- `.github/`：已新增 ISSUE_TEMPLATE/（bug_report.yml + feature_request.yml + config.yml）+ PULL_REQUEST_TEMPLATE.md + CODEOWNERS（untracked）
- CI（`.github/workflows/ci.yml`）：已存在且完整——`flutter analyze` + 6 个 hook 脚本（i18n coverage / inline styles / magic strings / direct instantiation / disposable cleanup / updated_at）+ `flutter test` 70% coverage 门槛 + Postgres service container + golden test placeholder
- Tech-debt：`docs/internal/tech-debt.md` 当前只 2 条 TD，**均已修复**——不是 ROADMAP 来源
- Provider 实现：`lib/providers/` 8 个 provider 文件（gemini / kling v3 / kling v3 omni / wanx i2v + image + r2v + t2v + dashscope_async base）

## 已发现的开放问题（plan 执行时需用户决策）

1. **`macos/Podfile` 是新文件，之前从未 commit 过** — 是新增 CocoaPods 集成？还是误产物？决策：commit 进 macOS 构建链 / 加进 .gitignore 退回无 CocoaPods。
2. **`macos/Flutter/Flutter-{Debug,Release}.xcconfig` 多了 `#include? "Pods/Target Support Files/..."` 一行** — pod install 自动加的 hook，与决策 1 同进退：要 CocoaPods 就 commit，不要就 restore。
3. **gitleaks 扫描如果命中历史 secret** — rotation 还是 history rewrite？history rewrite 会让所有 fork/clone 失效，是不可逆操作，需用户拍板。

---

## File Structure（PR 1/2/3 总览）

**新建：**
- `SECURITY.md`（根目录）— 漏洞上报政策
- `CODE_OF_CONDUCT.md`（根目录）— Contributor Covenant 2.1
- `ROADMAP.md`（根目录）— 公开路线图（Phase 2）
- `.github/workflows/secret-scan.yml`（Phase 2）— PR/push 触发 gitleaks 兜底
- `docs/superpowers/plans/2026-04-29-oss-launch.md`（本文件）

**修改：**
- `README.md` — 顶部 hero 截图区 + Badges 行（Phase 3）
- `README.zh-CN.md` — 同上中文版
- `.gitignore` 或 `macos/.gitignore` — 视决策 1/2 处理 Podfile

**已 staged / untracked，需收敛进 PR 1：**
- `CONTRIBUTING.md`（rename，已 staged）
- `.github/CODEOWNERS`、`.github/ISSUE_TEMPLATE/*`、`.github/PULL_REQUEST_TEMPLATE.md`（untracked）
- `README.md`、`README.zh-CN.md`（已修改，含 CONTRIBUTING 路径修正）
- `docs/internal/tech-debt.md`（已修改，私有文档变更，进 PR 1 一起带走）

**显式排除 PR 1：**
- `macos/Flutter/Flutter-*.xcconfig`（决策 2 之前不动）
- `macos/Podfile`（决策 1 之前不动）

---

# Phase 1 / PR 1: Pre-launch Hygiene

**目标:** 让 working tree 干净 + git history 无 secret + 补齐法定 OSS 政策文件。合并后 repo **内容**已经可公开（但仍 PRIVATE）。

**分支:** 继续 `chore/oss-onboarding`（已存在）。

---

### Task 1.1: 隔离 macOS 本地构建噪音

**Files:**
- Restore: `macos/Flutter/Flutter-Debug.xcconfig`
- Restore: `macos/Flutter/Flutter-Release.xcconfig`
- Stash 决策前不删: `macos/Podfile`、`macos/Podfile.lock`（如有）

**说明:** PR 1 显式不解决 CocoaPods 集成决策，先把噪音从 launch commit 里挤出去。决策 1/2 单独开 issue，由用户后续 PR 处理。

- [ ] **Step 1: 列出当前 macOS 改动**

```bash
git status -- macos/ && git diff --stat macos/
```

Expected: 看到 `Flutter-Debug.xcconfig`、`Flutter-Release.xcconfig` 修改，`Podfile` untracked。

- [ ] **Step 2: Restore xcconfig 改动**

```bash
git restore macos/Flutter/Flutter-Debug.xcconfig macos/Flutter/Flutter-Release.xcconfig
```

Expected: `git status` 不再列出这两个文件。

- [ ] **Step 3: Podfile 决策前临时挪走**

```bash
mv macos/Podfile /tmp/inkframe-podfile-stash-$(date +%s).rb
ls macos/Podfile 2>&1 | grep "No such" && echo "stashed OK"
```

Expected: 输出 `stashed OK`。完整路径记录到 plan 的"未决策残留"区。

- [ ] **Step 4: 验证 working tree 只剩 OSS 改动**

```bash
git status
```

Expected: 仅显示 `CONTRIBUTING.md`（rename）、`README.md`/`README.zh-CN.md`（modified）、`docs/internal/tech-debt.md`（modified）、`.github/*`（untracked）。**不应**再有 `macos/` 字眼。

- [ ] **Step 5: 不 commit，进 Task 1.2**

---

### Task 1.2: gitleaks 全 history 扫描

**Files:**
- 输出: `/tmp/inkframe-gitleaks-report.json`

- [ ] **Step 1: 安装 gitleaks（macOS）**

```bash
brew list gitleaks >/dev/null 2>&1 || brew install gitleaks
gitleaks version
```

Expected: 打印版本号（≥ v8.18）。

- [ ] **Step 2: 扫描全 git history**

```bash
gitleaks detect \
  --source /Users/kerro/Projects/InkFrame \
  --report-path /tmp/inkframe-gitleaks-report.json \
  --report-format json \
  --no-banner \
  --verbose
```

Expected: exit code 0 = 干净；exit code 1 = 有命中（不是错误，是发现 secret）。

- [ ] **Step 3: 命中分类**

```bash
test -s /tmp/inkframe-gitleaks-report.json && jq 'group_by(.RuleID) | map({rule: .[0].RuleID, count: length, files: [.[].File] | unique})' /tmp/inkframe-gitleaks-report.json || echo "no findings"
```

Expected: 要么 `no findings`；要么得到一份分组报告。

- [ ] **Step 4: 写裁决（无命中 / 有命中）**

如果 `no findings`：直接进 Task 1.3。

如果有命中：**STOP，回报用户决策**：
1. 命中是否真 secret（误报：assets fingerprint、UUID）？误报 → 加 `.gitleaksignore` 后重跑
2. 真 secret → 必须 rotate 该凭据**且** 决定是否 history rewrite（不可逆，会让所有 clone/fork 失效）
3. 用户拍板前**不要继续** Phase 1

- [ ] **Step 5: 提交 `.gitleaksignore`（如有误报）**

文件路径: `.gitleaksignore`（根目录），格式: `<commit-sha>:<file>:<rule-id>` 一行一条。

```bash
git add .gitleaksignore
git commit -m "chore(oss): allowlist gitleaks false positives"
```

---

### Task 1.3: 写 SECURITY.md

**Files:**
- Create: `SECURITY.md`

- [ ] **Step 1: 创建 `SECURITY.md`**

文件内容（中英双语，参考 GitHub Security Advisory 标准）：

```markdown
# Security Policy

## Supported Versions / 支持版本

We are currently in **alpha**. Security fixes land on the latest tag (`v0.1.0-alpha.x`) and unreleased `dev`.

当前处于 **alpha** 阶段。安全修复合入最新 tag (`v0.1.0-alpha.x`) 与未发布的 `dev` 分支，不再回溯更早 alpha。

| Version | Supported |
|---------|-----------|
| latest `v0.1.0-alpha.x` | ✅ |
| earlier `alpha.*` | ❌ |

## Reporting a Vulnerability / 漏洞上报

**Do NOT open a public GitHub issue.**

Use one of:

1. **GitHub Security Advisories**（推荐）: <https://github.com/KerroKapple/InkFrame/security/advisories/new>
2. **Email**: kerro99920+inkframe-security@gmail.com（请把所有信息加密发送或先索取 PGP key）

We aim to acknowledge within **72 hours** and provide a fix or mitigation timeline within **14 days**.

## Scope / 涵盖范围

In scope:
- Provider API key 泄漏路径（secure storage、日志、telemetry、错误堆栈）
- Script editor / canvas 节点 XSS 与命令注入
- Local PostgreSQL 数据完整性 / 越权读取
- 第三方 AI provider 凭据滥用风险（HMAC 签名、JWT 续期）

Out of scope:
- 用户自己 fork 后引入的修改
- Provider 上游服务漏洞（请上报给 provider）
- 物理访问下的本地文件读取（assumed threat model）

## Disclosure / 披露

修复发布后 30 天内公开 advisory。Reporter 同意可署名致谢。
```

- [ ] **Step 2: 写入文件**

```bash
# 直接通过 Write 工具完成，避免 heredoc 嵌套
```

- [ ] **Step 3: 检查渲染**

```bash
grep -c "^## " SECURITY.md
```

Expected: 输出 `5`（5 个二级标题）。

- [ ] **Step 4: stage（不单独 commit，等 Task 1.5 一起）**

```bash
git add SECURITY.md
```

---

### Task 1.4: 写 CODE_OF_CONDUCT.md

**Files:**
- Create: `CODE_OF_CONDUCT.md`

- [ ] **Step 1: 复制 Contributor Covenant 2.1**

来源: <https://www.contributor-covenant.org/version/2/1/code_of_conduct/code_of_conduct.md>

写入根目录 `CODE_OF_CONDUCT.md`，**唯一替换**: 第 6 节 "Enforcement" 中 contact 邮箱替换为：
```
kerro99920+inkframe-conduct@gmail.com
```

- [ ] **Step 2: 检查标识**

```bash
grep -E "Contributor Covenant" CODE_OF_CONDUCT.md && grep -E "kerro99920\+inkframe-conduct" CODE_OF_CONDUCT.md
```

Expected: 两条都命中。

- [ ] **Step 3: stage**

```bash
git add CODE_OF_CONDUCT.md
```

---

### Task 1.5: 收敛 PR 1 commits

**约束:** CONTRIBUTING.md 已声明强制线性历史 + Squash/Rebase merge。本任务以**多个有意义的 commit** 收敛改动，最终 PR 用 GitHub UI Squash merge 进 dev。

- [ ] **Step 1: 检查 staged / untracked 状态**

```bash
git status
```

Expected:
- staged: `CONTRIBUTING.md`（rename）、`SECURITY.md`、`CODE_OF_CONDUCT.md`、`.gitleaksignore`（如有）
- modified（unstaged）: `README.md`、`README.zh-CN.md`、`docs/internal/tech-debt.md`
- untracked: `.github/CODEOWNERS`、`.github/ISSUE_TEMPLATE/`、`.github/PULL_REQUEST_TEMPLATE.md`
- 不应出现: `macos/*`

- [ ] **Step 2: Commit A — OSS 政策文件**

```bash
git add SECURITY.md CODE_OF_CONDUCT.md
git status --short
git commit -m "$(cat <<'EOF'
docs(oss): add SECURITY.md + CODE_OF_CONDUCT.md

Contributor Covenant 2.1 + GitHub Security Advisories 流程。
公开前置依赖。
EOF
)"
```

- [ ] **Step 3: Commit B — `.github/` 模板与 CODEOWNERS**

```bash
git add .github/CODEOWNERS .github/ISSUE_TEMPLATE/ .github/PULL_REQUEST_TEMPLATE.md
git commit -m "$(cat <<'EOF'
chore(oss): add issue/PR templates + CODEOWNERS

- bug_report.yml / feature_request.yml / config.yml（disable blank issues，引导到 Discussions）
- PULL_REQUEST_TEMPLATE.md
- CODEOWNERS：@KerroKapple 默认接管
EOF
)"
```

- [ ] **Step 4: Commit C — CONTRIBUTING 移到根 + README 路径修正**

```bash
git add CONTRIBUTING.md README.md README.zh-CN.md
git commit -m "$(cat <<'EOF'
docs(oss): hoist CONTRIBUTING to root, fix README links

GitHub UI 在根目录有 CONTRIBUTING.md 时会在 PR 创建页自动链。
README EN/zh-CN 内部链接同步修正。
EOF
)"
```

- [ ] **Step 5: Commit D — tech-debt 私有文档变更**

```bash
git diff docs/internal/tech-debt.md
```

如果改动是合理的项目记录（不是被 OSS 工作意外改到），单独 commit：

```bash
git add docs/internal/tech-debt.md
git commit -m "docs(internal): tech-debt log housekeeping"
```

如果改动看不懂或不该带：`git restore docs/internal/tech-debt.md`，跳过。

- [ ] **Step 6: 终态检查**

```bash
git status
git log --oneline chore/oss-onboarding ^main | head -10
```

Expected: working tree clean，3-4 个新 commit 在 chore/oss-onboarding 上。

---

### Task 1.6: 开 PR 1

- [ ] **Step 1: rebase 到最新 main**

```bash
git fetch origin main
git rebase origin/main
```

Expected: rebase 干净；如有冲突，解决后 `git rebase --continue`。

- [ ] **Step 2: push 分支**

```bash
git push -u origin chore/oss-onboarding
```

- [ ] **Step 3: 开 PR（base = dev，按 CONTRIBUTING 分支模型）**

```bash
gh pr create --base dev --head chore/oss-onboarding \
  --title "chore(oss): pre-launch hygiene — SECURITY/COC/templates" \
  --body "$(cat <<'EOF'
## Summary

PR 1/3 of OSS launch (see `docs/superpowers/plans/2026-04-29-oss-launch.md`).

- 加 SECURITY.md（GitHub Security Advisories 流程 + 双语）
- 加 CODE_OF_CONDUCT.md（Contributor Covenant 2.1）
- `.github/` issue 模板 / PR 模板 / CODEOWNERS
- CONTRIBUTING.md 从 docs/ 移到根 + README 路径修正
- gitleaks history 扫描已通过（report 见 PR 评论）

## Out of scope（显式不动）

- `macos/Podfile`、`macos/Flutter/*.xcconfig` — CocoaPods 集成决策另开 issue
- ROADMAP / good first issues — PR 2
- 翻 public — PR 3

## Test plan

- [ ] CI 全绿（analyze + 6 hooks + test 70% + golden）
- [ ] gitleaks report 已贴评论，0 真 secret
- [ ] 本地 `gh repo view --json visibility` 仍为 PRIVATE
EOF
)"
```

- [ ] **Step 4: 贴 gitleaks 报告到 PR 评论**

```bash
PR_NUM=$(gh pr view --json number -q .number)
gh pr comment "$PR_NUM" --body "$(cat <<'EOF'
### gitleaks 全 history 扫描

```
[在此粘贴 Task 1.2 Step 3 的分组输出]
```
EOF
)"
```

- [ ] **Step 5: 等用户 review + CI 绿，再 Squash merge 到 dev**

合并方法: GitHub UI → "Squash and merge"。**不能** "Create a merge commit"（违反 CONTRIBUTING §69 线性历史）。

---

# Phase 2 / PR 2: Contributor On-ramp

**目标:** 让外部贡献者 fork → PR → CI 跑通的链路畅通；公开 ROADMAP 让人知道往哪走；标好入门 issue 让人知道从哪入手。

**前置:** PR 1 已 merge 到 dev。

**分支:** 新建 `chore/oss-on-ramp`（从 dev 切）。

```bash
git fetch origin
git checkout dev
git pull --rebase origin dev
git checkout -b chore/oss-on-ramp
```

---

### Task 2.1: 验证 CI 在 fork PR 上能跑

**Files:**
- 可能修改: `.github/workflows/ci.yml`

**背景:** 现有 `ci.yml` 触发条件 `pull_request`（无 branch 限制）。GitHub Actions 默认 fork PR 拿不到 secrets，但**当前 CI 不需要任何 secret**（postgres 是 service container、Flutter 是 public action）——理论上 fork PR 能跑通。需要实测验证。

- [ ] **Step 1: 静态审计 ci.yml 是否依赖 secrets**

```bash
grep -E "secrets\.|\\\$\{\{" .github/workflows/ci.yml
```

Expected: 输出仅包含 `${{ env.FLUTTER_VERSION }}` 一行；**不应**有 `secrets.XXX` 字眼。

- [ ] **Step 2: 检查 trigger 是否覆盖 dev 分支**

```bash
grep -A 5 "^on:" .github/workflows/ci.yml
```

Expected: `push: branches: [main]` + `pull_request:`（无 branches 限制 = 任何 PR 都跑）。

如果 `push` 只列 `main`，决策：是否要把 push 也覆盖到 dev？建议**保持现状**——push 到 dev 永远走 PR，PR 已被 trigger 覆盖，不需要双跑浪费 minutes。

- [ ] **Step 3: 加 fork 友好性注释（仅文档，不改逻辑）**

在 `ci.yml` 顶部注释扩充：

```yaml
# InkFrame CI
# 触发：push 到 main / 任何 PR（含 fork PR）。三条并行 job：analyze / test / golden。
# Runner 用 ubuntu-latest 控成本，macOS/Windows 烟测放到 release 流水线。
#
# Fork PR 兼容性：本 workflow 不依赖任何 secrets，fork PR 可直接跑。
# 维护者：新增任何 ${{ secrets.XXX }} 之前请评估对 fork PR 的影响——
# 默认 fork PR 拿不到 secrets，相关 step 必须用 if 守卫。
```

- [ ] **Step 4: stage 但不 commit，等 Task 2.5**

---

### Task 2.2: 加 secret-scan workflow（gitleaks 兜底）

**Files:**
- Create: `.github/workflows/secret-scan.yml`

**理由:** Phase 1 Task 1.2 是一次性 history 扫描；这里加常驻 workflow，每次 PR / push 自动跑，防新引入 secret。

- [ ] **Step 1: 写 workflow**

文件内容:

```yaml
name: secret-scan

on:
  push:
    branches: [main, dev]
  pull_request:

jobs:
  gitleaks:
    name: gitleaks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # GITLEAKS_LICENSE 仅 org 级仓库需要，public 个人 repo 不需要
```

- [ ] **Step 2: 本地 lint workflow 语法**

```bash
gh workflow view secret-scan 2>&1 || echo "workflow 尚未 push，本地无法 lint"
```

如本地有 `actionlint`：`actionlint .github/workflows/secret-scan.yml`，期望 0 输出。

- [ ] **Step 3: stage**

```bash
git add .github/workflows/secret-scan.yml
```

---

### Task 2.3: ROADMAP.md

**Files:**
- Create: `ROADMAP.md`

**写法:** 三段式 — Shipped / In Progress / Help Wanted。Provider 矩阵单列。每条带 owner（"Maintainer" / "Open" / GitHub @username）。

- [ ] **Step 1: 列已交付 release**

```bash
git tag --sort=-creatordate | head -10
```

记录: `v0.1.0-alpha.1` 至 `v0.1.0-alpha.8`，按时间倒序列出。

- [ ] **Step 2: 列已实现 provider**

```bash
ls lib/providers/*_provider.dart | sed 's|.*/||; s|_provider.dart||'
```

Expected: gemini_image / kling_v3 / kling_v3_omni / wanx_i2v / wanx_image / wanx_r2v / wanx_t2v + dashscope_async base。

- [ ] **Step 3: 写 `ROADMAP.md`**

文件内容（用 Write 工具落盘，避免 heredoc 嵌套）:

```markdown
# Roadmap

> 当前阶段: **alpha**。每个里程碑对应一个 minor tag。Help wanted = 维护者欢迎 PR / 协同设计的方向。
>
> 想认领某条？开 issue 或 Discussion，我们对齐 scope 后再动手。**不要直接闷头 PR 大功能**——先对齐方向避免白做。

## ✅ Shipped (v0.1.0-alpha.x)

| Tag | 主题 | 日期 |
|-----|------|------|
| alpha.8 | T5 video node UI loop — 5 款视频 Provider UI 接入 + Lightbox | 2026-04 |
| alpha.7 | canvas UX 收口 — 节点删除 / Inspector autosave / FAB | 2026-04 |
| alpha.6 | secure-storage：DashScope 系 6 款 Provider 共用 Key | 2026-04 |
| alpha.5 | canvas 点击选中连线 + midpoint 删除按钮 | 2026-04 |
| earlier | 见 `git tag`（alpha.1 ~ alpha.4） | — |

## 🛠 In Progress (Sprint 当前 / Maintainer)

- UI Sprint 3+ — 统一设计 token 落地剩余组件（@KerroKapple, tracked in #65 后续）
- macOS 构建链整理 — CocoaPods 集成的 commit 边界决策（issue: TBD）

## 🙋 Help Wanted

按贡献门槛由低到高:

### 文档 / i18n
- 翻译 README / CONTRIBUTING 到第 3 种语言（日 / 韩 / 西班牙语优先）
- ARB 文件中文翻译 review（current `app_zh.arb` 维护者一人翻译，需要母语者 review）

### Provider 接入
新增 AI provider 不需要懂整个 codebase，只需读 `docs/PROVIDER-API.md` 实现一个文件。需求矩阵：

| Provider | 类型 | 状态 | 优先级 |
|----------|------|------|--------|
| Stable Diffusion (local ComfyUI) | image | ❌ Open | 高 |
| Midjourney (via Discord API) | image | ❌ Open | 中 |
| OpenAI DALL-E 3 | image | ❌ Open | 中 |
| Runway Gen-3 | video | ❌ Open | 高 |
| Pika Labs | video | ❌ Open | 中 |
| Luma Dream Machine | video | ❌ Open | 中 |

### Canvas / 编辑器
- Undo/Redo 完整覆盖（当前部分操作未入 undo stack）
- 节点 group / collapse
- 画布缩放性能优化（节点 > 200 时 frame drop）

### 平台 / 发布
- Windows 烟测自动化（macOS 已手动跑，Windows 缺 reproducible）
- Linux 桌面端可行性（社区有需求即可启动）

### 测试基建
- Golden test 补齐（当前 `golden` job 是占位）
- E2E：完整 script → storyboard → export 流程

## 🚫 Out of Scope（明确不做）

- 移动端（iOS/Android）—— 项目定位是 desktop workstation
- Web 端 SaaS —— 与 local-first 设计哲学冲突
- 闭源 / 商业 license —— MIT 不变

## 如何参与

1. 看到感兴趣的条目 → 开 issue / 在已有 issue 评论"我来"
2. 维护者会在 24-72h 内 ack 并对齐 scope
3. 切 feature 分支 / fork → 按 `CONTRIBUTING.md` 规范开 PR
4. CI 绿 + review pass → squash merge

第一次贡献？看 issue tracker 里 `good first issue` 标签。
```

- [ ] **Step 4: 写入 + stage**

```bash
git add ROADMAP.md
```

---

### Task 2.4: README 链 ROADMAP + Discussions

**Files:**
- Modify: `README.md`、`README.zh-CN.md`

- [ ] **Step 1: 在 README 顶部 / 项目简介之后插入 navigation block**

英文版（README.md）— 在 hero / Badges 段落之下、首段功能描述之前插入：

```markdown
**Quick links**: [Roadmap](ROADMAP.md) · [Contributing](CONTRIBUTING.md) · [Architecture](docs/ARCHITECTURE.md) · [Provider API](docs/PROVIDER-API.md) · [Discussions](https://github.com/KerroKapple/InkFrame/discussions)
```

中文版（README.zh-CN.md）同样位置:

```markdown
**快速入口**: [路线图](ROADMAP.md) · [贡献指南](CONTRIBUTING.md) · [架构](docs/ARCHITECTURE.md) · [Provider API](docs/PROVIDER-API.md) · [讨论区](https://github.com/KerroKapple/InkFrame/discussions)
```

- [ ] **Step 2: 验证两个文件内容存在**

```bash
grep -c "ROADMAP.md" README.md README.zh-CN.md
```

Expected: 两个文件均 `≥ 1`。

- [ ] **Step 3: stage**

```bash
git add README.md README.zh-CN.md
```

---

### Task 2.5: 准备 5 个 good first issue 候选

**Output:** 一份候选列表（plan 内文档），等用户 review 后再用 gh CLI 批量创建。

**原则:**
- 不依赖未公开的内部知识
- 单文件 / 单组件可解
- 有清晰 acceptance criteria
- 30 分钟 - 2 小时可完成
- 不影响关键路径（出 bug 也不阻塞主流程）

- [ ] **Step 1: 扫描 codebase 找候选**

```bash
grep -rn -E "TODO|FIXME|HACK" lib/ --include="*.dart" | grep -v "_generated" | head -30
grep -rn "i18n" docs/ | head
```

记录扫到的 TODO 列表。

- [ ] **Step 2: 起草 5 个候选 issue（写入本 plan 同目录）**

文件路径: `docs/superpowers/plans/2026-04-29-good-first-issues.md`

模板（每个 issue 都需要这些字段）:

```markdown
## #N: <Title>

**Labels:** good first issue, <area>
**Estimated effort:** <30min / 1h / 2h>
**Files:** <相对路径>
**Skill required:** <Dart basics / i18n / shell scripting / ...>

### Background
<为什么需要这个改动，1-2 句>

### What to do
1. <具体步骤 1>
2. <具体步骤 2>
3. <验证方式>

### Acceptance criteria
- [ ] <可勾选条目 1>
- [ ] <可勾选条目 2>
- [ ] CI 绿（含 i18n coverage hook）
- [ ] PR 走 CONTRIBUTING.md 流程

### Hints
- 参考类似实现: <文件路径 / 已合 PR 链接>
- 不确定的地方在 PR 里 @ 维护者
```

5 个候选种子（Task 执行人按这个找）:

1. **README 缺一个英文 Quickstart 章节**（README.md 当前直接进 architecture，缺 5 行 quickstart）
2. **`app_zh.arb` 母语者文案 polish**（一次性 review，标硬翻味的 key）
3. **`scripts/hooks/check-i18n-coverage.sh` 增强：报告未使用的 key**（当前只检 missing，不查 unused）
4. **CONTRIBUTING.md 加一个 "Setting up your dev env on Windows" 小节**（当前偏 macOS）
5. **加 `.editorconfig`**（统一 IDE 缩进，2 空格 Dart / LF / final newline）

- [ ] **Step 3: 把候选写入文件，stage**

```bash
# 通过 Write 工具落盘 docs/superpowers/plans/2026-04-29-good-first-issues.md
git add docs/superpowers/plans/2026-04-29-good-first-issues.md
```

- [ ] **Step 4: 不立即创建 GitHub issue**

实际 `gh issue create` 留到 Phase 3 翻 public 之后再做（PRIVATE 时 issue 没意义，没人看得到）。

---

### Task 2.6: 收敛 PR 2 + 开 PR

- [ ] **Step 1: 检查改动**

```bash
git status
git diff --stat
```

Expected staged:
- `.github/workflows/ci.yml`（注释扩充）
- `.github/workflows/secret-scan.yml`（新增）
- `ROADMAP.md`（新增）
- `README.md` / `README.zh-CN.md`（quick links）
- `docs/superpowers/plans/2026-04-29-good-first-issues.md`（新增）

- [ ] **Step 2: 拆 commit 并提交**

```bash
git add .github/workflows/ci.yml
git commit -m "docs(ci): annotate fork PR compatibility"

git add .github/workflows/secret-scan.yml
git commit -m "ci: add gitleaks secret-scan workflow"

git add ROADMAP.md README.md README.zh-CN.md
git commit -m "$(cat <<'EOF'
docs(oss): add ROADMAP and link from README

公开路线图分为 Shipped / In Progress / Help Wanted 三段，
Provider 矩阵单列，方便外部贡献者认领方向。
EOF
)"

git add docs/superpowers/plans/2026-04-29-good-first-issues.md
git commit -m "docs(internal): draft good first issue candidates"
```

- [ ] **Step 3: rebase + push + 开 PR**

```bash
git fetch origin dev
git rebase origin/dev
git push -u origin chore/oss-on-ramp

gh pr create --base dev --head chore/oss-on-ramp \
  --title "chore(oss): contributor on-ramp — ROADMAP + secret-scan + first-issue draft" \
  --body "$(cat <<'EOF'
## Summary

PR 2/3 of OSS launch.

- ROADMAP.md：三段式 + Provider 矩阵 + Help Wanted
- README EN/zh-CN 加 quick links（ROADMAP / Discussions）
- ci.yml：fork PR 兼容性注释
- secret-scan.yml：常驻 gitleaks workflow（push + PR 触发）
- good first issue 候选 5 条（plan 文件内，待 PR 3 公开后用 gh CLI 创建）

## Test plan

- [ ] CI 全绿（analyze + 6 hooks + test + golden + secret-scan）
- [ ] secret-scan 在本 PR 上 0 命中
- [ ] README 渲染检查（GitHub PR 文件预览）
EOF
)"
```

- [ ] **Step 4: review + Squash merge 到 dev**

---

# Phase 3 / PR 3: Public Launch

**目标:** 翻 visibility → public，开 Discussions，配 branch protection，最后批量创建 good first issues + 发公告。

**前置:** PR 1 + PR 2 已合到 dev 并已合到 main（按 release 流程，从 dev 切 release/v0.1.0 → main）。

---

### Task 3.1: README 顶部 hero 区

**Files:**
- Modify: `README.md`、`README.zh-CN.md`
- 资产: `docs/assets/hero-screenshot.png`（新增） / `docs/assets/demo.gif`（可选）

**目的:** 用户来到 GitHub repo 第一屏决定是否 star。当前 README 直接进 architecture，缺视觉 hook。

- [ ] **Step 1: 准备 hero 资产**

```bash
mkdir -p docs/assets
```

资产要求:
- `hero-screenshot.png`: 1920x1080 或更高，展示 canvas + 一个完整 generation 流程
- 可选 `demo.gif`: ≤ 5 MB，展示拖拽节点 / 提交 job / lightbox 预览

**用户提供。** 自动化 agent 不能凭空生成截图——这一步必须人工。

如果暂时没资产 → 加 placeholder 占位:

```markdown
> 📸 Demo screenshot coming soon. Track at #<issue>.
```

并开一个 issue 记录"hero asset wanted"，加 `good first issue` 标签。

- [ ] **Step 2: README 顶部插入 hero 区（在标题之下，Quick links 之上）**

```markdown
<p align="center">
  <img src="docs/assets/hero-screenshot.png" alt="InkFrame canvas screenshot" width="800">
</p>

<p align="center">
  <a href="https://github.com/KerroKapple/InkFrame/actions"><img src="https://github.com/KerroKapple/InkFrame/workflows/ci/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT"></a>
  <a href="https://github.com/KerroKapple/InkFrame/releases"><img src="https://img.shields.io/github/v/tag/KerroKapple/InkFrame?label=version" alt="version"></a>
  <a href="README.zh-CN.md"><img src="https://img.shields.io/badge/lang-中文-red.svg" alt="zh-CN"></a>
</p>
```

zh-CN 同样位置：lang badge 改为 `[English](README.md)`。

- [ ] **Step 3: stage（不单独 commit，等 Task 3.5）**

```bash
git add docs/assets/ README.md README.zh-CN.md
```

---

### Task 3.2: 启用 GitHub Discussions

- [ ] **Step 1: gh CLI 启用**

```bash
gh repo edit KerroKapple/InkFrame --enable-discussions
```

- [ ] **Step 2: 验证**

```bash
gh repo view --json hasDiscussionsEnabled -q .hasDiscussionsEnabled
```

Expected: `true`。

- [ ] **Step 3: 创建初始 categories（GitHub UI）**

去 <https://github.com/KerroKapple/InkFrame/discussions/categories> 配置:

| Category | Format |
|----------|--------|
| 📣 Announcements | Announcement (only maintainers post) |
| 💡 Ideas | Open-ended discussion |
| 🙋 Q&A | Question / answer |
| 🎨 Show and tell | Open-ended discussion |
| 🌐 中文区 | Open-ended discussion |

CLI 当前不支持创建 category，必须 UI 操作。**手工 step。**

---

### Task 3.3: 配置 Branch Protection

**前提:** repo 仍 PRIVATE 也可以配。configrepetition 一次到位。

- [ ] **Step 1: main 保护规则**

```bash
gh api repos/KerroKapple/InkFrame/branches/main/protection \
  --method PUT \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["analyze + hooks", "test + coverage", "golden", "gitleaks"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true
}
JSON
```

- [ ] **Step 2: dev 保护规则（同 main 但 review 不强制）**

```bash
gh api repos/KerroKapple/InkFrame/branches/dev/protection \
  --method PUT \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["analyze + hooks", "test + coverage", "golden", "gitleaks"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

- [ ] **Step 3: 验证两条规则生效**

```bash
gh api repos/KerroKapple/InkFrame/branches/main/protection -q '.required_linear_history.enabled, .required_status_checks.contexts'
gh api repos/KerroKapple/InkFrame/branches/dev/protection -q '.required_linear_history.enabled'
```

Expected: 都 `true` + contexts 列表正确。

---

### Task 3.4: 翻 public

**⚠️ 不可逆 step。** 翻完之后所有历史 commit、所有 issue、所有 wiki（如有）瞬间公开。Phase 1/2 是给这一刻铺路的，所有清理必须先做完。

- [ ] **Step 1: 翻 public 前最后 checklist**

```bash
echo "=== Pre-public checklist ==="
echo "1. PR 1 & PR 2 已合 main? "; gh pr list --state merged --base main --limit 5
echo "2. main 分支 protection 已配? "; gh api repos/KerroKapple/InkFrame/branches/main/protection -q '.required_linear_history.enabled' 2>/dev/null
echo "3. gitleaks history 干净? "; gitleaks detect --source . --no-banner 2>&1 | tail -3
echo "4. SECURITY/COC/ROADMAP/CONTRIBUTING 都在根目录? "; ls SECURITY.md CODE_OF_CONDUCT.md ROADMAP.md CONTRIBUTING.md
echo "5. Discussions 已开? "; gh repo view --json hasDiscussionsEnabled -q .hasDiscussionsEnabled
echo "6. CI 在 main 是绿的? "; gh run list --branch main --limit 1
```

每条都通过，才进 Step 2。

- [ ] **Step 2: 翻 public**

```bash
gh repo edit KerroKapple/InkFrame --visibility public --accept-visibility-change-consequences
```

- [ ] **Step 3: 验证**

```bash
gh repo view --json visibility
```

Expected: `{"visibility":"PUBLIC"}`。

- [ ] **Step 4: 立即检查 GitHub UI**

打开 <https://github.com/KerroKapple/InkFrame> （无痕窗口 / 退出登录状态），确认:
- README 渲染正常、hero 截图加载（如已上传）
- LICENSE / SECURITY / COC / ROADMAP / CONTRIBUTING 都可访问
- 没有 404 链接
- Discussions tab 可见

---

### Task 3.5: 批量创建 good first issues

**前提:** repo 已 public。

- [ ] **Step 1: 创建 labels**

```bash
gh label create "good first issue" --color "7057ff" --description "Good for newcomers" 2>/dev/null || true
gh label create "help wanted" --color "008672" --description "Extra attention is needed" 2>/dev/null || true
gh label create "provider" --color "f9d0c4" --description "AI Provider 接入相关" 2>/dev/null || true
gh label create "i18n" --color "fbca04" --description "国际化 / 翻译" 2>/dev/null || true
gh label create "docs" --color "0075ca" --description "文档改进" 2>/dev/null || true
```

- [ ] **Step 2: 把 `docs/superpowers/plans/2026-04-29-good-first-issues.md` 里 5 条逐条创建**

每条用 `gh issue create`:

```bash
gh issue create \
  --title "<title from plan>" \
  --body "<body from plan>" \
  --label "good first issue" \
  --label "<area-label>"
```

- [ ] **Step 3: 验证**

```bash
gh issue list --label "good first issue"
```

Expected: 5 条全部列出。

---

### Task 3.6: 发布公告

- [ ] **Step 1: 在 Discussions 发 Announcement**

```bash
# Discussions API 创建需要 GraphQL，gh CLI 当前不支持直接 create discussion
# 走 UI: https://github.com/KerroKapple/InkFrame/discussions/new?category=announcements
```

公告模板（中英双语）:

```markdown
# InkFrame 开源了 / InkFrame is now open source

中文: 本地优先的 AI 影视创作工作站。Flutter Desktop（macOS + Windows），node-based canvas 串多个 AI image/video provider。当前 alpha，欢迎提 issue / 贡献 PR / 接入新 provider。

EN: Local-first AI filmmaking workstation. Flutter Desktop (macOS + Windows), node-based canvas wiring multiple AI image/video providers. Currently alpha, contributions welcome.

## 想参与？/ Want to contribute?
1. README → ROADMAP → CONTRIBUTING
2. Issue tracker `good first issue` 标签找入门任务
3. 想加 Provider？看 docs/PROVIDER-API.md
4. 不知道做什么？开 Discussion 聊一聊
```

- [ ] **Step 2: （可选）外部曝光**

按用户意愿:
- Hacker News "Show HN: InkFrame — local-first AI filmmaking workstation"
- Reddit r/LocalLLaMA / r/StableDiffusion
- Twitter / 小红书

**不要在 plan 里硬编码外部 channel。** 用户自己决定要不要 / 何时发。

---

# Self-Review

- [x] **Spec coverage**: 用户原始需求 = "开源仓库希望别人来一起做"。Plan 覆盖：法律基础（COC + SECURITY）、贡献入口（CONTRIBUTING + 模板 + ROADMAP + good first issue）、CI 安全网（fork PR 兼容 + gitleaks 兜底）、Branch protection、demo 资产、公告通道。✅
- [x] **Placeholder scan**: 检查 "TBD" / "TODO" / "implement later" / "appropriate" — 仅 Task 3.1 hero 截图依赖用户提供资产，其他全部有具体内容。✅
- [x] **Type consistency**: 文件路径、commit message 模板、gh CLI 调用格式跨 task 一致。Branch 名 `chore/oss-onboarding` (PR 1) → `chore/oss-on-ramp` (PR 2) 区分清晰。✅
- [x] **Risk surface**:
    - Task 1.2 gitleaks 命中 → 显式 STOP 给用户决策
    - Task 3.4 翻 public → checklist 6 条 + 不可逆警告
    - 决策 1/2 (CocoaPods) 显式排除，单独处理
- [x] **CI 假设**: 现有 `ci.yml` 已 fork-friendly（无 secrets 依赖），Task 2.1 仅做注释 + 验证，不擅自改逻辑。✅

---

# Execution Handoff

Plan 已落盘到 `docs/superpowers/plans/2026-04-29-oss-launch.md`。两种执行方式:

**1. Subagent-Driven（推荐）** — 每个 Task 派一个 fresh subagent，主 agent 在 Task 间 review + 决策点把关。适合：你想要每步可见 + 可干预，决策点（gitleaks 命中、翻 public）能停下来商量。

**2. Inline Execution** — 当前 session 内连续执行，到 PR 边界 / 决策点 checkpoint review。适合：你信任 plan + 想一口气推完 PR 1。

**翻 public（Task 3.4）无论哪种模式都必须人工最终确认。**

请告诉我:
1. 选 1 还是 2？
2. PR 1 的开放问题（Podfile / xcconfig 决策）现在拍板还是先 issue 化延后？
3. 要不要现在就先动 PR 1 Task 1.1（清噪音 + gitleaks 扫历史）？这部分零风险、零写文件、纯只读 + restore，可以独立先跑掉报你结果。
