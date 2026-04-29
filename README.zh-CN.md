# InkFrame

**[English](./README.md)** | **中文**

> 本地优先的 AI 影视创作工作站 —— Flutter Desktop，节点化画布串联多家 AI 图/视频 Provider，所有数据与密钥留在本机

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.41-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A5%203.11-blue.svg)](https://dart.dev)
[![Status](https://img.shields.io/badge/status-alpha-orange.svg)]()

**快速入口**：[路线图](ROADMAP.md) · [贡献指南](CONTRIBUTING.md) · [架构](docs/ARCHITECTURE.md) · [Provider API](docs/PROVIDER-API.md) · [安全策略](SECURITY.md) · [讨论区](https://github.com/KerroKapple/InkFrame/discussions)

InkFrame 给独立创作者和小团队做 **桌面级** AI 分镜工作台：

- **节点化画布**：把 *文本 / 图片 / 视频* 拖成可追溯的生成流水线，每个节点都记录输入、Provider、参数、产物与状态
- **多 Provider 直连**：阿里 wanx、快手 Kling、Google Gemini 等无中间服务器，请求直发 Provider
- **一切本地**：嵌入 PostgreSQL 17 存数据，API Key 进系统 Keychain / Credential Manager，产物落到本地磁盘
- **macOS + Windows 双端**，同一份 Dart 代码

> **当前状态**：Alpha，v0.1.0-alpha.8 已发布。视频生成闭环已可用；UI 仍在按 CineFlow 设计语言重构中。

---

## 目录

- [功能特性](#功能特性)
- [支持的 AI Provider](#支持的-ai-provider)
- [快速开始](#快速开始)
- [核心配置](#核心配置)
- [数据存储位置](#数据存储位置)
- [架构概览](#架构概览)
- [项目结构](#项目结构)
- [开发规范](#开发规范)
- [故障排查](#故障排查)
- [隐私与安全](#隐私与安全)
- [贡献](#贡献)
- [Roadmap](#roadmap)
- [License](#license)

---

## 功能特性

| 模块 | 状态 | 说明 |
|------|:----:|------|
| 节点画布（拖拽 / 连线 / 缩放）| ✅ | 文本、图片、视频三类节点，多种连边 |
| 多 Provider 适配（图 + 视频）| ✅ | 7 款真 Provider + 1 款 Fake，统一接口 |
| 任务队列（双层并发 + 限流）| ✅ | 全局 1–4 并发档位 + per-provider QPS Token Bucket |
| 嵌入 PostgreSQL 17 | ✅ | 应用启动自带，零外部 DB 依赖 |
| 系统级 SecureStorage | ✅ | macOS Keychain / Windows Credential Manager / Debug 文件后端 |
| 主题（dark / light / highContrast）| ✅ | 设计 Token 三套语义色，零硬编码色值 |
| i18n（zh-CN + en-US 100%）| ✅ | ARB 键集合 CI 强制对齐，包含 system prompt |
| 性能降级控制器（4 档位）| ✅ | 内存 / 帧率 / 磁盘三信号驱动，双阈值防抖动 |
| 视频生成闭环（5 款 Provider）| ✅ | wanx-t2v / wanx-i2v / wanx-r2v / kling-v3 / kling-v3-omni |
| Lightbox 预览 + 视频播放 | ✅ | media_kit 后端 |
| 内联节点操作面板（NodeInlinePanel）| 🚧 | Sprint 3 |
| 渐变曲线连边（StyledEdge）| 🚧 | Sprint 4 |
| 框选 / Group / 多人协作 | ⏳ | 远期 |
| Undo / Redo | ⏳ | 远期 |

---

## 支持的 AI Provider

所有 Provider 通过统一接口接入，新增一个 = 新建一个文件，零改动现有代码（OCP 落地）。

| ID | 供应商 | 类型 | 用途 | Key 申请入口 |
|----|--------|------|------|--------------|
| `wanx-image` | 阿里通义万相 | 图像 | 文生图 | DashScope 控制台 |
| `wanx-t2v` | 阿里通义万相 | 视频 | 文生视频 | DashScope 控制台 |
| `wanx-i2v` | 阿里通义万相 | 视频 | 图生视频 | DashScope 控制台 |
| `wanx-r2v` | 阿里通义万相 | 视频 | 参考图生视频 | DashScope 控制台 |
| `kling-v3` | 快手可灵 | 视频 | 文/图 生视频 | 快手开放平台 |
| `kling-v3-omni` | 快手可灵 | 视频 | 多模态视频生成 | 快手开放平台 |
| `gemini-image` | Google Gemini | 图像 | 多模态图像生成 | Google AI Studio |
| `fake` | 内置 | 图/视频 | 开发/测试，返回公开样例媒体 | 不需要 |

每个 Provider 实现遵循 `lib/core/interfaces/` 下的能力维度接口（`Submittable / Pollable / Cancellable / KeyValidatable / QuotaAware`），按需混合，不强加全量契约（ISP 落地）。

详细接入契约见 [docs/PROVIDER-API.md](docs/PROVIDER-API.md)。

---

## 快速开始

### 环境要求

- **OS**：macOS 12+ 或 Windows 10/11
- **Flutter**：≥ 3.41（stable channel）
- **Dart**：≥ 3.11
- **macOS 开发**：Xcode 16+（完整版，非仅 Command Line Tools）+ CocoaPods（`brew install cocoapods`）
- **PostgreSQL 17**：本机一份 `bin/`（含 `postgres / pg_ctl / initdb`），用 Homebrew / scoop 装即可，或自编译；通过 `INKFRAME_PG_BIN` 指向

### 克隆 + 初始化

```bash
git clone https://github.com/KerroKapple/InkFrame.git
cd InkFrame

# 拉依赖
flutter pub get

# 链接 git hooks（pre-commit analyze + pre-push 全量 test）
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../scripts/hooks/pre-push   .git/hooks/pre-push
```

### 第一次跑（不烧 API 配额）

```bash
# macOS
INKFRAME_PG_BIN=/opt/homebrew/opt/postgresql@17/bin \
INKFRAME_FAKE_PROVIDERS=1 \
flutter run -d macos --debug
```

`INKFRAME_FAKE_PROVIDERS=1` 把所有真 Provider 替换为本地 `FakeGenerationProvider`，返回公开样例图/视频，**第一次跑 UI 强烈推荐开启**——避免 key 未配置直接炸。

### 配置真 API Key

去掉 `INKFRAME_FAKE_PROVIDERS`，再次启动后进 **Settings → Providers**，按需填入：

- DashScope API Key（覆盖 `wanx-*` 全部 4 款）
- Kling Access Key + Secret Key（覆盖 `kling-v3` / `kling-v3-omni`）
- Gemini API Key（覆盖 `gemini-image`）

Key 写入位置：

| 构建类型 | 后端 |
|---------|------|
| Release | macOS Keychain / Windows Credential Manager |
| Debug（macOS）| `~/InkFrame/config/secrets.dev.json`（绕开 ad-hoc 签名对 Keychain 的限制）|

API Key 验证结果在内存缓存 1 小时，节省配额；用户可随时点 *重新验证*。

### 跑测试

```bash
flutter analyze              # 0 warning 为准（CI 强制 --fatal-infos）
flutter test --coverage      # 全量单元 + widget test，约 380+ tests
lcov --summary coverage/lcov.info

# 仅集成测试（需要 PG 进程）
flutter test --tags integration

# 排除集成测试
flutter test --exclude-tags integration
```

---

## 核心配置

### 环境变量

| 变量 | 默认 | 用途 |
|------|------|------|
| `INKFRAME_PG_BIN` | *未设*（用打包内置） | 指向本地 PG 17 `bin/`；Release 包优先用 app 内置 |
| `INKFRAME_FAKE_PROVIDERS` | `0` | `=1` 启用 fake Provider，全部不调外部 API |
| `INKFRAME_DATA_DIR` | `~/InkFrame` | 用户数据根目录（数据库、产物、配置）|
| `INKFRAME_LOG_LEVEL` | `INFO` | `DEBUG` / `INFO` / `WARN` / `ERROR` |

### 应用内设置项

- **性能档位**：省电（1）/ 均衡（2）/ 性能（3）/ 极致（4）—— 控制全局并发上限
- **主题**：跟随系统 / 深色 / 浅色 / 高对比度
- **字号**：S / M / L / XL（A11y）
- **数据目录**：可改（默认 `~/InkFrame`）
- **代理**：HTTP / SOCKS5，密码进 SecureStorage

---

## 数据存储位置

```
~/InkFrame/                              # 默认数据目录（INKFRAME_DATA_DIR 可改）
├── config/
│   ├── settings.json                    # 应用设置（无敏感字段）
│   └── secrets.dev.json                 # 仅 Debug：本地 key 文件后端
├── database/                            # 嵌入 PG data dir（initdb 生成）
│   └── PG_VERSION  base/  pg_wal/  ...
├── projects/
│   └── {projectId}/
│       └── canvases/
│           └── {canvasId}/
│               ├── images/              # 图片产物（按 nodeId 命名）
│               ├── videos/              # 视频产物
│               └── thumbnails/          # 缩略图
└── logs/
    ├── inkframe.log                     # 单文件 ≤ 10 MB，总量 ≤ 200 MB
    └── inkframe.crash.{ts}.log          # 崩溃日志，独立保留最近 3 份
```

数据库中**只存相对路径**（如 `images/node-abc.png`），运行时由 `FileResolverService` 拼接绝对路径，避免数据目录搬迁后链接失效。

---

## 架构概览

### 五层依赖

```
┌─────────────────────────────────────────────────────────────┐
│  Widget Layer        lib/features/*/widgets/, theme/        │
│                      只渲染状态、分发事件，零业务逻辑        │
├─────────────────────────────────────────────────────────────┤
│  ViewModel Layer     lib/features/*/providers/              │
│                      Riverpod Notifier，编排 Service         │
├─────────────────────────────────────────────────────────────┤
│  Service Layer       lib/services/, lib/features/*/services/│
│                      纯 Dart，零 Flutter import              │
├─────────────────────────────────────────────────────────────┤
│  Repository Layer    lib/storage/repositories/              │
│                      抽象接口在 core/interfaces/             │
├─────────────────────────────────────────────────────────────┤
│  Infrastructure      lib/storage/, lib/providers/, platform/│
│                      PostgreSQL / dio / Keychain / ffmpeg   │
└─────────────────────────────────────────────────────────────┘

依赖只能向下流动 —— 任何一层不得 import 上层符号
```

### 任务调度

```
全局并发上限（性能档位）
  省电=1 / 均衡=2 / 性能=3 / 极致=4
      ↕ min()
Per-Provider 并发上限（ProviderCapabilities.maxConcurrentJobs）
      ↕
Per-Provider Token Bucket（QPS / Burst）

调度状态机：
  pending ──► submitted ──► polling ──► success / error / timeout
     │                                       │
     └── cancelled_by_user                   │
                                             │
  任何阶段 ──────────────────────► cancelled_on_exit（app 退出）
```

详细架构（DI 矩阵 / 错误体系 14 错误码 / 性能降级双阈值 / A11y / 测试分层 / 构建流水线）见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

---

## 项目结构

```
lib/
├── main.dart                       # 入口 + ProviderScope
├── app.dart                        # MaterialApp、路由、主题切换
├── l10n/                           # ARB i18n（zh + en，100% 对齐）
├── theme/                          # 设计 Token + 组件库
│   ├── tokens.dart                 # InkColors / InkSpacing / InkRadius / InkShadow
│   ├── typography.dart
│   ├── primitives/                 # InkGlassCard / GradientButton / CompactTextField …
│   └── components/                 # InkButton / InkCard / InkInput …
├── core/                           # 共享抽象
│   ├── di/                         # Riverpod Provider 装配（唯一接线处）
│   ├── interfaces/                 # 抽象接口（无具体实现）
│   ├── errors/                     # InkError sealed hierarchy
│   ├── constants/                  # 枚举、常量（无副作用）
│   ├── logging/                    # InkLogger 接口
│   ├── models/                     # Freezed 不可变 domain 模型
│   └── paths/                      # FileResolverService 接口
├── features/                       # 垂直切分的功能模块
│   ├── workspace/                  # 工作台首页
│   ├── canvas/                     # 节点画布 + 生成流水
│   ├── settings/                   # 设置（含 API Key 配置）
│   ├── generation/                 # 生成调度
│   ├── lightbox/                   # 媒体预览
│   └── debug/                      # Debug-only（Primitives Showcase）
├── providers/                      # AI Provider 实现（Infrastructure）
│   ├── provider_registry.dart      # id → factory
│   ├── rate_limiter.dart           # Token Bucket
│   ├── dashscope_async_provider_base.dart
│   ├── wanx_image_provider.dart
│   ├── wanx_t2v_provider.dart
│   ├── wanx_i2v_provider.dart
│   ├── wanx_r2v_provider.dart
│   ├── kling_v3_provider.dart
│   ├── kling_v3_omni_provider.dart
│   ├── gemini_image_provider.dart
│   └── fake_generation_provider.dart
├── storage/                        # 嵌入 PG + repository 实现
│   ├── pg_controller.dart          # PG 进程生命周期（127.0.0.1 + auth=trust）
│   ├── pg_binary_locator.dart
│   ├── migrations/                 # 增量 schema migration
│   └── repositories/
└── services/                       # 应用级 Service
    ├── job_queue_service.dart
    ├── file_resolver_service.dart
    ├── secure_storage_service.dart
    └── …
```

---

## 开发规范

提交前请逐条确认（pre-commit hook 也会强制检查）：

### 硬规则（违反 = CI 拒收）

- **SOLID / DI**：所有外部依赖通过 Riverpod Provider 注入，禁止 `new ConcreteClass()` 出现在 Widget / Service 层；接口在 `core/interfaces/`，实现在 `storage/` 或 `providers/`，接线在 `core/di/`
- **零硬编码字符串**：所有 UI 文案、错误消息、AI system prompt 走 `context.l10n.xxx`；`app_en.arb` + `app_zh.arb` 必须同 commit 更新且 key 集合完全一致
- **零硬编码样式**：禁止 `Color(0xFF...)`、`fontSize: N`、`EdgeInsets.all(N)` 出现在 feature 代码；只用 `InkColors / InkSpacing / InkRadius` 等 token 与 Ink 组件
- **零向后兼容**：schema 变了就改，不写 migration helper，不留 deprecated API
- **错误用 InkError**：所有跨层错误必须是 `InkError` 子类，禁止裸 `Exception` / `String` 跨层传递
- **Disposable 必须清理**：`StreamSubscription / Timer / AnimationController` 必须 `ref.onDispose` 或 widget `dispose()`
- **TDD**：先写测试看红 → 实现看绿 → 重构。Repository 层覆盖率 ≥ 75%，其余 ≥ 70%

### 工具门禁

| Hook | 检测内容 |
|------|---------|
| `check-magic-strings.sh` | 硬编码 UI 字符串 / 魔法数字 / 状态字符串比较 |
| `check-inline-styles.sh` | `Color(0xFF...)` / 硬编码 EdgeInsets / BoxShadow |
| `check-direct-instantiation.sh` | Widget/Service 内 `new ConcreteClass()` |
| `check-disposable-cleanup.sh` | StreamSubscription / Timer / Controller 未 dispose |
| `check-i18n-coverage.sh` | ARB key 不一致 / 空值 / TODO 翻译 |
| `check-updated-at.sh` | UPDATE 语句缺少 `updated_at` |
| `check-keybindings.sh` | 默认快捷键命中 OS 保留键 |

完整规范见 [docs/CLAUDE.md](docs/CLAUDE.md) 与 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

### Commit 规范

Conventional Commits：

```
feat(canvas): 添加节点拖拽吸附
fix(provider/kling): poll 超时改用指数退避
refactor(storage): 抽出 BaseRepository.withUpdatedAt
test(generation): 覆盖 cancel pending 路径
docs(adr): 新增 0007-rate-limiting-strategy
chore: bump dart_test deps
```

不允许 `--no-verify` 跳 hook。pre-push 跑全量测试，慢但是底线。

---

## 故障排查

### `flutter run` 启动后立刻退出 / PG 报 "binaries not found"

`INKFRAME_PG_BIN` 没设或路径不对。验证：

```bash
ls "$INKFRAME_PG_BIN/postgres"  # 必须存在
"$INKFRAME_PG_BIN/postgres" --version  # 必须输出 17.x
```

macOS 用 Homebrew 装的话路径通常是 `/opt/homebrew/opt/postgresql@17/bin`（Apple Silicon）或 `/usr/local/opt/postgresql@17/bin`（Intel）。

### macOS Debug 启动时 Keychain 访问被拒

ad-hoc 签名的 debug 包不能写系统 Keychain。InkFrame 在 Debug 自动 fallback 到 `~/InkFrame/config/secrets.dev.json` 文件后端（仍然不入仓）。看日志确认 `secure_storage` 模块用的是 `FileSecureStorageService`。

### "Another postgres instance (pid=...) is already running"

之前的 InkFrame 进程没干净退出，留下了 `postmaster.pid`。InkFrame 启动时会自检 PID 是否还活着，活着就拒启。手动清理：

```bash
ps -p <pid>           # 确认那个 PID 是不是你想杀的
kill <pid>            # 或直接删 ~/InkFrame/database/postmaster.pid（仅在确认进程死了之后）
```

### `flutter test` pre-push 卡住

某个 widget test 可能在等异步任务。先单跑那个文件：

```bash
flutter test test/features/canvas/foo_test.dart -r expanded
```

### Provider 报 `invalid_key` 但 key 是对的

- 确认 key 没有前后空格（粘贴时常见）
- DashScope key 格式 `sk-xxx`（32+ 位），Gemini key 是 `AIza...`
- Kling 需要 *两个* 字段：Access Key + Secret Key
- 进设置面板点 *重新验证*，强制刷新 1 小时缓存

更多排查见 [docs/internal/t5-manual-regression.md](docs/internal/t5-manual-regression.md)。

---

## 隐私与安全

- **所有数据本机存储**：项目、产物、缩略图、日志全部落 `~/InkFrame/`，不上传任何云端（除你主动调用的 AI Provider 端点）
- **API Key 永不入 repo**：`.gitignore` 已拦截 `secrets*.json` / `apikey*` / `*.env` / `*.pem` / `*.key` / `*.local` 等常见模式；FileSecureStorage 在 `~/InkFrame/config/`，不在仓库里
- **直连 Provider**：生成请求由 InkFrame 本进程直发 DashScope / Kling / Gemini 端点，无中间服务器、无任何第三方 telemetry
- **日志脱敏**：API Key 在日志里仅保留前 4 位（`sk-a1b2****`），prompt 截断 50 字符防版权泄露，路径中的 home 目录替换为 `~`，代理密码完全 `[REDACTED]`
- **Key 存储后端**：
  - macOS Release → Keychain（kSecClassGenericPassword）
  - Windows Release → Credential Manager
  - macOS Debug → 本地 JSON 文件，绕开 ad-hoc 签名限制（仍在 ignore 范围内）

详见 [docs/CLAUDE.md](docs/CLAUDE.md) 中 "Provider API Keys" 与 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) §9 / §13.4。

---

## 贡献

欢迎 issue / PR。先读：

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/CLAUDE.md](docs/CLAUDE.md)（硬规则）
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)（DI / 错误体系 / 性能降级 / 测试分层）
- [docs/PROVIDER-API.md](docs/PROVIDER-API.md)（新增 Provider 必读）
- [docs/DATABASE.md](docs/DATABASE.md)（schema + migration 规则）
- [docs/TESTING.md](docs/TESTING.md)（TDD 节奏 + mock 边界）

提交前 checklist：

- [ ] `flutter analyze` 0 warning
- [ ] `flutter test` 全绿
- [ ] pre-commit 7 项硬检查通过
- [ ] `app_en.arb` 和 `app_zh.arb` 同步更新
- [ ] commit 走 conventional commits

---

## Roadmap

- [x] **T0–T5**：节点画布 + 多 Provider 骨架 + 视频生成闭环（v0.1.0-alpha.8）
- [x] **Sprint 1**：CineFlow 设计 token 对齐（Apple Blue accent + 5 级 surface）
- [x] **Sprint 2**：Design primitives（GlassCard / GradientButton / CompactTextField 等 9 个原子）
- [ ] **Sprint 3**：NodeInlinePanel v2（节点下方内联操作面板替代侧栏 Inspector）
- [ ] **Sprint 4**：StyledEdge（bezier 渐变曲线）
- [ ] **Sprint 5**：画布交互（marquee 框选 / handle drag / 伙伴边）
- [ ] **Beta**：A11y 完整覆盖（VoiceOver / Narrator 验收）+ Undo/Redo + Group + 导出系统
- [ ] **远期**：多人协作 / 插件化 Provider / 自定义节点

---

## License

[MIT](./LICENSE) © 2026 InkFrame contributors

---

## Acknowledgements

- 设计语言借鉴 **CineFlow**（节点化画布 + 毛玻璃视觉）
- 嵌入式 PostgreSQL 思路参考开源社区方案
- AI Provider SDK：阿里云 DashScope、Google Gemini、快手 Kling
- Flutter Desktop 生态：Riverpod、freezed、dio、media_kit、ffmpeg_kit_flutter、flutter_secure_storage
