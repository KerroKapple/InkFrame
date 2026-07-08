# Contributing to InkFrame

## 分支模型（GitHub Flow）

```
main        ← 集成主干。所有 PR 合这里。Release 时在 main 上打 tag (v0.1.0 / v0.1.1 / ...)
 │
 ├─ feature/<scope>-<kebab-desc>   新功能
 ├─ fix/<issue-id>-<desc>          bugfix
 ├─ chore/<desc>                   仓库维护、依赖升级、CI 调整
 ├─ docs/<desc>                    纯文档变更
 ├─ test/<desc>                    纯测试补齐
 ├─ release/v0.1.x                 版本冻结分支（仅在多版本并行维护时使用）
 └─ hotfix/<issue-id>-<desc>       线上紧急修复，从 main 分叉
```

**铁律：**
- `main` 受保护。禁止直接 push，全部走 PR
- feature 分支超过 3 天必须每日 rebase main，避免大合并冲突
- **线性历史强制**：`main` 禁止一切 merge commit。所有 PR **只允许 Squash 或 Rebase merge**，禁止 `--no-ff` 与 `Create a merge commit`。GitHub Branch Protection 已开启 `Require linear history`，非线性 push 会被远端直接拒

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

1. 从 `main` 切 feature branch
2. 本地跑 `flutter analyze && flutter test`
3. `git commit` 时 pre-commit hook 自动跑 5 条硬规则（i18n / tokens / magic strings / 直接实例化 / Disposable）
4. `git push` 时 pre-push hook 自动跑 `flutter test`
5. 开 PR 到 `main`
6. CI 全绿 + 至少 1 个 approve 才能合
7. 合并策略（**全线性，零 merge commit**）：
   - `feature/*` / `fix/*` / `chore/*` / `docs/*` / `test/*` → `main`：**Squash merge**（一个 PR 压一个 commit 进 main）
   - `release/*` / `hotfix/*` → `main`：**Rebase & merge**（保留每个 commit，无 merge commit；合入后在 `main` 打 annotated tag）
   - Stacked PR：子 PR 的 base 指向父 PR 分支；父 PR 合入 main 后，子 PR 自动 re-target main
8. 合并后 GitHub 自动删除源分支

## Tag & Release

- 严格 SemVer：`vMAJOR.MINOR.PATCH`
- Pre-release：`v0.1.0-alpha.1` / `v0.1.0-rc.1`

### 使用 `scripts/release-tag.sh`（推荐）

合入 `main` 后：

```bash
# 从 GitHub PR 页复制 squash/merge commit 的完整 SHA
scripts/release-tag.sh <merge-sha> v0.1.0-alpha.7 "release 说明"
```

脚本内置两条护栏：
1. `origin/main` HEAD commit 消息必须匹配 `release(v*)` 前缀（防 tag 被误打到非 release commit）
2. `<merge-sha>` 必须等于 `origin/main` HEAD（防本地 `main` 未同步导致的时序陷阱，见 TD-002）

出错退码：`2` 参数错、`10` 护栏 #1 失败、`11` 护栏 #2 失败。脚本成功后自动：

- `git tag -a <tag> <sha> -m "<message>"`
- `git push origin <tag>`
- `gh release create <tag> --generate-notes`（tag 带 `-alpha.N` / `-beta.N` / `-rc.N` 后缀时自动加 `--prerelease`）

测试：`./test/scripts/release_tag_test.sh`（纯 shell，零依赖）。

### 手工兜底（不推荐）

仅在脚本不可用时。按顺序：

1. `git fetch origin`
2. `git log -1 --format=%s origin/main` 确认是 release 合入 commit
3. `git tag -a v0.1.0-alpha.7 <origin/main HEAD sha> -m "..."`
4. `git push origin v0.1.0-alpha.7`
5. `gh release create v0.1.0-alpha.7 --generate-notes --prerelease`

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

# ✅ 允许
git rebase main                  # 同步上游
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
- `git push --force` 到 `main`（自己的 feature 分支可用 `--force-with-lease`）
- 在一个 PR 里混"重构 + 新功能"——分开提
- 跨 feature 分支互相 merge（会形成毛线团，用 rebase main）
- 任何方向的 `git merge --no-ff`——会产生 merge commit，违反线性历史铁律
- GitHub PR UI 点 "Create a merge commit"——必须选 Squash 或 Rebase
- 在 widget 里写硬编码字符串（用 `context.l10n`）
- 在 widget 里写硬编码颜色/字号（用 `context.inkColors` / `context.inkTypography`）
- 直接 `new Service()`（必须走 Riverpod provider）
- 为旧数据**格式**留并行解析 / 回退兼容代码，或保留"以防万一"的僵尸 API（zero backward compat）
- 事后**编辑已发布的迁移**，或让 schema 变更**删/重置用户数据**——升级只走追加的前向迁移（ADR-0012）


## 本地 PostgreSQL（T2 存储层）

> Windows? See [docs/SETUP.md#dev-env-on-windows](docs/SETUP.md#dev-env-on-windows).

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

### 方式 C：本机 Homebrew → 可重定位嵌入 PG（macOS 开发/本地出包，无需对象存储）

当对象存储尚未配置时，开发机可直接从本机 Homebrew `postgresql@17` 生成「可重定位」的
嵌入式 PG（vendoring 全部依赖闭包 + 改写 install name 为 `@rpath` + ad-hoc 重签名），
落地到 `macos/Runner/Resources/pg/macos-arm64/`，供 `flutter build macos` 打进 `.app`：

```bash
brew install postgresql@17
bash scripts/pg/make-relocatable-macos.sh        # 产物自洽，结尾自检 postgres --version
flutter build macos --debug                      # Podfile 的 "Bundle Embedded PostgreSQL" 阶段自动拷进 bundle
```

产物默认被 `.gitignore` 忽略，不入库。`.app` 启动后嵌入式 PG 会在 `~/InkFrame/database`
自动 initdb 并起库（沙盒已禁用，见 `macos/Runner/*.entitlements` 与 `docs/BUILD-RELEASE.md`）。

### Schema 与迁移

- `lib/storage/schema/schema_v1.dart`：v=1 首版 DDL（真相源）
- `lib/storage/schema/001_init.sql`：文档镜像，运行时不加载
- `MigrationRunner` 按 `app_migrations.dart` 里组装的 `schema_vN.dart` 常量列表顺序执行（**不扫 `.sql` 文件**）；单迁移 = DDL + 版本 UPSERT 同事务（ME-31）；库版本高于应用期望时拒绝降级（`SchemaDowngradeError`）
- 升级唯一路径 = 追加编号连续的前向迁移；已发布迁移不可变、不删用户数据（ADR-0012）

所有 `UPDATE` 语句必须 `SET updated_at = ...`（应用层维护）。pre-commit 的 `check-updated-at.sh` 会拦截违规。
