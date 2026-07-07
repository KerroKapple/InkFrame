# Third-Party Notices

InkFrame is distributed under the MIT license (see [`LICENSE`](./LICENSE)). The
application bundles and/or links a number of third-party components that remain
under their own licenses. This file records the attribution and license
obligations that travel with the distributed binaries.

The full license texts referenced below are shipped inside the application and
are viewable at runtime via **Settings → About → Open-source licenses**
(Flutter `showLicensePage`, which also aggregates every bundled pub package's
`LICENSE`). Non-pub components (native binaries, fonts) are registered into that
same page through `LicenseRegistry` — see `lib/core/licenses.dart`.

---

## 1. libmpv + FFmpeg (bundled native libraries) — LGPL-2.1

InkFrame plays and thumbnails video through `package:media_kit`. The actual
media stack is the **libmpv** shared library (which statically embeds **FFmpeg**
and supporting libraries), fetched and bundled by `media_kit_libs_video` at
build time.

- **License:** GNU Lesser General Public License, version 2.1 (LGPL-2.1).
  - License text bundled at `assets/licenses/LGPL-2.1.txt`.
- **Variant / build:** the media-kit **"video" (playback) build** — FFmpeg is
  configured **without** `--enable-gpl` and **without** `--enable-nonfree`, and
  mpv is built with `-Dgpl=false`. This is the LGPL build, **not** the GPL
  encoders build (media-kit ships those in separate `*-encoders-gpl-*` repos,
  which InkFrame does **not** depend on).
- **Upstream build repositories (corresponding source):**
  - Windows: <https://github.com/media-kit/libmpv-win32-video-build>
    (archive `mpv-dev-x86_64-20230924-git-652a1dd.7z`, release `2023-09-24`)
  - macOS: <https://github.com/media-kit/libmpv-darwin-build>
    (`v0.6.0`, `libmpv-xcframeworks_v0.6.0_macos-universal-video-default`)
  - Upstream projects: <https://ffmpeg.org> and <https://github.com/mpv-player/mpv>
- **Linking:** dynamic (Windows: `libmpv-2.dll`; macOS: `Mpv.xcframework`).
  Under LGPL-2.1 §6 the end user may replace these libraries with a modified
  version; dynamic linking satisfies that requirement, and the corresponding
  source is available from the upstream repositories listed above.

> Note: the exact Windows FFmpeg configure flags were inferred from the
> media-kit repository naming convention (the LGPL "video" repo vs. the separate
> "encoders-gpl" repo) and media-kit's LGPL-by-default policy (directly
> confirmed for the macOS `video-default` build). If you need a signed statement
> of the Windows build flags, confirm with the media-kit upstream. InkFrame
> attributes the stricter LGPL obligations regardless.

## 2. PostgreSQL (embedded database binary) — PostgreSQL License

InkFrame embeds a **PostgreSQL 17.2** server binary (see
`scripts/pg/pg-version.txt`) and runs it locally as the application datastore.

- **License:** The PostgreSQL License (a permissive OSI-approved BSD-style
  license).
  - License text bundled at `assets/licenses/PostgreSQL.txt`.
- **Copyright:**
  - Portions Copyright © 1996-2024, The PostgreSQL Global Development Group
  - Portions Copyright © 1994, The Regents of the University of California
- **Upstream:** <https://www.postgresql.org>

## 3. Bundled fonts — SIL Open Font License 1.1

Two font families are packaged as application assets (`assets/fonts/`).

| Family | Copyright | License | OFL text |
|---|---|---|---|
| Cormorant Garamond | Copyright 2015 The Cormorant Project Authors (github.com/CatharsisFonts/Cormorant) | SIL OFL 1.1 | `assets/fonts/OFL-CormorantGaramond.txt` |
| JetBrains Mono | Copyright 2020 The JetBrains Mono Project Authors (github.com/JetBrains/JetBrainsMono) | SIL OFL 1.1 | `assets/fonts/OFL-JetBrainsMono.txt` |

Neither bundled TTF declares a Reserved Font Name in its `name` table. Full OFL
1.1 text (with the FAQ pointer to <https://openfontlicense.org>) accompanies
each font per OFL condition 2.

## 4. Dart / Flutter pub dependencies

Each package below ships its own `LICENSE`, which Flutter's `showLicensePage`
aggregates automatically from the bundle. Listed here for completeness (direct
dependencies).

| Package | License |
|---|---|
| Flutter SDK / `flutter`, `flutter_localizations` | BSD-3-Clause |
| `flutter_riverpod`, `riverpod`, `riverpod_annotation` | MIT |
| `freezed`, `freezed_annotation` | MIT |
| `json_annotation`, `json_serializable` | BSD-3-Clause |
| `intl` | BSD-3-Clause |
| `logging` | BSD-3-Clause |
| `path` | BSD-3-Clause |
| `path_provider` | BSD-3-Clause |
| `cupertino_icons` | MIT |
| `postgres` | BSD-3-Clause |
| `uuid` | MIT |
| `dio` | MIT |
| `flutter_secure_storage` | BSD-3-Clause |
| `media_kit`, `media_kit_video`, `media_kit_libs_video` (Dart glue) | MIT |
| `window_manager` | MIT |
| `package_info_plus` | BSD-3-Clause |
| `file_selector` | BSD-3-Clause |

> The MIT license of `package:media_kit` covers only its Dart code. The bundled
> native libmpv/FFmpeg binaries are LGPL-2.1 — see §1.

## 5. External runtime dependency (not bundled)

- **FFmpeg (video export):** InkFrame invokes an **external** `ffmpeg` binary it
  discovers at runtime (`FfmpegLocator`) for video export. This binary is
  **not** distributed with InkFrame; whoever installs it is responsible for its
  license. It is unrelated to the LGPL FFmpeg embedded inside libmpv (§1).
