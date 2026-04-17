# Contributing to InkFrame

## 分支模型（简化 git-flow）

```
main        ← 只接 release-quality 代码，每次合入打 tag (v0.1.0 / v0.1.1 / ...)
 │
 ├─ dev    ← 集成主干。所有 feature/fix 合这里。日常开发默认目标
 │   │
 │   ├─ feature/<scope>-<kebab-desc>   新功能，≤ 3 天合回 dev
 │   ├─ fix/<issue-id>-<desc>          非紧急 bugfix
 │   ├─ chore/<desc>                   仓库维护、依赖升级、CI 调整
 │   ├─ docs/<desc>                    纯文档变更
 │   └─ test/<desc>                    纯测试补齐
 │
 ├─ release/v0.1.x                     版本冻结分支，只接 bugfix，合 main + 回合 dev
 └─ hotfix/<issue-id>-<desc>           线上紧急修复，从 main 分叉，合 main + 回合 dev
```

**铁律：**
- `main` / `dev` 均受保护。禁止直接 push，全部走 PR
- `main` 只从 `release/*` 或 `hotfix/*` 合进来
- feature 分支超过 3 天必须每日 rebase dev，避免大合并冲突
- **线性历史强制**：`main` / `dev` 禁止一切 merge commit。任何方向（feature→dev / release→main / main→dev 回合）**只允许 Squash 或 Rebase merge**，禁止 `--no-ff` 与 `Create a merge commit`。GitHub Branch Protection 已开启 `Require linear history`，非线性 push 会被远端直接拒

## 命名规范

| 类型 | 前缀 | 举例 |
|---|---|---|
| 功能 | `feature/` | `feature/canvas-node-dragging` |
| 修复 | `fix/` | `fix/GH-42-job-queue-deadlock` |
| 紧急 | `hotfix/` | `hotfix/GH-99-api-key-leak` |
| 维护 | `chore/` | `chore/bump-dio-5.4` |
| 文档 | `docs/` | `docs/architecture-v2` |
| 测试 | `test/` | `test/storage-cascade-matrix` |
| 版本 | `release/` | `release/v0.1.0` |

全小写 + kebab-case。不允许驼峰 / 下划线 / 中文。

## Commit 规范（Conventional Commits）

```
<type>(<scope>): <subject>

<可选正文，72 字换行，说 why 不说 what>

<可选 footer：BREAKING CHANGE / Closes #42 / Co-Authored-By>
```

- **type**: `feat` / `fix` / `refactor` / `perf` / `test` / `docs` / `style` / `build` / `ci` / `chore`
- **scope**: `canvas` / `script` / `generation` / `storyboard` / `assets` / `settings` / `jobs` / `theme` / `l10n` / `storage` / `providers` / `core` / ...
- **subject**: 祈使句、≤ 50 char、中英文均可

示例：
- `feat(theme): design tokens with dark/light/high-contrast variants`
- `fix(storage): release PG connection on cancellation`
- `test(canvas): node drag gesture golden baseline`

## PR 流程

1. 从 `dev` 切 feature branch（hotfix 除外：从 `main` 切）
2. 本地跑 `flutter analyze && flutter test`
3. `git commit` 时 pre-commit hook 自动跑 5 条硬规则（i18n / tokens / magic strings / 直接实例化 / Disposable）
4. `git push` 时 pre-push hook 自动跑 `flutter test`
5. 开 PR 到 `dev`（hotfix/release 开 PR 到 `main`）
6. CI 全绿 + 至少 1 个 approve 才能合
7. 合并策略（**全线性，零 merge commit**）：
   - `feature/*` / `fix/*` / `chore/*` / `docs/*` / `test/*` → `dev`：**Squash merge**（一个 PR 压一个 commit 进 dev）
   - `release/*` / `hotfix/*` → `main`：**Rebase & merge**（保留每个 commit，无 merge commit；合入后在 `main` 打 annotated tag）
   - `main` 变更回合 `dev`：**Rebase & merge** 经过新 PR（禁止直接 `git merge main` 产生 merge commit）
   - Stacked PR：子 PR 的 base 指向父 PR 分支；父 PR 合入 dev 后，子 PR 自动 re-target dev
8. 合并后 GitHub 自动删除源分支

## Tag & Release

- 合入 `main` 后必须打 annotated tag：`git tag -a v0.1.0 -m "..."`
- 严格 SemVer：`vMAJOR.MINOR.PATCH`
- Pre-release：`v0.1.0-alpha.1` / `v0.1.0-rc.1`
- Release note 用 `gh release create v0.1.0 --generate-notes`

