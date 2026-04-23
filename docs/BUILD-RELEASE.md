# InkFrame 构建与发布手册 v0.1.0

> **受众**：负责打包、签名、发版的工程师
> **权威性**：`ARCHITECTURE.md §14` 的工程化展开。冲突以本文为准（更具体）
> **范围**：开发构建 → Release 构建 → 签名/公证 → 打包分发 → 自动更新 → 回滚

---

## 目录

1. [开发环境准备](#1-开发环境准备)
2. [版本号规范](#2-版本号规范)
3. [PG 二进制分发](#3-pg-二进制分发)
4. [构建流水线（完整顺序）](#4-构建流水线完整顺序)
5. [macOS 签名与公证](#5-macos-签名与公证)
6. [macOS 打包（DMG）](#6-macos-打包dmg)
7. [Windows 签名](#7-windows-签名)
8. [Windows 打包（MSIX / MSI）](#8-windows-打包msix--msi)
9. [Release Checklist](#9-release-checklist)
10. [自动更新协议](#10-自动更新协议)
11. [GitHub Releases 发布](#11-github-releases-发布)
12. [回滚协议](#12-回滚协议)
13. [CI 发布流水线](#13-ci-发布流水线)
14. [机密管理](#14-机密管理)

---

## 1. 开发环境准备

### 1.1 版本锁定

| 工具 | 版本 | 锁定位置 |
|---|---|---|
| Flutter | stable channel（见 `.fvmrc` 或 `flutter --version`） | `.fvmrc` / `pubspec.yaml` 的 `environment.flutter` |
| Dart | 随 Flutter | — |
| PostgreSQL | **17.2** | `scripts/pg/pg-version.txt` |
| Xcode | ≥ 15.0 | macOS 宿主 |
| Visual Studio Build Tools | 2022（含 "Desktop C++"） | Windows 宿主 |
| Inno Setup / WiX | 见 §8 | Windows 打包 |

### 1.2 一次性设置

```bash
# macOS
scripts/dev/setup-macos.sh    # 安装 cocoapods、xcodeproj、notarytool 凭据

# Windows (PowerShell)
scripts\dev\setup-windows.ps1 # 安装 signtool 路径、EV dongle 驱动
```

### 1.3 构建前自检

```bash
flutter doctor -v             # 全绿
dart --version                # 与 .fvmrc 一致
ls resources/pg/{platform}/   # PG 二进制已拉取
```

### 1.4 视频依赖（T5 起）

T5 Sprint 引入 `media_kit` + `media_kit_libs_video` —— 视频生成结果的缩略抽帧 + 灯箱播放依赖 libmpv。

- **macOS**：`media_kit_libs_macos_video` 自带 libmpv.dylib，Flutter build 自动嵌入 `Contents/Frameworks/`。`codesign --deep --force` 已覆盖新增 dylib，无需额外命令。
- **Windows**：`media_kit_libs_windows_video` 自带 libmpv 相关 DLL，CMake 自动收敛到 `build/windows/x64/runner/Release/`。MSIX / MSI 打包时自动包含。
- **体积影响**：安装包 +~40 MB（libmpv x64）。alpha 阶段可接受；GA 前如需瘦身，考虑按需加载或切更轻量 player。
- **CI 约束**：headless Ubuntu runner 无 GPU / 原生播放栈，`media_kit` 依赖文件（`lib/features/canvas/widgets/video_lightbox.dart` / `lib/services/media_kit_*_service.dart` 等）被 coverage 阈值排除，改由手动回归清单覆盖，见 `docs/internal/t5-manual-regression.md`。

---

## 2. 版本号规范

### 2.1 SemVer

`vMAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`

- `v0.1.0-alpha.3` — 内测
- `v0.1.0-beta.1` — 公开测试
- `v0.1.0` — 正式版
- `v0.1.1` — 补丁
- `v0.2.0` — 新 sprint feature 叠加

### 2.2 pubspec.yaml

```yaml
# pubspec.yaml
version: 0.1.0+1000    # 语义版本+build number
```

- `0.1.0` 是用户可见版本；`1000` 是 build number（iOS/macOS CFBundleVersion、Android versionCode 语义）
- **硬约束**：build number **单调递增**，绝不回退——Apple Notarization 拒绝相同 build number 覆盖

### 2.3 构建命令覆盖

```bash
flutter build macos --release \
  --build-name=0.1.0-beta.1 \
  --build-number=1023
```

CI 由 git tag 推导：`v0.1.0-beta.1` → build-name = `0.1.0-beta.1`，build-number 用 GitHub run number。

---

## 3. PG 二进制分发

### 3.1 目录结构

```
resources/pg/
├── macos/
│   ├── bin/              # initdb, pg_ctl, postgres
│   ├── lib/              # 共享库
│   ├── share/            # 模板
│   └── PG_VERSION        # 17
├── windows/
│   ├── bin/              # initdb.exe, pg_ctl.exe, postgres.exe
│   ├── lib/
│   └── share/
└── README.md             # 用户可见的版权声明（PostgreSQL License）
```

**大小预算**：每平台 ~60 MB，打包压缩后（DMG/MSIX）约 20 MB。

### 3.2 拉取脚本

`scripts/pg/fetch-binaries.sh`：

- 从可信镜像源下载（官方 / EDB / 自建 mirror 三选）
- SHA256 校验（`scripts/pg/checksums.txt`）
- 幂等：已存在且 SHA256 匹配则跳过
- 失败时明确报错，不静默降级

```bash
# 本地首次 / 清理后执行
bash scripts/pg/fetch-binaries.sh

# CI 每次构建前执行（有缓存）
- uses: actions/cache@v4
  with:
    path: resources/pg/
    key: pg-17.2-${{ runner.os }}
- run: bash scripts/pg/fetch-binaries.sh
```

### 3.3 运行时定位

`PgBinaryLocator` 的查找顺序（高到低）：

1. `INKFRAME_PG_BIN` 环境变量（开发/测试覆盖）
2. App Bundle `Contents/Resources/pg/` (macOS) / `resources\pg\` (Windows)
3. Repo 相对路径 `resources/pg/{platform}/`（`flutter run` 场景）
4. 全未命中 → `PgBinaryNotFoundError`

见 `test/storage/pg_binary_locator_test.dart`。

---

## 4. 构建流水线（完整顺序）

**顺序硬约束**——跳步会导致 build 产物不一致。

```bash
# Step 1: 拉 PG 二进制（幂等）
bash scripts/pg/fetch-binaries.sh

# Step 2: 依赖
flutter pub get

# Step 3: 代码生成（freezed / riverpod / json_serializable）
dart run build_runner build --delete-conflicting-outputs

# Step 4: i18n 生成
flutter gen-l10n

# Step 5: 静态分析门槛（0 warning）
flutter analyze --fatal-infos

# Step 6: 测试门槛（全绿 + 覆盖率）
flutter test --coverage

# Step 7: 平台构建
flutter build macos --release --build-name=$VERSION --build-number=$BUILD
# 或
flutter build windows --release --build-name=$VERSION --build-number=$BUILD

# Step 8: 签名 / 公证 / 打包（见后续章节）
```

**产物路径**：

| 平台 | 构建产物 | 分发产物 |
|---|---|---|
| macOS | `build/macos/Build/Products/Release/InkFrame.app` | `dist/InkFrame-{version}-macos.dmg` |
| Windows | `build/windows/x64/runner/Release/inkframe.exe` + `*.dll` | `dist/InkFrame-{version}-windows.msix` |

---

## 5. macOS 签名与公证

### 5.1 前置凭据

- **Developer ID Application** 证书 —— Apple Developer 控制台
- **Developer ID Installer** 证书（若分发 `.pkg`）
- **App-specific Password** —— [appleid.apple.com](https://appleid.apple.com) 生成，用于 notarytool
- **Team ID** —— 10 位，Apple Developer 账号

### 5.2 Keychain Profile（notarytool 无密码化）

```bash
# 一次性设置
xcrun notarytool store-credentials "inkframe-notary" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_SPECIFIC_PASSWORD"
```

### 5.3 Entitlements

`macos/Runner/Release.entitlements`（最小集）：

```xml
<dict>
  <key>com.apple.security.app-sandbox</key><false/>
  <key>com.apple.security.network.client</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
  <key>com.apple.security.files.downloads.read-write</key><true/>
  <!-- 禁 app-sandbox 因为我们要 fork postgres 进程；用 hardened runtime 提供安全 -->
</dict>
```

### 5.4 签名

```bash
# 深度签名（嵌入的 PG 二进制、dylib 必须一起签）
codesign --deep --force --options runtime \
  --entitlements macos/Runner/Release.entitlements \
  --sign "Developer ID Application: Kerro Kapple ($TEAM_ID)" \
  --timestamp \
  build/macos/Build/Products/Release/InkFrame.app

# 验证
codesign --verify --deep --strict --verbose=2 \
  build/macos/Build/Products/Release/InkFrame.app
spctl --assess --type exec --verbose \
  build/macos/Build/Products/Release/InkFrame.app
```

### 5.5 公证

```bash
# 提交
xcrun notarytool submit dist/InkFrame-$VERSION-macos.dmg \
  --keychain-profile "inkframe-notary" \
  --wait

# 装订（staple） — 让 DMG 离线也能通过 Gatekeeper
xcrun stapler staple dist/InkFrame-$VERSION-macos.dmg

# 验证
xcrun stapler validate dist/InkFrame-$VERSION-macos.dmg
```

### 5.6 常见公证失败与处置

| 错误 | 根因 | 处置 |
|---|---|---|
| `The binary is not signed with a valid Developer ID certificate` | 用了 Development 证书 | 换成 Developer ID Application |
| `The signature does not include a secure timestamp` | 忘加 `--timestamp` | 加上重签 |
| `Hardened Runtime is not enabled` | 缺 `--options runtime` | 加上重签 |
| `Unsealed contents present in the root directory of an embedded framework` | PG 二进制没一起签 | 用 `--deep` |
| 卡在 `In Progress` > 30min | Apple 侧队列 | 等，不要重复提交 |

---

## 6. macOS 打包（DMG）

```bash
# 使用 create-dmg（brew install create-dmg）
create-dmg \
  --volname "InkFrame $VERSION" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "InkFrame.app" 200 190 \
  --app-drop-link 600 185 \
  --background "assets/dmg-background.png" \
  "dist/InkFrame-$VERSION-macos.dmg" \
  "build/macos/Build/Products/Release/"
```

**验收**：挂载 DMG → 拖入 Applications → 首次打开无 Gatekeeper 警告。

---

## 7. Windows 签名

### 7.1 证书要求

- **EV Code Signing Certificate**（不是普通 OV）—— SmartScreen 信誉立刻生效，免"未知发布者"警告
- 证书在 USB Dongle（SafeNet / YubiHSM）——CI 需要连接 Dongle 的自托管 runner 或云签服务

### 7.2 签名命令

```powershell
signtool sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a `
  build\windows\x64\runner\Release\inkframe.exe

# 所有 DLL 也要签（PG 二进制目录）
Get-ChildItem -Recurse -Filter *.dll build\windows\x64\runner\Release\ | ForEach-Object {
  signtool sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 /a $_.FullName
}

# 验证
signtool verify /pa /v build\windows\x64\runner\Release\inkframe.exe
```

---

## 8. Windows 打包（MSIX / MSI）

**推荐 MSIX**（Windows 10 1809+，含 Store 兼容性 + 自动回滚）。

```powershell
# 使用 flutter_distributor（推荐）
dart pub global activate flutter_distributor
flutter_distributor release --name=prod --jobs=release-windows
```

`distribute_options.yaml`：

```yaml
releases:
  - name: prod
    jobs:
      - name: release-windows
        package:
          platform: windows
          target: msix
          build_args:
            build-name: $VERSION
            build-number: $BUILD
```

**MSI 备选**：用 WiX Toolset，模板见 `windows/installer/inkframe.wxs`。

---

## 9. Release Checklist

> 一张 checklist 走完 = 可以发版。任一条跳过 = 阻断。

**代码冻结前：**

- [ ] 所有 PR 合入 `main` 且 CI 全绿
- [ ] `flutter analyze --fatal-infos` 0 warning
- [ ] `flutter test --coverage` 全绿，门槛达标（数据层 75% / 其余 70%）
- [ ] Golden 无未解释 diff
- [ ] `docs/internal/tech-debt.md` 已 review，P0 债务已清
- [ ] CHANGELOG.md 已更新

**构建：**

- [ ] `pubspec.yaml` version 已 bump
- [ ] git tag `v$VERSION` 已打
- [ ] macOS 构建产物通过 `codesign --verify` + `stapler validate`
- [ ] Windows 构建产物通过 `signtool verify`
- [ ] DMG / MSIX 在干净虚拟机（无开发证书）上首次启动可用
- [ ] 嵌入 PG 在首次启动完成 `initdb + pg_ctl start + schema_version=1` ≤ 8s
- [ ] 烟测：创建项目 → 创建画布 → 添加节点 → 退出 → 重启 → 数据仍在

**发布：**

- [ ] GitHub Release 草稿已填，内容与 CHANGELOG 一致
- [ ] 工件已上传（DMG + MSIX）
- [ ] Release notes 的 breaking changes 已标红
- [ ] 发布渠道（alpha/beta/stable）正确标记
- [ ] update manifest（`updates.json`）已更新
- [ ] 回滚通道可用（见 §12）

---

## 10. 自动更新协议

### 10.1 检查流程

```
App 启动 + 每 6h 一次
  → GET https://inkframe.app/updates.json?channel=stable&platform=macos
  ← { "latest": "0.1.1", "url": "https://...dmg", "notes": "..." }
  → 比对本地版本
  → 若有新版：后台通知栏 / 关于页红点
  → 用户手动触发"下载并安装"
```

**硬约束**：

- **不**强制自动安装——用户必须显式点"安装"
- 检查不阻塞启动；失败静默（写 INFO 日志）
- 用户可在设置关闭自动检查

### 10.2 Update Manifest 格式

```json
{
  "channel": "stable",
  "platform": "macos",
  "latest": "0.1.1",
  "minimum_supported": "0.1.0",
  "url": "https://github.com/.../InkFrame-0.1.1-macos.dmg",
  "sha256": "...",
  "size_bytes": 85234123,
  "release_notes_url": "https://github.com/.../releases/tag/v0.1.1",
  "release_date": "2026-05-10T00:00:00Z"
}
```

### 10.3 SHA256 校验

下载后**必须**验证 SHA256 与 manifest 一致——防劫持 / 防损坏。不匹配则删文件 + 报错。

### 10.4 增量更新

P0/P1 **不做**增量（bsdiff / zstd patch）；全量下载，简单可靠。P2 评估。

---

## 11. GitHub Releases 发布

### 11.1 命名规范

```
v0.1.0              → stable
v0.1.0-beta.3       → beta (prerelease=true)
v0.1.0-alpha.1      → alpha (prerelease=true)
```

### 11.2 发布命令

```bash
gh release create v0.1.0 \
  --title "InkFrame 0.1.0" \
  --notes-file CHANGELOG-v0.1.0.md \
  dist/InkFrame-0.1.0-macos.dmg \
  dist/InkFrame-0.1.0-windows.msix \
  dist/InkFrame-0.1.0-sbom.spdx.json
```

**附带产物**（强制）：

- 两个平台的安装包
- `sbom.spdx.json` —— Software Bill of Materials（供应链合规）
- `checksums.txt` —— 所有产物的 SHA256

### 11.3 Release Notes 结构

```markdown
# InkFrame 0.1.0

## Highlights
- 首个 P0-Alpha 版本……

## New Features
- ...

## Fixes
- ...

## Breaking Changes
- ⚠️ ...（无则写 "None"）

## Known Issues
- ...

## Upgrade Notes
- ...（无则写 "No action required"）

## Checksums
- InkFrame-0.1.0-macos.dmg: sha256:xxxxxx
- InkFrame-0.1.0-windows.msix: sha256:xxxxxx
```

---

## 12. 回滚协议

### 12.1 触发条件

- 发版后 24h 内收到 3+ 用户同一 P0 bug 报告
- 核心功能（生成 / 保存 / 启动）不可用
- 数据损坏风险

### 12.2 步骤

1. **下架新版**：修改 `updates.json`，将 `latest` 改回上一个稳定版；GitHub Release 标 `Pre-release` 或删除（不强制删，保留可供研究）
2. **通告用户**：
   - GitHub Issue Pinned 公告
   - 官网 banner
   - 下一版本 Release Notes 中列出事故分析（`docs/internal/postmortem/v0.1.X.md`）
3. **热修**：走 `main` 新分支 `hotfix/v0.1.X` → PR → 合流 → 发 `v0.1.X+1`
4. **数据损坏场景**：若 schema migration 已执行且不可回滚，**禁止**回退 app 版本——走 `forward fix only`，出新版本修数据

### 12.3 硬约束

- **不修改**已发布的 GitHub Release 工件（SHA256 不能变——用户校验会失败）
- **不删除** tag——保留历史
- Schema 降级必须通过**下一个版本的 migration 脚本**实现，不是回退 app

---

## 13. CI 发布流水线

`.github/workflows/release.yml`（触发：push tag `v*`）：

```yaml
on:
  push:
    tags: ['v*']

jobs:
  build-macos:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: bash scripts/pg/fetch-binaries.sh
      - run: flutter pub get && flutter gen-l10n && dart run build_runner build
      - run: flutter analyze --fatal-infos
      - run: flutter test
      - run: flutter build macos --release --build-name=${GITHUB_REF_NAME#v} --build-number=${GITHUB_RUN_NUMBER}
      - name: Sign + Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          TEAM_ID: ${{ secrets.TEAM_ID }}
        run: bash scripts/sign-and-notarize-macos.sh
      - uses: actions/upload-artifact@v4
        with: { name: macos-dmg, path: dist/*.dmg }

  build-windows:
    runs-on: self-hosted-ev-dongle   # EV 证书 Dongle 机
    # ... 同结构

  release:
    needs: [build-macos, build-windows]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
      - name: Create GitHub Release
        run: |
          gh release create ${GITHUB_REF_NAME} \
            --title "InkFrame ${GITHUB_REF_NAME#v}" \
            --notes-file CHANGELOG-${GITHUB_REF_NAME}.md \
            dist/*
      - name: Update manifest
        run: python scripts/release/update-manifest.py
```

---

## 14. 机密管理

### 14.1 机密清单

| 机密 | 存放 | 本地访问 | CI 访问 |
|---|---|---|---|
| Apple ID / App-specific Password | macOS Keychain（notary profile）| `xcrun notarytool --keychain-profile` | GitHub Secrets + `security import` |
| Team ID | 环境变量（非机密，但跟 Apple ID 绑） | `.envrc` | GitHub Secrets |
| Developer ID 证书 | Keychain（导出 .p12 存 Secrets）| Keychain | `security import` + cleanup |
| EV Code Signing | Dongle（物理） | Dongle PIN | 自托管 runner 挂载 Dongle |
| GitHub Token（gh CLI） | `gh auth login` | 本机 gh | `GITHUB_TOKEN` 内置 |
| Update 站点上传 Key | — | `rsync -e "ssh -i ..."` | GitHub Secrets |

### 14.2 规则

- **禁止**将任何机密提交到 git——`.gitignore` 已覆盖 `.envrc` / `.env` / `*.p12` / `*.mobileprovision`
- `scripts/` 内的构建脚本**只**从环境变量 / Keychain 读取，不从文件字面量
- CI 使用 GitHub Environment Protection——Production Environment 需要 reviewer approve
- 证书轮换：每年 Apple Developer 续费时同步更新 Keychain + CI Secrets

---

## 变更记录

| 日期 | 版本 | 内容 | 作者 |
|---|---|---|---|
| 2026-04-15 | v0.1.0 | 初版，基于 ARCHITECTURE §14 展开；覆盖 macOS/Windows 全流程 | P9 |
