# naming-shot-unify · 统一叫法：分镜 → 镜头、导入脚本 → 导入剧本、「创建 N 个镜头」
- 波次 W0 / lane D / 叠在 undo-stack 之后（同 lane 串行，文件不相交；基底 = undo-stack 分支或已合入它的 origin/main）；依赖切片：无（undo-stack 只是排队关系）；阻塞决定：无。并掉 shot-node-naming（ShellExport）。

> **执行代理约定**
> - 在自己的工作树里、从 origin/main（或「基底」写的前序切片分支）起分支 `feat/naming-shot-unify`。
> - 只改「允许改的文件」；不跑 flutter / dart 构建和测试（主 Agent 跑）。
> - 不改 ARB、lib/l10n/generated/、docs/CLAUDE.md：新文案键在回报里列出（key · en · zh），由主 Agent 统一加；代码里照常用 `context.l10n.<key>`。
> - 四张注册表（canvas_shortcut_registry.dart、canvas_menu/menu_registry.dart、app_actions/app_action_catalog.dart、canvas/util/more_menu_model.dart）每片只追加一行（替换自己的占位行算一行）。
> - CanvasNode 的新派生属性写成新文件里的 extension，不改 canvas_node.dart。
> - 不给 NodeRepository / EdgeRepository / StyleLaneRepository 加抽象方法（NodeRepository 有 26 个 fake）；用现有 create / update / patchTypeConfig / softDelete / restore，多步写走 UnitOfWork。
> - 新画布动作写进新文件 `lib/features/canvas/util/canvas_<x>_actions.dart`；只有改已有函数（addNodeFromMenu、duplicateNodes、moveNodesToLane、linkByPortDrop、addLaneViaDialog、fitAll）才碰 canvas_tool_actions.dart，且 W1 只有 canvas-capsule 能碰它。
> - 回报：分支名、提交 SHA、改了哪些文件、新文案键表、没做完 / 偏离派工单的地方。

## 目标
- 同一个节点类型全应用只叫「镜头」：工具条 tooltip「镜头节点」、卡片类型名、检查器分组、⌘K「添加镜头节点」、空画布 CTA 都不再出现「分镜」。
- 「导入脚本」一律改叫「导入剧本」（与左栏「剧本」页同名）。
- 剧本导入对话框的确认按钮写出数量：「创建 3 个镜头」/ Create 3 shots；还没内容时写「创建镜头」并置灰。

## 设计依据
- GapsCanvas.dc.html ›「新建菜单补项」：「建节点组加便签、统一叫「镜头」」；›「「更多」下拉」：「「导入脚本」改叫「导入剧本」，与左栏「剧本」页同名，相关 ARB 一起改」。
- ShellExport.dc.html ›「新建节点 ›」规则：「叫法与工具条 / 新建菜单 / 节点库同一份：图像配置 · 视频配置 · 文本 · 镜头 · 便签 · 泳道；工具条的 canvasToolShotNode「分镜节点」改叫「镜头节点」」。
- GapsPanels（revise-summary 第 7 节「剧本导入对话框」）：「按钮改成「创建 N 个镜头」」。
- critic.txt 第二节第 16 条：同一类型 ShellExport / 工具条叫「分镜」、节点库 / 新建菜单叫「镜头」，统一一个叫法。
- GapsCanvas「下一镜」继承表里也已写「镜头备注」——所以 inspectorShotNotesLabel 跟着改。
- 设计缺口：画板没说「分镜创作 / 开始分镜」这种**动作义**的用法要不要改。本片按「只改节点类型名」处理，`studioEmptySubtitle`、`canvasEmptySubtitle` 不改（见风险）。「分镜 PDF」（ShellExport 交付物名）属于后续 storyboard-pdf-export，也不改。

## 允许改的文件
- `lib/features/storyboard/widgets/script_import_dialog.dart`：确认按钮改调 `l.scriptImportConfirm(drafts.length)`（第 145 行，现为无参 `l.scriptImportConfirm`）；文件头注释与 `autofocus` 旁注释里的「导入脚本」「分镜链」改成「导入剧本」「镜头链」。不改布局、不改逻辑。
- `test/features/storyboard/widgets/script_import_dialog_test.dart`：把 `'Create shots'` 断言改成带数量的文案；加 zh 断言用例（见测试）。
- `test/features/canvas/node_card_test.dart`：第 147 行三元组 `(CanvasNodeType.shot, 'Shot', '分镜')` 的 zh 改为 `'镜头'`。
- ARB 改值由主 Agent 做（下表写全）。

