# InkFrame

**[English](./README.md)** | **中文**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.41-blue.svg)](https://flutter.dev)

本地 AI 影视创作工作站。节点画布把文本、图片、视频节点接到 DashScope（wanx）、Kling、Gemini 上。数据和 API Key 留在本地。

状态：alpha（v0.1.0-alpha.8）。macOS + Windows，单份 Dart 代码。

## 上手

依赖：Flutter ≥ 3.41、Dart ≥ 3.11、本地 PostgreSQL 17 二进制。macOS 还需要 Xcode 16 + CocoaPods。

```bash
git clone https://github.com/KerroKapple/InkFrame.git
cd InkFrame
flutter pub get

# 用 fake provider 跑，不烧 API 配额
INKFRAME_PG_BIN=/opt/homebrew/opt/postgresql@17/bin \
INKFRAME_FAKE_PROVIDERS=1 \
flutter run -d macos
```

接真实 API 时去掉 `INKFRAME_FAKE_PROVIDERS`，进 **Settings → Providers** 填 Key。Key 落到 Keychain / Credential Manager。

```bash
flutter analyze              # 0 warning（CI 用 --fatal-infos）
flutter test                 # 全量
flutter test --tags integration
```

环境变量、密钥后端、数据目录布局见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 文档

- [ROADMAP.md](ROADMAP.md) — 已发布与待办
- [CONTRIBUTING.md](CONTRIBUTING.md) — 流程、hook、commit 规范
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — DI、分层、错误模型、降级
- [docs/PROVIDER-API.md](docs/PROVIDER-API.md) — 接入新 Provider
- [docs/DATABASE.md](docs/DATABASE.md) — schema 与迁移
- [docs/TESTING.md](docs/TESTING.md) — TDD 分层与 mock
- [SECURITY.md](SECURITY.md) — 漏洞报告与密钥处理

## Bug 反馈

提 [GitHub issue](https://github.com/KerroKapple/InkFrame/issues) 或开 [Discussion](https://github.com/KerroKapple/InkFrame/discussions)。

## License

[MIT](./LICENSE)