## 本地 Hook 安装（首次 clone 必做）

```bash
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../scripts/hooks/pre-push   .git/hooks/pre-push
```

不装 hook 等于绕过闸门，PR 进 CI 会打回——别省这两行。

## 本地 git 配置（线性历史约束）

```bash
# 全局默认 pull 走 rebase，杜绝 pull 产生 merge commit
git config --global pull.rebase true

# rebase 时自动 stash 未提交变更
git config --global rebase.autostash true

# 新建分支默认跟随 rebase 策略
git config --global branch.autoSetupRebase always
```

**禁止动作清单：**

```bash
# ❌ 产生 merge commit
git merge --no-ff <branch>
git pull                         # 如果没设 pull.rebase=true 就会 fetch+merge

# ❌ 绕闸
git commit --no-verify
git push --force origin main     # 受保护分支严禁 force push
git push --force origin dev

# ✅ 允许
git rebase dev                   # 同步上游
git push --force-with-lease      # 仅在自己的 feature 分支
```

## 本地验证命令

```bash
flutter pub get                        # 装依赖
flutter gen-l10n                       # 重生成 AppLocalizations（改 ARB 后）
flutter analyze                        # 0 warning
flutter test                           # 全绿
flutter test --coverage                # + coverage/lcov.info
lcov --summary coverage/lcov.info      # 摘要
```

## 代码规范

- **SOLID / DI / i18n / Design Tokens 硬规则**：见 [CLAUDE.md](CLAUDE.md)。Widget 里任何硬编码字符串 / 硬编码颜色字号 / 直接 `new Service()` 都会被 hook 拦下
- **模型**：全部 freezed；禁止可变 class / `Map<String, dynamic>` 当模型用
- **异常**：每个 domain 一个 exception type；禁止 `catch (e)` 吞通用 Exception
- **架构蓝图**：`docs/ARCHITECTURE.md`

## 不许做的

- `git commit --no-verify` 绕过 pre-commit hook
- `git push --force` 到 `main` 或 `dev`（自己的 feature 分支可用 `--force-with-lease`）
- 在一个 PR 里混"重构 + 新功能"——分开提
- 跨 feature 分支互相 merge（会形成毛线团，用 rebase dev）
- 任何方向的 `git merge --no-ff`——会产生 merge commit，违反线性历史铁律
- GitHub PR UI 点 "Create a merge commit"——必须选 Squash 或 Rebase
- 在 widget 里写硬编码字符串（用 `context.l10n`）
- 在 widget 里写硬编码颜色/字号（用 `context.inkColors` / `context.inkTypography`）
- 直接 `new Service()`（必须走 Riverpod provider）
- 为老 schema 留 migration / 向后兼容代码（InkFrame 明确 zero backward compat）


## 本地 PostgreSQL（T2 存储层）

InkFrame 使用嵌入式 PostgreSQL 17 作为本地存储。开发阶段有两种方式：

### 方式 A：Homebrew 本地 PG（推荐开发机）

```bash
brew install postgresql@17
brew services start postgresql@17
createdb inkframe_test

# 跑集成测
export TEST_PG_URL="postgres://$(whoami)@127.0.0.1:5432/inkframe_test?sslmode=disable"
flutter test
```

未设置 `TEST_PG_URL` 时，标记 `@Tags(['pg'])` 的集成测会自动 skip，不阻塞常规开发。

### 方式 B：嵌入二进制（发布打包）

```bash
export PG_ARTIFACT_BASE_URL=<对象存储 base URL>
./scripts/pg/fetch-binaries.sh
```

拉取脚本会按 `scripts/pg/pg-version.txt`（当前 17.2）校验 SHA256，写入：
- macOS: `macos/Runner/Resources/pg/<platform>/bin + /lib`
- Windows: `windows/runner/resources/pg/<platform>/bin + /lib`

未配置对象存储时脚本输出 `NOT_CONFIGURED`，不会误判成功。

### Schema 与迁移

- `lib/storage/schema/schema_v1.dart`：v=1 首版 DDL（真相源）
- `lib/storage/schema/001_init.sql`：文档镜像，运行时不加载
- `MigrationRunner` 按版本号扫描后续 `002_*.sql`，高版本拒绝回滚

所有 `UPDATE` 语句必须 `SET updated_at = ...`（应用层维护）。pre-commit 的 `check-updated-at.sh` 会拦截违规。
