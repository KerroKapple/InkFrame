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
# from Git Bash — zero config: downloads the official EDB zip pinned by
# scripts/pg/upstream.lock (URL + SHA256), trims it to bin/lib/share
./scripts/pg/fetch-binaries.sh
```

**Expected output:** the script downloads the EDB PostgreSQL zip, verifies the SHA256
pinned in `scripts/pg/upstream.lock`, trims it, and prints `[fetch-binaries] OK
postgres (PostgreSQL) 17.2 → windows/runner/resources/pg/windows-x64`. Day-to-day
development still uses your locally installed PG 17 (step 3) rather than the embedded
binaries — you only need this step before producing a release package. (Setting
`PG_ARTIFACT_BASE_URL` switches the script to an object-storage source instead.)

**预期输出：** 脚本会下载 EDB 官方 PostgreSQL zip，按 `scripts/pg/upstream.lock` 锁定的
SHA256 校验并裁剪，打印 `[fetch-binaries] OK postgres (PostgreSQL) 17.2 → …`。日常开发
仍用你本地装的 PG 17（第 3 步），只有要打发布包时才需要这一步。（设 `PG_ARTIFACT_BASE_URL`
可切换到对象存储源。）

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
7 most recent and skipping if today's file already exists. Manual backups
(`inkframe-manual-…`, Settings → Backups & restore → *Back up now*) and pre-restore safety
backups (`inkframe-prerestore-…`) live in the same folder with their own retention (3 each);
every backup ships a `<name>.meta.json` sidecar (SHA-256 + schema version) used to verify
integrity before restore. Backups never block startup — any failure is only logged
(`db.backup` module). The data root is the platform-conventional path (Windows
`%LOCALAPPDATA%\InkFrame`, macOS `~/Library/Application Support/InkFrame`; DIR-1).

InkFrame 每次启动写一份嵌入式 PostgreSQL 的每日冷备到
`<数据根>/backups/inkframe-YYYY-MM-DD.dump`（pg_dump 自定义格式 `-Fc`），保留最新 7 份、
当日已有则跳过。手动备份（`inkframe-manual-…`，设置 → 备份与还原 → 立即备份）与还原前
安全备份（`inkframe-prerestore-…`）在同一目录、各自保留 3 份；每份备份带
`<name>.meta.json` sidecar（SHA-256 + schema 版本），还原前校验完整性。备份绝不阻断
启动 —— 任何失败只记日志（`db.backup` module）。数据根为平台惯例路径
（Win `%LOCALAPPDATA%\InkFrame`、macOS `~/Library/Application Support/InkFrame`；DIR-1）。

**Project archives (export / import).** A project card's menu exports the whole project as a
single zip (rows + media, full fidelity); Studio's *Import project…* button re-imports it as a
brand-new project with fresh ids — archives from a newer InkFrame are refused.
项目卡菜单可把整个项目导出为单个 zip（数据行+媒体，全保真）；Studio 的「导入项目…」把它
作为**全新项目**（全新 id）导入；来自更新版本的项目包会被拒绝。

**Restore (in-app, preferred).** Settings → *Backups & restore* lists every backup with a
per-item *Restore*; the startup-failure screen offers *Restore latest backup* when the
database won't boot. Restore loads the dump into a scratch database first
(`--single-transaction`) and only swaps it in on success — **a failed restore leaves your
current data untouched**. A safety backup is attempted first; running generations are
cancelled and the app returns to the home screen. Media files on disk are not rolled back.

**还原（app 内，首选）。** 设置 → 备份与还原 逐份「还原」；数据库起不来时启动失败页提供
「从最近备份还原」。还原先把备份灌进临时库（`--single-transaction`），成功才对换——
**还原失败不会动你当前的数据**。还原前会尽量先做一次安全备份；进行中的生成任务会被取消，
完成后回到主页。磁盘上的媒体文件不回滚。

**Manual restore (advanced, app closed).** SCRAM auth means the DB password lives in the
OS keystore. Prefer restoring into a scratch DB and swapping, mirroring the in-app flow;
the plain `--clean` shown below does not remove tables that are absent from an older dump:

**手工恢复（进阶，先关 app）。** SCRAM 认证下库口令在系统密钥库里。建议仿 app 内流程
「临时库+对换」；下面的裸 `--clean` 不会清掉旧 dump 里不存在的表：

```bash
# PGPASSWORD from OS keystore key `database.pg.password`; port from <data-root>/config/pg.port
PGPASSWORD=<pw> pg_restore -h 127.0.0.1 -p <port> -U inkframe -d postgres \
  --clean --if-exists "<data-root>/backups/inkframe-2026-07-15.dump"
```

## Network proxy / 网络代理（LB-24）

InkFrame 的全部 Dart 层出网请求（AI 服务商生成链路、产物下载、检查更新）读取标准代理环境变量（变量名大小写双查）：

- `HTTPS_PROXY` — https 请求；缺失时依次回落 `HTTP_PROXY`、`ALL_PROXY`
- `HTTP_PROXY` — http 请求；缺失时回落 `ALL_PROXY`
- `NO_PROXY` — 逗号分隔例外表：精确 host、域后缀（`.foo.com`、`*.foo.com` 或裸 `foo.com`）、`*`（全直连）
- 变量**存在但为空串** = 显式禁用该档（同 curl），不再向后回落

示例（PowerShell；**改环境变量需重启 InkFrame**——进程启动时读取一次）：

```powershell
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
```

中文网络环境连 OpenAI / Gemini 等海外服务商通常需要设置本节变量。已知边界（有意取舍，勿当 bug 报）：

- 代理串接受 `http://user:pass@host:port` / `http://host:port` / `host:port`（Basic 凭据会透传）。**解析不出目标**（如含空格/非法字符）的值按直连处理；**能解析但指向不可达或非代理地址**的值会得到连接错误——与 curl 行为一致，不做连通性预检。
- `localhost` / `127.x` / `::1` 目标**恒直连**——本机端点（自定义 OpenAI 兼容 endpoint、LM Studio、ComfyUI 桥）不会被代理劫持，无需手工加 `NO_PROXY`。
- **不支持**：SOCKS 代理（`socks5://` 值按直连处理）、`NO_PROXY` 的端口段（`host:8080`）与 CIDR（`10.0.0.0/8`）写法——这类条目按普通 host 字面匹配，通常不命中。
- 若代理做 TLS 拦截（企业中间人证书），dio 会报证书错误——这是预期防护而非 InkFrame 缺陷；请将拦截根证书加入系统信任或对相应域名走 `NO_PROXY`。
- 设置页代理区（免环境变量的 UI 配置）为后续切片（LB-24 P1）。

All Dart-layer outbound requests honor `HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY` / `NO_PROXY` (case-insensitive; empty value = explicit disable; loopback targets always bypass; Basic credentials pass through). Values whose target cannot be parsed fall back to direct connection; parseable-but-wrong values fail with connection errors, same as curl. SOCKS, `NO_PROXY` port/CIDR entries are unsupported. Restart the app after changing variables. A settings-page proxy UI is planned as LB-24 P1.

---

See also: [docs/ARCHITECTURE.md](ARCHITECTURE.md) (env vars, key storage, data dirs),
[docs/DATABASE.md](DATABASE.md), [docs/BUILD-RELEASE.md](BUILD-RELEASE.md).

另见：[docs/ARCHITECTURE.md](ARCHITECTURE.md)（环境变量、密钥后端、数据目录）、
[docs/DATABASE.md](DATABASE.md)、[docs/BUILD-RELEASE.md](BUILD-RELEASE.md)。
