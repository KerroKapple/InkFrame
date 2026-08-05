<div align="center">

# 🎬 InkFrame

**English** | **[中文](./README.zh-CN.md)**

**Local-first AI filmmaking workstation — wire text, image, and video AI into one node canvas, on your own machine.**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.41-blue.svg)](https://flutter.dev)
[![Status](https://img.shields.io/badge/status-alpha-orange.svg)](./ROADMAP.md)
[![Stars](https://img.shields.io/github/stars/KerroKapple/InkFrame?style=social)](https://github.com/KerroKapple/InkFrame/stargazers)

</div>

InkFrame is a desktop workstation for AI-driven filmmaking. A node-based canvas lets you chain
prompt → image → video through real providers — DashScope (Wanx), Kling, Gemini, and more (9
built-in) — while every project file and API key stays on **your disk**. No cloud account, no
upload, no SaaS lock-in.

<p align="center">
  <img src="docs/media/hero-canvas.png" alt="InkFrame node canvas — prompt, provider config and a generated cinematic still" width="100%">
</p>

<p align="center">
  <img src="docs/media/demo-generation.gif" alt="Generating an image on the canvas: submit, live queue progress, result lands on the node" width="70%">
</p>


## ✨ Why InkFrame

- **🔒 Local-first by design** — projects live in an embedded PostgreSQL on your machine; keys go to the OS Keychain / Credential Manager, never a plaintext `.env`.
- **🕸️ Node canvas** — compose shots visually: drop text / image / video nodes, wire them, and watch generation flow through the graph with live job progress.
- **🔌 Multi-provider** — mix and match image/video models from different vendors in one project. Adding a new one is a single file (see [`docs/PROVIDER-API.md`](docs/PROVIDER-API.md)).
- **🖥️ One codebase, two desktops** — macOS + Windows from a single Dart/Flutter source, frameless "Amber Noir" UI.
- **🧪 Quota-safe dev** — built-in fake providers run the whole app and exercise the canvas without burning a single API credit.

## 🔄 How it works

```mermaid
flowchart LR
    A["📝 Text / Prompt node"] --> B["🖼️ Image node<br/>(Wanx · Gemini)"]
    B --> C["🎞️ Video node<br/>(Kling · Wanx i2v)"]
    C --> D["📦 Storyboard / Export"]
    subgraph Local["🔒 Your machine"]
      DB[("Embedded<br/>PostgreSQL")]
      KEY["🔑 OS Keychain"]
    end
    B -.persist.-> DB
    C -.persist.-> DB
    B -.auth.-> KEY
    C -.auth.-> KEY
```

Build a shot graph on the canvas, hit generate, and InkFrame runs the jobs through your configured
providers — caching results and project state locally as it goes.

## 🎨 Providers

| Provider | Type | Status |
|----------|------|--------|
| Wanx (DashScope) | image · i2v · r2v · t2v | ✅ Implemented |
| Kling V3 / V3 Omni | video | ✅ Implemented |
| Gemini Image | image | ✅ Implemented |
| OpenAI GPT-Image (`gpt-image-2`) | image | ✅ Implemented |
| Stability Stable Image Core | image | ✅ Implemented |
| OpenAI-compatible custom endpoint (`custom_providers.json`) | image | ✅ Implemented |
| Stable Diffusion (local ComfyUI) | image | 🟢 Help wanted |
| OpenAI DALL·E 3 (dedicated integration) | image | 🟢 Help wanted |
| Runway Gen-3 / Gen-4 | video | 🟢 Help wanted |
| Midjourney · Pika · Luma | image/video | 🟢 Help wanted |

Want to add one? It's the lowest-effort way to contribute — see [`docs/PROVIDER-API.md`](docs/PROVIDER-API.md) and the [Help Wanted](./ROADMAP.md#-help-wanted) list.

## 🚀 Get started

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
flutter test --tags pg       # real-PG integration tests (need TEST_PG_URL; auto-skipped otherwise)
```

Environment variables, key storage, and data-directory layout: see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## 🧱 Tech stack

Flutter (desktop) · Riverpod (state + DI) · Freezed (immutable models) · embedded PostgreSQL via `postgres` · `dio` (provider HTTP) · `flutter_secure_storage` (keys) · `media_kit` (video playback + frame extraction) · `window_manager` (frameless chrome).

## 📍 Status

**Alpha** (`v0.1.0-alpha.9`). Single Dart codebase shipping on macOS + Windows. M1 ("usable") and
M2 ("what creators need" — character consistency, batch variants, prompt presets, cost estimation)
are complete with CI fully green; M3 first slices are in progress across four tracks (shot
storyboarding, custom providers, asset gallery, video export). Remaining beta gaps are tracked in
[docs/BOARD.md](docs/BOARD.md). See [ROADMAP.md](ROADMAP.md) for what's shipped and what's next.

## 📚 Documentation

- [ROADMAP.md](ROADMAP.md) — what's shipped, what's next
- [CONTRIBUTING.md](CONTRIBUTING.md) — workflow, hooks, commit rules
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — DI, layers, error model, degradation
- [docs/PROVIDER-API.md](docs/PROVIDER-API.md) — adding a provider
- [docs/DATABASE.md](docs/DATABASE.md) — schema and migrations
- [docs/TESTING.md](docs/TESTING.md) — TDD layering and mocks
- [SECURITY.md](SECURITY.md) — reporting and key handling

## 🤝 Contributing

Maintainer-welcomed directions live in [ROADMAP.md](ROADMAP.md#-help-wanted) — providers, canvas UX,
i18n, and test infra. Please open an issue or post in [Discussions](https://github.com/KerroKapple/InkFrame/discussions)
to align scope **before** writing a large PR. First time? Look for the
[`good first issue`](https://github.com/KerroKapple/InkFrame/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) label.

## 🐞 Reporting bugs

Open a [GitHub issue](https://github.com/KerroKapple/InkFrame/issues) or start a [Discussion](https://github.com/KerroKapple/InkFrame/discussions).

## 📄 License

[MIT](./LICENSE)
