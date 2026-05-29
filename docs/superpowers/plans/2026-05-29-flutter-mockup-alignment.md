# Flutter ↔ Mockup Visual Alignment Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the *running Flutter app* render its four implemented screens (Lock / Studio Home / Canvas / — partial — chrome on Settings) ≥ 90 % faithful to the polished HTML mockups in `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/`, which are now the single surviving reference (the original PNGs in `IF.zip` are gone from this machine).

**Architecture:** Token-first. A foundation phase reconciles the systematic metric/typography drift between the mockup CSS and `lib/theme/` so every later screen edit consumes a correct token instead of a magic number. Then one phase per screen, each independently shippable as its own PR. NET-NEW widgets get full code; the long tail of small restyles is batched into per-screen "polish pass" tasks with exact `file:line → old → new` tables. Verification = `flutter test` (structural widget smoke tests) + `flutter analyze` + a screenshot-diff harness (build the macOS app, drive to each screen, `screencapture`, eyeball against a freshly re-rendered mockup PNG).

**Tech Stack:** Flutter 3.41.6 (desktop/macOS), Riverpod, `window_manager`, Cormorant Garamond + JetBrains Mono fonts, gen-l10n ARB i18n. Verified available on this machine: Xcode 26.5, CocoaPods 1.16.2, macOS desktop device, Chrome headless.

**Branch policy:** `main`/`dev` are protected (project rule — feature branch + PR only). Work continues on the current `feat/ui-mockup-png-alignment` branch (or split per-phase branches off it). Never commit to a protected branch.

---

## Scope & Assumptions

**In scope** (pure visual alignment of *existing* Flutter screens to existing mockups):

- Phase 0 — Foundation: token reconciliation + verification harness.
- Phase 1 — Lock screen (`01-lock.html`).
- Phase 2 — Studio Home (`02-studio-home.html`).
- Phase 3 — Canvas (`03-canvas.html`), compact render-queue only.

**Explicitly OUT of scope** (do NOT build these here — they are feature work, not UI alignment, and the design spec `docs/superpowers/specs/2026-05-13-ui-redesign-design.md §9` already defers them to "spec v2"):

| Deferred item | Why it's out of scope |
|---|---|
| Settings `服务商` provider-management redesign (status pills, 主用/备用 role, endpoint+model display, quota, overflow menu) | Needs a new persisted data layer (provider config / role / connection-status / quota) that does not exist in `lib/storage` or `lib/core/models`. Confirmed absent. → **new spec.** |
| Settings `操作偏好` toggles + `速率限制` editable inputs | Needs an `app_settings`/preferences table + an `InkToggle` component; rate-limit values are today `const` in `provider_capabilities.dart`, not user-editable. → **new spec.** |
| Full Task-Queue screen (`04-task-queue.html`) | Needs real `jobQueueService` data wiring + a new feature module/route. The *compact* in-canvas render queue IS in scope (Phase 3). |
| Storyboard (`05`), Script Editor (`06`), Asset Library (`07`), Asset Generation (`08`), Account (`10`), Toasts (`11`), Error States (`12`) | Net-new feature screens, not yet implemented in Flutter at all. → **ROADMAP epics / spec v2.** |

> **Assumption flagged for the user (asking was disabled this session):** I interpreted "好好做ui 效果都给你做好参考了" as *"make the Flutter app match the mockups."* If you actually meant "keep polishing the HTML mockups," stop — that is the already-largely-executed `2026-05-23-mockup-png-alignment.md`, not this plan. Per our rule, **do not execute until you approve.**

**Settings note:** The only Settings work included here is the shared chrome unification that falls out of Phase 0 (replacing its Material `AppBar` with `InkWindowChrome`), because that is pure restyling with no new data. Everything else on Settings is deferred above.

---

## Token-Scale Reference (read before any screen phase)

The mockup CSS radius scale is offset one step from Flutter's. **No new radius tokens are needed** — every step already exists. Use this mapping whenever a mockup says `--r-*`:

| Mockup CSS | px | Flutter constant |
|---|---|---|
| `--r-sm` | 4 | `InkRadius.sm` |
| `--r-md` | 6 | `InkRadius.bentoBtn` |
| `--r-lg` | 8 | `InkRadius.md` |
| `--r-xl` | 12 | `InkRadius.lg` |
| `--r-pill` | 999 | `InkRadius.pill` |

Current spacing (`InkSpacing`): xs=4, sm=8, md=16, lg=24, xl=32, xxl=48. The mockups also use 18 / 22 / 36 — these have no 8-multiple token; Phase 0 adds the layout metrics that matter and the rest are accepted at the nearest token unless a polish table says otherwise.

---

## Verification Harness (used by every phase)

Two layers. Structural correctness is automated; pixel fidelity is eyeballed (per design spec §6 — **no golden tests this round**, pixel diff is too noisy during visual iteration).

**1. Automated (run after every task that touches Dart):**

```bash
flutter analyze
flutter test
bash scripts/check-i18n-coverage.sh   # ARB en/zh key parity (existing CI hook)
```

**2. Screenshot-diff (run at the end of each screen phase):**

```bash
# (a) Re-render the mockup reference PNGs (the /tmp ones are ephemeral).
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
MK=/Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups
OUT=/tmp/mk-ref; mkdir -p "$OUT"
for n in 01-lock 02-studio-home 03-canvas; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 \
    --virtual-time-budget=2500 --screenshot="$OUT/$n.png" "file://$MK/$n.html" 2>/dev/null
done

# (b) Run the app, navigate to the screen, capture the window, compare side by side.
flutter run -d macos    # then unlock with a real key, open a project, etc.
# In another shell, capture the focused InkFrame window interactively:
screencapture -w /tmp/app-<screen>.png
open /tmp/app-<screen>.png "$OUT/<n>.png"   # eyeball ≥ 90% match
```

Expected at phase end: each app screenshot reads as the same screen as its mockup twin — same layout regions, same type faces, same accent treatment, no missing elements from that phase's task list.

---

## File Map

