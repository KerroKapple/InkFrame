# InkFrame

> 本地优先的 AI 影视创作工作站 —— Flutter Desktop，节点化画布串联图/视频生成，数据与密钥全部留在本机

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.41-blue.svg)](https://flutter.dev)
[![Status](https://img.shields.io/badge/status-alpha-orange.svg)]()

InkFrame 是一个给独立创作者、小团队用的 **桌面级** 分镜工作台：
- 节点化画布，把 **文本 / 图片 / 视频** 串成可追溯的生成流水线
- **直连多个 AI Provider**（阿里 wanx-t2v/i2v/image、快手 Kling v3/Omni、Gemini Image 等），无中间服务器
- 数据、产物、API Key 全部存本机（嵌入 PostgreSQL + macOS Keychain / Windows Credential Manager）
- macOS + Windows 双端

> **当前状态**：Alpha，v0.1.0-alpha.8 已发布。视频生成闭环可用；UI 仍在按 CineFlow 设计语言重构中。

---

## 功能概览

- 🎨 **节点化画布**：拖拽节点 + 连线构建生成流水线，支持图片/视频/文本节点
- 🤖 **多 Provider 接入**：`wanx-image`、`wanx-t2v`、`wanx-i2v`、`wanx-r2v`、`kling-v3`、`kling-v3-omni`、`gemini-image`
- 🔐 **本地密钥**：API Key 默认进系统 Keychain（Release）/ 本地 JSON（Debug）
- 💾 **嵌入式存储**：InkFrame 自带 PostgreSQL 17 进程，零外部 DB 依赖
- 🌗 **主题 & i18n**：dark / light / highContrast 三态，zh-CN + en-US 100% 覆盖
- 🧪 **TDD 骨架**：349+ 单元/widget 测试，`pre-commit`/`pre-push` 硬闸门

## 截图 / 演示

> Alpha 阶段视觉仍在快速迭代，请以最新 commit 实际跑起来为准。

暂无正式截图。`flutter run -d macos --debug` 后 AppBar 右上角 🎨 图标进 **Primitives Showcase** 查看设计系统原子与 InlinePanel Mock。

---

## 快速开始

### 环境要求

- macOS 12+ 或 Windows 10/11
- **Flutter ≥ 3.41** (stable channel)，**Dart ≥ 3.11**
- macOS 开发需 **Xcode 16+**（完整版，非仅 CLT）
- 运行时需一份本地 PostgreSQL 17（用 Homebrew 或 scoop 装均可；或设 `INKFRAME_PG_BIN` 指向自编译 bin 目录）

### 克隆 + 初始化

```bash
git clone https://github.com/KerroKapple/InkFrame.git
cd InkFrame

# 依赖
flutter pub get

# 必做：链接 git hooks（pre-commit analyze + pre-push 全量 test）
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../scripts/hooks/pre-push   .git/hooks/pre-push
```

### 跑起来

```bash
# macOS 需先装 CocoaPods：brew install cocoapods
# 开发用：debug 模式 + fake providers 不烧 API 配额
INKFRAME_PG_BIN=/opt/homebrew/opt/postgresql@17/bin \
INKFRAME_FAKE_PROVIDERS=1 \
flutter run -d macos --debug
```

- `INKFRAME_PG_BIN`：本地 PostgreSQL 17 `bin/` 目录（含 `postgres / pg_ctl / initdb`）
- `INKFRAME_FAKE_PROVIDERS=1`：把所有真 Provider 替换为本地 fake（返回公开 sample 视频/图，不调外部 API）。**第一次跑 UI 时建议开启**，避免 key 未配置直接炸

去掉 `INKFRAME_FAKE_PROVIDERS` 即可用真 Provider：首次启动后在 **Settings → Providers** 填入 API Key（DashScope / Gemini 等），key 会存入：
- **Release 构建**：macOS Keychain / Windows Credential Manager
- **Debug 构建（macOS）**：`~/InkFrame/config/secrets.dev.json`（文件型后端，绕开 Keychain 对 ad-hoc 签名的限制）

### 跑测试

```bash
flutter analyze             # 0 warning 为准
flutter test --coverage     # 全量单测 + widget test
lcov --summary coverage/lcov.info
```

---

## 项目结构

```
lib/
├── main.dart                    # 入口 + ProviderScope
├── app.dart                     # MaterialApp + 路由
├── l10n/                        # ARB i18n（zh + en 对齐）
├── theme/                       # 设计 token + primitives 组件库
│   ├── tokens.dart              # InkColors / InkSpacing / InkRadius ...
│   ├── primitives/              # InkGlassCard / GradientButton / ...
│   └── ...
├── core/                        # 共享抽象
│   ├── di/                      # Riverpod provider 装配
│   ├── interfaces/              # 抽象接口
│   └── models/                  # Freezed domain 模型
├── features/                    # 垂直切分的功能模块
│   ├── workspace/               # 工作台首页
│   ├── canvas/                  # 节点画布 + 生成流水
│   ├── settings/                # 设置（含 API Key 配置）
│   ├── generation/              # 生成调度
│   └── debug/                   # Debug-only（Primitives Showcase）
├── providers/                   # 各家 AI Provider 实现
├── storage/                     # 嵌入 PostgreSQL + repository
└── services/                    # 平台服务（SecureStorage / Download）
```

详细架构 & 规范见：
- [docs/CLAUDE.md](docs/CLAUDE.md) — SOLID / DI / i18n / token 硬规则
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — 模块关系
- [docs/PROVIDER-API.md](docs/PROVIDER-API.md) — Provider 接入契约

---

## 隐私 & 安全

- **所有数据本机存储**，不上传任何云端（除你主动调用的 AI Provider 端点）
- **API Key 永不入 repo** — `.gitignore` 已拦截 `secrets*.json / apikey* / *.env` 等常见模式
- **生成请求直连 Provider**，InkFrame 不做中间人日志
- 详见 `docs/CLAUDE.md` 的 "Provider API Keys" 章节

---

## 贡献

欢迎 issue / PR。先读：
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)
- [docs/CLAUDE.md](docs/CLAUDE.md)（硬规则：SOLID / i18n 100% / 零硬编码色值 / 零向后兼容 hack）

提交前确保：
- [ ] `flutter analyze` 0 warning
- [ ] `flutter test` 全绿
- [ ] pre-commit 6 项硬检查通过（i18n 覆盖、token 消费、直接实例化、Disposable 清理等）
- [ ] commit 走 conventional commits（`feat:` / `fix:` / `refactor:` / `test:` / `docs:`）

---

## Roadmap（摘要）

- [x] T0-T5：节点画布 + 多 Provider 骨架 + 视频生成闭环（v0.1.0-alpha.8）
- [x] Sprint 1：CineFlow 设计 token 对齐（Apple Blue accent + 5 级 surface）
- [x] Sprint 2：Design primitives（GlassCard / GradientButton / CompactTextField 等 9 个原子）
- [ ] Sprint 3：NodeInlinePanel v2（节点下方内联操作面板替代侧栏 Inspector）
- [ ] Sprint 4：StyledEdge（bezier 渐变曲线）
- [ ] Sprint 5：画布交互（marquee / handle drag / 伙伴边）
- [ ] Undo/Redo、Group、多人协作 —— 更远期

---

## License

[MIT](./LICENSE) © 2026 InkFrame contributors

---

## Acknowledgements

- 设计语言借鉴 [CineFlow](https://github.com/) — 节点化画布 + 毛玻璃视觉
- 嵌入式 PostgreSQL 方案参考 [embedded-postgres](https://github.com/zonkyio/embedded-postgres) 思路
- AI Provider SDK：阿里云 DashScope、Google Gemini、快手 Kling
