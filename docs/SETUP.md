# Dev Environment Setup / 开发环境搭建

This is the single source of truth for getting InkFrame building and running on a dev
machine, across platforms. Contribution flow (branches, hooks, commits) lives in
[CONTRIBUTING.md](../CONTRIBUTING.md).

本文是 InkFrame 各平台开发环境搭建的唯一真相源。贡献流程（分支、hook、commit 规范）见
[CONTRIBUTING.md](../CONTRIBUTING.md)。

## Baseline / 基线要求

| Tool | Version | Locked in |
|---|---|---|
| Flutter | stable channel, ≥ 3.41 (CI: 3.41.6) | `.github/workflows/ci.yml` / `pubspec.yaml` |
| Dart | ≥ 3.11 (ships with Flutter) | `pubspec.yaml` |
| PostgreSQL | 17 (binaries locked to 17.2) | `scripts/pg/pg-version.txt` |
| ffmpeg | optional — video export only | not pinned; runtime probe `INKFRAME_FFMPEG` env → PATH (`FfmpegLocator`) |

> ffmpeg is **optional**: without it, only video export fails (with an explicit error) — everything
> else works. / ffmpeg **可选**：缺失时仅视频导出报错，其余功能不受影响。

After cloning, the common first steps on every platform:

每个平台 clone 后的通用首步：

```bash
flutter pub get
flutter doctor          # resolve any reported issues first
flutter analyze         # 0 warnings (CI uses --fatal-infos)
flutter test            # full suite
```

---

## Git hooks / Git 钩子

After cloning, wire the version-controlled hooks in `scripts/hooks/` (pre-commit +
pre-push) as your local git hooks — no manual symlink into `.git/hooks` needed:

clone 后执行一次，把仓库内受版本控制的 `scripts/hooks/`（pre-commit + pre-push）接为本地
git 钩子，无需手动 symlink 到 `.git/hooks`：

```bash
git config core.hooksPath scripts/hooks
```

- **pre-commit**: `flutter analyze` + `dart run custom_lint` + `flutter test test/quality/`
  （定向质量测试，纯文件 IO，不连库，秒级）。
- **pre-push**: `flutter analyze` + 全量 `flutter test`。

> CONTRIBUTING.md 如有 hook 章节，请指回本节 —— SETUP.md 是开发环境的唯一真相源。

---

<a id="dev-env-on-windows"></a>

## Dev env on Windows / 开发环境 — Windows

These are the gotchas a Windows contributor hits on a fresh box, and the exact
command/path that fixed each one. macOS contributors can skip this section.

下面是 Windows 贡献者在干净机器上首次 setup 会踩的坑，以及解决每个坑的具体命令 / 路径。
macOS 贡献者可跳过本节。

### 1. Flutter Windows desktop target / 启用 Windows 桌面目标

A fresh Flutter install does **not** enable the Windows desktop target by default, so
`flutter run -d windows` reports "No devices found". Enable it once, then verify:

全新安装的 Flutter **默认不启用** Windows 桌面目标，`flutter run -d windows` 会报
"No devices found"。启用一次后用 `flutter doctor` 验证：

```powershell
flutter config --enable-windows-desktop
flutter doctor          # the "[√] Windows ... develop for Windows" line must be green
flutter devices         # "Windows (desktop)" should now appear
```

### 2. Visual Studio Build Tools 2022 / C++ 工具链

Flutter Windows desktop builds with MSVC + CMake. Install **Visual Studio Build Tools
2022** (the standalone Build Tools is enough — the full Visual Studio IDE is not
required), and tick:

Flutter Windows 桌面用 MSVC + CMake 构建。安装 **Visual Studio Build Tools 2022**（独立的
Build Tools 即可，不需要完整 Visual Studio IDE），勾选以下 workload / 组件：

- Workload: **Desktop development with C++** / **使用 C++ 的桌面开发**
- Component: **Windows 10 SDK** or **Windows 11 SDK** (the latest available) /
  **Windows 10/11 SDK**（选最新版）
- Component: **MSVC v143 - VS 2022 C++ x64/x86 build tools**

`flutter doctor` flags a missing or incomplete C++ toolchain under the
"Visual Studio" line — if it is not green, the workload above is the fix.

`flutter doctor` 会在 "Visual Studio" 这一行标出缺失或不完整的 C++ 工具链 —— 这一行不绿，
基本就是上面的 workload 没装全。

### 3. PostgreSQL 17 / 本地数据库

InkFrame stores projects in PostgreSQL 17. On Windows, install it with the official
**EDB installer** (default install path `C:\Program Files\PostgreSQL\17`).

InkFrame 用 PostgreSQL 17 存项目数据。Windows 上用官方 **EDB 安装包** 安装（默认安装路径
`C:\Program Files\PostgreSQL\17`）。

The dev app finds the PG binaries via the `INKFRAME_PG_BIN` env var. Point it at the
install's `bin` directory:

开发态 app 通过 `INKFRAME_PG_BIN` 环境变量定位 PG 二进制，指向安装目录下的 `bin`：

```powershell
$env:INKFRAME_PG_BIN = "C:\Program Files\PostgreSQL\17\bin"
```

**Gotcha — the service may not be running.** The EDB installer registers a
`postgresql-x64-17` Windows service. It is set to auto-start, but if the app cannot
connect, confirm it is actually running (and start it manually if not):

**坑 —— 服务可能没在跑。** EDB 安装包会注册 `postgresql-x64-17` Windows 服务，默认开机自启；
但如果 app 连不上，先确认它真的在运行（没运行就手动启动）：

```powershell
Get-Service postgresql-x64-17           # STATUS should be Running
Start-Service postgresql-x64-17         # start it if it is Stopped
Set-Service postgresql-x64-17 -StartupType Automatic   # ensure auto-start
```