```
lib/theme/
├── tokens.dart                 # Phase 0: +InkLayout class, chrome height 44
├── typography.dart             # Phase 0: +serifTitle / serifLogo / serifBrand
└── components/
    └── ink_window_chrome.dart  # Phase 0: height → InkLayout.chromeHeight, bg → surface1, win-btn 30×26

test/theme/
└── tokens_test.dart            # Phase 0: assert new token/typography values

lib/features/lock/                         # Phase 1
├── lock_screen.dart                        # OFFLINE marker, help copy, spacing, serifBrand
├── widgets/lock_logo.dart                  # serifBrand + 2px '/' margin
├── widgets/lock_secure_field.dart          # 44h, mono text, focus-amber border
└── widgets/lock_lang_chip.dart  (CREATE)   # bordered 中/EN chip, working locale toggle

lib/features/studio/                        # Phase 2
├── studio_home_screen.dart                 # title row + Grid/List + Sort, 4-col grid, FAB weight
├── controllers/studio_view_mode.dart (CREATE)  # grid/list + sort enum providers
├── widgets/studio_top_chrome.dart          # trailing ⌥/⚑, drop ⌘K+avatar
├── widgets/library_sidebar.dart            # 248w, accent rail, selected=surface2, indents
├── widgets/project_card.dart               # gradient variants + vignette, name h1.1, meta ls
└── widgets/studio_provider_banner.dart     # bold lead-in, '→' action, dot glow

lib/features/canvas/                        # Phase 3
├── widgets/canvas_screen.dart              # mount real inspector, drop mock CanvasInspector
├── widgets/canvas_top_chrome.dart          # view-nav tabs, left breadcrumb, export icon, logo 19/w300
├── widgets/canvas_view.dart                # dot-grid bg (surfaceCanvas), zoom pill, hint strip
├── widgets/canvas_left_toolbar.dart        # lower tool group + separator + More + tooltips
├── widgets/edge_painter.dart               # straight+arrow → amber cubic bezier (+live glow)
├── widgets/canvas_node_card.dart           # becomes the ONLY node card; fix shot→borderHover, stripe 3px
├── widgets/node_card.dart      (DELETE)     # dead duplicate; consolidate onto canvas_node_card
├── widgets/canvas_render_queue.dart        # real counts/format, running-dot halo
└── widgets/chrome_view_nav.dart (CREATE)   # Canvas/Storyboard/Script/Generation/Queue tab row
```

---

# Phase 0 — Foundation (tokens + harness)

**Goal:** every metric/type the later phases need exists as a token, and the verification harness is proven to work. Ship as one PR.

### Task 0.1 — Add `InkLayout` metric tokens

**Files:**
- Modify: `lib/theme/tokens.dart` (append after `InkRadius`, before `InkShadow`, ~line 189)
- Test: `test/theme/tokens_test.dart`

- [ ] **Step 1: Write the failing test** — append to `test/theme/tokens_test.dart`:

```dart
group('InkLayout', () {
  test('exact metric values match the mockup spec', () {
    expect(InkLayout.chromeHeight, 44);
    expect(InkLayout.sidebarWidth, 248);
    expect(InkLayout.canvasToolbarWidth, 56);
    expect(InkLayout.inspectorWidth, 320);
    expect(InkLayout.nodeWidth, 200);
    expect(InkLayout.controlHeight, 44);
    expect(InkLayout.winBtnWidth, 30);
    expect(InkLayout.winBtnHeight, 26);
    expect(InkLayout.iconButton, 28);
  });
});
```

- [ ] **Step 2: Run it, watch it fail**

Run: `flutter test test/theme/tokens_test.dart`
Expected: FAIL — `Undefined name 'InkLayout'`.

- [ ] **Step 3: Implement** — add to `lib/theme/tokens.dart`:

```dart
/// 布局尺寸 token：固定像素的结构尺寸（chrome / 侧栏 / 画布控件 / 窗口按钮）。
/// 与 mockup `_shared.css` 的结构变量一一对应。
class InkLayout {
  InkLayout._();
  static const double chromeHeight = 44; // --chrome-h
  static const double sidebarWidth = 248; // Studio LIBRARY 栏 (.sidebar)
  static const double canvasToolbarWidth = 56; // Canvas 左工具栏
  static const double inspectorWidth = 320; // Canvas 右 Inspector
  static const double nodeWidth = 200; // 节点卡 (.node)
  static const double controlHeight = 44; // CTA / 输入框标准高
  static const double winBtnWidth = 30; // 窗口控制按钮宽 (.win-ctrl b)
  static const double winBtnHeight = 26; // 窗口控制按钮高
  static const double iconButton = 28; // 图标按钮命中区 (.ico-btn)
}
```

- [ ] **Step 4: Run it, watch it pass** — `flutter test test/theme/tokens_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/tokens.dart test/theme/tokens_test.dart
git commit -m "$(cat <<'EOF'
feat(theme): add InkLayout metric tokens for chrome/sidebar/canvas

Encodes the mockup _shared.css structural dimensions (chrome 44, sidebar
248, toolbar 56, inspector 320, node 200, window buttons 30x26) so screen
widgets stop hardcoding pixel sizes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.2 — Add serif typography variants

**Files:**
- Modify: `lib/theme/typography.dart` (constructor + `defaults` factory + `scaled`)
- Test: `test/theme/tokens_test.dart`

Rationale: mockup uses Cormorant at three new weights/sizes — 32/w400 section titles (`Recent Projects`, `服务商`), 19/w300 chrome logo, 72/w300 Lock brand. Today only `display` (48/w300) and `headline` (22/w400) exist, so callers do ad-hoc `copyWith(fontSize: …)` with the wrong weight.

- [ ] **Step 1: Write the failing test** — append to `test/theme/tokens_test.dart`:

```dart
group('serif typography variants', () {
  final t = InkTypography.defaults();
  test('serifTitle is Cormorant w400 32', () {
    expect(t.serifTitle.fontFamily, 'CormorantGaramond');
    expect(t.serifTitle.fontSize, 32);
    expect(t.serifTitle.fontWeight, FontWeight.w400);
    expect(t.serifTitle.height, 1.1);
  });
  test('serifLogo is Cormorant w300 19', () {
    expect(t.serifLogo.fontFamily, 'CormorantGaramond');
    expect(t.serifLogo.fontSize, 19);
    expect(t.serifLogo.fontWeight, FontWeight.w300);
  });
  test('serifBrand is Cormorant w300 72', () {
    expect(t.serifBrand.fontFamily, 'CormorantGaramond');
    expect(t.serifBrand.fontSize, 72);
    expect(t.serifBrand.fontWeight, FontWeight.w300);
    expect(t.serifBrand.height, 1.0);
  });
  test('scaled() scales the serif variants', () {
    final s = InkTypography.defaults().scaled(2.0);
    expect(s.serifTitle.fontSize, 64);
    expect(s.serifBrand.fontSize, 144);
  });
});
```

- [ ] **Step 2: Run it, watch it fail** — `flutter test test/theme/tokens_test.dart` → FAIL (`serifTitle` not defined).

- [ ] **Step 3: Implement** in `lib/theme/typography.dart`:

3a. Add three constructor params (after `code` in the `const InkTypography({...})` list):
```dart
    required this.serifTitle,
    required this.serifLogo,
    required this.serifBrand,
