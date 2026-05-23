# HTML Mockup ↔ PNG Reference Alignment Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Patch the 12 existing HTML mockups in `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/` so each renders ≥ 90 % faithful to its reference PNG in `IF.zip` (extracted to `/tmp/if-mockups/IF/`), without rewriting working files.

**Architecture:** Targeted CSS / markup patches per file. One shared addition (`_shared.css` gets a `.fake-thumb-*` library so 4 mockups can stop using empty placeholders). All other edits are surgical: rename a colliding class, brighten an SVG stroke, drop a tab, swap menu labels. Headless Chrome (`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --screenshot`) is the verification harness — re-shoot each touched file at 1536×1024 and eyeball-diff against its PNG twin.

**Tech Stack:** Plain HTML + CSS + SVG. No JS. No build step. Reference fonts loaded from Google Fonts CDN; Amber Noir tokens already in `_shared.css`.

**Reference materials:**
- Reference PNGs: `/tmp/if-mockups/IF/*.png` (12 files, 1536×1024)
- HTML mockups under audit: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/*.html`
- Audit baseline screenshots: `/tmp/if-mockups/html-shots/*.png` (taken 2026-05-23)
- Token source of truth: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/_shared.css`

**Branch policy:** `main` is protected (project rule: feature branch + PR only). All work goes on `feat/ui-mockup-png-alignment`.

---

## Audit Summary (the "spec")

Each HTML was screenshotted with Chrome headless at 1536×1024 and compared visually against its PNG twin.

| # | Screen | Match | Concrete diff | Fix in task |
|---|---|---|---|---|
| 01 | Lock | ★★★★☆ | Tagline wrapped in `.tag` pill — global `.tag` rule applies border + radius. PNG has plain spaced caps, no pill. | Task 8 |
| 02 | Studio Home | ★★★☆☆ | Card thumbnails are empty radial-gradient placeholders. PNG shows cinematic still frames. | Task 2 |
| 03 | Canvas | ★★★☆☆ | SVG bezier wires use `stroke: var(--fg-4)` (= `#5A5048`) + `stroke-dasharray: 4 4` + 1.4px width — invisible against the dot grid. PNG wires are bright amber, solid. | Task 5 |
| 04 | Task Queue | ★★★★☆ | Same wire-dimness issue (smaller impact) — accept current state for this pass. | (none) |
| 05 | Storyboard | ★★★★☆ | Thumbnail column empty placeholders. | Task 3 |
| 06 | Script Editor | ★★★★☆ | Floating menu actions are 编辑/加镜头/加角色/移除. PNG has 编辑/复制/批注/删除/历史. | Task 9 |
| 07 | Asset Library | ★★★★☆ | Gallery tiles empty placeholders. | Task 4 |
| 08 | Asset Generation | ★★★★☆ | 4 tabs (人物/场景/道具/**其他**) — PNG only has 3. Candidate slots empty. | Tasks 4 + 7 |
| 09 | Settings | ★★★★★ | — | (none) |
| 10 | Account | ★★★★★ | — | (none) |
| 11 | Toasts | ★★☆☆☆ | **CSS bug**: each toast has `<div class="body">` which is matched by the page-level `.body { display: flex }` selector in `_shared.css`, so title/msg/actions render as horizontal flex items → text scatters. Also 2×2 grid vs PNG's vertical stack at bottom-right over canvas backdrop. | Task 6 |
| 12 | Error States | ★★★★★ | — | (none) |

**Untouched files:** 04 (Task Queue), 09 (Settings), 10 (Account), 12 (Error States) — already ≥ 90 % match.

---

## File Map

### Modifications

```
docs/superpowers/specs/2026-05-13-ui-redesign/mockups/
├── _shared.css                       # +fake-thumb library (Task 1)
├── 01-lock.html                      # tagline depill (Task 8)
├── 02-studio-home.html               # apply fake-thumb to 8 cards (Task 2)
├── 03-canvas.html                    # brighten SVG edges (Task 5)
├── 05-storyboard.html                # apply fake-thumb to 6 row stills (Task 3)
├── 06-script-editor.html             # menu actions text (Task 9)
├── 07-asset-library.html             # apply fake-thumb to gallery (Task 4)
├── 08-asset-generation.html          # drop 其他 tab (Task 7) + fake-thumb candidates (Task 4)
└── 11-toasts.html                    # rename .body→.content + restack (Task 6)
```

No new files. No deletions.

---

## Task 0 — Feature Branch + Baseline Screenshots

**Files:** none modified.

- [ ] **Step 1:** Confirm on `main` and working tree clean

```bash
git status
git rev-parse --abbrev-ref HEAD
```

Expected: `On branch main`, `nothing to commit`.

- [ ] **Step 2:** Create feature branch

```bash
git checkout -b feat/ui-mockup-png-alignment
```

Expected: `Switched to a new branch 'feat/ui-mockup-png-alignment'`.

- [ ] **Step 3:** Capture baseline screenshots of all 12 mockups (for after-diff)

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT=/tmp/mockup-baseline
mkdir -p "$OUT"
for n in 01-lock 02-studio-home 03-canvas 04-task-queue 05-storyboard 06-script-editor 07-asset-library 08-asset-generation 09-settings 10-account 11-toasts 12-error-states; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
    --screenshot="$OUT/$n.png" \
    "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/$n.html" 2>/dev/null
done
ls -la "$OUT" | wc -l
```

Expected: 14 (12 PNGs + `.` + `..`).

---

## Task 1 — Fake-Thumb Library in `_shared.css`

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/_shared.css` (append after line 319)

**Why:** 4 mockups (02 / 05 / 07 / 08) currently render empty radial-gradient boxes where the PNG shows moody cinematic stills. A small CSS-only library of named atmospheric backgrounds lets each mockup invoke `.fake-thumb.thumb-dock` / `.thumb-watch` / `.thumb-night` / etc. without duplicating gradient strings.

- [ ] **Step 1:** Append the library block to the bottom of `_shared.css`

```css
/* ===== Fake cinematic thumbnails ===== */
/* Multi-layer gradient + film-grain noise overlay to fake a moody still
   without needing an actual image asset. Variants paint different scenes. */
