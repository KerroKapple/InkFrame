# ARB Reconciliation (dead-key purge + localize sidebar label) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the i18n layer back in sync with the post–Amber-Noir reality: delete the 13 orphaned `workspace*` ARB keys that the Studio rewrite (#101) stranded, and replace the one remaining hardcoded `'Projects'` sidebar label with a proper localized key.

**Architecture:** Two independent, test-guarded edits to the ARB source of truth (`app_en.arb` / `app_zh.arb`), each followed by `flutter gen-l10n` to regenerate `lib/l10n/generated/`. A new pure-Dart hygiene test locks in en/zh key parity and forbids any future `workspace*` key resurfacing; a widget test proves the sidebar renders the localized label under `zh`.

**Tech Stack:** Flutter (Dart), Flutter gen-l10n (ARB → `AppLocalizations`), `flutter_test` + the repo's `pumpInkApp` harness (`test/_harness/test_app.dart`), Riverpod provider overrides.

---

## Preconditions

- **Flutter must be on PATH.** Verify with `flutter --version` before starting. The auditing session could not locate `flutter`/`flutter.bat` on this machine; `gen-l10n`, `analyze`, and `test` all require it. If it is missing, stop and install/expose the SDK — this plan cannot be executed without it.
- Run from repo root `E:\InkFrame`.
- Branch off `main` first: `git checkout -b chore/arb-reconciliation`.

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `test/l10n/arb_hygiene_test.dart` | Regression guard: en/zh key sets identical + no `workspace*` keys | **Create** |
| `lib/l10n/app_en.arb` | English source of truth | **Modify** (delete dead block, add 1 key) |
| `lib/l10n/app_zh.arb` | Chinese translations | **Modify** (delete dead block, add 1 key) |
| `lib/l10n/generated/*.dart` | gen-l10n output | **Regenerated** (never hand-edited) |
| `test/features/studio/library_sidebar_l10n_test.dart` | Proves sidebar `Projects` node is localized | **Create** |
| `lib/features/studio/widgets/library_sidebar.dart:102` | Sidebar `Projects` tree node | **Modify** (hardcode → `context.l10n`) |

Why two tasks split this way: the dead-key purge (Tasks 1–2) and the label localization (Tasks 3–4) are independent behaviors with independent tests. Each lands as its own commit and is individually revertible.

---

### Task 1: ARB hygiene regression test (red)

**Files:**
- Test: `test/l10n/arb_hygiene_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/l10n/arb_hygiene_test.dart`:

```dart
// ARB 卫生回归：保证 en/zh key 集合完全一致，且不残留死 key（workspace* 系列）。
// CLAUDE.md 声明的"两 locale key 集合必须相同"在此固化为可执行断言。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 读取 ARB 文件里"真实"的 message key —— 排除 @@locale 与 @ 开头的 metadata。
Set<String> _messageKeys(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    fail('ARB not found: $path');
  }
  final Map<String, dynamic> json =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return json.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  const String enPath = 'lib/l10n/app_en.arb';
  const String zhPath = 'lib/l10n/app_zh.arb';

  test('en 与 zh 的 message key 集合完全一致', () {
    final Set<String> en = _messageKeys(enPath);
    final Set<String> zh = _messageKeys(zhPath);
    expect(en.difference(zh), isEmpty,
        reason: 'keys present in en but missing in zh');
    expect(zh.difference(en), isEmpty,
        reason: 'keys present in zh but missing in en');
  });

  test('不残留 workspace* 死 key（已被 Studio 重写取代）', () {
    final Set<String> all = <String>{
      ..._messageKeys(enPath),
      ..._messageKeys(zhPath),
    };
    final Iterable<String> orphans = all.where((k) => k.startsWith('workspace'));
    expect(orphans, isEmpty, reason: 'orphaned workspace* keys: $orphans');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/l10n/arb_hygiene_test.dart`
Expected: the **parity** test PASSES (en/zh already match), the **workspace** test FAILS with `orphaned workspace* keys: (workspaceTitle, workspaceHeroTagline, ...)`.

- [ ] **Step 3: Commit the red test**