```

3b. Add three fields (after `final TextStyle code;`):
```dart
  final TextStyle serifTitle; // Cormorant w400 32 —— 节区大标题
  final TextStyle serifLogo;  // Cormorant w300 19 —— chrome 品牌字
  final TextStyle serifBrand; // Cormorant w300 72 —— Lock 巨型品牌字
```

3c. In the `defaults` factory, after the `code: TextStyle(...)` entry, add (reuse the same `fontFamilyFallback` serif list as `display`):
```dart
        serifTitle: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: const <String>[
            'PingFang SC', 'Microsoft YaHei', 'Noto Serif CJK SC', 'Noto Sans CJK SC',
          ],
          fontSize: 32 * scale,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.32,
          height: 1.1,
        ),
        serifLogo: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: const <String>[
            'PingFang SC', 'Microsoft YaHei', 'Noto Serif CJK SC', 'Noto Sans CJK SC',
          ],
          fontSize: 19 * scale,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.19,
          height: 1.0,
        ),
        serifBrand: TextStyle(
          fontFamily: 'CormorantGaramond',
          fontFamilyFallback: const <String>[
            'PingFang SC', 'Microsoft YaHei', 'Noto Serif CJK SC', 'Noto Sans CJK SC',
          ],
          fontSize: 72 * scale,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.72,
          height: 1.0,
        ),
```

3d. In `scaled(double scale)`, add three entries to the returned `InkTypography(...)`:
```dart
        serifTitle: serifTitle.copyWith(fontSize: (serifTitle.fontSize ?? 32) * scale),
        serifLogo: serifLogo.copyWith(fontSize: (serifLogo.fontSize ?? 19) * scale),
        serifBrand: serifBrand.copyWith(fontSize: (serifBrand.fontSize ?? 72) * scale),
```

- [ ] **Step 4: Run it, watch it pass** — `flutter test test/theme/tokens_test.dart` → PASS. Then `flutter analyze` (catches any other construction site of `InkTypography` that now needs the new required params — there should be none beyond `defaults`, but fix if analyze flags one).

- [ ] **Step 5: Commit**

```bash
git add lib/theme/typography.dart test/theme/tokens_test.dart
git commit -m "$(cat <<'EOF'
feat(theme): add serifTitle/serifLogo/serifBrand Cormorant variants

Mockups use Cormorant at 32/w400 (section titles), 19/w300 (chrome logo),
72/w300 (Lock brand). Adds them as first-class typography tokens so screens
stop doing ad-hoc copyWith with the wrong weight.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.3 — Unify window chrome to 44px / surface1 / 30×26 buttons

**Files:**
- Modify: `lib/theme/components/ink_window_chrome.dart` (height ~25, bg ~30, win-button ~123-124)
- Test: `test/theme/ink_window_chrome_test.dart` (create if absent)

This is shared by Lock/Studio/Canvas/Settings — fixing it once aligns the chrome metric everywhere.

- [ ] **Step 1: Write the failing test** — `test/theme/ink_window_chrome_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_window_chrome.dart';
import 'package:inkframe/theme/tokens.dart';
import '../helpers/pump_app.dart'; // existing test helper that wraps ProviderScope + theme

void main() {
  testWidgets('chrome bar is InkLayout.chromeHeight tall', (tester) async {
    await pumpApp(tester, const InkWindowChrome(leading: Text('x')));
    final size = tester.getSize(find.byType(InkWindowChrome));
    expect(size.height, InkLayout.chromeHeight); // 44
  });
}
```

> If `test/helpers/pump_app.dart` does not exist, inline a minimal `MaterialApp` + `ProviderScope` wrapper with `buildAppTheme()` instead; check `test/` for the existing pattern first (`grep -rn "pumpWidget" test/ | head`).

- [ ] **Step 2: Run it, watch it fail** — `flutter test test/theme/ink_window_chrome_test.dart` → FAIL (height is 56).

- [ ] **Step 3: Implement** in `lib/theme/components/ink_window_chrome.dart`:
  - Replace the hardcoded `height: 56` (the `SizedBox`/`Container` and any `preferredSize`) with `InkLayout.chromeHeight`.
  - Replace the chrome background `colors.surfaceCanvas` with `colors.surface1`.
  - Replace the window-button box `width: 40` / `height: 32` with `InkLayout.winBtnWidth` / `InkLayout.winBtnHeight`.

- [ ] **Step 4: Run it, watch it pass** — `flutter test test/theme/ink_window_chrome_test.dart` → PASS. Then `flutter test` (full) + `flutter analyze` to confirm no screen that assumed 56px broke (e.g. a `preferredSize` consumer in `studio_top_chrome.dart` / `canvas_top_chrome.dart` — update those to `InkLayout.chromeHeight` if they referenced 56).