To run the `@Tags(['pg'])` integration tests, also create a test DB and export
`TEST_PG_URL` (tests auto-skip when it is unset, so this is optional for UI work):

要跑 `@Tags(['pg'])` 集成测试，再建一个测试库并导出 `TEST_PG_URL`（不设时这些测试自动 skip，
纯 UI 开发可不管）：

```powershell
& "C:\Program Files\PostgreSQL\17\bin\createdb.exe" -U postgres inkframe_test
$env:TEST_PG_URL = "postgres://postgres@127.0.0.1:5432/inkframe_test?sslmode=disable"
```

Likewise, the `@Tags(['ffmpeg'])` integration tests need ffmpeg on PATH plus `TEST_FFMPEG=1`
(auto-skipped when unset):

同理，`@Tags(['ffmpeg'])` 集成测试需要 PATH 里有 ffmpeg 并设 `TEST_FFMPEG=1`（不设自动 skip）：

```powershell
$env:TEST_FFMPEG = "1"
flutter test --tags ffmpeg
```

### 4. PG runtime binaries for packaging / 打包用 PG 运行时二进制

The release build embeds bundled PG binaries under
`windows/runner/resources/pg/windows-x64/`. They are fetched by
`scripts/pg/fetch-binaries.sh` (run it from Git Bash on Windows):

发布构建会把打包好的 PG 二进制嵌到 `windows/runner/resources/pg/windows-x64/`，由
`scripts/pg/fetch-binaries.sh` 拉取（Windows 上从 Git Bash 运行）：

```bash
# from Git Bash
export PG_ARTIFACT_BASE_URL=https://<bucket>/inkframe/pg
./scripts/pg/fetch-binaries.sh
```

**Expected output:** with `PG_ARTIFACT_BASE_URL` set, the script verifies the SHA256
against `scripts/pg/pg-version.txt` (17.2) and prints `[fetch-binaries] OK`. With the
URL **unset** it prints `[fetch-binaries] NOT_CONFIGURED` and exits non-zero — that is
expected for normal dev, because day-to-day development uses your locally installed PG
17 (step 3) rather than the embedded binaries. You only need this step before producing
a release package.

**预期输出：** 设了 `PG_ARTIFACT_BASE_URL` 时，脚本会按 `scripts/pg/pg-version.txt`（17.2）
校验 SHA256 并打印 `[fetch-binaries] OK`。**没设** URL 时打印 `[fetch-binaries] NOT_CONFIGURED`
并以非零退出 —— 这对日常开发是正常的，因为平时开发用的是你本地装的 PG 17（第 3 步），而不是嵌入
二进制。只有要打发布包时才需要这一步。

### Run it / 跑起来

With the above in place, run the app with fake providers (no API keys, no quota burn):

以上就绪后，用 fake provider 跑 app（不需要 API Key，不烧配额）：

```powershell
$env:INKFRAME_PG_BIN = "C:\Program Files\PostgreSQL\17\bin"
$env:INKFRAME_FAKE_PROVIDERS = "1"
flutter run -d windows
```

For real generation, drop `INKFRAME_FAKE_PROVIDERS` and add keys in
**Settings → Providers** — on Windows they are stored in the **Credential Manager**.

接真实生成时去掉 `INKFRAME_FAKE_PROVIDERS`，进 **Settings → Providers** 填 Key ——
Windows 上 Key 落到 **凭据管理器（Credential Manager）**。

## Database backups & recovery / 数据库备份与恢复

On every launch InkFrame writes one daily cold backup of the embedded PostgreSQL to
`<data-root>/backups/inkframe-YYYY-MM-DD.dump` (pg_dump custom format `-Fc`), keeping the
7 most recent and skipping if today's file already exists. Backups never block startup —
any failure is only logged (`db.backup` module). The data root is the
platform-conventional path (Windows `%LOCALAPPDATA%\InkFrame`, macOS
`~/Library/Application Support/InkFrame`; DIR-1).

InkFrame 每次启动写一份嵌入式 PostgreSQL 的每日冷备到
`<数据根>/backups/inkframe-YYYY-MM-DD.dump`（pg_dump 自定义格式 `-Fc`），保留最新 7 份、
当日已有则跳过。备份绝不阻断启动 —— 任何失败只记日志（`db.backup` module）。数据根为平台
惯例路径（Win `%LOCALAPPDATA%\InkFrame`、macOS `~/Library/Application Support/InkFrame`；DIR-1）。

**Manual restore (advanced).** SCRAM auth means the DB password lives in the OS keystore,
so restoring by hand needs that password (an in-app restore flow is tracked as LB-22). With
the app closed, using the bundled `pg_restore` and the running cluster's port/password:

**手工恢复（进阶）。** SCRAM 认证下库口令在系统密钥库里，手工还原需要该口令（app 内一键还原
入口见 LB-22）。关闭 app 后，用打包的 `pg_restore` + 集群端口/口令：

```bash
# PGPASSWORD from OS keystore key `database.pg.password`; port from <data-root>/config/pg.port
PGPASSWORD=<pw> pg_restore -h 127.0.0.1 -p <port> -U inkframe -d postgres \
  --clean --if-exists "<data-root>/backups/inkframe-2026-07-15.dump"
```

---

See also: [docs/ARCHITECTURE.md](ARCHITECTURE.md) (env vars, key storage, data dirs),
[docs/DATABASE.md](DATABASE.md), [docs/BUILD-RELEASE.md](BUILD-RELEASE.md).

另见：[docs/ARCHITECTURE.md](ARCHITECTURE.md)（环境变量、密钥后端、数据目录）、
[docs/DATABASE.md](DATABASE.md)、[docs/BUILD-RELEASE.md](BUILD-RELEASE.md)。
