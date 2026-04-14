# Contributing to InkFrame

## 分支策略

- `main`：受保护分支。所有改动走 PR。
- `feat/<scope>-<desc>` / `fix/<scope>-<desc>` / `chore/<desc>`：短命 feature branch，完成即合并即删除。
- 每个 PR 对应一个 T（T1 工程骨架 / T2 存储层 …），PR 标题带 T 编号。

## Commit 规范（Conventional Commits）

```
<type>(<scope>): <subject>
```

- **type**: `feat` / `fix` / `refactor` / `test` / `docs` / `chore`
- **scope**: `core` / `theme` / `l10n` / `storage` / `canvas` / `script` / `generation` / `ci` / ...
- **subject**: 祈使句、≤ 60 char、中英文均可

示例：
- `feat(theme): design tokens with dark/light/high-contrast variants`
- `fix(storage): release PG connection on cancellation`
- `test(canvas): node drag gesture golden baseline`

## PR 流程

1. fork / 切 feature branch
2. 本地跑 `flutter analyze && flutter test`
3. 提交前 pre-commit hook 会自动跑硬规则检查（i18n / tokens / magic strings / 直接实例化 / Disposable）
4. 推送前 pre-push hook 会跑 `flutter test`
5. 开 PR，CI（analyze / test / golden）全绿才能合并
6. Squash merge 或 rebase merge，**不做 merge commit**

## 本地 Hook 安装（首次 clone 必做）

```bash
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../scripts/hooks/pre-push   .git/hooks/pre-push
```

不装 hook 等于绕过闸门，PR 进 CI 会打回——别省这两行。

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

- **SOLID / DI / i18n / Design Tokens 硬规则**：见仓库根 [CLAUDE.md](CLAUDE.md)。Widget 里任何硬编码字符串 / 硬编码颜色字号 / 直接 `new Service()` 都会被 hook 拦下
- **模型**：全部 freezed；禁止可变 class / `Map<String, dynamic>` 当模型用
- **异常**：每个 domain 一个 exception type；禁止 `catch (e)` 吞通用 Exception
- **架构蓝图**：`docs/ARCHITECTURE.md`

## 不许做的

- `git commit --no-verify`
- `git push --force` 到 `main`
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