- [ ] **Step 5: Commit**

```bash
git add lib/theme/components/ink_window_chrome.dart lib/features/*/widgets/*top_chrome.dart test/theme/ink_window_chrome_test.dart
git commit -m "$(cat <<'EOF'
fix(theme): chrome bar 44px on surface1 with 30x26 window buttons

Matches mockup _shared.css .chrome (44h, surface-1 bg) and .win-ctrl
(30x26). Shared across Lock/Studio/Canvas/Settings.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 0.4 — Prove the screenshot harness

**Files:** none modified.

- [ ] **Step 1:** Re-render mockup refs (harness section command (a)) → confirm `/tmp/mk-ref/{01-lock,02-studio-home,03-canvas}.png` exist.
- [ ] **Step 2:** `flutter run -d macos`, unlock with a real provider key, and `screencapture -w /tmp/app-lock.png` the window. `open` it beside `/tmp/mk-ref/01-lock.png`. Confirm you can visually compare. This proves the loop before any screen work; if the macOS build fails, resolve pods (`cd macos && pod install`) before proceeding — do NOT continue blind.

---

# Phase 1 — Lock Screen

**Goal:** Lock renders ≥ 90 % to `01-lock.html`. Ship as one PR. (Source deltas: Lock audit — H1–H4, M1–M6, L1–L2.)

### Task 1.1 — Working `中 / EN` language chip (replaces no-op ghost button)

**Files:**
- Create: `lib/features/lock/widgets/lock_lang_chip.dart`
- Modify: `lib/features/lock/lock_screen.dart` (top-right, replace the `InkGhostButton(label: '中 / EN', onPressed: () {})`)
- Test: `test/features/lock/lock_lang_chip_test.dart`

The mockup chip is a bordered pill: `surface1` bg, 1px `border`, `InkRadius.bentoBtn` (6) radius, two mono segments; active segment is `accent` on `surface2`, `/` divider is `fg4`. Tapping a segment sets the locale.

- [ ] **Step 1: Write the failing test**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inkframe/features/lock/widgets/lock_lang_chip.dart';
import 'package:inkframe/core/di/locale_controller.dart'; // localeControllerProvider
// + your standard test theme wrapper

void main() {
  testWidgets('tapping EN sets locale to en', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: LockLangChip())),
    ));
    await tester.tap(find.text('EN'));
    await tester.pump();
    expect(container.read(localeControllerProvider)?.languageCode, 'en');
  });
}
```

> Verify the exact provider name/shape first: `grep -rn "localeController\|localePreference" lib/core/di`. Use whatever setter the controller exposes (e.g. `.setLocale(...)`).

- [ ] **Step 2: Run it, watch it fail** — FAIL (`LockLangChip` undefined).

- [ ] **Step 3: Implement** `lib/features/lock/widgets/lock_lang_chip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/locale_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';

/// Lock 屏右上角语言切换 chip（中 / EN）。
class LockLangChip extends ConsumerWidget {
  const LockLangChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final current = ref.watch(localeControllerProvider)?.languageCode ?? 'zh';
    Widget seg(String label, String code) {
      final active = current == code;
      return GestureDetector(
        onTap: () => ref.read(localeControllerProvider.notifier).setLocale(Locale(code)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm, vertical: InkSpacing.xs),
          color: active ? c.surface2 : null,
          child: Text(label, style: t.caption.copyWith(color: active ? c.accent : c.fg3)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface1,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('中', 'zh'),
        Text('/', style: t.caption.copyWith(color: c.fg4)),
        seg('EN', 'en'),
      ]),
    );
  }
}
```

> Adjust `localeControllerProvider.notifier).setLocale(...)` to the real API discovered in Step 1.

- [ ] **Step 4:** In `lock_screen.dart`, replace the top-right `InkGhostButton(...)` with `const LockLangChip()`. Run `flutter test test/features/lock/lock_lang_chip_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lock/widgets/lock_lang_chip.dart lib/features/lock/lock_screen.dart test/features/lock/lock_lang_chip_test.dart
git commit -m "feat(lock): bordered 中/EN language chip with working locale toggle" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.2 — `OFFLINE · LOCAL ONLY` corner marker + version dot separator

**Files:**
- Modify: `lib/features/lock/lock_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/lock/lock_screen_test.dart`

- [ ] **Step 1: Add i18n key** to BOTH ARB files (identical key sets — CI enforces):

`app_en.arb`:
```json
"lockOfflineLocalOnly": "OFFLINE · LOCAL ONLY",
"@lockOfflineLocalOnly": { "description": "Lock screen bottom-right privacy marker" },
```
`app_zh.arb`:
```json
"lockOfflineLocalOnly": "离线 · 仅本地",
```
Then run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test** — in `lock_screen_test.dart`, pump `LockScreen` and assert:
```dart
expect(find.text('OFFLINE · LOCAL ONLY'), findsOneWidget);
```
Run → FAIL.

- [ ] **Step 3: Implement** — in the Lock `Stack`, add bottom-right:
```dart
Positioned(
  right: InkSpacing.lg, bottom: InkSpacing.md,
  child: Text(context.l10n.lockOfflineLocalOnly,
      style: context.inkTypography.caption.copyWith(color: context.inkColors.fg3, letterSpacing: 0.88)),
),
```
And change the bottom-left version line to use a dimmed dot separator via `Text.rich`:
```dart
Text.rich(TextSpan(style: t.caption.copyWith(color: c.fg3, letterSpacing: 0.88), children: [
  TextSpan(text: 'v${info.version}'),
  TextSpan(text: ' · ', style: TextStyle(color: c.fg4)),
  TextSpan(text: info.buildNumber),
])),
```

- [ ] **Step 4: Run** `flutter test test/features/lock/lock_screen_test.dart` → PASS; `bash scripts/check-i18n-coverage.sh` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/lock/lock_screen.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb test/features/lock/lock_screen_test.dart
git commit -m "feat(lock): OFFLINE·LOCAL ONLY marker + dimmed-dot version line" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

### Task 1.3 — Privacy help copy rewrite (with bold keychain span)

**Files:** `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/features/lock/lock_screen.dart`

The current copy is wrong (it talks about "your provider dashboard"/"our servers"). Mockup copy: line 1 `Keys never leave this machine. Stored in your **OS keychain**.`, line 2 `We don't phone home. Once you unlock, the desk is yours.`

