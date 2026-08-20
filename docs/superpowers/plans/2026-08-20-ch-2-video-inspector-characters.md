# CH-2 视频 Inspector 角色区 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 image inspector 的角色区抽成共享 widget，挂进 video inspector——给 CH-1 已落地的视频角色注入补上用户可见入口（video 节点自此可写 `type_config.character_ids`）。

**Architecture:** 机械抽取 + 参数化门控。`_CharactersSection`/`_NameDialog`/`_CharacterChip` 从 `image_config_inspector.dart`（1033 行）整体搬到新共享文件 `characters_section.dart` 并转公开；唯一行为参数是 ref 支持判定——image 保持 `maxRefImages>0 && imageToImage`，video 对齐 CH-1 注入门只要 `maxRefImages>0`（**不检查 modes**，r2v/omni 语义，见 generation_controller.dart:674 拍板注释）。video 侧按卡片要求以 `maxRefImages>0` 门控挂载（不支持的 provider 整段不出现，与 image 侧「挂载+警示文案」不同属有意差异）。

**决策（卡片留白处，本计划拍板）：** `_NameDialog` 与 `_CharacterChip` 同时被 `_PresetsSection` 使用——**一并搬进共享文件转公开**（`InspectorNameDialog`/`CharacterChip`），image inspector 回头 import。理由：留私有副本=两份漂移源；`characters_section.dart` 是它们语义上的家（chip 渲染角色、dialog 命名角色，`_PresetsSection` 只是复用者）。image inspector 从 1033 行减 ~340 行，顺带完成卡片「给 image inspector 减重」目标。**不动 `_PromptPreview`**（P1-17 债明令勿同窗）。

**Tech Stack:** 纯 widget 搬移（零新依赖）；InspectorSubmitController.saveConfig 写 `character_ids`（既有）；测试复用 `test_app.dart` pumpInkApp + fake_repositories/fake_character harness。**零新 ARB key**（全部复用 inspectorCharacters* 既有键，本卡不碰 l10n）。

**行为零变化的证据面：** 既有 `image_config_inspector_characters_test.dart`（10 例）不改一行断言、搬移后必须全绿——这是「机械搬移未走样」的红线证据。

---

### Task 1: 抽取共享 `characters_section.dart`（image 侧行为零变化）

**Files:**
- Create: `lib/features/canvas/widgets/characters_section.dart`
- Modify: `lib/features/canvas/widgets/image_config_inspector.dart`（删 L586-940 三个类，import 新文件，改 4 处调用点）
- Test: 既有 `test/features/canvas/widgets/image_config_inspector_characters_test.dart` **不改动**，作回归证据

- [ ] **Step 1: 新建 `characters_section.dart`，整体搬移三个类**

从 `image_config_inspector.dart` 剪切（非复制）以下内容到新文件：
- `_CharactersSection` + `_CharactersSectionState`（现 L586-817）→ 改名 `CharactersSection`/`_CharactersSectionState`
- `_NameDialog` + `_NameDialogState`（现 L819-867 一带，含「controller 生命周期归 dialog」注释）→ 改名 `InspectorNameDialog`/`_InspectorNameDialogState`
- `_CharacterChip`（现 L869-940 一带，含 LB-23 cacheWidth 与 `_kCharacterThumbSize` 常量）→ 改名 `CharacterChip`；`_kCharacterThumbSize = 20` 常量一起搬

新文件头注释与公开签名（构造参数新增 `requireImageToImageMode`）：

```dart
// CharactersSection：config 节点角色区（CH-2 起 image/video inspector 共享）。
// 把项目级角色挂到节点（写 type_config.character_ids）+ 存为角色/从文件导入。
// ref 支持判定按调用方口径参数化：image 要求 maxRefImages>0 且 imageToImage;
// video 对齐 CH-1 注入门只要 maxRefImages>0（不检查 modes——r2v/omni 的参考图
// 语义不落在 modes 里，见 generation_controller._injectCharacterRefs 拍板注释）。

class CharactersSection extends ConsumerStatefulWidget {
  const CharactersSection({
    super.key,
    required this.targetNode,
    required this.selectedCaps,
    required this.requireImageToImageMode,
  });

  final CanvasNode targetNode;
  final ProviderCapabilities? selectedCaps;

  /// image inspector 传 true（维持原门）；video inspector 传 false（CH-1 口径）。
  final bool requireImageToImageMode;
  ...
}
```