## 不许碰的文件
- menu-split：`lib/features/canvas/widgets/create_node_menu.dart`、`lib/features/canvas/widgets/canvas_menu/*`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`create_node_menu_test.dart`。
- canvas-view-split：`lib/features/canvas/widgets/canvas_view.dart`、`lib/features/canvas/widgets/stage/*`、`test/features/canvas/widgets/canvas_view_test.dart`。
- esc-ladder → zoom-reset-100：`canvas_shortcuts.dart`、`widgets/shortcuts/*`、`util/escape_ladder.dart`、`providers/canvas_escape_ladder.dart`、`settings/util/shortcut_catalog.dart`、`util/canvas_zoom.dart`。
- multi-select-core → duration-format：`providers/canvas_selection_controller.dart`、`util/selection_geometry.dart`、`lib/l10n/duration_format.dart`。
- undo-stack：`models/canvas_command.dart`、`models/edge_endpoints.dart`、`providers/canvas_history_controller.dart`。
- 其它断言英文「Import script…」的测试（canvas_toolbar_test、canvas_empty_state_test、canvas_create_menu_test）：英文值不变，**不要动**。

## 具体改动
- ARB 改值表（主 Agent 改 app_zh.arb / app_en.arb 并 gen-l10n；key 不改名）：

| key | 旧 zh | 新 zh | en（新值；无变化写「不变」） |
|---|---|---|---|
| canvasNodeShotType | 分镜 | 镜头 | 不变（Shot） |
| inspectorShotTitle | 分镜 | 镜头 | 不变（Shot）——当前无代码引用 |
| inspectorShotNotesLabel | 分镜备注 | 镜头备注 | 不变（Shot notes） |
| inspectorShotNotesHint | 描述这个分镜（机位、动作、氛围）… | 描述这个镜头（机位、动作、氛围）… | 不变 |
| sequencePreviewTooltip | 按叙事顺序预览分镜 | 按叙事顺序预览镜头 | 不变——当前无代码引用 |
| sequencePreviewDisabledTooltip | 用叙事连线把分镜串起来后即可预览序列 | 用叙事连线把镜头串起来后即可预览序列 | 不变 |
| canvasAddShotNode | 添加分镜节点 | 添加镜头节点 | 不变（Add shot node） |
| canvasEmptyAddShot | 添加分镜节点 | 添加镜头节点 | 不变 |
| canvasAddImportScript | 导入脚本… | 导入剧本… | 不变（Import script…） |
| canvasEmptyImportScript | 导入脚本 | 导入剧本 | 不变 |
| scriptImportTitle | 导入脚本 | 导入剧本 | 不变（Import script） |
| scriptImportHint | 把脚本粘进来。每一镜变成一个节点，按顺序串成一条链。 | 把剧本粘进来。每一镜变成一个镜头节点，按顺序串成一条链。 | 不变 |
| scriptImportFailed | 脚本导入失败，画布未做改动。 | 剧本导入失败，画布未做改动。 | 不变 |
| inspectorGroupShot | 分镜 | 镜头 | 不变（Shot） |
| canvasToolShotNode | 分镜节点 | 镜头节点 | 不变（Shot node） |
| galleryLineageShotText | 分镜文本 | 镜头文本 | 不变（Shot text） |
| **scriptImportConfirm**（改成带计数） | 创建分镜 | `{count, plural, =0{创建镜头} other{创建 {count} 个镜头}}` | `{count, plural, =0{Create shots} =1{Create 1 shot} other{Create {count} shots}}`，加 `"@scriptImportConfirm": {"description": "Script import dialog confirm button; count = shots the pasted script splits into (0 = nothing yet, button disabled)", "placeholders": {"count": {"type": "int"}}}` |

- 不改：`studioEmptySubtitle`（开始你的分镜创作）、`canvasEmptySubtitle`（添加第一个节点，开始分镜）——动作义，不是类型名。
- 对话框签名不变：`ScriptImportDialog({required String canvasId, Offset origin})`、`showScriptImportDialog(...)`。复数键已有先例：`scriptImportShotCount` / `scriptImportDone`。