.fake-thumb {
  position: relative;
  background-color: #0a0807;
  background-image: var(--ft-bg, none);
  background-size: cover;
  background-position: center;
  overflow: hidden;
}
.fake-thumb::after {
  content: "";
  position: absolute; inset: 0;
  background-image:
    radial-gradient(1.5px 1.5px at 14% 22%, rgba(232,223,208,0.18), transparent 60%),
    radial-gradient(1px 1px at 78% 64%, rgba(232,223,208,0.10), transparent 60%),
    radial-gradient(1px 1px at 36% 88%, rgba(232,223,208,0.08), transparent 60%),
    radial-gradient(1px 1px at 92% 18%, rgba(232,223,208,0.12), transparent 60%);
  pointer-events: none;
}
.fake-thumb::before {
  content: "";
  position: absolute; inset: 0;
  background:
    radial-gradient(ellipse at 50% 100%, rgba(0,0,0,0.55) 0%, transparent 55%);
  pointer-events: none;
}

/* Variant palette — keep tones inside the Amber Noir token range */
.thumb-night     { --ft-bg:
  radial-gradient(circle at 30% 40%, rgba(75,122,146,0.25) 0%, transparent 55%),
  linear-gradient(180deg, #14181f 0%, #07090c 100%); }
.thumb-dock      { --ft-bg:
  radial-gradient(circle at 70% 30%, rgba(201,168,91,0.20) 0%, transparent 50%),
  linear-gradient(160deg, #1c1812 0%, #08070a 100%); }
.thumb-watch     { --ft-bg:
  radial-gradient(circle at 50% 50%, rgba(227,166,72,0.32) 0%, rgba(58,42,22,0.6) 35%, #0a0807 80%); }
.thumb-character { --ft-bg:
  radial-gradient(circle at 50% 38%, rgba(201,168,91,0.18) 0%, transparent 55%),
  linear-gradient(180deg, #2a1f12 0%, #08060a 100%); }
.thumb-fog       { --ft-bg:
  radial-gradient(ellipse at 50% 60%, rgba(181,168,154,0.15) 0%, transparent 55%),
  linear-gradient(180deg, #1a1814 0%, #0a0907 100%); }
.thumb-dawn      { --ft-bg:
  radial-gradient(circle at 50% 80%, rgba(216,139,58,0.22) 0%, transparent 55%),
  linear-gradient(180deg, #14110e 0%, #06050a 100%); }
.thumb-ember     { --ft-bg:
  radial-gradient(circle at 40% 70%, rgba(200,82,58,0.18) 0%, transparent 50%),
  linear-gradient(140deg, #1c130e 0%, #08060a 100%); }
.thumb-prop      { --ft-bg:
  radial-gradient(circle at 60% 50%, rgba(216,139,58,0.16) 0%, transparent 55%),
  linear-gradient(180deg, #1f1812 0%, #0a0807 100%); }
```

- [ ] **Step 2:** Smoke-render the library — create `/tmp/ft-smoke.html` and screenshot

```bash
cat > /tmp/ft-smoke.html <<'HTML'
<!doctype html><html><head>
<link rel="stylesheet" href="file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/_shared.css">
<style>body{padding:20px;background:#0B0908}
.row{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}
.cell{aspect-ratio:16/10;border-radius:8px;border:1px solid #2A2522}
.label{color:#B5A89A;font-family:monospace;font-size:11px;margin-top:6px}
</style></head><body>
<div class="row">
<div><div class="cell fake-thumb thumb-night"></div><div class="label">thumb-night</div></div>
<div><div class="cell fake-thumb thumb-dock"></div><div class="label">thumb-dock</div></div>
<div><div class="cell fake-thumb thumb-watch"></div><div class="label">thumb-watch</div></div>
<div><div class="cell fake-thumb thumb-character"></div><div class="label">thumb-character</div></div>
<div><div class="cell fake-thumb thumb-fog"></div><div class="label">thumb-fog</div></div>
<div><div class="cell fake-thumb thumb-dawn"></div><div class="label">thumb-dawn</div></div>
<div><div class="cell fake-thumb thumb-ember"></div><div class="label">thumb-ember</div></div>
<div><div class="cell fake-thumb thumb-prop"></div><div class="label">thumb-prop</div></div>
</div></body></html>
HTML
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --window-size=1280,640 --screenshot=/tmp/ft-smoke.png file:///tmp/ft-smoke.html
```

Expected: `/tmp/ft-smoke.png` exists, eight distinct moody panels visible.

- [ ] **Step 3:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/_shared.css
git commit -m "$(cat <<'EOF'
feat(mockups): fake-thumb library for cinematic placeholders

Add .fake-thumb base + 8 named variants (night/dock/watch/character/fog/
dawn/ember/prop) so 02/05/07/08 mockups can stop using empty radial
gradients. Each variant stays inside the Amber Noir token palette and
adds noise + vignette overlays to look like a backed-off film still
without needing image assets.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 — Apply Fake-Thumb to 02 Studio Home

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/02-studio-home.html`

- [ ] **Step 1:** Delete the per-card `.proj.v1` … `.proj.v8 .still` gradient blocks (lines 64-70 in original) — these are replaced by shared variants.

In `02-studio-home.html`, remove these lines from the local `<style>` block:

```css
.proj.v2 .still { background: linear-gradient(160deg, #1f1410 0%, #0a0807 100%); }
.proj.v3 .still { background: linear-gradient(180deg, #1a1a22 0%, #0a0a0e 100%); }
.proj.v4 .still { background: radial-gradient(circle at 70% 30%, #2a1f12, #0a0807 70%); }
.proj.v5 .still { background: linear-gradient(120deg, #14110e, #221b13 100%); }
.proj.v6 .still { background: linear-gradient(200deg, #1a1612, #0a0807); }
.proj.v7 .still { background: linear-gradient(180deg, #2b1f15, #0c0a08); }
.proj.v8 .still { background: linear-gradient(180deg, #16100c, #0a0807); }
```

And simplify the base `.proj .still` block from:

```css
.proj .still {
  aspect-ratio: 16/10;
  border-bottom: 1px solid var(--border-subtle);
  background:
    radial-gradient(circle at 30% 40%, rgba(201,168,91,0.10) 0%, transparent 50%),
    linear-gradient(180deg, #1c1812 0%, #0c0a08 100%);
  position: relative;
}
.proj .still::after { … }
```

to:

```css
.proj .still {
  aspect-ratio: 16/10;
  border-bottom: 1px solid var(--border-subtle);
}
```

(The `::after` star-dots block is now redundant — `.fake-thumb::after` provides it.)

- [ ] **Step 2:** Change each `.proj` row's `<div class="still">` to `<div class="still fake-thumb thumb-XXX">` per below mapping (replace the existing 8 `.proj` lines around 157-164):

```html
<div class="proj"><div class="still fake-thumb thumb-night"></div><div class="body"><div class="name">Nocturne</div><div class="meta">EP 02 · 2024.06.20 · 📦 31</div></div></div>
<div class="proj"><div class="still fake-thumb thumb-dock"></div><div class="body"><div class="name">The Last Harbor</div><div class="meta">EP 01 · 2024.06.18 · 📦 22</div></div></div>
<div class="proj"><div class="still fake-thumb thumb-fog"></div><div class="body"><div class="name">Paper Reverie</div><div class="meta">EP 03 · 2024.06.10 · 📦 14</div></div></div>
<div class="proj"><div class="still fake-thumb thumb-ember"></div><div class="body"><div class="name">Eclipse Chronicle</div><div class="meta">EP 04 · 2024.06.07 · 📦 41</div></div></div>
<div class="proj"><div class="still fake-thumb thumb-dawn"></div><div class="body"><div class="name">Ashes of Tomorrow</div><div class="meta">EP 01 · 2024.05.30 · 📦 19</div></div></div>
<div class="proj"><div class="still fake-thumb thumb-character"></div><div class="body"><div class="name">Afterlight</div><div class="meta">EP 02 · 2024.05.28 · 📦 27</div></div></div>
<div class="proj"><div class="still fake-thumb thumb-watch"></div><div class="body"><div class="name">Fragments</div><div class="meta">EP 01 · 2024.05.20 · 📦 8</div></div></div>
<div class="proj"><div class="still fake-thumb thumb-prop"></div><div class="body"><div class="name">Silent Script</div><div class="meta">DRAFT · 2024.05.14 · 📦 3</div></div></div>
```

- [ ] **Step 3:** Re-screenshot and eyeball

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/02-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/02-studio-home.html"
open /tmp/02-after.png /tmp/if-mockups/IF/首页.png
```

Expected: 8 moody varied stills, each clearly a different scene (vs uniform brown blobs before).

- [ ] **Step 4:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/02-studio-home.html
git commit -m "$(cat <<'EOF'
fix(mockup-02): replace empty card placeholders with fake-thumb variants

Studio Home project cards now use the 8 fake-thumb variants from
_shared.css. Removes the local per-card gradient overrides + dead
::after star-dot block.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 — Apply Fake-Thumb to 05 Storyboard

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/05-storyboard.html`

- [ ] **Step 1:** Read `05-storyboard.html` to find the row-thumbnail markup

```bash
grep -n "thumb\|缩略\|row" docs/superpowers/specs/2026-05-13-ui-redesign/mockups/05-storyboard.html | head -20
```

- [ ] **Step 2:** Replace each row's empty thumb element with `<div class="thumb fake-thumb thumb-night"></div>` (6 rows, vary the variant):

| Row | Variant suggestion |
|---|---|
| 012 | thumb-night |
| 013 | thumb-watch |
| 014 | thumb-dawn |
| 015 | thumb-character |
| 016 | thumb-fog |
| 017 | thumb-watch |

(Use `Edit` tool with `replace_all: false` for each occurrence, one at a time, providing enough surrounding context to make the match unique.)

- [ ] **Step 3:** Re-screenshot and eyeball vs `/tmp/if-mockups/IF/智能分镜.png`

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/05-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/05-storyboard.html"
open /tmp/05-after.png /tmp/if-mockups/IF/智能分镜.png
```

- [ ] **Step 4:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/05-storyboard.html
git commit -m "fix(mockup-05): storyboard rows use fake-thumb variants" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 — Apply Fake-Thumb to 07 Asset Library + 08 Asset Generation

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/07-asset-library.html`
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/08-asset-generation.html`

- [ ] **Step 1:** In `07-asset-library.html`, find the gallery tile elements and add `fake-thumb thumb-<variant>` classes. Use 4-6 different variants so the gallery shows a mix.

```bash
grep -n "tile\|asset-card\|gallery" docs/superpowers/specs/2026-05-13-ui-redesign/mockups/07-asset-library.html | head -20
```

Mix variants — characters → `thumb-character`, environments → `thumb-fog`/`thumb-dock`, props → `thumb-watch`/`thumb-prop`, weapons/textures → `thumb-ember`.

- [ ] **Step 2:** In `08-asset-generation.html`, apply fake-thumb to the 4 candidate slots in the center column (variant: `thumb-character`) and the right-column 5 history thumbnails (variants: `thumb-fog`, `thumb-character`, `thumb-watch`, `thumb-dawn`, `thumb-night`).

(Leave the third "running 62%" candidate placeholder alone; per PNG it shows a progress bar overlay rather than a still.)

- [ ] **Step 3:** Re-screenshot both

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/07-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/07-asset-library.html"
"$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/08-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/08-asset-generation.html"
open /tmp/07-after.png /tmp/if-mockups/IF/素材库.png /tmp/08-after.png /tmp/if-mockups/IF/素材生成.png
```

- [ ] **Step 4:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/07-asset-library.html docs/superpowers/specs/2026-05-13-ui-redesign/mockups/08-asset-generation.html
git commit -m "fix(mockup-07-08): asset library + generation use fake-thumb variants" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 — Brighten 03 Canvas SVG Edges

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/03-canvas.html` (lines 164-166)

- [ ] **Step 1:** Replace the `.edges path` block

Old:

```css
.edges { position: absolute; inset: 0; pointer-events: none; }
.edges path { fill: none; stroke: var(--fg-4); stroke-width: 1.4; stroke-dasharray: 4 4; }
.edges path.live { stroke: var(--accent); stroke-dasharray: 0; }
```

New:

```css
.edges { position: absolute; inset: 0; pointer-events: none; }
.edges path { fill: none; stroke: rgba(201,168,91,0.55); stroke-width: 1.6; stroke-dasharray: 0; stroke-linecap: round; }
.edges path.live { stroke: var(--accent); stroke-width: 1.8; filter: drop-shadow(0 0 4px rgba(201,168,91,0.35)); }
```

Rationale: PNG wires are bright amber solid lines, not dim dashed greys. Live wires get a tiny glow to read as "active flow."

- [ ] **Step 2:** Re-screenshot

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/03-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/03-canvas.html"
open /tmp/03-after.png /tmp/if-mockups/IF/画布.png
```

Expected: Wires now clearly visible connecting Elara→Harbor Docks→Wide Shot row and Pocket Watch→CU Watch→Watch Closeup row, with diagonal wires bridging the rows.

- [ ] **Step 3:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/03-canvas.html
git commit -m "fix(mockup-03): brighten canvas edges to match PNG amber wires" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6 — Fix 11 Toasts CSS Collision

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/11-toasts.html`

- [ ] **Step 1:** Rename the colliding inner class. In the local `<style>` block, change every `.toast .body` to `.toast .content`. In the HTML body markup, change each `<div class="body">` inside a `<div class="toast …">` to `<div class="content">`.

Specifically — in the `<style>` block (around lines 61-63):

Old:

```css
.toast .body { flex: 1; }
.toast .title { font-size: 13px; color: var(--fg-1); font-weight: 600; }
.toast .msg { font-family: var(--ff-mono); font-size: 11px; color: var(--fg-3); margin-top: 4px; letter-spacing: 0.04em; }
```

New:

```css
.toast .content { flex: 1; display: block; }
.toast .title { font-size: 13px; color: var(--fg-1); font-weight: 600; }
.toast .msg { font-family: var(--ff-mono); font-size: 11px; color: var(--fg-3); margin-top: 4px; letter-spacing: 0.04em; }
```

And in the 4 toast blocks (lines 95-133), change every `<div class="body">` → `<div class="content">`.

- [ ] **Step 2:** Restack toasts vertically at bottom-right (PNG layout).

Replace the `.grid` rule (lines 22-29):

Old:

```css
.grid {
  position: absolute; right: 36px; top: 110px; bottom: 36px;
  display: grid; gap: 16px;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: auto auto;
  align-content: end;
  width: 720px;
}
```

New:

```css
.grid {
  position: absolute; right: 36px; bottom: 36px;
  display: flex; flex-direction: column;
  gap: 12px;
  width: 360px;
}
```

- [ ] **Step 3:** Add a faded canvas backdrop behind the toasts (PNG shows toasts overlaid on a dim canvas mockup).

Replace the existing `.stage` rule (lines 11-15):

Old:

```css
.stage { flex: 1; position: relative; overflow: hidden;
  background:
    radial-gradient(circle at 20% 80%, rgba(201,168,91,0.06), transparent 50%),
    var(--surface-canvas);
}
```

New:

```css
.stage { flex: 1; position: relative; overflow: hidden;
  background:
    radial-gradient(circle at 30% 40%, rgba(201,168,91,0.04), transparent 55%),
    radial-gradient(circle at 70% 70%, rgba(75,122,146,0.03), transparent 55%),
    var(--surface-canvas);
}
.stage::before {
  content: "";
  position: absolute; inset: 80px 80px 60px 80px;
  border-radius: 12px;
  background-image:
    radial-gradient(1.4px 1.4px at 16% 28%, rgba(232,223,208,0.06), transparent 60%),
    radial-gradient(1.4px 1.4px at 64% 42%, rgba(232,223,208,0.05), transparent 60%);
  opacity: 0.5;
  pointer-events: none;
}
```

- [ ] **Step 4:** Re-screenshot

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/11-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/11-toasts.html"
open /tmp/11-after.png /tmp/if-mockups/IF/通知类型.png
```

Expected: 4 toast cards stacked vertically at bottom-right. Each toast shows title bold + msg mono + actions row underneath (no more text scatter).

- [ ] **Step 5:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/11-toasts.html
git commit -m "$(cat <<'EOF'
fix(mockup-11): toast CSS collision + vertical stack

Rename inner `.body` → `.content` so it stops inheriting display:flex
from the page-level `.body` rule in _shared.css (was causing toast
title/msg/actions to render as horizontal flex items, scattering text).

Also restack toasts vertically at bottom-right per PNG reference,
and add a faint canvas backdrop.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 — 08 Asset Generation: Drop "其他" Tab

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/08-asset-generation.html` (line 118)

- [ ] **Step 1:** Delete the trailing `<span>其他</span>` so the tab row reads:

Old:

```html
<span class="on">人物</span><span>场景</span><span>道具</span><span>其他</span>
```

New:

```html
<span class="on">人物</span><span>场景</span><span>道具</span>
```

- [ ] **Step 2:** Re-screenshot (combined with Task 4's already-shot 08-after if Task 4 ran first, otherwise reshoot)

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/08-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/08-asset-generation.html"
open /tmp/08-after.png /tmp/if-mockups/IF/素材生成.png
```

- [ ] **Step 3:** Commit (can be folded into Task 4's commit if done together)

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/08-asset-generation.html
git commit -m "fix(mockup-08): drop '其他' tab to match PNG 3-tab layout" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8 — 01 Lock: Depill Tagline

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/01-lock.html`

**Why:** The tagline `<div class="tag">A Desk For Storyboarders</div>` matches the global `.tag` rule in `_shared.css` (pill with border + radius + padding). Per PNG it should be plain spaced caps, no pill.

- [ ] **Step 1:** Rename the local class from `tag` to `subtitle` in both the HTML and CSS.

In the local `<style>` block (line 63-70), change:

Old:

```css
.tag {
  margin-top: 18px;
  font-family: var(--ff-mono);
  font-size: 11px;
  letter-spacing: 0.42em;
  color: var(--fg-3);
  text-transform: uppercase;
}
```

New:

```css
.subtitle {
  margin-top: 18px;
  font-family: var(--ff-mono);
  font-size: 11px;
  letter-spacing: 0.42em;
  color: var(--fg-3);
  text-transform: uppercase;
}
```

In the HTML body (line 126), change:

Old:

```html
<div class="tag">A Desk For Storyboarders</div>
```

New:

```html
<div class="subtitle">A Desk For Storyboarders</div>
```

- [ ] **Step 2:** Re-screenshot

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/01-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/01-lock.html"
open /tmp/01-after.png /tmp/if-mockups/IF/首页登录.png
```

Expected: Tagline now plain spaced caps, no border pill around it.

- [ ] **Step 3:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/01-lock.html
git commit -m "fix(mockup-01): depill lock tagline to match PNG" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9 — 06 Script Editor: Floating Menu Actions

**Files:**
- Modify: `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/06-script-editor.html`

- [ ] **Step 1:** Locate the floating menu

```bash
grep -n "编辑\|加镜头\|加角色\|移除" docs/superpowers/specs/2026-05-13-ui-redesign/mockups/06-script-editor.html
```

- [ ] **Step 2:** Change the menu items to match PNG: `编辑` / `复制` / `批注` / `删除` / `查看历史`. The `删除` item should keep the red/danger color (it's the destructive action).

For each item replacement, use `Edit` with enough context for a unique match. Concrete edits:

| Old text | New text | Notes |
|---|---|---|
| 编辑 | 编辑 | unchanged |
| 加镜头 | 复制 | swap label |
| 加角色 | 批注 | swap label |
| 移除 | 删除 | rename, keep danger color class |
| (none) | 查看历史 | add new menu item between 批注 and 删除 |

If the current menu uses generic structure like `<div class="menu-item">移除</div>` repeated, modify each one's text and add a new menu-item row for `查看历史` before the divider that precedes `删除`.

- [ ] **Step 3:** Re-screenshot

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
  --screenshot=/tmp/06-after.png \
  "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/06-script-editor.html"
open /tmp/06-after.png /tmp/if-mockups/IF/剧本解析.png
```

- [ ] **Step 4:** Commit

```bash
git add docs/superpowers/specs/2026-05-13-ui-redesign/mockups/06-script-editor.html
git commit -m "fix(mockup-06): script editor menu actions match PNG (编辑/复制/批注/查看历史/删除)" --trailer "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10 — Re-Screenshot All 12 + Visual Diff Summary

**Files:** none modified (verification + commit of side-by-side strip if useful).

- [ ] **Step 1:** Final pass — re-screenshot all 12 mockups into a clean dir

```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT=/tmp/mockup-final
mkdir -p "$OUT"
for n in 01-lock 02-studio-home 03-canvas 04-task-queue 05-storyboard 06-script-editor 07-asset-library 08-asset-generation 09-settings 10-account 11-toasts 12-error-states; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --window-size=1536,1024 --virtual-time-budget=2000 \
    --screenshot="$OUT/$n.png" \
    "file:///Users/kerro/Projects/InkFrame/docs/superpowers/specs/2026-05-13-ui-redesign/mockups/$n.html" 2>/dev/null
done
ls -la "$OUT"
```

Expected: 12 PNGs in `/tmp/mockup-final/`.

- [ ] **Step 2:** Open each pair side-by-side for the user to eyeball-approve

```bash
declare -A pairs=(
  [01-lock]=首页登录
  [02-studio-home]=首页
  [03-canvas]=画布
  [04-task-queue]=任务队列
  [05-storyboard]=智能分镜
  [06-script-editor]=剧本解析
  [07-asset-library]=素材库
  [08-asset-generation]=素材生成
  [09-settings]=设置
  [10-account]="账户设置、"
  [11-toasts]=通知类型
  [12-error-states]=错误类型
)
for k in "${!pairs[@]}"; do
  open "/tmp/mockup-final/$k.png" "/tmp/if-mockups/IF/${pairs[$k]}.png"
done
```

User confirms each pair (or flags remaining issues). If any pair still diverges enough to fix, loop back to the relevant task.

- [ ] **Step 3:** Push branch and open PR

```bash
git push -u origin feat/ui-mockup-png-alignment
gh pr create --title "fix(mockups): align 12 HTML mockups with PNG references" --body "$(cat <<'EOF'
## Summary
- Patched 8 of 12 HTML mockups to match the IF.zip PNG references closer (≥ 90 % visual match).
- Untouched: 04 Task Queue, 09 Settings, 10 Account, 12 Error States (already ≥ 90 %).
- Added `.fake-thumb-*` library to `_shared.css` so 02/05/07/08 use cinematic placeholders instead of empty radial gradients.

## Key fixes
- **11 Toasts**: CSS class collision (`<div class="body">` inside toast was matching page-level `.body { display: flex }`) — renamed to `.content`. Also restacked toasts vertically per PNG.
- **03 Canvas**: SVG bezier wires were too dim against dot grid — brightened to amber.
- **08 Asset Generation**: dropped extra "其他" tab.
- **01 Lock**: removed accidental pill border around tagline.
- **06 Script Editor**: floating menu actions renamed per PNG.

## Test plan
- [ ] Open each `docs/superpowers/specs/2026-05-13-ui-redesign/mockups/*.html` and compare visually to `/tmp/if-mockups/IF/*.png` (or the original `D:\Docs\IMG\IF\*.png`).
- [ ] No `.html` JS errors in browser console.
EOF
)"
```

---

## Self-Review Checklist

After the plan was drafted, I re-checked it with the audit table:

- **Spec coverage:** Every diff row in the audit table that needed a fix points to a task. The 4 rows marked ★★★★★ (09/10/12) and 04 (★★★★☆ but accepted as good-enough) are explicitly skipped.
- **Placeholder scan:** Each "edit" step includes the actual old → new code blocks. No TBD, no "handle appropriately."
- **Type consistency:** CSS class names used in markup match the ones in styles (`fake-thumb`, `thumb-night`, `subtitle`, `content`). Variant names referenced in Tasks 2/3/4 all exist in Task 1.
- **Ambiguity check:** Task 9 (06 script editor) is the fuzziest because I haven't read the file yet — the table maps old → new labels concretely, but the exact selectors depend on the file's structure. The first step grabs context with grep; if the menu structure is unexpected, the implementer should pause and confirm.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-23-mockup-png-alignment.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review the diff and screenshot between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session, batch with checkpoints at Task 1 / Task 6 / Task 10.

Which approach?