- [ ] **Step 1:** Rewrite `lockKeyHelpLine1` / `lockKeyHelpLine2` values in BOTH ARB files. Suggested zh: `密钥永不离开本机，存于系统钥匙串。` / `我们不回传任何数据，解锁后这张案头就归你了。` Run `flutter gen-l10n`.
- [ ] **Step 2:** Render line 1 as `Text.rich` with the "OS keychain"/"系统钥匙串" phrase in `c.fg2` weight 500; merge the two lines into one block with `height: 1.7` (drop the `SizedBox` gap). Caption (mono) style throughout.
- [ ] **Step 3:** `flutter test` + `bash scripts/check-i18n-coverage.sh` → PASS.
- [ ] **Step 4: Commit** `fix(lock): privacy help copy matches mockup + bold keychain span`.

### Task 1.4 — Lock polish pass (batched ALIGN tweaks)

**Files:** `lib/features/lock/lock_screen.dart`, `lib/features/lock/widgets/lock_logo.dart`, `lib/features/lock/widgets/lock_secure_field.dart`, `lib/theme/primitives/ink_amber_button.dart`

Apply each row exactly. These are visual-fidelity tweaks; verify via the screenshot harness, not a unit test.

| # | File | Change |
|---|---|---|
| 1 | `lock_logo.dart` | Use `t.serifBrand` for the brand (replaces `display.copyWith(fontSize:72)`); add `SizedBox(width: 2)` each side of the `/`; remove the `FittedBox(scaleDown)` so it stays 72px. |
| 2 | `lock_secure_field.dart` | Field height → `InkLayout.controlHeight` (44); text + hint style → `t.caption.copyWith(fontSize: 13, color: ...)` (mono); add a `FocusNode` listener flipping the bottom border to `c.accent` on focus. |
| 3 | `lock_screen.dart` | Tagline `letterSpacing: 4.5` → `4.62`; help-block already handled in 1.3. |
| 4 | `ink_amber_button.dart` | Label `FontWeight.w500` → `w600`; button height literal `44` → `InkLayout.controlHeight`. (Shared by Studio FAB too — intended.) |
| 5 | `lock_screen.dart` | Decide M1: keep the 56→44 chrome (now 44 from Phase 0) OR remove chrome on Lock per mockup's chrome-less floating-controls layout. **Recommended: keep chrome** (consistency across screens) and verify the centered column + decorative "I" bleed still match after the height change. |

- [ ] **Step 1:** Apply rows 1–5. Run `flutter analyze` + `flutter test` → green.
- [ ] **Step 2:** Screenshot-diff harness: `screencapture -w /tmp/app-lock.png`; `open /tmp/app-lock.png /tmp/mk-ref/01-lock.png`. Confirm ≥ 90 %.
- [ ] **Step 3: Commit** `fix(lock): brand/field/button polish to match mockup`.

### Task 1.5 — Lock phase PR

- [ ] Push branch; `gh pr create` titled `fix(ui): align Lock screen with mockup` summarizing Tasks 1.1–1.4 + the Phase 0 dependency.

---

# Phase 2 — Studio Home

**Goal:** Studio renders ≥ 90 % to `02-studio-home.html`. Ship as one PR. (Source deltas: Studio audit H1–H6, M1–M13, L1–L11.) Order: structure → controls → cards → polish.

### Task 2.1 — Title row with Grid/List switch + Sort control

**Files:**
- Create: `lib/features/studio/controllers/studio_view_mode.dart`
- Modify: `lib/features/studio/studio_home_screen.dart` (title block ~113-122)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Test: `test/features/studio/studio_view_mode_test.dart`

- [ ] **Step 1:** Add i18n keys to BOTH ARB files: `studioViewGrid` ("Grid"/"网格"), `studioViewList` ("List"/"列表"), `studioSortUpdated` ("Sort: Updated"/"排序：更新时间"). `flutter gen-l10n`.
- [ ] **Step 2: Write failing test** for the providers:
```dart
test('view mode defaults to grid and toggles', () {
  final c = ProviderContainer(); addTearDown(c.dispose);
  expect(c.read(studioViewModeProvider), StudioViewMode.grid);
  c.read(studioViewModeProvider.notifier).state = StudioViewMode.list;
  expect(c.read(studioViewModeProvider), StudioViewMode.list);
});
```
Run → FAIL.
- [ ] **Step 3: Implement** `studio_view_mode.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
enum StudioViewMode { grid, list }
final studioViewModeProvider =
    StateProvider.autoDispose<StudioViewMode>((ref) => StudioViewMode.grid);
```
- [ ] **Step 4:** Build the title `Row(mainAxisAlignment: spaceBetween, crossAxisAlignment: end)`: left = `Text(l10n.studioRecentProjects, style: t.serifTitle)`; right = a bordered 2-segment Grid/List toggle (mono caption, active = `accent` on `surface2`, radius `InkRadius.bentoBtn`) + a ghost `Sort: Updated ▾` button. Wire the toggle to `studioViewModeProvider`. (List-mode rendering itself can be a follow-up; the switch + state ship now and grid stays the default.)
- [ ] **Step 5: Run** test + i18n check → PASS. **Commit** `feat(studio): title row with Grid/List switch and Sort control`.

### Task 2.2 — Sidebar alignment

**Files:** `lib/features/studio/widgets/library_sidebar.dart`

