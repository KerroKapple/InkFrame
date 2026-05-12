# InkFrame

**English** | **[中文](./README.zh-CN.md)**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.41-blue.svg)](https://flutter.dev)

Local AI filmmaking workstation. A node-based canvas wires text, image, and video nodes through DashScope (wanx), Kling, and Gemini. Data and API keys stay on disk.

Status: alpha (v0.1.0-alpha.8). macOS + Windows, single Dart codebase.

## Get started

Requirements: Flutter ≥ 3.41, Dart ≥ 3.11, PostgreSQL 17 binaries on disk. macOS also needs Xcode 16 + CocoaPods.

```bash
git clone https://github.com/KerroKapple/InkFrame.git
cd InkFrame
flutter pub get

# Run with fake providers — no API keys, no quota burn
INKFRAME_PG_BIN=/opt/homebrew/opt/postgresql@17/bin \
INKFRAME_FAKE_PROVIDERS=1 \
flutter run -d macos
```

For real generation, drop `INKFRAME_FAKE_PROVIDERS` and add keys in **Settings → Providers**. Keys go to Keychain / Credential Manager.

```bash
flutter analyze              # 0 warnings (CI uses --fatal-infos)
flutter test                 # full suite
flutter test --tags integration
```

Environment variables, key storage, and data-directory layout: see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Documentation

- [ROADMAP.md](ROADMAP.md) — what's shipped, what's next
- [CONTRIBUTING.md](CONTRIBUTING.md) — workflow, hooks, commit rules
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — DI, layers, error model, degradation
- [docs/PROVIDER-API.md](docs/PROVIDER-API.md) — adding a provider
- [docs/DATABASE.md](docs/DATABASE.md) — schema and migrations
- [docs/TESTING.md](docs/TESTING.md) — TDD layering and mocks
- [SECURITY.md](SECURITY.md) — reporting and key handling

## Reporting bugs

Open a [GitHub issue](https://github.com/KerroKapple/InkFrame/issues) or start a [Discussion](https://github.com/KerroKapple/InkFrame/discussions).

## License

[MIT](./LICENSE)
