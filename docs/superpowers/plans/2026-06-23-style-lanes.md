# Style Lanes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make style lanes a working end-to-end feature — render lanes on the canvas, assign nodes by drag, CRUD lanes, and inject lane `style_prompt` into generation (PRD §7.4).

**Architecture:** Data + repository layer already exists (`style_lanes` table, `nodes.lane_id`, `canvas.lane_direction`, `StyleLaneRepository` + provider). This plan adds the consuming UI/state/logic: pure-function utils (geometry, tint, prompt assembler), a `StyleLane` model + `canvasLanesControllerProvider`, lane rendering + CRUD widgets, drag-to-assign with position persistence, and a `PromptAssembler` wired into `GenerationController`.

**Tech Stack:** Flutter Desktop, Riverpod (hand-written providers, NO codegen), Postgres repos via DI, freezed NOT used for these hand-rolled models (match existing `CanvasNode`), flutter_localizations ARB.

## Global Constraints

- Dart/Flutter; Flutter binary not on PATH → use `C:/Users/Kerro/flutter/bin/flutter.bat`.
- NO backward-compat / migration code. Schema already has every column — **no migration**.
- Models hand-rolled immutable (match `CanvasNode`); NO freezed/codegen for new models.
- Providers hand-written (`AutoDisposeAsyncNotifierProviderFamily(...)`), NO `@riverpod`.
- Zero hardcoded user-facing strings → all via `context.l10n`; en + zh ARB key sets identical.
- Zero hardcoded styles → colors/spacing/radius via design tokens (`context.inkColors`, `InkSpacing`, `InkRadius`); pass token colors INTO `CustomPainter` (no context inside paint).
- Code comments Chinese, minimal. Conventional commits. No `--no-verify`.
- Internal matching词表 (tint keywords) are English+Chinese code constants, NOT ARB.
- `testWidgets`: never `await` real `dart:io`; use Sync APIs / mocks.
- Canvas extent constant: 4000 (matches `SizedBox(width:4000,height:4000)` in `canvas_view.dart`).

---

## Execution Waves (concurrency map)

- **Wave A (fully parallel — all independent files):** T1, T2, T3, T4, T5, T6
- **Wave B (after A):** T7 (needs T4), T8 (needs T6)
- **Wave C (parallel, after B — independent new widget files):** T9, T10, T11, T12
- **Wave D (parallel, after C — three DISTINCT existing files):** T13 (`canvas_view.dart`), T14 (`generation_controller.dart`), T15 (`image_config_inspector.dart`)

---

### Task 1: Lane geometry util (pure)

**Files:**
- Create: `lib/features/canvas/util/lane_geometry.dart`
- Test: `test/features/canvas/util/lane_geometry_test.dart`

**Interfaces:**
- Consumes: `StyleLane` (Task 4) — but to keep Task 1 independent, geometry takes a minimal `({String id, double size})` list, NOT `StyleLane`.
- Produces:
  - `enum LaneDirection { horizontal, vertical }`
  - `LaneDirection laneDirectionFromString(String s)` — `'vertical'`→vertical else horizontal
  - `String laneDirectionToString(LaneDirection d)`
  - `List<Rect> laneRects({required List<({String id, double size})> lanes, required LaneDirection direction, required double canvasExtent})`
  - `String? laneIdAtPoint({required Offset point, required List<({String id, double size})> lanes, required LaneDirection direction})`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';

void main() {
  const lanes = [(id: 'a', size: 100.0), (id: 'b', size: 200.0)];

  test('horizontal rects stack on Y, full width', () {
    final r = laneRects(lanes: lanes, direction: LaneDirection.horizontal, canvasExtent: 4000);
    expect(r[0], const Rect.fromLTWH(0, 0, 4000, 100));
    expect(r[1], const Rect.fromLTWH(0, 100, 4000, 200));
  });

  test('vertical rects stack on X, full height', () {
    final r = laneRects(lanes: lanes, direction: LaneDirection.vertical, canvasExtent: 4000);
    expect(r[0], const Rect.fromLTWH(0, 0, 100, 4000));
    expect(r[1], const Rect.fromLTWH(100, 0, 200, 4000));
  });

  test('laneIdAtPoint horizontal picks band by Y center', () {
    expect(laneIdAtPoint(point: const Offset(10, 50), lanes: lanes, direction: LaneDirection.horizontal), 'a');
    expect(laneIdAtPoint(point: const Offset(10, 150), lanes: lanes, direction: LaneDirection.horizontal), 'b');
  });

  test('laneIdAtPoint returns null when out of bounds or empty', () {
    expect(laneIdAtPoint(point: const Offset(10, 9999), lanes: lanes, direction: LaneDirection.horizontal), isNull);
    expect(laneIdAtPoint(point: Offset.zero, lanes: const [], direction: LaneDirection.horizontal), isNull);
  });

  test('direction string round-trip', () {
    expect(laneDirectionFromString('vertical'), LaneDirection.vertical);
    expect(laneDirectionFromString('horizontal'), LaneDirection.horizontal);
    expect(laneDirectionFromString('garbage'), LaneDirection.horizontal);
    expect(laneDirectionToString(LaneDirection.vertical), 'vertical');
  });
}
```

- [ ] **Step 2: Run test, verify it fails** — `"C:/Users/Kerro/flutter/bin/flutter.bat" test test/features/canvas/util/lane_geometry_test.dart` → FAIL (file not found).

- [ ] **Step 3: Implement**

```dart
// 泳道几何：纯函数。画布固定 4000×4000，泳道按传入顺序（调用方已按 sort_order 排）累计偏移。
import 'dart:ui';

enum LaneDirection { horizontal, vertical }

LaneDirection laneDirectionFromString(String s) =>
    s == 'vertical' ? LaneDirection.vertical : LaneDirection.horizontal;

String laneDirectionToString(LaneDirection d) =>
    d == LaneDirection.vertical ? 'vertical' : 'horizontal';

/// 横向：带沿 Y 堆叠、跨满宽；竖向：带沿 X 堆叠、跨满高。
List<Rect> laneRects({
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
  required double canvasExtent,
}) {
  final rects = <Rect>[];
  var offset = 0.0;
  for (final lane in lanes) {
    rects.add(direction == LaneDirection.horizontal
        ? Rect.fromLTWH(0, offset, canvasExtent, lane.size)
        : Rect.fromLTWH(offset, 0, lane.size, canvasExtent));
    offset += lane.size;
  }
  return rects;
}

/// 点落在哪条泳道；越界 / 空返回 null。
String? laneIdAtPoint({
  required Offset point,
  required List<({String id, double size})> lanes,
  required LaneDirection direction,
}) {
  var offset = 0.0;
  final coord = direction == LaneDirection.horizontal ? point.dy : point.dx;
  for (final lane in lanes) {
    if (coord >= offset && coord < offset + lane.size) return lane.id;
    offset += lane.size;
  }
  return null;
}
```

- [ ] **Step 4: Run test, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/util/lane_geometry.dart test/features/canvas/util/lane_geometry_test.dart && git commit -m "feat(canvas): lane geometry util"`