| # | Change | Source delta |
|---|---|---|
| 1 | Width `280` → `InkLayout.sidebarWidth` (248) | M2 |
| 2 | Selected row: bg `surface3` → `surface2`; add a 2px left accent rail (`Container(width:2, color: accent)` via a `Stack`/`Border`) | M3, M4 |
| 3 | Section `+` affordance: render only for the Library section, not Archive (gate `_SectionLabel`'s trailing add) | M5 |
| 4 | Tree indent: base left `24`→`20`, step `16` (so 20/36/52) | L6 |
| 5 | Section label: size `11`→`10`, color `fg3`→`fg4`, keep `letterSpacing: 2` | L7 |
| 6 | Footer: `MainAxisAlignment.spaceBetween` → left cluster `Row(spacing via SizedBox 12)`; icon order tags/people/settings/trash | L5 |
| 7 | Archived count `'0'` → bind to a real archived count (or hide when 0) | L8 |
| 8 | "Projects" tree label literal → new i18n key `studioProjectsLabel` (add to both ARB) | L11 |

- [ ] Apply rows 1–8 (+ ARB key for row 8, `flutter gen-l10n`). `flutter analyze` + `flutter test` → green. Screenshot-diff the sidebar region. **Commit** `fix(studio): sidebar width/selection/indents/footer to match mockup`.

### Task 2.3 — Project card cinematic thumbnails + meta

**Files:** `lib/features/studio/widgets/project_card.dart`, `lib/features/studio/studio_home_screen.dart`, `lib/features/studio/models/project_with_canvases.dart`

- [ ] **Step 1: Thumbnails (H2):** when a real project thumbnail exists, render it; otherwise paint a placeholder that varies per card. Add a small set of token-derived gradient variants (cycle by index) + a bottom vignette (`radial-gradient`-equivalent via a `Stack` + `DecoratedBox` with `Alignment`-based `RadialGradient`). Keep all colors from `context.inkColors` (no raw hex). The 8 mockup palettes (night/dock/fog/ember/dawn/character/watch/prop) can be approximated with `surface*`/`accent`/`info`/`danger`/`warning` tints — do NOT hardcode the mockup's raw hex; derive from tokens with opacity.
- [ ] **Step 2: Meta (H3):** the meta line is currently a hardcoded `'EP 01 · 2026.05 · …'`. Either (a) extend `ProjectWithCanvases` (freezed) with `episodeLabel`, `updatedAt`, `assetCount` and build the line from real fields, or (b) if that data isn't available from the repo yet, keep canvas-count but format the date from a real `updatedAt` if the model has one. **Pick (a) only if the repo already exposes these fields** — check `grep -n "updated\|episode\|asset" lib/storage/repositories/postgres_project_repository.dart`; if absent, this becomes a small data task or is deferred with a `// TODO(spec-v2)` and the line uses real canvas count + real date. Do not invent fake data silently.
- [ ] **Step 3: Name line-height (M13):** card name `t.headline.copyWith(height: 1.1)`. Meta `letterSpacing` `1` → `0.4` (L1).
- [ ] **Step 4:** `flutter analyze` + `flutter test`; screenshot-diff the grid. **Commit** `fix(studio): cinematic card thumbnails + name/meta polish`.

### Task 2.4 — 4-column grid + FAB + chrome trailing + banner polish

**Files:** `studio_home_screen.dart`, `studio_top_chrome.dart`, `studio_provider_banner.dart`

| # | Change | Delta |
|---|---|---|
| 1 | Grid columns: `maxWidth >= 1280 ? 4 : 3` → fixed 4 columns (or lower breakpoint) so the default workspace width shows 4 | H5 |
| 2 | Grid `childAspectRatio: 16/14.5` → tune so the body isn't clipped at 4 cols (or use an intrinsic-height grid) | L4 |
| 3 | FAB insets `32` → `36`; label weight already w600 from Task 1.4 | M11, M12 |
| 4 | Chrome trailing: drop `⌘K` pill + avatar; render two ghost icon buttons (⌥ view-options, ⚑ flag) per mockup | H1 |
| 5 | Breadcrumb middle segment `Text('Projects')` literal → i18n `studioProjectsLabel` (reuse Task 2.2 key) | L10 |
| 6 | Provider banner: bold lead-in clause in `fg1`; action label append `→`; wrap warning dot in a translucent-warning glow ring | M6, M7 |

- [ ] Apply rows 1–6. `flutter analyze` + `flutter test` → green. Full Studio screenshot-diff vs `/tmp/mk-ref/02-studio-home.png` → ≥ 90 %. **Commit** `fix(studio): 4-col grid, FAB, chrome trailing, banner polish`.

### Task 2.5 — Studio phase PR

- [ ] Push; `gh pr create` titled `fix(ui): align Studio Home with mockup`.

---

# Phase 3 — Canvas

**Goal:** Canvas renders ≥ 90 % to `03-canvas.html` (compact render queue included; full task-queue view is out of scope). Ship as one PR. This phase has **architecture cleanup**, not just restyling — do those first.

> **Architecture findings to resolve first (from the Canvas audit):**
> 1. The live tree renders nodes via `node_card.dart`, but a mockup-faithful `canvas_node_card.dart` already exists and is **never mounted** (dead code). → Consolidate onto `canvas_node_card.dart`, delete `node_card.dart`.
> 2. `canvas_screen.dart` mounts `CanvasInspector` fed **hardcoded mock strings**, while the *real* `NodeInspectorRouter` is rendered separately inside `canvas_view.dart`. → Two inspectors exist; keep the real one, delete/replace the mock.

### Task 3.1 — Consolidate node cards onto `canvas_node_card.dart`

**Files:** `lib/features/canvas/widgets/canvas_node_card.dart`, `node_card.dart` (delete), `canvas_view.dart` (swap the widget used to render nodes), tests.

- [ ] **Step 1:** Confirm where live nodes are instantiated: `grep -rn "node_card\|NodeCard\|CanvasNodeCard" lib/features/canvas`. Identify the call site in `canvas_view.dart` that builds `NodeCard`.
- [ ] **Step 2: Write/extend a widget test** asserting a rendered node shows: the type stripe, a serif title, a 16:9 thumb frame, and a mono `ID … | …×…` footer (finders by text/key). Run → FAIL (live `NodeCard` lacks these).
- [ ] **Step 3:** Point the call site at `CanvasNodeCard`. Fix inside `canvas_node_card.dart`: stripe height `4`→`3`; `shot` type stripe `border`→`borderHover`; node width literal → `InkLayout.nodeWidth` (200); node radius → `InkRadius.md` (8, per mapping table); title → `t.serifTitle.copyWith(fontSize: 14)` or a 14px serif; mono footer via `t.caption.copyWith(...)` (remove inline `fontFamily:'JetBrainsMono'`); selected border 1px accent (drop heavy `InkShadow.elevated`); hover border → `borderHover`.
- [ ] **Step 4:** Delete `node_card.dart`. `flutter analyze` (catches dangling imports) → fix; `flutter test` → PASS.
- [ ] **Step 5: Commit** `refactor(canvas): single node card (CanvasNodeCard), delete dead duplicate`.

### Task 3.2 — Resolve duplicate inspector

**Files:** `canvas_screen.dart`, `canvas_inspector.dart`, `canvas_view.dart`, `node_inspector_router.dart`

- [ ] **Step 1:** Decide the single owner of the right rail. **Recommended:** let `NodeInspectorRouter` (already real, selection-driven) own the right `InkLayout.inspectorWidth` rail; remove the mock `CanvasInspector` mount from `canvas_screen.dart`. If you instead keep `CanvasInspector` as the shell, back its header + KV rows + Notes with the selected node's real attributes (delete every hardcoded literal: `canvasInspectorMock*`, `Position 140,220,0`, the English Notes string).
- [ ] **Step 2:** Ensure exactly one inspector renders for a selected node (no "Wide Shot" mock panel alongside the real one). Add/extend a widget test: select a node → its real id appears in the inspector; no mock title present.
- [ ] **Step 3:** Header id-line format → `{TYPE} NODE · ID {id} · UPD {ts}` (add i18n `inspectorUpdatedAt` to both ARB if you surface the timestamp; otherwise omit the UPD segment rather than faking it). Replace inline `fontFamily:'JetBrainsMono'` + magic letterSpacing with `t.caption.copyWith(...)`.
- [ ] **Step 4:** `flutter analyze` + `flutter test` → green. **Commit** `refactor(canvas): single selection-driven inspector, drop mock panel`.

### Task 3.3 — Amber bezier edges (replace straight-line + arrowheads)

**Files:** `lib/features/canvas/widgets/edge_painter.dart`

- [ ] **Step 1:** Replace `canvas.drawLine(...)` center-to-center + triangle arrowheads with cubic beziers: `Path()..moveTo(start)..cubicTo(c1, c2, end)` using horizontal tangents (control points offset horizontally by ~half the dx) — matching the mockup's left→right node flow. Remove arrowheads.
- [ ] **Step 2:** Stroke: default `c.accent.withValues(alpha: 0.55)` width 1.6; `live` edges full `c.accent` width 1.8 with a soft glow (`Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)` underlay, or `drawShadow`). Keep colors from tokens.
- [ ] **Step 3:** Existing `edge_painter` tests (if any) — update expectations; if none, add a smoke test that the painter paints without throwing for a sample edge set. `flutter test` → PASS.
- [ ] **Step 4: Commit** `fix(canvas): amber cubic-bezier wires with live glow, no arrowheads`.

### Task 3.4 — Canvas backdrop: dot grid + zoom pill + hint strip

**Files:** `lib/features/canvas/widgets/canvas_view.dart` (+ small new private widgets in-file or `chrome_view_nav.dart` sibling), i18n ARB.

- [ ] **Step 1: Dot grid (H, canvas/nodes):** background fill `surface1`→`surfaceCanvas`; add a `CustomPaint` dot-grid layer behind nodes — `rgba`-equivalent dots from `c.fg4` at low opacity, ~22px spacing, 1px. Paint it as the lowest layer of the canvas `Stack`.
- [ ] **Step 2: Zoom pill (NET-NEW):** `Positioned(top: 12, left/right centered)` pill — `surface2` bg, `border`, `InkRadius.pill`, mono caption — showing `{zoom}% − [track] + 🔒 60 FPS` (FPS in `c.success`). Read the zoom from the existing `InteractiveViewer`/transform controller (`grep -n "InteractiveViewer\|TransformationController\|scale" lib/features/canvas`). Add i18n `canvasFpsLabel` if you localize "FPS".
- [ ] **Step 3: Hint strip (NET-NEW):** `Positioned(bottom, centered)` mono micro strip `Pan [Space]  Zoom [⌘+/−]  Add Node [A]  Connect [C]  Frame [F]` with accent keycaps. Add i18n keys `canvasHintPan/Zoom/AddNode/Connect/Frame` (both ARB). `flutter gen-l10n`.
- [ ] **Step 4:** Widget smoke test: canvas renders the zoom pill + hint strip without throwing. `flutter analyze` + `flutter test` + i18n check → green. **Commit** `feat(canvas): dot-grid backdrop, zoom pill, keyboard-hint strip`.

### Task 3.5 — Top chrome view-nav tabs + breadcrumb + export icon

**Files:** Create `lib/features/canvas/widgets/chrome_view_nav.dart`; modify `canvas_top_chrome.dart`; ARB.

- [ ] **Step 1:** Add i18n keys `chromeViewCanvas/Storyboard/Script/Generation/Queue` (both ARB). `flutter gen-l10n`.
- [ ] **Step 2:** Build `ChromeViewNav` — a mono caption tab row; active tab = `accent` on `surface2` pill. For now only "Canvas" is a real route; the others can be visually present but inert (or disabled) — match the mockup look without wiring nonexistent screens.
- [ ] **Step 3:** In `canvas_top_chrome.dart`: place the breadcrumb **left-aligned** right after the logo (not centered — the mockup never centers it); feed real `project › episode › view` names. Insert `ChromeViewNav` after the breadcrumb. Logo → `t.serifLogo` (19/w300). Trailing: add an export/download `ico-btn` (`Icons.file_download`) beside play; drop the `⌘K` pill + avatar (canvas mockup has neither). Window buttons already 30×26 from Phase 0. Optionally drop the separate "Studio" back chip (mockup's back affordance is the logo).
- [ ] **Step 4:** Widget test: the five tab labels render; "Canvas" is active. `flutter test` + i18n check → green. **Commit** `feat(canvas): chrome view-nav tabs + left breadcrumb + export icon`.

### Task 3.6 — Left toolbar: lower tool group + separator + More + tooltips

**Files:** `lib/features/canvas/widgets/canvas_left_toolbar.dart`; ARB; `tokens.dart` (one token).

- [ ] **Step 1:** Add an `accentBorderSubtle` color or reuse: the active-tool border uses `accent @ 0.35`. To avoid the inline magic alpha, either add `static const double subtleAlpha = 0.35;` somewhere central or keep `c.accent.withValues(alpha: 0.35)` with a `// mockup .tool.active` comment. (Lightweight — a full new color token is optional.)
- [ ] **Step 2:** Add the lower tool group after a 28px `borderSubtle` separator: Undo `↶` / Redo `↷` / Center `⊙` / Snap `⊞`, then a flex spacer, then a bottom More `⋯` button. Use Material icons closest to each (`undo`, `redo`, `center_focus_strong`, `grid_4x4`, `more_horiz`).
- [ ] **Step 3:** Wrap every tool button in a `Tooltip` with a new i18n key (`toolSelect/Pan/Box/Connect/Shape/Text/Image/Tool3d/Undo/Redo/Center/Snap/More`) — both ARB. `flutter gen-l10n`.
- [ ] **Step 4:** Widget test: toolbar renders the expected number of tool buttons + separator. `flutter test` + i18n check → green. **Commit** `feat(canvas): full left toolbar (lower group, separator, More, tooltips)`.

### Task 3.7 — Compact render queue: real data + format + halo

**Files:** `lib/features/canvas/widgets/canvas_render_queue.dart`; ARB.

- [ ] **Step 1:** Replace the hardcoded `'3 · 2 ▾'` header and the three mock job rows with real data from `jobQueueServiceProvider` (`grep -n "jobQueue\|activeJobs" lib/services lib/features/generation`). Header text via a plural-aware i18n key `renderQueueHeaderCount` → "{n} jobs · {m} running" (both ARB, ICU plural if needed). `flutter gen-l10n`.
- [ ] **Step 2:** Running dot: add the translucent `cta @ 0.18` glow ring (outer container) per mockup. Replace inline `fontFamily:'JetBrainsMono'` with `t.caption.copyWith(...)`. Progress bar geometry already matches (height 3, surface3 track, cta fill, left:18).
- [ ] **Step 3:** Widget test with an overridden `jobQueueServiceProvider` exposing 0 / 1 / N jobs → header text + row count render correctly (and the empty state is sane). `flutter test` + i18n check → green. **Commit** `feat(canvas): render queue bound to real job data + running halo`.

### Task 3.8 — Canvas phase PR

- [ ] Push; `gh pr create` titled `fix(ui): align Canvas with mockup (nodes, edges, inspector, chrome, queue)` summarizing the architecture cleanup + visual alignment.

---

## Out-of-Scope Follow-ups (do NOT do in this plan — for the user)

These surfaced during the audit and need their own specs/plans (most need new data/state, which the design spec §9 already deferred to "spec v2"):

1. **Settings redesign** — provider management table (status/role/quota/endpoint), persisted operation preferences (+ `InkToggle` component + settings table), editable rate limits. Feature work.
2. **Full Task-Queue screen** (`04-task-queue.html`) — needs a route + real job data view.
3. **Storyboard / Script Editor / Asset Library / Asset Generation / Account / Toasts / Error States** — net-new feature screens (mockups 05–08, 10–12).

---

## Self-Review

- **Spec coverage:** Every Lock delta (H1–H4/M1–M6/L1–L2) maps to Tasks 1.1–1.4. Studio deltas map to 2.1–2.4. Canvas deltas map to 3.1–3.7. Settings + unbuilt screens are explicitly carved out with rationale (design-spec §9 + missing data layer), not silently dropped.
- **Placeholder scan:** NET-NEW widgets (lang chip, view-nav, zoom pill, toolbar group) have full code or exact construction steps. The long-tail ALIGN tweaks are concrete `file → old → new` tables, not "make it match." The two spots with genuine unknowns (Studio card real-data fields in 2.3; locale controller API in 1.1) carry an explicit `grep` to confirm before coding, with a defined fallback — not a silent guess.
- **Type/name consistency:** `InkLayout`, `serifTitle/serifLogo/serifBrand`, `StudioViewMode`/`studioViewModeProvider`, `CanvasNodeCard`, `ChromeViewNav`, `LockLangChip` are used consistently across the tasks that reference them. Radius mapping table is the single source for every `--r-*` lookup.
- **Project-rule compliance baked in:** every new string → both ARB files + `gen-l10n` + `check-i18n-coverage.sh`; new metrics → `InkLayout`/typography tokens (zero hardcoded styles); TDD where structurally testable, screenshot-diff where it's pure pixels (design-spec §6 forbids goldens this round); freezed for any model change (2.3); conventional commits; protected-branch policy respected.
- **Known soft spots:** (1) the screenshot harness needs manual navigation (unlock/open project/open canvas) — Task 0.4 proves the loop before any screen work so a broken build is caught early. (2) Phase 3 is ~2× the size of Phase 1/2 and front-loads architecture cleanup; it is independently shippable but the largest review.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-29-flutter-mockup-alignment.md`. **Per project rule, do not start coding until the user approves** (and confirms the scope assumption at the top — Flutter-vs-mockup, not HTML-mockup polishing).

Two execution options once approved:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task; review diff + screenshot between tasks; fast iteration. Natural checkpoints: end of Phase 0, end of each screen phase (before its PR).

**2. Inline Execution** — execute tasks in this session with checkpoints at Task 0.4 / 1.5 / 2.5 / 3.8.

Each phase is its own shippable PR, so phases can also be parceled to different people/agents in parallel after Phase 0 lands (Phase 0 is the shared dependency).