`_supportsRefs` 改为：

```dart
  bool get _supportsRefs {
    final caps = widget.selectedCaps;
    if (caps == null || caps.maxRefImages <= 0) return false;
    return !widget.requireImageToImageMode ||
        caps.modes.contains(GenerationMode.imageToImage);
  }
```

其余方法体（`_readAttached`/`_toggle`/`_characterThumb`/`_referenceSource`/`build`/`_importFromFile`/`_createFromReference`/`_promptName`）**逐字搬移不改**。import 列表按 analyzer 报错补齐（来源即 image_config_inspector 现 import：canvas_node/provider_capabilities/inspector_submit_controller/characters_controller/canvas_edges/nodes controller/character_assets/file_resolver/ink_error/l10n_x/app_theme/tokens/ink_error_banner/ink_dashed_slot/file_selector 等）。

- [ ] **Step 2: image_config_inspector.dart 改调用点**

```dart
import 'characters_section.dart';
```

四处改名：
1. L442 挂载处：`_CharactersSection(` → `CharactersSection(targetNode: ..., selectedCaps: ..., requireImageToImageMode: true,)`
2. `_PresetsSection` 内 L531：`_CharacterChip(` → `CharacterChip(`
3. `_PresetsSection` 内 L577：`_NameDialog(` → `InspectorNameDialog(`
4. 文件头注释若列了区块清单，同步措辞（角色区已抽共享文件）

- [ ] **Step 3: 回归验证（既有 10 例一行未改必须全绿）**

```bash
flutter analyze lib test 2>&1 | tail -1
flutter test test/features/canvas/widgets/image_config_inspector_characters_test.dart 2>&1 | tail -2
```

Expected: No issues / All tests passed（若测试红=搬移走样，回 Step 1 对照原文逐字核对，禁止改测试迁就实现）。

- [ ] **Step 4: 提交**

```bash
git add lib/features/canvas/widgets
git commit -m "refactor(canvas): CH-2 前置——角色区/命名框/角色 chip 抽共享 characters_section.dart,image inspector 减重 ~340 行行为零变化

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 2: video inspector 挂载角色区（TDD）

**Files:**
- Modify: `lib/features/canvas/widgets/video_config_inspector.dart`（NodeInputsSection 挂载点前，现 L305 一带）
- Test: `test/features/canvas/widgets/video_config_inspector_characters_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

新建测试文件，harness 三来源拼装：caps 常量抄 `video_config_inspector_test.dart` 的 `_fakeVideoCaps`（maxRefImages=1，即 ref-capable）与 `_noCameraCaps`（maxRefImages=0）；角色数据/仓储 override 抄 `image_config_inspector_characters_test.dart` 的 fake_character + fake_repositories 用法；节点必须带 `projectId`/`canvasId`（角色区首行守卫 projectId==null 即 shrink——image 侧测试文件头注释已踩过此坑）。

```dart
// CH-2：video inspector 角色区——maxRefImages>0 挂载(不要求 imageToImage,CH-1 口径),
// =0 整段不出现;chip 点选写 type_config.character_ids。
void main() {
  testWidgets('maxRefImages>0 → 角色区出现（无 imageToImage mode 也出现）',
      (tester) async {
    // _fakeVideoCaps.modes = [textToVideo, imageToVideo]——无 imageToImage,
    // 若共享 section 误用 image 门此测必红。
    await _pumpVideoInspector(tester, capsList: [_fakeVideoCaps]);
    expect(find.byType(CharactersSection), findsOneWidget);
  });

  testWidgets('maxRefImages=0 → 角色区整段不挂载', (tester) async {
    await _pumpVideoInspector(tester, capsList: [_noCameraCaps]);
    expect(find.byType(CharactersSection), findsNothing);
  });

  testWidgets('点选角色 chip → saveConfig 写 character_ids', (tester) async {
    // 角色仓储种一条 Character(id: 'ch-1'),tap chip 后断言
    // fake canvas 仓储收到的 typeConfig 含 {'character_ids': ['ch-1']}
    // （断言写法对照 image_config_inspector_characters_test.dart 既有 toggle 用例）。
  });
}
```