---

### Task 2: Lane tint inference util (pure)

**Files:**
- Create: `lib/features/canvas/util/lane_tint.dart`
- Test: `test/features/canvas/util/lane_tint_test.dart`

**Interfaces:**
- Produces:
  - `String? inferTintHex(String stylePrompt)` — keyword→hex, first group hit wins, null if none
  - `Color? parseHexColor(String? hex)` — `#RRGGBB`/`#AARRGGBB`→Color, null if invalid
  - `Color? effectiveLaneTint({required String? tintColor, required String stylePrompt})` — user color first, else inferred, else null

- [ ] **Step 1: Write failing test**

```dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/lane_tint.dart';

void main() {
  test('infers warm orange from zh/en keywords', () {
    expect(inferTintHex('烛光餐厅'), '#FF8A50');
    expect(inferTintHex('warm sunset light'), '#FF8A50');
  });
  test('first group in table order wins (no stacking)', () {
    // contains both 暖(warm group) and 夜(cold group); warm defined first.
    expect(inferTintHex('暖色的夜晚'), '#FF8A50');
  });
  test('returns null when no keyword and when empty', () {
    expect(inferTintHex('abstract geometry'), isNull);
    expect(inferTintHex('   '), isNull);
  });
  test('parseHexColor handles #RRGGBB and #AARRGGBB', () {
    expect(parseHexColor('#FF8A50'), const Color(0xFFFF8A50));
    expect(parseHexColor('80FF8A50'), const Color(0x80FF8A50));
    expect(parseHexColor('bad'), isNull);
    expect(parseHexColor(null), isNull);
  });
  test('effectiveLaneTint prefers explicit color over inference', () {
    expect(effectiveLaneTint(tintColor: '#112233', stylePrompt: '森林'), const Color(0xFF112233));
    expect(effectiveLaneTint(tintColor: null, stylePrompt: '森林'), const Color(0xFF3E7C5A));
    expect(effectiveLaneTint(tintColor: null, stylePrompt: 'nothing'), isNull);
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement**

```dart
// PRD §7.3 风格泳道底色推断：中英双语词表，按定义顺序取首个命中、不叠加。
import 'dart:ui';

const List<({String hex, List<String> keywords})> _kTintGroups = [
  (hex: '#FF8A50', keywords: ['暖', '黄昏', '餐厅', '烛光', 'warm', 'dusk', 'sunset', 'restaurant', 'candle']),
  (hex: '#4A78C8', keywords: ['雨', '夜', '冷', '霓虹', 'rain', 'night', 'cold', 'neon']),
  (hex: '#9AD8D8', keywords: ['荧光', '白', '医院', '办公', 'fluorescent', 'white', 'hospital', 'office']),
  (hex: '#3E7C5A', keywords: ['森林', '自然', '草地', 'forest', 'nature', 'grass', 'meadow']),
  (hex: '#6A4C93', keywords: ['恐怖', '暗', '废墟', 'horror', 'dark', 'ruin']),
];

