# InkFrame

**English** | **[中文](./README.zh-CN.md)**

> A local-first AI filmmaking workstation — Flutter Desktop with a node-based canvas that wires together multiple AI image/video providers. Your data and API keys never leave your machine.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A5%203.41-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A5%203.11-blue.svg)](https://dart.dev)
[![Status](https://img.shields.io/badge/status-alpha-orange.svg)]()

InkFrame is a **desktop-class** AI storyboard tool for indie creators and small teams:

- **Node-based canvas** — chain *text / image / video* nodes into a traceable generation pipeline; every node records its input, provider, parameters, output, and status
- **Direct provider access** — calls go straight to Aliyun wanx, Kuaishou Kling, Google Gemini, etc. No middleman server.
- **Everything stays local** — embedded PostgreSQL 17 for data, system Keychain / Credential Manager for keys, generated assets on local disk
- **macOS + Windows**, single Dart codebase

> **Status**: Alpha. v0.1.0-alpha.8 has shipped. The video-generation loop is functional; UI is being reworked toward a CineFlow-style design language.

---

## Table of Contents

- [Features](#features)
- [Supported AI Providers](#supported-ai-providers)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Where Your Data Lives](#where-your-data-lives)
- [Architecture Overview](#architecture-overview)
- [Project Layout](#project-layout)
- [Development Standards](#development-standards)
- [Troubleshooting](#troubleshooting)
- [Privacy & Security](#privacy--security)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

---

## Features

| Module | Status | Notes |
|--------|:------:|-------|
| Node canvas (drag / connect / zoom) | ✅ | Text, image, and video nodes with multiple edge types |
| Multi-provider integration (image + video) | ✅ | 7 real providers + 1 fake, behind a unified interface |
| Job queue (two-tier concurrency + rate limiting) | ✅ | Global 1–4 concurrency tiers + per-provider QPS token bucket |
| Embedded PostgreSQL 17 | ✅ | Bundled with the app — zero external DB dependency |
| System-level secure storage | ✅ | macOS Keychain / Windows Credential Manager / debug file backend |
| Themes (dark / light / high-contrast) | ✅ | Three semantic-color sets via design tokens, zero hard-coded colors |
| i18n (zh-CN + en-US, 100% coverage) | ✅ | ARB key sets enforced equal at CI; system prompts are localized too |
| Performance degradation controller (4 tiers) | ✅ | Driven by memory / FPS / disk signals with hysteresis |
| Video generation loop (5 providers) | ✅ | wanx-t2v / wanx-i2v / wanx-r2v / kling-v3 / kling-v3-omni |
| Lightbox preview + video playback | ✅ | media_kit backend |
| Inline node panel (NodeInlinePanel) | 🚧 | Sprint 3 |
| Styled gradient edges (StyledEdge) | 🚧 | Sprint 4 |
| Marquee selection / Group / collaboration | ⏳ | Long-term |
| Undo / Redo | ⏳ | Long-term |

---

## Supported AI Providers

All providers are wired through a single interface — adding a new one means a new file with zero changes to existing code (Open/Closed Principle in practice).

| ID | Vendor | Type | Use case | Where to get a key |
|----|--------|------|----------|--------------------|
| `wanx-image` | Aliyun Tongyi Wanxiang | Image | Text-to-image | DashScope Console |
| `wanx-t2v` | Aliyun Tongyi Wanxiang | Video | Text-to-video | DashScope Console |
| `wanx-i2v` | Aliyun Tongyi Wanxiang | Video | Image-to-video | DashScope Console |
| `wanx-r2v` | Aliyun Tongyi Wanxiang | Video | Reference-image-to-video | DashScope Console |
| `kling-v3` | Kuaishou Kling | Video | Text/image-to-video | Kuaishou Open Platform |
| `kling-v3-omni` | Kuaishou Kling | Video | Multimodal video generation | Kuaishou Open Platform |
| `gemini-image` | Google Gemini | Image | Multimodal image generation | Google AI Studio |
| `fake` | Built-in | Image / Video | Dev/test — returns public sample media | None needed |

Each provider implementation honors the capability-segregated interfaces under `lib/core/interfaces/` (`Submittable / Pollable / Cancellable / KeyValidatable / QuotaAware`), mixed in only where supported (Interface Segregation Principle in practice).

Full integration contract: [docs/PROVIDER-API.md](docs/PROVIDER-API.md).

---

## Quick Start

### Requirements

- **OS**: macOS 12+ or Windows 10/11
- **Flutter**: ≥ 3.41 (stable channel)
- **Dart**: ≥ 3.11
- **macOS dev**: Xcode 16+ (full IDE, not just Command Line Tools) + CocoaPods (`brew install cocoapods`)
- **PostgreSQL 17**: a local `bin/` (with `postgres / pg_ctl / initdb`); install via Homebrew / scoop / from source. Point `INKFRAME_PG_BIN` at it.

### Clone + bootstrap

```bash
git clone https://github.com/KerroKapple/InkFrame.git
cd InkFrame

# Pull dependencies
flutter pub get

# Wire up git hooks (pre-commit analyze + pre-push full test)
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
ln -sf ../../scripts/hooks/pre-push   .git/hooks/pre-push
```

### First run (without burning API quota)

```bash
# macOS
INKFRAME_PG_BIN=/opt/homebrew/opt/postgresql@17/bin \
INKFRAME_FAKE_PROVIDERS=1 \
flutter run -d macos --debug
```

`INKFRAME_FAKE_PROVIDERS=1` swaps every real provider for the local `FakeGenerationProvider` that returns public sample images/videos. **Strongly recommended for the first UI run** — avoids crashes from missing keys.

### Wire in real API keys

Drop `INKFRAME_FAKE_PROVIDERS`, restart, then go to **Settings → Providers** and fill in:

- DashScope API key (covers all four `wanx-*` providers)
- Kling Access Key + Secret Key (covers `kling-v3` / `kling-v3-omni`)
- Gemini API key (covers `gemini-image`)

Where keys are stored:

| Build type | Backend |
|------------|---------|
| Release | macOS Keychain / Windows Credential Manager |
| Debug (macOS) | `~/InkFrame/config/secrets.dev.json` (works around Keychain restrictions on ad-hoc-signed builds) |

Key validation results are cached in memory for one hour to save quota; users can hit *Re-validate* anytime.

### Run tests

```bash
flutter analyze              # Must report 0 warnings (CI runs --fatal-infos)
flutter test --coverage      # Full unit + widget suite, ~380+ tests
lcov --summary coverage/lcov.info

# Integration tests only (requires a PG process)
flutter test --tags integration

# Skip integration tests
flutter test --exclude-tags integration
```

---

## Configuration

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `INKFRAME_PG_BIN` | *unset* (uses bundled binaries) | Path to a local PG 17 `bin/`; release builds prefer the in-app bundle |
| `INKFRAME_FAKE_PROVIDERS` | `0` | Set to `1` to use fake providers — no external API calls |
| `INKFRAME_DATA_DIR` | `~/InkFrame` | Root of user data (database, generated assets, config) |
| `INKFRAME_LOG_LEVEL` | `INFO` | `DEBUG` / `INFO` / `WARN` / `ERROR` |

### In-app settings

- **Performance tier**: Power-saver (1) / Balanced (2) / Performance (3) / Max (4) — controls global concurrency
- **Theme**: Follow system / Dark / Light / High contrast
- **Font scale**: S / M / L / XL (A11y)
- **Data directory**: configurable (default `~/InkFrame`)
- **Proxy**: HTTP / SOCKS5; password lives in SecureStorage

---

## Where Your Data Lives

```
~/InkFrame/                              # Default data root (overridable via INKFRAME_DATA_DIR)
├── config/
│   ├── settings.json                    # App settings (no sensitive fields)
│   └── secrets.dev.json                 # Debug only: local key file backend
├── database/                            # Embedded PG data dir (created by initdb)
│   └── PG_VERSION  base/  pg_wal/  ...
├── projects/
│   └── {projectId}/
│       └── canvases/
│           └── {canvasId}/
│               ├── images/              # Image outputs (named by nodeId)
│               ├── videos/              # Video outputs
│               └── thumbnails/          # Thumbnails
└── logs/
    ├── inkframe.log                     # Per file ≤ 10 MB, total ≤ 200 MB
    └── inkframe.crash.{ts}.log          # Crash logs; last 3 retained, outside rotation
```

The database stores **relative paths only** (e.g. `images/node-abc.png`); `FileResolverService` joins them with the data root at runtime, so moving the data directory doesn't break references.

---

## Architecture Overview

### Five-layer dependency

```
┌─────────────────────────────────────────────────────────────┐
│  Widget Layer        lib/features/*/widgets/, theme/        │
│                      Renders state, dispatches events.      │
│                      Zero business logic.                   │
├─────────────────────────────────────────────────────────────┤
│  ViewModel Layer     lib/features/*/providers/              │
│                      Riverpod Notifiers, orchestrate svcs.  │
├─────────────────────────────────────────────────────────────┤
│  Service Layer       lib/services/, lib/features/*/services/│
│                      Pure Dart, zero Flutter imports.       │
├─────────────────────────────────────────────────────────────┤
│  Repository Layer    lib/storage/repositories/              │
│                      Abstract interfaces in core/interfaces.│
├─────────────────────────────────────────────────────────────┤
│  Infrastructure      lib/storage/, lib/providers/, platform/│
│                      PostgreSQL / dio / Keychain / ffmpeg.  │
└─────────────────────────────────────────────────────────────┘

Dependencies only flow downward — no layer may import from above.
```

### Job scheduling

```
Global concurrency cap (performance tier)
  Power=1 / Balanced=2 / Performance=3 / Max=4
      ↕ min()
Per-provider concurrency cap (ProviderCapabilities.maxConcurrentJobs)
      ↕
Per-provider token bucket (QPS / Burst)

State machine:
  pending ──► submitted ──► polling ──► success / error / timeout
     │                                       │
     └── cancelled_by_user                   │
                                             │
  any stage ────────────────────► cancelled_on_exit (app shutdown)
```

Full architecture (DI matrix / 14-code error taxonomy / hysteresis-based degradation / A11y / test layering / build pipeline) lives in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Project Layout

```
lib/
├── main.dart                       # Entry + ProviderScope
├── app.dart                        # MaterialApp, routing, theme switching
├── l10n/                           # ARB i18n (zh + en, 100% aligned)
├── theme/                          # Design tokens + component library
│   ├── tokens.dart                 # InkColors / InkSpacing / InkRadius / InkShadow
│   ├── typography.dart
│   ├── primitives/                 # InkGlassCard / GradientButton / CompactTextField …
│   └── components/                 # InkButton / InkCard / InkInput …
├── core/                           # Shared abstractions
│   ├── di/                         # Riverpod provider wiring (single source of truth)
│   ├── interfaces/                 # Abstract interfaces (no implementations)
│   ├── errors/                     # InkError sealed hierarchy
│   ├── constants/                  # Enums, constants (side-effect free)
│   ├── logging/                    # InkLogger interface
│   ├── models/                     # Freezed immutable domain models
│   └── paths/                      # FileResolverService interface
├── features/                       # Feature modules (vertical slices)
│   ├── workspace/                  # Workspace home
│   ├── canvas/                     # Node canvas + generation pipeline
│   ├── settings/                   # Settings (incl. API key configuration)
│   ├── generation/                 # Generation orchestration
│   ├── lightbox/                   # Media preview
│   └── debug/                      # Debug-only (Primitives Showcase)
├── providers/                      # AI provider implementations (Infrastructure)
│   ├── provider_registry.dart      # id → factory
│   ├── rate_limiter.dart           # Token bucket
│   ├── dashscope_async_provider_base.dart
│   ├── wanx_image_provider.dart
│   ├── wanx_t2v_provider.dart
│   ├── wanx_i2v_provider.dart
│   ├── wanx_r2v_provider.dart
│   ├── kling_v3_provider.dart
│   ├── kling_v3_omni_provider.dart
│   ├── gemini_image_provider.dart
│   └── fake_generation_provider.dart
├── storage/                        # Embedded PG + repository implementations
│   ├── pg_controller.dart          # PG process lifecycle (127.0.0.1 + auth=trust)
│   ├── pg_binary_locator.dart
│   ├── migrations/                 # Incremental schema migrations
│   └── repositories/
└── services/                       # App-level services
    ├── job_queue_service.dart
    ├── file_resolver_service.dart
    ├── secure_storage_service.dart
    └── …
```

---

## Development Standards

Confirm every item before committing (the pre-commit hook also enforces these):

### Hard rules (CI rejects on violation)

- **SOLID / DI**: every external dependency is injected through a Riverpod provider. No `new ConcreteClass()` inside Widget / Service layers. Interfaces in `core/interfaces/`, implementations in `storage/` or `providers/`, wiring in `core/di/`.
- **Zero hard-coded strings**: every UI string, error message, and AI system prompt goes through `context.l10n.xxx`. `app_en.arb` and `app_zh.arb` must be updated in the same commit and have identical key sets.
- **Zero hard-coded styles**: no `Color(0xFF...)`, `fontSize: N`, or `EdgeInsets.all(N)` in feature code. Use `InkColors / InkSpacing / InkRadius` tokens and Ink components.
- **Zero backward compatibility**: when a schema changes, change the code — don't write migration helpers or keep deprecated APIs.
- **Errors as `InkError`**: every cross-layer error must be an `InkError` subtype. No raw `Exception` / `String` crossing layers.
- **Disposables must be cleaned up**: `StreamSubscription / Timer / AnimationController` must be disposed via `ref.onDispose` or widget `dispose()`.
- **TDD**: red → green → refactor. Repository layer coverage ≥ 75%, everything else ≥ 70%.

### Pre-commit hooks

| Hook | Checks |
|------|--------|
| `check-magic-strings.sh` | Hard-coded UI strings / magic numbers / status string comparisons |
| `check-inline-styles.sh` | `Color(0xFF...)` / hard-coded EdgeInsets / BoxShadow |
| `check-direct-instantiation.sh` | `new ConcreteClass()` inside Widget/Service |
| `check-disposable-cleanup.sh` | StreamSubscription / Timer / Controller without dispose |
| `check-i18n-coverage.sh` | ARB key drift / empty values / TODO translations |
| `check-updated-at.sh` | UPDATE statements missing `updated_at` |
| `check-keybindings.sh` | Default shortcuts colliding with OS reserved keys |

Full standards: [docs/CLAUDE.md](docs/CLAUDE.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Commit conventions

Conventional Commits:

```
feat(canvas): add node drag snapping
fix(provider/kling): switch poll backoff to exponential
refactor(storage): extract BaseRepository.withUpdatedAt
test(generation): cover cancel-pending path
docs(adr): add 0007-rate-limiting-strategy
chore: bump dart_test deps
```

`--no-verify` to skip hooks is not allowed. The pre-push hook runs the full test suite — slow but it's the floor.

---

## Troubleshooting

### App exits immediately after `flutter run`, or PG reports "binaries not found"

`INKFRAME_PG_BIN` is unset or wrong. Verify:

```bash
ls "$INKFRAME_PG_BIN/postgres"            # must exist
"$INKFRAME_PG_BIN/postgres" --version     # must report 17.x
```

Homebrew on macOS typically puts it at `/opt/homebrew/opt/postgresql@17/bin` (Apple Silicon) or `/usr/local/opt/postgresql@17/bin` (Intel).

### macOS Debug build hits a Keychain access denial

Ad-hoc-signed debug builds can't write to the system Keychain. InkFrame automatically falls back to `~/InkFrame/config/secrets.dev.json` in Debug builds (still git-ignored). Check the logs — the `secure_storage` module should report `FileSecureStorageService`.

### "Another postgres instance (pid=...) is already running"

A previous InkFrame process didn't shut down cleanly and left a `postmaster.pid`. InkFrame checks whether that PID is still alive on startup and refuses to launch if it is. Clean up manually:

```bash
ps -p <pid>           # confirm the PID is what you think it is
kill <pid>            # or remove ~/InkFrame/database/postmaster.pid (only after the process is gone)
```

### `flutter test` hangs in pre-push

A widget test is probably awaiting an async task. Run that file in isolation first:

```bash
flutter test test/features/canvas/foo_test.dart -r expanded
```

### Provider returns `invalid_key` even though the key is correct

- Check for leading/trailing whitespace (common when pasting)
- DashScope keys are `sk-xxx` (32+ chars); Gemini keys start with `AIza...`
- Kling needs *two* fields: Access Key + Secret Key
- Hit *Re-validate* in the settings panel to bypass the 1-hour cache

More: [docs/internal/t5-manual-regression.md](docs/internal/t5-manual-regression.md).

---

## Privacy & Security

- **Everything stays local**: projects, generated assets, thumbnails, and logs all live under `~/InkFrame/`. Nothing is uploaded to any cloud (except the AI provider endpoints you actively call).
- **API keys never enter the repo**: `.gitignore` blocks `secrets*.json` / `apikey*` / `*.env` / `*.pem` / `*.key` / `*.local` and similar patterns. The file-based SecureStorage backend writes to `~/InkFrame/config/`, outside the repo.
- **Direct provider calls**: generation requests go straight from the InkFrame process to DashScope / Kling / Gemini endpoints. No middleman, no third-party telemetry.
- **Log redaction**: API keys appear as `sk-a1b2****` (first 4 chars only); prompts are truncated to 50 chars to avoid copyright leakage; home paths in log lines become `~`; proxy passwords become `[REDACTED]`.
- **Key storage backends**:
  - macOS Release → Keychain (`kSecClassGenericPassword`)
  - Windows Release → Credential Manager
  - macOS Debug → local JSON file (works around ad-hoc signing limits; still ignored by git)

Details: "Provider API Keys" in [docs/CLAUDE.md](docs/CLAUDE.md), and §9 / §13.4 of [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Contributing

Issues and PRs welcome. Read first:

- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)
- [docs/CLAUDE.md](docs/CLAUDE.md) (hard rules)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (DI / errors / degradation / test layering)
- [docs/PROVIDER-API.md](docs/PROVIDER-API.md) (required before adding a provider)
- [docs/DATABASE.md](docs/DATABASE.md) (schema + migration rules)
- [docs/TESTING.md](docs/TESTING.md) (TDD rhythm + mock boundaries)

Pre-submission checklist:

- [ ] `flutter analyze` reports 0 warnings
- [ ] `flutter test` is fully green
- [ ] All 7 pre-commit hooks pass
- [ ] `app_en.arb` and `app_zh.arb` are updated together
- [ ] Commit message follows Conventional Commits

---

## Roadmap

- [x] **T0–T5**: Node canvas + multi-provider skeleton + video generation loop (v0.1.0-alpha.8)
- [x] **Sprint 1**: CineFlow design-token alignment (Apple Blue accent + 5-tier surface)
- [x] **Sprint 2**: Design primitives (GlassCard / GradientButton / CompactTextField — 9 atoms)
- [ ] **Sprint 3**: NodeInlinePanel v2 (inline action panel below the node, replacing the side Inspector)
- [ ] **Sprint 4**: StyledEdge (Bézier gradient curves)
- [ ] **Sprint 5**: Canvas interactions (marquee selection / handle drag / partner edges)
- [ ] **Beta**: Full A11y coverage (VoiceOver / Narrator) + Undo/Redo + Group + export pipeline
- [ ] **Long-term**: Multi-user collaboration / pluggable providers / custom node types

---

## License

[MIT](./LICENSE) © 2026 InkFrame contributors

---

## Acknowledgements

- Visual language inspired by **CineFlow** (node-based canvas + frosted-glass aesthetic)
- Embedded PostgreSQL approach informed by open-source community work
- AI provider SDKs: Aliyun DashScope, Google Gemini, Kuaishou Kling
- Flutter Desktop ecosystem: Riverpod, freezed, dio, media_kit, ffmpeg_kit_flutter, flutter_secure_storage