（第三例的完整断言按 image 侧同名场景照抄改 caps；若 image 侧无现成 toggle 落库断言则经 fake_repositories 的 canvas 仓储 update 记录断。）

- [ ] **Step 2: 跑测试确认红**

```bash
flutter test test/features/canvas/widgets/video_config_inspector_characters_test.dart 2>&1 | tail -3
```

Expected: FAIL（CharactersSection findsNothing——video inspector 尚未挂载）。

- [ ] **Step 3: 实现挂载（video_config_inspector.dart）**

import 增 `'characters_section.dart'`；`build` 内 NodeInputsSection 块之前插入：

```dart
            // CH-2：角色区（CH-1 视频注入的用户入口）。门控对齐注入门：
            // 仅 maxRefImages>0 挂载——与 image 侧「常挂+警示文案」有意不同，
            // 视频多数 provider 无 ref 能力,常挂=一屏死区。
            if (selected != null && selected.maxRefImages > 0) ...[
              const SizedBox(height: InkSpacing.lg),
              CharactersSection(
                targetNode: widget.node,
                selectedCaps: selected,
                requireImageToImageMode: false,
              ),
            ],
```

- [ ] **Step 4: 测试绿 + 双 inspector 回归**

```bash
flutter test test/features/canvas/widgets/ 2>&1 | tail -2
flutter analyze lib test 2>&1 | tail -1
```

Expected: 全过、no issues。

- [ ] **Step 5: 提交**

```bash
git add lib/features/canvas/widgets test/features/canvas/widgets
git commit -m "feat(canvas): CH-2 视频 Inspector 角色区——CH-1 注入自此有用户入口,门控 maxRefImages>0 对齐注入口径

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 3: 状态回填 + 全量闸门 + PR

**Files:**
- Modify: `docs/BOARD.md`（近期落地表 #228 行后加行）
- Modify: `docs/MASTERPLAN.md:88`（E5 行 CH-2 标 ✅）
- Modify: `docs/superpowers/plans/2026-07-07-launch-features.md:146`（CH-2 卡加状态行）

- [ ] **Step 1: 三处回填**（PR 号预写 #229，建 PR 时核实）

MASTERPLAN E5 行：`video inspector 角色区` → `video inspector 角色区(**CH-2 ✅ #229**)`，并把括号注里「用户可见入口随 CH-2」句改为「用户可见入口已随 CH-2 落地」。

features plan CH-2 卡后加：

```markdown
  状态:已随 #229 落地——三类抽共享 characters_section.dart(NameDialog/CharacterChip
  一并转公开,_PresetsSection 改 import;image inspector 减重 ~340 行零行为变化,
  既有 10 例角色区测试一行未改全绿);video 侧 maxRefImages>0 门控挂载,
  requireImageToImageMode=false 对齐 CH-1 注入口径。
```

BOARD 近期落地表：

```markdown
| CH-2 视频 Inspector 角色区:角色区/命名框/角色 chip 抽共享 `characters_section.dart`（image inspector 1033→约 690 行,行为零变化以既有 10 例测试一行未改全绿为证）+ video inspector 门控挂载（`maxRefImages>0` 对齐 CH-1 注入门,不检查 imageToImage——r2v/omni 语义;与 image 侧常挂+警示有意不同）——CH-1 视频角色注入自此有用户可见入口 | #229 |
```

- [ ] **Step 2: 全量闸门 + 提交 + push（pbcopy 交用户 `!` 执行）+ PR + CI 绿合并**

```bash
flutter analyze lib test && flutter test --exclude-tags golden
git add -A docs && git commit -m "docs: CH-2 收口回填——BOARD/MASTERPLAN/features 计划三处状态

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
printf 'git push -u origin feat/ch-2-video-inspector-characters' | pbcopy   # 用户 ! 执行
gh pr create --title "feat: CH-2 视频 Inspector 角色区——抽共享 section + CH-1 注入的用户入口" --body "(正文技术记号一律反引号,禁裸 @)"
gh pr checks <PR#> --watch && gh pr merge <PR#> --squash --delete-branch
```