## 行为规则与边界情况
1. 刚打开（0 镜）：按钮文字 en「Create shots」/ zh「创建镜头」，`onPressed == null`。
2. 粘贴后 N≥1：按钮文字随预览实时变（1 → Create 1 shot / 创建 1 个镜头；3 → Create 3 shots / 创建 3 个镜头），与预览头「N 镜」同一个 N（都取 `_drafts.length`）。
3. 切拆分策略后数量变（3 → 4），按钮文字同步变成 4。
4. 忙碌中（提交事务时）按钮置灰，文字保持提交时的 N，不闪回 0。
5. 失败（事务回滚）：对话框留着、按钮文字仍是 N，可再点；失败卡文案 zh「剧本导入失败，画布未做改动。」。
6. 全应用 zh 界面里节点类型名不再出现「分镜」：节点卡空 label 回退名、工具条 tooltip、⌘K、空画布 CTA、检查器分组 / 备注框、画廊血缘「镜头文本」。
7. mac / Windows 无差异（纯文案）。不涉及撤销栈。

## 新文案键
无新键。只改 `scriptImportConfirm` 的值并加占位符（见上表），其余为改值。

## 测试
先改测试再改实现（第 1、4 条在实现前必红）。
- `test/features/storyboard/widgets/script_import_dialog_test.dart`
  1. 「刚打开：预览为空，创建按钮禁用」：按 `find.widgetWithText(FilledButton, 'Create shots')` 找到且 `onPressed` 为 null（0 镜分支）。
  2. 「粘贴文本 → 预览实时显示镜数与各镜标题」：按钮改成 `'Create 3 shots'`，`onPressed` 非 null。
  3. 「切到「每行一镜」→ 预览随策略重算」：追加断言按钮变成 `'Create 4 shots'`。
  4. 新用例「单镜文本 → 按钮写 Create 1 shot」：粘贴「就一镜」，找到 `'Create 1 shot'`。
  5. 「点创建 / 单镜 / 事务失败」三条：点击目标改成 `find.textContaining('Create')` 对应的带数字文案（`'Create 3 shots'` / `'Create 1 shot'`），其余断言不变。
  6. 新用例「zh：标题导入剧本，按钮创建 3 个镜头」：`pumpInkApp(..., locale: const Locale('zh'))`（pump 帮手加可选 locale 参数），粘贴三镜，断言 `find.text('导入剧本')`、`find.text('创建 3 个镜头')`、清空文本后 `find.text('创建镜头')`。
- `test/features/canvas/node_card_test.dart` 第 147 行：shot 的 zh 期望改 `'镜头'`（「shot 标题条：空 label 回退本地化类型名 (en/zh)」）。

## 变异点
1. `script_import_dialog.dart` 把 `l.scriptImportConfirm(drafts.length)` 改成 `l.scriptImportConfirm(0)` → 测试 2、3、4、6 红。
2. 改成 `l.scriptImportConfirm(drafts.length + 1)`（数量错一位）→ 测试 4（Create 1 shot）红。
3. 主 Agent 把 app_zh.arb `scriptImportConfirm` 的 other 分支改回「创建分镜」→ 测试 6 红。
4. 把 app_zh.arb `canvasNodeShotType` 改回「分镜」→ node_card_test「shot 标题条…(en/zh)」红。
5. 把 app_zh.arb `scriptImportTitle` 改回「导入脚本」→ 测试 6 红。

## 验收
- `flutter analyze lib test`（会抓 generated 未重生成、旧的无参调用）；`flutter test test/features/storyboard test/features/canvas/node_card_test.dart test/l10n`；`arb_hygiene_test` 键集一致。
- 人工 grep：`grep -n "分镜\|脚本" lib/l10n/app_zh.arb` 只剩 studioEmptySubtitle / canvasEmptySubtitle 两行。
- 截图（zh）：ScriptImportDialog 三态——空（创建镜头，灰）、粘贴三镜（创建 3 个镜头）、切每行一镜（创建 4 个镜头）；画布工具条「分镜」键悬停 tooltip「镜头节点  …」。

## 风险与不确定
- `inspectorShotTitle`、`sequencePreviewTooltip` 当前没有代码引用；按零兼容原则应删，但删键不属本片（会碰别片的 ARB 合并），回报里提给主 Agent 决定。
- 「开始分镜」「分镜创作」若用户也想改，只是两行 ARB 值，不影响测试。
- 英文侧不改「Import script」：script 本来就是剧本义；若主 Agent 想用 screenplay，需同时改 4 个英文断言测试文件（不在本片）。