String? inferTintHex(String stylePrompt) {
  final lower = stylePrompt.trim().toLowerCase();
  if (lower.isEmpty) return null;
  for (final g in _kTintGroups) {
    for (final kw in g.keywords) {
      if (lower.contains(kw.toLowerCase())) return g.hex;
    }
  }
  return null;
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

Color? effectiveLaneTint({required String? tintColor, required String stylePrompt}) =>
    parseHexColor(tintColor) ?? parseHexColor(inferTintHex(stylePrompt));
```

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/util/lane_tint.dart test/features/canvas/util/lane_tint_test.dart && git commit -m "feat(canvas): lane tint inference util"`

---

### Task 3: Prompt assembler (pure, PRD §7.4)

**Files:**
- Create: `lib/features/generation/services/prompt_assembler.dart`
- Test: `test/features/generation/prompt_assembler_test.dart`

**Interfaces:**
- Produces: `String assemblePrompt({String baseStylePrefix, String laneStylePrompt, List<String> associatedTexts, required String userPrompt, String baseStyleSuffix, bool ignoreLaneStyle})`

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/generation/services/prompt_assembler.dart';

void main() {
  test('joins all non-empty segments with ", "', () {
    final r = assemblePrompt(
      baseStylePrefix: 'cinematic',
      laneStylePrompt: 'warm light',
      associatedTexts: ['a girl', 'red coat'],
      userPrompt: 'walking',
      baseStyleSuffix: '8k',
    );
    expect(r, 'cinematic, warm light, a girl, red coat, walking, 8k');
  });
  test('skips empty segments, no dangling comma', () {
    expect(assemblePrompt(userPrompt: 'solo'), 'solo');
    expect(assemblePrompt(baseStylePrefix: 'x', userPrompt: 'y'), 'x, y');
  });
  test('does not add comma after a segment ending in punctuation', () {
    expect(assemblePrompt(baseStylePrefix: 'a scene.', userPrompt: 'night'), 'a scene. night');
  });
  test('ignoreLaneStyle drops the lane segment', () {
    final r = assemblePrompt(laneStylePrompt: 'warm', userPrompt: 'cat', ignoreLaneStyle: true);
    expect(r, 'cat');
  });
  test('associated texts keep given order', () {
    expect(assemblePrompt(associatedTexts: ['1', '2', '3'], userPrompt: 'p'), '1, 2, 3, p');
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement**

```dart
// PRD §7.4 唯一拼接公式：base前缀 + 泳道风格 + 关联文本 + 用户prompt + base后缀。
// 段间 ", "（上段以标点结尾则只空格）；空段跳过；ignoreLaneStyle 时泳道段为空。
String assemblePrompt({
  String baseStylePrefix = '',
  String laneStylePrompt = '',
  List<String> associatedTexts = const [],
  required String userPrompt,
  String baseStyleSuffix = '',
  bool ignoreLaneStyle = false,
}) {
  final segments = <String>[
    baseStylePrefix,
    if (!ignoreLaneStyle) laneStylePrompt,
    ...associatedTexts,
    userPrompt,
    baseStyleSuffix,
  ];
  final parts = [for (final s in segments) if (s.trim().isNotEmpty) s.trim()];
  if (parts.isEmpty) return '';
  final buf = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i++) {
    buf.write(_endsWithPunct(parts[i - 1]) ? ' ' : ', ');
    buf.write(parts[i]);
  }
  return buf.toString();
}

const _kPunct = {',', '.', ';', '!', '?', '，', '。', '；', '！', '？', '、'};
bool _endsWithPunct(String s) => s.isNotEmpty && _kPunct.contains(s[s.length - 1]);
```

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/generation/services/prompt_assembler.dart test/features/generation/prompt_assembler_test.dart && git commit -m "feat(generation): §7.4 prompt assembler"`

---

### Task 4: StyleLane model

**Files:**
- Create: `lib/features/canvas/models/style_lane.dart`
- Test: `test/features/canvas/models/style_lane_test.dart`

**Interfaces:**
- Produces: `StyleLane` (immutable) with fields `id, canvasId, label, stylePrompt, sortOrder, tintColor?, size`; `copyWith`; `==`/`hashCode`; `static StyleLane fromRow(Map<String,Object?>)`.

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';

void main() {
  test('fromRow maps columns', () {
    final lane = StyleLane.fromRow({
      'id': 'l1', 'canvas_id': 'c1', 'label': 'Day', 'style_prompt': 'warm',
      'sort_order': 2, 'tint_color': '#FF8A50', 'size': 320.0,
    });
    expect(lane.id, 'l1');
    expect(lane.canvasId, 'c1');
    expect(lane.label, 'Day');
    expect(lane.stylePrompt, 'warm');
    expect(lane.sortOrder, 2);
    expect(lane.tintColor, '#FF8A50');
    expect(lane.size, 320.0);
  });
  test('fromRow tolerates nulls with defaults', () {
    final lane = StyleLane.fromRow({'id': 'l', 'canvas_id': 'c'});
    expect(lane.label, '');
    expect(lane.stylePrompt, '');
    expect(lane.sortOrder, 0);
    expect(lane.tintColor, isNull);
    expect(lane.size, 400.0);
  });
  test('copyWith + equality', () {
    const a = StyleLane(id: 'l', canvasId: 'c', label: 'x');
    expect(a.copyWith(label: 'y').label, 'y');
    expect(a.copyWith(), a);
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement**

```dart
// StyleLane：风格泳道 UI 模型（手写不可变，对齐 CanvasNode 风格，不引 freezed）。
import 'package:flutter/foundation.dart';

@immutable
class StyleLane {
  const StyleLane({
    required this.id,
    required this.canvasId,
    this.label = '',
    this.stylePrompt = '',
    this.sortOrder = 0,
    this.tintColor,
    this.size = 400.0,
  });

  final String id;
  final String canvasId;
  final String label;
  final String stylePrompt;
  final int sortOrder;
  final String? tintColor;
  final double size;

  StyleLane copyWith({
    String? label,
    String? stylePrompt,
    int? sortOrder,
    String? tintColor,
    bool clearTint = false,
    double? size,
  }) =>
      StyleLane(
        id: id,
        canvasId: canvasId,
        label: label ?? this.label,
        stylePrompt: stylePrompt ?? this.stylePrompt,
        sortOrder: sortOrder ?? this.sortOrder,
        tintColor: clearTint ? null : (tintColor ?? this.tintColor),
        size: size ?? this.size,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyleLane &&
          id == other.id &&
          canvasId == other.canvasId &&
          label == other.label &&
          stylePrompt == other.stylePrompt &&
          sortOrder == other.sortOrder &&
          tintColor == other.tintColor &&
          size == other.size;

  @override
  int get hashCode =>
      Object.hash(id, canvasId, label, stylePrompt, sortOrder, tintColor, size);

  static StyleLane fromRow(Map<String, Object?> row) => StyleLane(
        id: row['id']!.toString(),
        canvasId: row['canvas_id']!.toString(),
        label: (row['label'] as String?) ?? '',
        stylePrompt: (row['style_prompt'] as String?) ?? '',
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        tintColor: row['tint_color'] as String?,
        size: (row['size'] as num?)?.toDouble() ?? 400.0,
      );
}
```

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/models/style_lane.dart test/features/canvas/models/style_lane_test.dart && git commit -m "feat(canvas): StyleLane model"`

---

### Task 5: i18n keys + gen-l10n

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- Generated (do not hand-edit): `lib/l10n/generated/*`

**Interfaces:**
- Produces these `context.l10n` getters used by later tasks: `laneAdd, laneNewTitle, laneEditTitle, laneNameLabel, laneNameHint, laneStyleLabel, laneStyleHint, laneTintLabel, laneTintAuto, laneResetAuto, laneSizeLabel, laneDelete, laneDeleteConfirmTitle, laneDeleteConfirmBody, laneDialogSave, laneDialogCancel, laneDirectionToggle, laneUntitled, laneCreateFailed, laneUpdateFailed, laneDeleteFailed, inspectorPromptPreviewLabel, inspectorIgnoreLaneStyle`.

- [ ] **Step 1: Add keys to `lib/l10n/app_en.arb`** (insert before closing brace; keep existing keys):

```json
  "laneAdd": "Add lane",
  "laneNewTitle": "New lane",
  "laneEditTitle": "Edit lane",
  "laneNameLabel": "Name",
  "laneNameHint": "Lane name",
  "laneStyleLabel": "Style description",
  "laneStyleHint": "e.g. warm sunset lighting, candlelit",
  "laneTintLabel": "Background color",
  "laneTintAuto": "Auto",
  "laneResetAuto": "Reset to auto",
  "laneSizeLabel": "Lane size",
  "laneDelete": "Delete lane",
  "laneDeleteConfirmTitle": "Delete this lane?",
  "laneDeleteConfirmBody": "Nodes in this lane keep their position but lose the lane style.",
  "laneDialogSave": "Save",
  "laneDialogCancel": "Cancel",
  "laneDirectionToggle": "Toggle lane direction",
  "laneUntitled": "Untitled lane",
  "laneCreateFailed": "Failed to create lane",
  "laneUpdateFailed": "Failed to update lane",
  "laneDeleteFailed": "Failed to delete lane",
  "inspectorPromptPreviewLabel": "Final prompt preview",
  "inspectorIgnoreLaneStyle": "Ignore lane style"
```

- [ ] **Step 2: Add the SAME keys to `lib/l10n/app_zh.arb`:**

```json
  "laneAdd": "添加泳道",
  "laneNewTitle": "新建泳道",
  "laneEditTitle": "编辑泳道",
  "laneNameLabel": "名称",
  "laneNameHint": "泳道名称",
  "laneStyleLabel": "风格描述",
  "laneStyleHint": "如：温暖的黄昏光线、烛光",
  "laneTintLabel": "背景色",
  "laneTintAuto": "自动",
  "laneResetAuto": "重置为自动",
  "laneSizeLabel": "泳道尺寸",
  "laneDelete": "删除泳道",
  "laneDeleteConfirmTitle": "确认删除该泳道？",
  "laneDeleteConfirmBody": "泳道内节点位置保留，但会失去该泳道风格。",
  "laneDialogSave": "保存",
  "laneDialogCancel": "取消",
  "laneDirectionToggle": "切换泳道方向",
  "laneUntitled": "未命名泳道",
  "laneCreateFailed": "创建泳道失败",
  "laneUpdateFailed": "更新泳道失败",
  "laneDeleteFailed": "删除泳道失败",
  "inspectorPromptPreviewLabel": "最终 prompt 预览",
  "inspectorIgnoreLaneStyle": "忽略区域风格"
```

> Ensure the JSON before your insertion point ends with a comma. Keep both files' key order identical.

- [ ] **Step 3: Regenerate localizations**

Run: `"C:/Users/Kerro/flutter/bin/flutter.bat" gen-l10n`
Expected: regenerates `lib/l10n/generated/`, no errors.

- [ ] **Step 4: Verify key parity** — `"C:/Users/Kerro/flutter/bin/flutter.bat" test test/l10n` (if an ARB-parity test exists) OR run the project's parity check. Expected: en/zh key sets identical.

- [ ] **Step 5: Commit** — `git add lib/l10n && git commit -m "feat(i18n): style-lane UI keys (en+zh)"`

---

### Task 6: CanvasNode gains laneId + ignoreLaneStyle

**Files:**
- Modify: `lib/features/canvas/models/canvas_node.dart`
- Test: `test/features/canvas/models/canvas_node_lane_test.dart` (new)

**Interfaces:**
- Produces: `CanvasNode.laneId` (`String?`), `CanvasNode.ignoreLaneStyle` (`bool`, from `type_config['ignore_lane_style'] == true`), `copyWith({..., String? laneId, bool clearLaneId})`, `fromRow` maps `lane_id`.

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  test('fromRow maps lane_id and ignore_lane_style', () {
    final n = CanvasNodeMapping.fromRow({
      'id': 'n', 'canvas_id': 'c', 'type': 'image', 'node_role': 'config',
      'lane_id': 'lane-1', 'type_config': {'ignore_lane_style': true},
    });
    expect(n.laneId, 'lane-1');
    expect(n.ignoreLaneStyle, isTrue);
  });
  test('laneId null + ignore defaults false', () {
    final n = CanvasNodeMapping.fromRow({
      'id': 'n', 'canvas_id': 'c', 'type': 'image', 'node_role': 'config',
    });
    expect(n.laneId, isNull);
    expect(n.ignoreLaneStyle, isFalse);
  });
  test('copyWith sets and clears laneId', () {
    const n = CanvasNode(id: 'n', label: '', type: CanvasNodeType.image, laneId: 'a');
    expect(n.copyWith(laneId: 'b').laneId, 'b');
    expect(n.copyWith(clearLaneId: true).laneId, isNull);
    expect(n.copyWith().laneId, 'a');
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Edit `canvas_node.dart`** — apply these four edits:

(a) Add field to constructor (after `this.sourceNodeId,`):
```dart
    this.laneId,
```
(b) Add field declaration (after `final String? sourceNodeId;` block):
```dart
  /// 所属泳道 id（schema nodes.lane_id）；不在任何泳道时为 null。
  final String? laneId;
```
(c) Add getter (near other typeConfig getters):
```dart
  /// 该节点是否忽略所属泳道的风格（type_config.ignore_lane_style）。
  bool get ignoreLaneStyle => typeConfig['ignore_lane_style'] == true;
```
(d) Update `copyWith` signature + body — add `String? laneId, bool clearLaneId = false,` to params and `laneId: clearLaneId ? null : (laneId ?? this.laneId),` to the constructor call.
(e) Update `==` to add `laneId == other.laneId &&` and `hashCode` to include `laneId`.
(f) In `fromRow`, add `laneId: row['lane_id']?.toString(),` to the `CanvasNode(...)` construction.

- [ ] **Step 4: Run, verify PASS.** Also run existing `test/features/canvas/canvas_nodes_controller_test.dart` to ensure no regression.
- [ ] **Step 5: Commit** — `git add lib/features/canvas/models/canvas_node.dart test/features/canvas/models/canvas_node_lane_test.dart && git commit -m "feat(canvas): CanvasNode laneId + ignoreLaneStyle"`

---

### Task 7: canvasLanesController + lane direction provider

**Files:**
- Create: `lib/features/canvas/providers/canvas_lanes_controller.dart`
- Test: `test/features/canvas/canvas_lanes_controller_test.dart`

**Interfaces:**
- Consumes: `StyleLane` (T4), `styleLaneRepositoryProvider` + `canvasRepositoryProvider` (`lib/core/di/repositories.dart`), `LaneDirection`/`laneDirectionFromString`/`laneDirectionToString` (T1).
- Produces:
  - `canvasLanesControllerProvider` (`AutoDisposeAsyncNotifierProviderFamily<CanvasLanesController, List<StyleLane>, String>`)
  - `CanvasLanesController` with `Future<StyleLane> createLane({String label, String stylePrompt, String? tintColor})`, `Future<void> updateLane(String id, {String? label, String? stylePrompt, String? tintColor, bool clearTint, double? size})`, `Future<void> deleteLane(String id)`
  - `canvasLaneDirectionProvider` (`FutureProvider.autoDispose.family<LaneDirection, String>`)
  - `Future<void> setLaneDirection(Ref ref, String canvasId, LaneDirection dir)` — updates canvas row + invalidates provider

- [ ] **Step 1: Write failing test** (mirror `canvas_nodes_controller_test.dart` harness; use `FakeStyleLaneRepository` from `test/_harness/fake_repositories.dart` — if absent, add a minimal fake there).

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/core/interfaces/style_lane_repository.dart';

class _FakeLaneRepo implements StyleLaneRepository {
  final Map<String, Map<String, Object?>> store = {};
  int _seq = 0;
  @override
  Future<String> create({required String canvasId, String label = '', String stylePrompt = '', int sortOrder = 0, String? tintColor, double size = 400.0}) async {
    final id = 'lane-${_seq++}';
    store[id] = {'id': id, 'canvas_id': canvasId, 'label': label, 'style_prompt': stylePrompt, 'sort_order': sortOrder, 'tint_color': tintColor, 'size': size};
    return id;
  }
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) async =>
      store.values.where((r) => r['canvas_id'] == canvasId).toList();
  @override
  Future<int> update(String id, Map<String, Object?> patch) async { store[id]?.addAll(patch); return 1; }
  @override
  Future<int> softDelete(String id) async => store.remove(id) == null ? 0 : 1;
  @override
  Future<Map<String, Object?>?> findById(String id) async => store[id];
  @override
  Future<int> restore(String id) async => 0;
  @override
  Future<int> hardDelete(String id) async => store.remove(id) == null ? 0 : 1;
}

void main() {
  test('createLane appends and updates state', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final lane = await c.read(canvasLanesControllerProvider('cv').notifier).createLane(label: 'A');
    expect(lane.label, 'A');
    final lanes = c.read(canvasLanesControllerProvider('cv')).valueOrNull!;
    expect(lanes.map((l) => l.id), contains(lane.id));
  });

  test('deleteLane removes from state', () async {
    final repo = _FakeLaneRepo();
    final c = ProviderContainer(overrides: [
      styleLaneRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(c.dispose);
    await c.read(canvasLanesControllerProvider('cv').future);
    final notifier = c.read(canvasLanesControllerProvider('cv').notifier);
    final lane = await notifier.createLane(label: 'A');
    await notifier.deleteLane(lane.id);
    expect(c.read(canvasLanesControllerProvider('cv')).valueOrNull, isEmpty);
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement** (model after `CanvasNodesController`'s `_alive` + optimistic pattern):

```dart
// CanvasLanesController — DB-backed 画布泳道集合（按 canvasId 分族）。
// 乐观更新 + 失败回滚，与 CanvasNodesController 同策略（ME-27 _alive 守卫）。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/repositories.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/style_lane_repository.dart';
import '../models/style_lane.dart';
import '../util/lane_geometry.dart';

final canvasLanesControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    CanvasLanesController, List<StyleLane>, String>(
  CanvasLanesController.new,
  name: 'canvasLanesControllerProvider',
);

class CanvasLanesController
    extends AutoDisposeFamilyAsyncNotifier<List<StyleLane>, String> {
  bool _alive = false;

  @override
  Future<List<StyleLane>> build(String canvasId) async {
    _alive = true;
    ref.onDispose(() => _alive = false);
    final repo = await ref.watch(styleLaneRepositoryProvider.future);
    final rows = await repo.listByCanvas(canvasId);
    final lanes = rows.map(StyleLane.fromRow).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return lanes;
  }

  StyleLaneRepository get _repo {
    final repo = ref.read(styleLaneRepositoryProvider).valueOrNull;
    if (repo == null) throw StateError('styleLaneRepositoryProvider not ready');
    return repo;
  }

  Future<StyleLane> createLane({
    String label = '',
    String stylePrompt = '',
    String? tintColor,
  }) async {
    final repo = _repo;
    final canvasId = arg;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    final nextOrder =
        previous.isEmpty ? 0 : previous.map((l) => l.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final id = await repo.create(
      canvasId: canvasId,
      label: label,
      stylePrompt: stylePrompt,
      sortOrder: nextOrder,
      tintColor: tintColor,
    );
    final lane = StyleLane(
      id: id,
      canvasId: canvasId,
      label: label,
      stylePrompt: stylePrompt,
      sortOrder: nextOrder,
      tintColor: tintColor,
    );
    if (_alive) state = AsyncData([...previous, lane]);
    return lane;
  }

  Future<void> updateLane(
    String id, {
    String? label,
    String? stylePrompt,
    String? tintColor,
    bool clearTint = false,
    double? size,
  }) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    final patch = <String, Object?>{
      if (label != null) 'label': label,
      if (stylePrompt != null) 'style_prompt': stylePrompt,
      if (clearTint) 'tint_color': null else if (tintColor != null) 'tint_color': tintColor,
      if (size != null) 'size': size,
    };
    if (patch.isEmpty) return;
    state = AsyncData([
      for (final l in previous)
        if (l.id == id)
          l.copyWith(
            label: label,
            stylePrompt: stylePrompt,
            tintColor: tintColor,
            clearTint: clearTint,
            size: size,
          )
        else
          l,
    ]);
    try {
      await repo.update(id, patch);
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> deleteLane(String id) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <StyleLane>[];
    state = AsyncData(previous.where((l) => l.id != id).toList());
    try {
      await repo.softDelete(id);
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
}

/// 画布泳道方向（读 canvases.lane_direction）。
final canvasLaneDirectionProvider =
    FutureProvider.autoDispose.family<LaneDirection, String>((ref, canvasId) async {
  final repo = await ref.watch(canvasRepositoryProvider.future);
  final row = await repo.findById(canvasId);
  return laneDirectionFromString((row?['lane_direction'] as String?) ?? 'horizontal');
});

/// 切换并持久化泳道方向，然后失效方向 provider 触发重读。
Future<void> setLaneDirection(Ref ref, String canvasId, LaneDirection dir) async {
  final repo = await ref.read(canvasRepositoryProvider.future);
  await repo.update(canvasId, {'lane_direction': laneDirectionToString(dir)});
  ref.invalidate(canvasLaneDirectionProvider(canvasId));
}
```

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/providers/canvas_lanes_controller.dart test/features/canvas/canvas_lanes_controller_test.dart && git commit -m "feat(canvas): canvasLanesController + lane direction provider"`

---

### Task 8: Persist node move + lane assignment

**Files:**
- Modify: `lib/features/canvas/providers/canvas_nodes_controller.dart`
- Test: extend `test/features/canvas/canvas_nodes_controller_test.dart`

**Interfaces:**
- Consumes: `NodeRepository.update` (already exists), `CanvasNode.copyWith(clearLaneId:)` (T6).
- Produces: replaces `void moveNode(String id, Offset delta)` with `Future<void> moveNode(String id, Offset delta, {required String? laneId})` — persists `position_x/y` + `lane_id` (incl. null) optimistically, rolls back on `InkError`.

- [ ] **Step 1: Write failing test** (use existing fake NodeRepository in `test/_harness/fake_repositories.dart`; assert repo received an `update` with new position + lane_id, and rollback on failure).

```dart
// Add inside the existing controller test group:
test('moveNode persists position and lane_id, updates state', () async {
  // arrange: container with fake node repo containing one node at (0,0)
  // act: await controller.moveNode(id, const Offset(50, 60), laneId: 'lane-9');
  // assert: fake repo last update == {'position_x': 50.0, 'position_y': 60.0, 'lane_id': 'lane-9'}
  //         and state node.position == Offset(50,60), node.laneId == 'lane-9'
});
test('moveNode rolls back memory on InkError', () async {
  // fake repo.update throws LocalIOError → expect throwsA(isA<InkError>())
  //   and state node position unchanged.
});
```
(Implementer: flesh out using the same fake-repo wiring already present in this test file.)

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Replace `moveNode`**

```dart
  /// 拖动结束：持久化新位置 + 归属泳道（laneId 可为 null=移出所有泳道）。
  /// 乐观更新内存，DB 失败回滚并上抛（UI toast）。
  Future<void> moveNode(String id, Offset delta, {required String? laneId}) async {
    final repo = _repo;
    final previous = state.valueOrNull ?? const <CanvasNode>[];
    CanvasNode? target;
    for (final n in previous) {
      if (n.id == id) target = n;
    }
    if (target == null) return;
    final newPos = target.position + delta;
    state = AsyncData([
      for (final n in previous)
        if (n.id == id)
          n.copyWith(position: newPos, laneId: laneId, clearLaneId: laneId == null)
        else
          n,
    ]);
    try {
      await repo.update(id, <String, Object?>{
        'position_x': newPos.dx,
        'position_y': newPos.dy,
        'lane_id': laneId,
      });
    } on InkError catch (_) {
      if (_alive) state = AsyncData(previous);
      rethrow;
    }
  }
```

> Update the file header comment (the S3 "moveNode 只改内存" note) to reflect that move now persists.

- [ ] **Step 4: Run, verify PASS** (this file's full test).
- [ ] **Step 5: Commit** — `git add lib/features/canvas/providers/canvas_nodes_controller.dart test/features/canvas/canvas_nodes_controller_test.dart && git commit -m "feat(canvas): persist node move + lane assignment"`

---

### Task 9: LaneBackground painter

**Files:**
- Create: `lib/features/canvas/widgets/lane_background.dart`
- Test: `test/features/canvas/widgets/lane_background_test.dart`

**Interfaces:**
- Consumes: `StyleLane` (T4), `laneRects`/`LaneDirection` (T1), `effectiveLaneTint` (T2).
- Produces: `class LaneBackground extends StatelessWidget` with `{required List<StyleLane> lanes, required LaneDirection direction, required double canvasExtent, required Color dividerColor}`.

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/lane_background.dart';

void main() {
  testWidgets('renders a CustomPaint for lanes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LaneBackground(
        lanes: const [StyleLane(id: 'a', canvasId: 'c', size: 100, tintColor: '#FF8A50')],
        direction: LaneDirection.horizontal,
        canvasExtent: 400,
        dividerColor: const Color(0xFF333333),
      ),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
```

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement**

```dart
// 泳道背景层：CustomPaint。底色由数据驱动（effectiveLaneTint），分界线色由调用方传入 token。
import 'package:flutter/material.dart';

import '../models/style_lane.dart';
import '../util/lane_geometry.dart';
import '../util/lane_tint.dart';

class LaneBackground extends StatelessWidget {
  const LaneBackground({
    super.key,
    required this.lanes,
    required this.direction,
    required this.canvasExtent,
    required this.dividerColor,
  });

  final List<StyleLane> lanes;
  final LaneDirection direction;
  final double canvasExtent;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(canvasExtent),
      painter: _LanePainter(
        lanes: lanes,
        direction: direction,
        canvasExtent: canvasExtent,
        dividerColor: dividerColor,
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  _LanePainter({
    required this.lanes,
    required this.direction,
    required this.canvasExtent,
    required this.dividerColor,
  });

  final List<StyleLane> lanes;
  final LaneDirection direction;
  final double canvasExtent;
  final Color dividerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = laneRects(
      lanes: [for (final l in lanes) (id: l.id, size: l.size)],
      direction: direction,
      canvasExtent: canvasExtent,
    );
    final line = Paint()
      ..color = dividerColor
      ..strokeWidth = 1;
    for (var i = 0; i < lanes.length; i++) {
      final rect = rects[i];
      final tint = effectiveLaneTint(
        tintColor: lanes[i].tintColor,
        stylePrompt: lanes[i].stylePrompt,
      );
      if (tint != null) {
        canvas.drawRect(rect, Paint()..color = tint.withValues(alpha: 0.10));
      }
      // 分界线：泳道末端 1px 细线（首条不画起始线）。
      if (i > 0) {
        if (direction == LaneDirection.horizontal) {
          canvas.drawLine(Offset(0, rect.top), Offset(canvasExtent, rect.top), line);
        } else {
          canvas.drawLine(Offset(rect.left, 0), Offset(rect.left, canvasExtent), line);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LanePainter old) =>
      old.direction != direction ||
      old.dividerColor != dividerColor ||
      !_sameLanes(old.lanes, lanes);

  bool _sameLanes(List<StyleLane> a, List<StyleLane> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
```

> If `withValues` is unavailable on this Flutter version, use `tint.withOpacity(0.10)`.

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/widgets/lane_background.dart test/features/canvas/widgets/lane_background_test.dart && git commit -m "feat(canvas): lane background painter"`

---

### Task 10: LaneTitleBar overlay

**Files:**
- Create: `lib/features/canvas/widgets/lane_title_bar.dart`
- Test: `test/features/canvas/widgets/lane_title_bar_test.dart`

**Interfaces:**
- Consumes: `StyleLane` (T4), tokens, l10n keys (T5).
- Produces: `class LaneTitleBar extends StatelessWidget` with `{required StyleLane lane, required VoidCallback onEdit, required VoidCallback onDelete}` — a half-opaque bar showing `lane.label` (fallback `l10n.laneUntitled`) + edit + delete icon buttons.

- [ ] **Step 1: Write failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/widgets/lane_title_bar.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

void main() {
  testWidgets('shows label and fires onEdit', (tester) async {
    var edited = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(AppThemeVariant.dark),
      home: Scaffold(
        body: LaneTitleBar(
          lane: const StyleLane(id: 'a', canvasId: 'c', label: 'Day'),
          onEdit: () => edited = true,
          onDelete: () {},
        ),
      ),
    ));
    expect(find.text('Day'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit).first);
    expect(edited, isTrue);
  });
}
```

> Confirm the actual `buildAppTheme` signature / `AppThemeVariant` name from `lib/theme/app_theme.dart` and adjust the test harness accordingly.

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement** — a `Material` bar (`colors.surface3` @ partial opacity), `Row` with `Expanded(Text(label))` + `IconButton(Icons.edit)` + `IconButton(Icons.delete_outline)`, all sizes via `InkSpacing`, colors via `context.inkColors`, tooltips via `context.l10n.laneEditTitle` / `laneDelete`.

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/widgets/lane_title_bar.dart test/features/canvas/widgets/lane_title_bar_test.dart && git commit -m "feat(canvas): lane title bar overlay"`

---

### Task 11: LaneEditDialog

**Files:**
- Create: `lib/features/canvas/widgets/lane_edit_dialog.dart`
- Test: `test/features/canvas/widgets/lane_edit_dialog_test.dart`

**Interfaces:**
- Consumes: `StyleLane` (T4), `effectiveLaneTint`/`inferTintHex` (T2), l10n (T5), `InkInput` (`lib/theme/components/ink_input.dart`).
- Produces: `Future<LaneEditResult?> showLaneEditDialog(BuildContext context, {StyleLane? existing})`; `class LaneEditResult { final String label; final String stylePrompt; final String? tintColor; }` — `tintColor==null` means "auto".

- [ ] **Step 1: Write failing test**

```dart
// Pump a button that calls showLaneEditDialog; enter name + style; tap Save;
// assert returned LaneEditResult has the typed label/style and tintColor null (auto).
// (Implementer: build the harness like other dialog tests in the repo, with AppLocalizations delegates + theme.)
```

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement** — `AlertDialog`-style using tokens: name `InkInput`, style `InkInput` (multiline), a row of tint swatches (the 5 `_kTintGroups` hexes are private; expose preset swatches by hardcoding the same hex list HERE as a UI constant `const _kLaneSwatches = ['#FF8A50','#4A78C8','#9AD8D8','#3E7C5A','#6A4C93']`) + an "Auto" chip (`laneTintAuto`) that sets tintColor=null, + live preview box using `effectiveLaneTint`. Save returns `LaneEditResult`; Cancel returns null. Buttons use `laneDialogSave` / `laneDialogCancel`.

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/widgets/lane_edit_dialog.dart test/features/canvas/widgets/lane_edit_dialog_test.dart && git commit -m "feat(canvas): lane edit dialog"`

---

### Task 12: LaneToolbar (add lane + direction toggle)

**Files:**
- Create: `lib/features/canvas/widgets/lane_toolbar.dart`
- Test: `test/features/canvas/widgets/lane_toolbar_test.dart`

**Interfaces:**
- Consumes: `canvasLanesControllerProvider`, `canvasLaneDirectionProvider`, `setLaneDirection` (T7), `showLaneEditDialog` (T11), l10n (T5).
- Produces: `class LaneToolbar extends ConsumerWidget` with `{required String canvasId}` — a compact `Row`/`Column` with a "+lane" button (opens `showLaneEditDialog`, then `createLane`) and a direction-toggle `IconButton`.

- [ ] **Step 1: Write failing test** — pump `LaneToolbar` in a `ProviderScope` with overridden lane/canvas repos; tap +; verify `showLaneEditDialog` path creates a lane (assert via the lanes controller state). Keep it a smoke test if full dialog flow is heavy.

- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement** — read `canvasLaneDirectionProvider(canvasId)` for the toggle icon (`Icons.swap_horiz`/`swap_vert`), `+` button calls `showLaneEditDialog` then `ref.read(canvasLanesControllerProvider(canvasId).notifier).createLane(...)` with `.catchError` → snackbar `laneCreateFailed`; toggle calls `setLaneDirection(ref, canvasId, flipped)`. All styling via tokens.

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/widgets/lane_toolbar.dart test/features/canvas/widgets/lane_toolbar_test.dart && git commit -m "feat(canvas): lane toolbar (add + direction toggle)"`

---

### Task 13: Integrate lanes into CanvasView

**Files:**
- Modify: `lib/features/canvas/widgets/canvas_view.dart`
- Test: `test/features/canvas/widgets/canvas_lane_integration_test.dart` (new)

**Interfaces:**
- Consumes: `canvasLanesControllerProvider`, `canvasLaneDirectionProvider` (T7), `LaneBackground` (T9), `LaneTitleBar` (T10), `showLaneEditDialog` (T11), `LaneToolbar` (T12), `laneIdAtPoint` + `laneRects` (T1).
- Produces: lanes rendered behind edges/nodes; title bars overlaid; toolbar shown; `onDragEnd` computes target lane and calls `moveNode(id, delta, laneId: ...)`.

- [ ] **Step 1: Write failing widget test** — render a canvas with one lane (override repos) and one node; drag the node into the lane's band; assert `NodeRepository.update` was called with the lane's id. (Mirror existing `canvas_screen_job_listener_test.dart` harness.)

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Edit `_CanvasStage`** (the `InteractiveViewer → SizedBox(4000) → Stack`):
  - Add at top of `build`: read lanes + direction:
    ```dart
    final lanes = ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ?? const <StyleLane>[];
    final direction = ref.watch(canvasLaneDirectionProvider(canvasId)).valueOrNull ?? LaneDirection.horizontal;
    ```
  - Insert as the FIRST child of the `Stack` (behind edge layer):
    ```dart
    if (lanes.isNotEmpty)
      Positioned.fill(
        child: IgnorePointer(
          child: LaneBackground(
            lanes: lanes, direction: direction, canvasExtent: 4000,
            dividerColor: colors.borderSubtle,
          ),
        ),
      ),
    ```
  - Change each node's `onDragEnd` to compute the lane from the node's new center:
    ```dart
    onDragEnd: (totalDelta) {
      final center = node.position + totalDelta + Offset(node.size.width / 2, node.size.height / 2);
      final laneId = laneIdAtPoint(point: center, lanes: [for (final l in lanes) (id: l.id, size: l.size)], direction: direction);
      ref.read(canvasNodesControllerProvider(canvasId).notifier).moveNode(node.id, totalDelta, laneId: laneId).catchError((Object _) {});
    },
    ```
  - Add lane title bars (after node layer, before edge-delete button) — for each lane compute its rect via `laneRects` and place a `Positioned` `LaneTitleBar` at the rect's top-left (horizontal: full-width strip at `rect.top`; vertical: at `rect.left`), wired to `showLaneEditDialog` (→ `updateLane`) and delete-confirm (→ `deleteLane`).
  - In `_CanvasBody.build`, overlay `LaneToolbar(canvasId: canvasId)` in the `leftArea` Stack (e.g. top-left, below the link hint).

- [ ] **Step 4: Run, verify PASS** + run full canvas test dir.
- [ ] **Step 5: Commit** — `git add lib/features/canvas/widgets/canvas_view.dart test/features/canvas/widgets/canvas_lane_integration_test.dart && git commit -m "feat(canvas): render lanes + drag-to-assign in CanvasView"`

---

### Task 14: Inject lane/base/text prompt into generation

**Files:**
- Modify: `lib/features/generation/generation_controller.dart`
- Test: `test/features/generation/generation_controller_prompt_test.dart` (new)

**Interfaces:**
- Consumes: `assemblePrompt` (T3), `CanvasRepository` + `StyleLaneRepository` (DI), existing `edges`/`nodes`.
- Produces: `submitFromConfigNode` builds `fullPrompt` via `assemblePrompt`; `jobs.create(fullPrompt: full, userPrompt: prompt, ...)` and `GenerationTask(prompt: full, ...)`.

- [ ] **Step 1: Write failing test** — fake node/canvas/lane/edge repos: a config node with `lane_id` + canvas base prefix/suffix + a connected text node; assert the created job's `fullPrompt` equals the §7.4 assembly; assert `ignore_lane_style:true` drops the lane segment; assert missing canvas/lane degrades to bare `userPrompt`.

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Edit controller** — four edits:
  - (a) Provider (`generationControllerProvider`): add
    ```dart
    final canvas = await ref.watch(canvasRepositoryProvider.future);
    final lanes = await ref.watch(styleLaneRepositoryProvider.future);
    ```
    and pass `canvas: canvas, lanes: lanes` to the constructor.
  - (b) Constructor + fields: add `required this.canvas,` / `required this.lanes,` and `final CanvasRepository canvas; final StyleLaneRepository lanes;` (import the two interfaces).
  - (c) Add a private resolver after `_resolveRefImages`:
    ```dart
    /// PRD §7.4：组装 base前缀 + 泳道风格 + 关联文本 + userPrompt + base后缀。
    /// 任一查询失败降级（仅用 userPrompt），不阻断生成。
    Future<String> _assembleFullPrompt({
      required String userPrompt,
      required String canvasId,
      required String configNodeId,
      required String? laneId,
      required bool ignoreLaneStyle,
    }) async {
      var basePrefix = '';
      var baseSuffix = '';
      try {
        final c = await canvas.findById(canvasId);
        basePrefix = (c?['base_style_prefix'] as String?) ?? '';
        baseSuffix = (c?['base_style_suffix'] as String?) ?? '';
      } catch (_) {}
      var laneStyle = '';
      if (!ignoreLaneStyle && laneId != null) {
        try {
          final l = await lanes.findById(laneId);
          laneStyle = (l?['style_prompt'] as String?) ?? '';
        } catch (_) {}
      }
      final texts = await _resolveAssociatedTexts(configNodeId);
      return assemblePrompt(
        baseStylePrefix: basePrefix,
        laneStylePrompt: laneStyle,
        associatedTexts: texts,
        userPrompt: userPrompt,
        baseStyleSuffix: baseSuffix,
        ignoreLaneStyle: ignoreLaneStyle,
      );
    }

    /// 连入的 data 边里的文本节点内容，按 edge.created_at 升序。
    Future<List<String>> _resolveAssociatedTexts(String configNodeId) async {
      final List<Map<String, Object?>> incoming;
      try {
        incoming = await edges.listIncoming(configNodeId);
      } catch (_) {
        return const [];
      }
      final rows = incoming.where((r) => r['edge_type'] == 'data').toList()
        ..sort((a, b) => (a['created_at']?.toString() ?? '')
            .compareTo(b['created_at']?.toString() ?? ''));
      final out = <String>[];
      for (final r in rows) {
        final srcId = r['source_node_id']?.toString();
        if (srcId == null) continue;
        Map<String, Object?>? src;
        try {
          src = await nodes.findById(srcId);
        } catch (_) {
          continue;
        }
        if (src == null || src['type'] != 'text') continue;
        final tc = _readTypeConfig(src['type_config']);
        final text = (tc['text'] as String?)?.trim();
        final label = (src['label'] as String?)?.trim();
        final content = (text != null && text.isNotEmpty) ? text : (label ?? '');
        if (content.isNotEmpty) out.add(content);
      }
      return out;
    }
    ```
  - (d) In `submitFromConfigNode`, after computing `prompt` and reading `cfgRow`, derive lane info and build `fullPrompt`, then use it:
    ```dart
    final laneId = cfgRow['lane_id']?.toString();
    final ignoreLane = typeConfig['ignore_lane_style'] == true;
    final fullPrompt = await _assembleFullPrompt(
      userPrompt: prompt,
      canvasId: canvasId,
      configNodeId: configNodeId,
      laneId: laneId,
      ignoreLaneStyle: ignoreLane,
    );
    ```
    Then change `jobs.create(... fullPrompt: fullPrompt, userPrompt: prompt, ...)` and `GenerationTask(... prompt: fullPrompt, ...)`.
    (Note: `canvasId` is defined at line ~161; ensure the assembly call is placed AFTER it.)

- [ ] **Step 4: Run, verify PASS** + existing `generation_controller_test.dart` / `generation_controller_video_test.dart` (update their fakes to provide canvas/lanes repos — supply empty fakes so they degrade to userPrompt and keep asserting current behavior).
- [ ] **Step 5: Commit** — `git add lib/features/generation/generation_controller.dart test/features/generation/ && git commit -m "feat(generation): inject lane/base/text prompt (§7.4)"`

---

### Task 15: Inspector — prompt preview + ignore-lane toggle

**Files:**
- Modify: `lib/features/canvas/widgets/image_config_inspector.dart`
- Test: `test/features/canvas/widgets/image_config_inspector_preview_test.dart` (new)

**Interfaces:**
- Consumes: `assemblePrompt` (T3), `canvasLanesControllerProvider` (T7), `canvasRepositoryProvider`, l10n (T5), `InspectorSubmitController.saveConfig` (existing).
- Produces: below the inputs section, a live "Final prompt preview" (read-only) computed from current prompt + node's lane + canvas base + connected texts; and a "Ignore lane style" `SwitchListTile` writing `type_config.ignore_lane_style` via `saveConfig`.

- [ ] **Step 1: Write failing widget test** — pump `ImageConfigInspector` with overrides (a node in a lane + canvas base prefix); type a prompt; assert the preview text contains the lane style and base prefix; toggle ignore → preview drops the lane segment.

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement** — add a `_PromptPreview` + ignore toggle:
  - Add a `bool _ignoreLane = widget.node.ignoreLaneStyle;` to state; a `SwitchListTile` (`title: Text(context.l10n.inspectorIgnoreLaneStyle)`) that on change `setState` + `_submitCtrl.saveConfig({'ignore_lane_style': v})`.
  - Add a `_PromptPreview` `ConsumerWidget` (or inline) that watches `canvasLanesControllerProvider(canvasId)` to find `node.laneId`'s `style_prompt`, reads canvas base via a small `FutureProvider`/`ref.watch(canvasRepositoryProvider...)` (degrade to empty on error), resolves connected text labels from `canvasNodesControllerProvider`+`canvasEdgesControllerProvider` (already watched in `_InputsSection`), then renders `assemblePrompt(...)` in a tokenized read-only box labeled `context.l10n.inspectorPromptPreviewLabel`.
  - Keep all styling via tokens; the preview updates as the prompt controller changes (it already calls `setState` in `_onPromptChanged`).

- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** — `git add lib/features/canvas/widgets/image_config_inspector.dart test/features/canvas/widgets/image_config_inspector_preview_test.dart && git commit -m "feat(canvas): inspector prompt preview + ignore-lane toggle"`

---

## Final verification (after all tasks)

- [ ] `"C:/Users/Kerro/flutter/bin/flutter.bat" analyze` → 0 issues
- [ ] `"C:/Users/Kerro/flutter/bin/flutter.bat" test` → all green
- [ ] i18n parity check passes (en/zh identical key sets)
- [ ] Manual DoD sanity (spec §7): lanes visible (h/v), CRUD works, drag reassigns + persists, generation `fullPrompt` includes lane style.

## Self-Review (completed by author)

- **Spec coverage:** §2.1.1 data/state → T4,T6,T7; §2.1.2 geometry/tint → T1,T2; §2.1.3 render → T9,T10,T13; §2.1.4 interaction → T8,T11,T12,T13; §2.1.5 prompt → T3,T14,T15; §2.1.6 i18n → T5; §2.1.7 tests → every task. Deferred items (§2.2) intentionally absent.
- **Placeholder scan:** core-logic tasks (T1–T9,T14) have complete code; UI tasks (T10–T13,T15) give complete interfaces + structural code + exact token/l10n/provider names — acceptable as they assemble already-specified pieces.
- **Type consistency:** `moveNode(id, delta, {required String? laneId})`, `copyWith({laneId, clearLaneId})`, `createLane/updateLane/deleteLane`, `assemblePrompt(...)`, `laneIdAtPoint(...)`, `effectiveLaneTint(...)` are referenced identically across tasks.
