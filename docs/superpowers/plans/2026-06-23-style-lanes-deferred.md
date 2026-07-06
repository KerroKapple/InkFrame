# Style Lanes — Deferred Items Implementation Plan

> **For agentic workers:** subagent-driven, TDD, frequent commits. Extends `feat/style-lanes` (PR #122). Steps use checkbox syntax.

**Goal:** Finish PRD §7 to full fidelity — project base-style editor + 7 presets (§7.7), drag-resize lanes, drag-reorder lanes, double-tap collapse.

**Excluded:** "power-save solid divider" (§7.3) — depends on the unbuilt performance-tier system (§3.9); current dividers are already 1px solid, so no behavioral gap.

## Global Constraints
- Flutter at `C:/Users/Kerro/flutter/bin/flutter.bat`. Package `inkframe`.
- Models hand-rolled; providers hand-written (no codegen).
- **Preset PROMPT text is English-only code constants (NEVER i18n — model contract, per docs/CLAUDE.md), overriding PRD §7.7.** Only preset BUTTON LABELS are i18n.
- Zero hardcoded user strings → `context.l10n`; en+zh key sets identical. Zero hardcoded styles → tokens.
- Errors are `InkError` subtypes; controllers optimistic + rollback on failure; widget catches narrowed to `on InkError`.
- Comments Chinese, minimal. Test theme: `buildAppTheme(variant: InkThemeVariant.dark, textScale: 1)`. Deep test files import harness via `../../../_harness/`. testWidgets: no real `dart:io` await.

## Execution Waves
- **Wave 1 (parallel, disjoint files):** T16, T17, T18, T19
- **Wave 2 (after 1):** T20 (canvas_view + lane_background + lane_title_bar) and T21 (canvas_top_chrome) — disjoint files, parallel.

---

### Task 16: Shared base-style provider + presets

**Files:**
- Create: `lib/features/canvas/providers/canvas_base_style.dart`
- Create: `lib/features/canvas/util/base_style_presets.dart`
- Modify: `lib/features/canvas/widgets/image_config_inspector.dart` (remove private `_canvasBaseStyleProvider`, import shared `canvasBaseStyleProvider`; update its single usage site).
- Test: `test/features/canvas/canvas_base_style_test.dart`

**Produces:**
- `final canvasBaseStyleProvider = FutureProvider.autoDispose.family<({String prefix, String suffix}), String>(...)` — same body as the inspector's current private provider (reads canvasRepository.findById → base_style_prefix/suffix, degrade to '').
- `Future<void> setBaseStyle(WidgetRef ref, String canvasId, {required String prefix, required String suffix})` — `canvasRepository.update(canvasId, {'base_style_prefix': prefix, 'base_style_suffix': suffix})` then `ref.invalidate(canvasBaseStyleProvider(canvasId))`.
- `base_style_presets.dart`: `class BaseStylePreset { final String id; final String prompt; const BaseStylePreset(this.id, this.prompt); }` and `const kBaseStylePresets = <BaseStylePreset>[ BaseStylePreset('cinematic', 'cinematic film still, dramatic lighting, shallow depth of field, 35mm'), BaseStylePreset('anime', 'modern anime style, clean lineart, vibrant cel shading'), BaseStylePreset('ghibli', 'Studio Ghibli style, hand-painted backgrounds, soft warm palette'), BaseStylePreset('cyberpunk', 'cyberpunk, neon-lit, rain-slicked streets, high contrast'), BaseStylePreset('inkwash', 'traditional Chinese ink wash painting, sumi-e, minimal flowing brushstrokes'), BaseStylePreset('photographic', 'photorealistic, natural lighting, high detail, DSLR'), BaseStylePreset('anim3d', '3D animated film style, soft global illumination, subsurface scattering') ];`

- [ ] Write failing test: `setBaseStyle` calls canvasRepo.update with prefix/suffix (use a fake CanvasRepository capturing patch; ProviderContainer; call setBaseStyle via a WidgetRef — use `container.read`... note setBaseStyle takes WidgetRef; for the unit test, test the underlying behavior by constructing a fake repo and asserting update called — you may need a ConsumerWidget harness OR change to test via a ProviderContainer + a small Consumer. Simplest: pump a tiny ConsumerWidget that calls setBaseStyle in a button, tap it, assert fake repo.update captured prefix/suffix). Also test `canvasBaseStyleProvider` returns ('','') on null row.
- [ ] Implement provider + presets; refactor inspector.
- [ ] Run test → pass. Commit.

---

### Task 17: Base-style editor dialog + ARB

**Files:**
- Create: `lib/features/canvas/widgets/base_style_editor_dialog.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb` (gen-l10n run centrally)
- Test: `test/features/canvas/widgets/base_style_editor_dialog_test.dart`

**ARB keys (add identical set to both, English / 中文):**
- `baseStyleEditTooltip`: "Base style" / "基底风格"
- `baseStyleEditTitle`: "Project base style" / "项目基底风格"
- `baseStylePrefixLabel`: "Prefix (prepended to every prompt)" / "前缀（加在所有 prompt 最前）"
- `baseStylePrefixHint`: "e.g. cinematic film still" / "如：电影感画面"
- `baseStyleSuffixLabel`: "Suffix (appended to every prompt)" / "后缀（加在所有 prompt 最后）"
- `baseStyleSuffixHint`: "e.g. 8k, highly detailed" / "如：8k，高细节"
- `baseStylePresetsLabel`: "Presets" / "快速预设"
- `baseStylePresetCinematic`: "Cinematic" / "真人电影"
- `baseStylePresetAnime`: "Anime" / "国漫"
- `baseStylePresetGhibli`: "Ghibli" / "吉卜力"
- `baseStylePresetCyberpunk`: "Cyberpunk" / "赛博朋克"
- `baseStylePresetInkwash`: "Ink wash" / "水墨"
- `baseStylePresetPhoto`: "Photographic" / "写实摄影"
- `baseStylePreset3d`: "3D animation" / "3D动画"
(Reuse existing `laneDialogSave` / `laneDialogCancel` for the buttons.)

**Produces:** `Future<({String prefix, String suffix})?> showBaseStyleEditorDialog(BuildContext context, {required String prefix, required String suffix})`.
- A `StatefulWidget` dialog: two `InkInput`s (prefix multiline + suffix multiline, prefilled), a `Wrap` of 7 preset `ActionChip`s. Tapping a preset sets the prefix controller text to that preset's English prompt (`kBaseStylePresets`), user may then edit. Preset label resolved by a `_presetLabel(BuildContext, String id)` switch → l10n getters above. Save → `Navigator.pop((prefix: prefixCtrl.text.trim(), suffix: suffixCtrl.text.trim()))`; cancel → pop null. Dispose controllers. All styling via tokens.

- [ ] Write failing test: pump a button → showBaseStyleEditorDialog(prefix:'a', suffix:'b'); assert both prefill; tap the "Cinematic" preset chip → prefix field now contains the cinematic English prompt; tap Save → returns record with that prefix. (Harness like lane_edit_dialog_test.) Read `lib/theme/components/ink_input.dart` first.
- [ ] Implement dialog + ARB keys.
- [ ] (central) gen-l10n; run test → pass. Commit.

---

### Task 18: Lane reorder in controller

**Files:**
- Modify: `lib/features/canvas/providers/canvas_lanes_controller.dart`
- Test: extend `test/features/canvas/canvas_lanes_controller_test.dart`

**Produces:** `Future<void> reorderLanes(List<String> orderedIds)` — reassigns `sort_order = index` for the given order, optimistically reorders in-memory state, persists each lane whose sort_order changed via `repo.update(id, {'sort_order': i})`; on `InkError` rollback to previous and rethrow. Ignores ids not in current state.

- [ ] Write failing test: with lanes [a(0), b(1), c(2)] in fake repo, `reorderLanes(['c','a','b'])` → state order is c,a,b with sort_order 0,1,2 and repo received updates. Add a rollback test (repo.update throws → state restored).
- [ ] Implement. Run → pass. Commit.

```dart
  /// 按给定 id 顺序重排泳道，sort_order=下标。乐观更新 + 失败回滚。
  Future<void> reorderLanes(List<String> orderedIds) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    final byId = {for (final l in previous) l.id: l};
    final reordered = <StyleLane>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final lane = byId[orderedIds[i]];
      if (lane != null) reordered.add(lane.copyWith(sortOrder: i));
    }
    if (reordered.length != previous.length) return; // 不完整顺序，跳过
    state = AsyncData(reordered);
    try {
      for (var i = 0; i < reordered.length; i++) {
        if (previous.firstWhere((l) => l.id == reordered[i].id).sortOrder != i) {
          await repo.update(reordered[i].id, <String, Object?>{'sort_order': i});
        }
      }
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
```

---

### Task 19: Lane collapse ephemeral provider

**Files:**
- Create: `lib/features/canvas/providers/lane_collapse_controller.dart`
- Test: `test/features/canvas/lane_collapse_controller_test.dart`

**Produces:** per-canvas ephemeral collapsed-id set (view-only, no DB).
```dart
final laneCollapseProvider = AutoDisposeNotifierProviderFamily<
    LaneCollapseController, Set<String>, String>(
  LaneCollapseController.new,
  name: 'laneCollapseProvider',
);

class LaneCollapseController
    extends AutoDisposeFamilyNotifier<Set<String>, String> {
  @override
  Set<String> build(String arg) => const <String>{};
  void toggle(String laneId) {
    final next = {...state};
    if (!next.remove(laneId)) next.add(laneId);
    state = next;
  }
  bool isCollapsed(String laneId) => state.contains(laneId);
}
```
- [ ] Write failing test: toggle adds then removes id. Implement. Run → pass. Commit.

---

### Task 20: Canvas integration — resize, reorder, collapse

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_view.dart` (_CanvasStage)
- Modify: `lib/features/canvas/widgets/lane_background.dart` (accept `collapsedIds` → skip tint for collapsed lanes; collapsed lanes still occupy geometry but draw no tint)
- Modify: `lib/features/canvas/widgets/lane_title_bar.dart` (add `collapsed` bool + `onToggleCollapse` VoidCallback → an expand/collapse icon button; double-tap also toggles)
- Test: `test/features/canvas/widgets/lane_interactions_test.dart`

**Behavior:**
1. **Resize:** between adjacent lanes draw a thin interactive divider strip (Positioned GestureDetector, ~10px thick along the divider, full cross-axis). On drag (vertical for horizontal lanes, horizontal for vertical), accumulate delta into the upper lane's size in local state for live feel; on drag end call `canvasLanesControllerProvider(canvasId).notifier.updateLane(upperLaneId, size: clamped)` (clamp min 80). The divider strips render ABOVE the LaneBackground but should not block node interaction broadly — keep them thin and only along divider lines.
2. **Reorder:** make each `LaneTitleBar` draggable (wrap in `GestureDetector` with onPanUpdate/onPanEnd, or use a `Draggable`+`DragTarget` per title). Simplest robust approach: on title-bar vertical drag end, compute the target index from drop position vs lane rects (`laneRects`), build the new id order, call `reorderLanes(newOrder)`. Show no fancy animation.
3. **Collapse:** double-tap a title bar (or its collapse icon) → `laneCollapseProvider(canvasId).notifier.toggle(laneId)`. Pass the collapsed set to `LaneBackground` (skip tint) and to each `LaneTitleBar` (`collapsed:` flag → show expand icon). Collapse is purely visual (no geometry/DB change) for this MVP.

- [ ] Write failing widget test (`lane_interactions_test.dart`): override repos (reuse the integration test's fakes pattern incl. appPathsProvider). Tests: (a) dragging a divider calls updateLane with a changed size; (b) double-tapping a title bar toggles collapse so LaneBackground receives the collapsed id (assert via no-tint or a test hook); (c) reorder: invoke the title drag → reorderLanes path and assert repo sort_order updates. Keep tests resilient — if gesture coordinates through InteractiveViewer are brittle, drive the callbacks directly (as canvas_lane_integration_test does).
- [ ] Implement. Run targeted test + analyze. Commit.

> Keep all sizes/colors tokenized; divider strip color = `colors.borderSubtle`; grab cursor `SystemMouseCursors.resizeRow/resizeColumn`.

---

### Task 21: Base-style entry in CanvasTopChrome

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_top_chrome.dart`
- Test: `test/features/canvas/widgets/canvas_top_chrome_base_style_test.dart`

**Behavior:** Add a small tokenized button (icon `Icons.palette_outlined` + tooltip `context.l10n.baseStyleEditTooltip`) into the chrome (e.g. in `_Trailing` before the ⌘K chip, or as a new center-right affordance). It is a `ConsumerWidget`/`Consumer` reading `currentCanvasIdProvider`; on tap: read current `canvasBaseStyleProvider(canvasId)` value (degrade to ('','')), `showBaseStyleEditorDialog(context, prefix:..., suffix:...)`, and on non-null result `await setBaseStyle(ref, canvasId, prefix: r.prefix, suffix: r.suffix)` wrapped in `try/on InkError` → snackbar `laneUpdateFailed` (reuse) or a dedicated key. Guard `context.mounted`.

- [ ] Write failing test: pump CanvasTopChrome in ProviderScope with overridden canvasRepository + currentCanvasId; tap the base-style button; assert the dialog opens (find `baseStyleEditTitle` text). Read `test/features/canvas/widgets/canvas_top_chrome_test.dart` (it exists) for the harness.
- [ ] Implement. Run → pass. Commit.

---

## Final verification (T22)
- [ ] `flutter analyze` → 0 issues
- [ ] `flutter test` → all green (44 pg-skips expected)
- [ ] Final whole-branch review (opus) of the new commits; fix Critical/Important.
- [ ] Push `feat/style-lanes` (updates PR #122); update PR body noting deferred items now done.
