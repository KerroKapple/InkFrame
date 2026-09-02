# W-UX-live — 真机可用性走查 (Windows desktop, live)

**CONCLUSION**: 0 findings by severity — the live walkthrough could not be performed. **1 P0 environment blocker** prevented launching the app at all; no in-app screens were reached and no screenshots were captured.

## Screens covered

**None reached.** The app never launched. Everything in the requested flow list (onboarding, Studio home, canvas node add/connect/inspector, generation submit, Storyboard import/preview, Gallery, Export, Settings, Command palette, empty/loading/error states) is unaudited from a live-interaction standpoint.

What I did establish, as a substitute check, is that the current branch's Dart code is not the reason for the failure: `flutter analyze lib` on this branch reports **"No issues found!"** — the blocker below is purely an environment/toolchain issue on this machine, not a compile or lint defect in the diff (`lib/features/canvas/widgets/characters_section.dart`, `inspector_chip.dart`, `name_dialog.dart`, `image_config_inspector.dart`, `video_config_inspector.dart`, `generation_controller.dart`).

## Findings

### [P0] Cannot build/launch the Windows desktop app on this machine — missing symlink privilege

- **Screen/flow**: App launch (blocks all downstream flows)
- **What happened**: Ran `flutter devices` — `windows-x64` desktop device is correctly detected. Ran `flutter run -d windows` from repo root (`D:\Projects\InkFrame`). Dependency resolution succeeded, but the build failed immediately with:
  ```
  Error: Building with plugins requires symlink support.

  Please enable Developer Mode in your system settings. Run
    start ms-settings:developers
  to open settings.
  ```
  This comes from Flutter's Windows plugin-linking step (`flutter_plugins.dart`, `handleSymlinkException`, Win32 error 1314 `ERROR_PRIVILEGE_NOT_HELD`): creating the per-plugin symlinks under `windows/flutter/ephemeral/.plugin_symlinks` requires either Windows Developer Mode enabled or an Administrator-elevated terminal — neither is available on this session/machine (verified: no prior `build/windows/...Debug|Release` artifacts exist to run directly; current shell confirmed **not** running elevated via `WindowsPrincipal.IsInRole(Administrator) = False`; checked for a pre-built exe in the four sibling Codex worktrees under `.worktrees/` — none exist there either).
  Enabling Windows Developer Mode is a system/security-setting change (`Settings → Privacy & Security → For developers`), which is outside what I'm permitted to change unilaterally, so I did not toggle it and instead stopped to report the blocker, per this task's own escalation instructions.
- **Why it's a problem**: This is an environment issue, not an InkFrame defect — but it's worth flagging in `docs/BOARD.md`/dev-setup docs (if not already) that a fresh Windows dev machine needs Developer Mode ON (or an elevated shell) before `flutter run -d windows` will work at all, given the number of native Windows plugins in this project (window_manager, screen_retriever, media_kit, flutter_secure_storage_windows, file_selector_windows, package_info_plus, etc. — all confirmed present in `pubspec.yaml`).
- **Suggested fix**: Not an app fix. For this audit to proceed, a human (or a session with permission to change Windows settings) needs to either run `start ms-settings:developers` and toggle "Developer Mode" on, or re-run from an Administrator-elevated terminal, then re-invoke this audit.

## What I tried before stopping (per task's "try ≥2 alternatives" instruction)

1. `flutter run -d windows` (standard launch) — failed as above.
2. Searched for any already-built executable to run directly without rebuilding (`build/windows/x64/runner/{Debug,Release}/*.exe` in this checkout and in the four `.worktrees/*` sibling checkouts) — none found; this is the first build attempt on this machine.
3. Checked whether the current shell already has the privilege needed to create the plugin symlinks without a settings change (`IsInRole(Administrator)`) — it does not, and I have no way to supply admin credentials/UAC consent non-interactively.
4. Considered falling back to a web/Edge build (also listed as an available device) to at least see *some* UI — rejected: the task explicitly scopes this as a desktop-app audit, and InkFrame's desktop-only plugins (embedded PostgreSQL, `window_manager` frameless chrome, `media_kit` desktop video, Windows Credential Manager secure storage) mean a web build would not compile/behave the same and would produce a misleading, non-representative audit.
5. Ran `flutter analyze lib` as a sanity check that the branch itself isn't broken — clean, confirming the blocker is environmental, not a code regression on `feat/ch-2-video-inspector-characters`.

No native-desktop screenshot/input tooling was available in this session either (only Chrome-browser MCP tools, explicitly out of scope per the task); a PowerShell screenshot helper was prepared (`GetWindowRect` + `CopyFromScreen`) at `C:\Users\Kerro\AppData\Local\Temp\claude\...\scratchpad\screenshot.ps1` for use once the app can launch, but it was never exercised since no window ever appeared.

## Screenshots

None captured — the app window never opened, so there is nothing to screenshot. `flutter devices` output and the exact build error text above are the only artifacts from this session; no image evidence exists.

## Recommendation

Re-run this live UX audit after either (a) Developer Mode is enabled on the audit machine, or (b) a pre-built `inkframe.exe` is provided/checked into a reachable location, or (c) the audit is run from an environment where an elevated shell is acceptable. Until then, this report should be treated as "not run" rather than "no issues found" for the live-interaction portion of the larger review.