```bash
git add test/l10n/arb_hygiene_test.dart
git commit -m "test(l10n): add ARB hygiene guard (parity + no dead workspace keys)"
```

---

### Task 2: Purge the 13 dead `workspace*` keys (green)

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Regenerated: `lib/l10n/generated/*.dart`

These keys are stranded: `grep -rn "l10n\.workspace" lib/` returns zero references — the Amber Noir Studio rewrite (#101) replaced `WorkspaceHome` with `studio/`.

- [ ] **Step 1: Delete the dead block from `app_en.arb`**

Remove this exact contiguous block (15 lines) from `lib/l10n/app_en.arb`:

```json
  "workspaceTitle": "Workspace",
  "workspaceHeroTagline": "AI-driven storyboard desktop tool",
  "workspaceHeroSubtitle": "Runs locally with privacy control; integrates multiple model providers; one canvas stitches text, image and video",
  "workspaceProjectsHeader": "My Projects",
  "workspaceProjectsEmpty": "No projects yet. Tap the FAB to create your first one.",
  "workspaceNewProject": "New project",
  "workspaceNewProjectHint": "Project name",
  "workspaceNewCanvas": "New canvas",
  "workspaceNewCanvasHint": "Canvas name",
  "workspaceCanvasCount": "{count} canvas(es)",
  "@workspaceCanvasCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "workspaceOpenCanvas": "Open",
  "workspaceBackToWorkspace": "Back to workspace",
  "workspaceLoadError": "Failed to load project list",
```

After deletion the line above the block (`"canvasSampleProjectName"` group) ends with `,` and the line below (`"inspectorTitle"`) is unchanged — JSON stays valid. Leave the blank separator line that followed the block.

- [ ] **Step 2: Delete the dead block from `app_zh.arb`**

Remove this exact contiguous block (15 lines) from `lib/l10n/app_zh.arb`:

```json
  "workspaceTitle": "工作台",
  "workspaceHeroTagline": "AI 驱动的分镜创作桌面工具",
  "workspaceHeroSubtitle": "本地运行、隐私可控；集成多个模型 Provider，一个画布把图文视频串起来",
  "workspaceProjectsHeader": "我的项目",
  "workspaceProjectsEmpty": "还没有项目。点右下角按钮新建第一个。",
  "workspaceNewProject": "新建项目",
  "workspaceNewProjectHint": "项目名",
  "workspaceNewCanvas": "新建画布",
  "workspaceNewCanvasHint": "画布名",
  "workspaceCanvasCount": "{count} 个画布",
  "@workspaceCanvasCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "workspaceOpenCanvas": "打开",
  "workspaceBackToWorkspace": "返回工作台",
  "workspaceLoadError": "项目列表加载失败",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0, rewrites `lib/l10n/generated/app_localizations*.dart` without the `workspace*` getters. (Config is read from repo-root `l10n.yaml`.)

- [ ] **Step 4: Run the hygiene test to verify it passes**

Run: `flutter test test/l10n/arb_hygiene_test.dart`
Expected: both tests PASS.

- [ ] **Step 5: Verify nothing else broke**

Run: `flutter analyze`
Expected: `No issues found!` (no code referenced the deleted keys).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/generated
git commit -m "fix(l10n): purge 13 orphaned workspace* keys stranded by Studio rewrite"
```

> Do **not** stage `untranslated.json` if gen-l10n emits it at the repo root — it is a build artifact, not source.

---

### Task 3: Sidebar `Projects` localization test (red)

**Files:**
- Test: `test/features/studio/library_sidebar_l10n_test.dart`

The defect: `library_sidebar.dart:102` hardcodes `label: 'Projects'`. Under English it happens to look right; under Chinese it wrongly shows English. The test pins the `zh` behavior so the hardcode fails.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/studio/library_sidebar_l10n_test.dart`:

```dart
// LibrarySidebar 的 "Projects" 树节点必须走 l10n —— zh locale 下应显示"项目"。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/studio/models/project_with_canvases.dart';
import 'package:inkframe/features/studio/widgets/library_sidebar.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('zh locale 下 Projects 节点显示本地化文案"项目"', (tester) async {
    await pumpInkApp(
      tester,
      const Scaffold(body: LibrarySidebar()),
      locale: const Locale('zh'),
      overrides: <Override>[
        workspaceProjectsProvider.overrideWith(
          (ref) async => const <ProjectWithCanvases>[
            ProjectWithCanvases(
              id: 'p1',
              name: 'Demo',
              canvases: <CanvasRef>[],
            ),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('项目'), findsOneWidget);
    expect(find.text('Projects'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/studio/library_sidebar_l10n_test.dart`
Expected: FAIL — `find.text('项目')` finds nothing and `find.text('Projects')` finds one (the hardcoded label).

---

### Task 4: Localize the `Projects` label (green)

**Files:**
- Modify: `lib/l10n/app_en.arb` (add 1 key)
- Modify: `lib/l10n/app_zh.arb` (add 1 key)
- Regenerated: `lib/l10n/generated/*.dart`
- Modify: `lib/features/studio/widgets/library_sidebar.dart:102`

- [ ] **Step 1: Add the key to `app_en.arb`**

Find the line `  "studioLibrary": "LIBRARY",` and insert directly below it:

```json
  "studioLibraryProjects": "Projects",
```

- [ ] **Step 2: Add the key to `app_zh.arb`**

Find the line `  "studioLibrary": "工作库",` and insert directly below it:

```json
  "studioLibraryProjects": "项目",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exits 0; `AppLocalizations` now exposes a `studioLibraryProjects` getter.

- [ ] **Step 4: Replace the hardcoded label**

In `lib/features/studio/widgets/library_sidebar.dart`, the `_LibraryTree.build` method has `BuildContext context` in scope. Change line 102:

```dart
          label: 'Projects',
```

to:

```dart
          label: context.l10n.studioLibraryProjects,
```

(`import '../../../l10n/l10n_x.dart';` is already present at line 8 — no new import needed.)

- [ ] **Step 5: Run the widget test to verify it passes**

Run: `flutter test test/features/studio/library_sidebar_l10n_test.dart`
Expected: PASS.

- [ ] **Step 6: Re-run the hygiene test (parity still holds)**

Run: `flutter test test/l10n/arb_hygiene_test.dart`
Expected: both tests PASS (the new key exists in both locales).

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/generated lib/features/studio/widgets/library_sidebar.dart test/features/studio/library_sidebar_l10n_test.dart
git commit -m "fix(l10n): localize hardcoded Projects sidebar label"
```

---

### Task 5: Full verification + push

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: all tests pass (suite was green at HEAD; this plan only adds keys/tests and removes dead ones).

- [ ] **Step 2: Final analyze (pre-push gate parity)**

Run: `flutter analyze`
Expected: `No issues found!` — matches the `flutter analyze` pre-push hook added in #107, so `git push` will not be rejected.

- [ ] **Step 3: Push and open PR**

```bash
git push -u origin chore/arb-reconciliation
gh pr create --fill
```

---

## Self-Review

**Spec coverage** (the two audit findings this plan addresses):
- "13 orphaned `workspace*` ARB keys" → Tasks 1–2 (guard test + deletion). ✅
- "`'Projects'` hardcoded label at `library_sidebar.dart:102`" → Tasks 3–4 (zh widget test + localized key + code change). ✅
- Out of scope by design (separate plan recommended): the ~60 hardcoded style literals (`fontSize`, width/height) — these belong to the ROADMAP "Design-token rollout for remaining components" workstream, not i18n.

**Placeholder scan:** No TBD/TODO/"add error handling"/"similar to" — every ARB block and Dart snippet is complete literal content. ✅

**Type consistency:** `workspaceProjectsProvider` returns `Future<List<ProjectWithCanvases>>` (defined in `lib/features/studio/models/project_with_canvases.dart`); the override and the `ProjectWithCanvases`/`CanvasRef` constructors in the Task 3 test match that definition (`id`, `name`, `canvases` / `id`, `name`). The new getter is named `studioLibraryProjects` consistently in the ARB keys (Task 4 steps 1–2) and the call site (Task 4 step 4). ✅
