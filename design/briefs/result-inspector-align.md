# result-inspector-align · 产物检查器三处对齐：节点头走 ARB、片长统一格式、图标换成图标集 v1
- 波次 W11 / lane B / 基底：叠在 node-menu-append-chain 之后（两片文件不相交）；依赖切片：duration-format（W0，formatDurationLabel）、naming-shot-unify（W0，「镜头」叫法）、tc-set-current（W3，改过三个产物检查器文件）、multi-select-inspector（W9，改过 canvas_inspector_panel.dart）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
选中一个节点时，检查器顶部第二行不再显示代码里的枚举名「image / result」，改成本地化的「图片 / 产物 · Gemini」（英文「Image / Result · Gemini」）。视频产物的片长从「00:00:05」变成「5 秒」。预览框里的占位与播放浮标换成图标集 v1 的单色描边图标，尺寸取 token，不再混用 Material 图标。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/GapsPanels.dc.html` ›「产物检查器 · 已实现」：「照 fix/demo-inspectors 的代码画，设计与实现对齐用」；「三段共用 result_inspector_parts：预览 · 生成参数 · 动作行」；「要对齐：1 枚举名『image / result』改走 ARB；2 片长『00:00:05』改统一格式『5 秒』；3 Material 图标、写死 40 换图标集 v1 与 token」；「首帧 = thumbnail_url；没出片『等待生成』」；「预留：『设为当前』排动作行最前」（W3 已做，本片不动顺序）。
- plan.md 第 0 节：fix/demo-inspectors 已在 025aeae 补上 ARB 键，原先「ARB 留在工作树里」的前置不存在了；`gallery_time.galleryFormatDuration` 不动（画廊卡片 / 信息面板仍用它）。
- 图标集 v1：`lib/theme/icons/ink_glyph.dart` 头注「与设计稿『图标集 v1』是同一份路径」，设计源是 `/home/user/plan/design/icons.js`（45 个）。三处 Material 图标的对照：`hourglass_empty_outlined`（等待生成）⇒ 现有 `InkGlyph.progress`（进行中）；`play_circle_outline` ⇒ 新字形 `playCircle`；`broken_image_outlined`（图片丢失）⇒ 新字形 `imageMissing`。
- 设计缺口：画板只画了「对齐前」，没画对齐后节点头的样子与分隔符；本片沿用现有「类型 / 角色 · 服务商」的排法，只把两段换成文案。
- 设计缺口：画板标题写「镜头 01 · 图像」，而现有 ARB `canvasNodeImageType` 中文是「图片」——本片复用 `nodeTypeLabel`（与节点卡同源），不另起「图像」，叫法统一留给主 Agent 决定。
- 设计缺口：图标集 v1 里没有「图片丢失」「圆圈播放」两个字形；本片按下面的路径补，设计源 icons.js 要同步加两条（回报给主 Agent / 设计侧）。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：同样不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `lib/features/canvas/widgets/canvas_inspector_panel.dart`：`_NodeSummary.build` 里 `'${node.type.name} / ${node.role.name}'`（origin/main 第 184 行；W9 改过本文件，行号以落地为准）换成 `inspectorNodeKind(nodeTypeLabel(context, node.type), _roleLabel(l, node.role))`；加私有 `_roleLabel`。`node_card.dart` 只 import 不改（已 import）。
- `lib/features/canvas/widgets/result_inspector_parts.dart`：片长行 `galleryFormatDuration(p.durationMs!)`（第 198 行）换成 `formatDurationLabel(l, p.durationMs!)`，`mono: true` 去掉（「5 秒」是文案不是格式量），删掉 gallery_time import；`ResultPreviewPlaceholder` 的 `IconData icon` 改成 `InkGlyph glyph`，内部画 `InkIcon(glyph, size: InkIconSize.md, color: c.fg5)`（原来误用间距 token `InkSpacing.s20` 当图标尺寸）；`ResultFileImage` 的坏图占位用 `InkGlyph.imageMissing`。
- `lib/features/canvas/widgets/video_result_inspector.dart`：等待生成 ⇒ `InkGlyph.progress`；有片没首帧 ⇒ `InkGlyph.playCircle`；首帧上的浮标 `Icon(Icons.play_circle_outline, size: 40, …)` ⇒ `InkIcon(InkGlyph.playCircle, size: InkIconSize.xl, color: c.fg1)`。
- `lib/features/canvas/widgets/image_result_inspector.dart`：等待生成 ⇒ `InkGlyph.progress`；`flutter/material.dart` 若不再需要则换 widgets。
- `lib/theme/icons/ink_glyph.dart`：追加两个字形（放在「通知与状态」组末尾）。
- `lib/theme/tokens.dart`：`InkIconSize` 追加 `static const double xl = 40; // 预览框上的播放浮标`（只追加）。
- 测试：`test/features/canvas/widgets/video_result_inspector_test.dart`（片长断言改新口径 + 图标断言）、`test/features/canvas/widgets/image_result_inspector_test.dart`（新）、`test/features/canvas/widgets/canvas_inspector_node_summary_test.dart`（新）、`test/theme/icons/ink_glyph_test.dart`（新字形自动进循环，只在必要时补断言）、`test/theme/icons/ink_icon_sheet_golden_test.dart`（头注「45 个」改 47；基线由 CI 重生成，见风险）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- batch-run-dialog：新 `widgets/batch_run_dialog.dart`、`util/canvas_batch_run_actions.dart`、Ctrl ↵ 核心键文件、`widgets/canvas_toolbar.dart`、`widgets/left_rail/outline_panel.dart`、`app_preferences.dart`、`file_preferences_service.dart`。
- node-menu-append-chain（同 lane 前一片）：`util/append_to_chain.dart`、`util/canvas_append_chain_actions.dart`、`canvas_menu/append_chain_menu_entries.dart`。
- script-import：`lib/features/storyboard/` 下 controller / splitter / dialog / duration_estimate。
- mention-token-core：`lib/core/text/character_mention.dart`、`generation_controller.dart`、`import_remapper.dart`、`util/clipboard_snapshot.dart`、`prompt_assembler.dart`。
- f6-notification-region：`toast_layer.dart`、`lib/theme/components/ink_toast_card.dart`、`toast_center.dart`、`notification_bell.dart`、`shortcut_catalog.dart`。
- 全波：`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_shortcuts.dart`、`models/canvas_command.dart`、`widgets/node_card.dart`（只 import）、`lib/features/gallery/util/gallery_time.dart`、`util/result_params.dart`、`lib/theme/components/ink_icon.dart`（只调用）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：script-import：`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/util/script_splitter.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`；f6-notification-region：`lib/features/settings/widgets/shortcuts_section.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// canvas_inspector_panel.dart
String _roleLabel(AppLocalizations l, NodeRole role) => switch (role) { NodeRole.config => l.inspectorNodeRoleConfig, NodeRole.result => l.inspectorNodeRoleResult };

// result_inspector_parts.dart
class ResultPreviewPlaceholder extends StatelessWidget { const ResultPreviewPlaceholder({super.key, required this.glyph, this.text}); final InkGlyph glyph; final String? text; }

// ink_glyph.dart（追加；路径来源写进 /// 注释）
/// 图片丢失：外框 = R(3.5, 3.5, 13, 13, 1.5)（icons.js 的 R 工具，与 assets 内框同圆角）；
/// 山形线照搬 assets 第 3 笔；斜杠新画一笔。
imageMissing(<InkGlyphPart>[
  InkGlyphPart.stroke('M5 3.5h10a1.5 1.5 0 0 1 1.5 1.5v10a1.5 1.5 0 0 1 -1.5 1.5h-10a1.5 1.5 0 0 1 -1.5 -1.5v-10a1.5 1.5 0 0 1 1.5 -1.5z'),
  InkGlyphPart.stroke('M3.75 14.25l2.75-2.75 2.5 2.5 1.5-1.5 2.75 2.75'),
  InkGlyphPart.stroke('M4.75 4.75l10.5 10.5'),
]),
/// 圆圈播放：外圈照搬 help 第 1 笔（C(10, 10, 7.25)）；三角按 run 的比例缩到圈内。
playCircle(<InkGlyphPart>[
  InkGlyphPart.stroke('M2.75 10a7.25 7.25 0 1 0 14.5 0a7.25 7.25 0 1 0 -14.5 0z'),
  InkGlyphPart.stroke('M8.5 7v6l4.75-3z'),
]),

// tokens.dart（追加）
// InkIconSize.xl = 40
```

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 单选 image 产物：节点头第二行 = `inspectorNodeKind(canvasNodeImageType, inspectorNodeRoleResult)` + 「 · 服务商」，不出现 `image`、`result` 这两个英文枚举名（zh 下）。
2. 四种类型 × 两种角色都走文案（text / shot 配置节点也是：「文本 / 配置」「镜头 / 配置」）；没有 provider_id ⇒ 只有前半段，不留尾部「 · 」。
3. 视频产物有 duration：片长行 = `formatDurationLabel(l, ms)`（5000 ⇒ zh「5 秒」）；≥ 60 s 走 m:ss（由 W0 函数保证）；产物没 duration ⇒ 这一行不画（现有行为）。片长不是估算，不加 ~。
4. 画廊的卡片和信息面板仍是「00:00:05」（galleryFormatDuration 没动）。
5. 图片产物还没出图 / 视频产物还没出片 ⇒ 占位画 `InkGlyph.progress` + 「等待生成」，不再是 Material 沙漏。
6. 图片文件解析失败 / 越权路径 / projectId 缺失 ⇒ 占位 `InkGlyph.imageMissing` + 「图片丢失」文案，不崩。
7. 视频有片无首帧 ⇒ 只画 `playCircle`（无文案）；有首帧 ⇒ 首帧铺满 + 居中 `playCircle`，尺寸 = `InkIconSize.xl`，颜色 fg1。
8. 占位图标尺寸 = `InkIconSize.md`，颜色 fg5；三个产物检查器文件里不再出现 `Icons.` 与字面量 40。
9. 预览可点（视频文件在）与动作行（设为当前 / 播放 / 定位来源 / 在序列中定位）行为不变；不可用置灰 50% 不隐藏（现有）。
10. 多选时（W9 多选检查器）不画 _NodeSummary，本片不影响；无选中空态不变。
11. 撤销栈、并发：无写操作，不涉及。mac / Windows：纯绘制，无差异；新字形在两平台同一份路径。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| inspectorNodeKind | {type} / {role} | {type} / {role} |
| inspectorNodeRoleConfig | Config | 配置 |
| inspectorNodeRoleResult | Result | 产物 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/widgets/canvas_inspector_node_summary_test.dart`（新，ProviderScope + 选中一个节点 pump `CanvasInspectorPanel`，zh 与 en 各一遍）：
  - 「image 产物节点头是『图片 / 产物 · <服务商>』，find.textContaining('image / result') 为空」（规则 1）。
  - 「shot 配置节点无服务商 ⇒ 『镜头 / 配置』，末尾无 ' · '」（规则 2）。
  - 「en 下是『Image / Result』」。
- `test/features/canvas/widgets/video_result_inspector_test.dart`：
  - 改「生成参数」用例：`find.text(formatDurationLabel(l, 5000))` 一个、`find.text('00:00:05')` 为空（规则 3）。
  - 新「还没出片 ⇒ 占位是 InkIcon(progress)」「有片无首帧 ⇒ InkIcon(playCircle)」「有首帧 ⇒ 浮标 InkIcon(playCircle) 尺寸 == InkIconSize.xl」「find.byType(Icon) 在预览框内为空」（规则 5、7、8）。
- `test/features/canvas/widgets/image_result_inspector_test.dart`（新，batchResultsControllerProvider override 成空列表）：「无 imageUrl ⇒ InkIcon(progress) + 等待生成」「imageUrl 指向不存在文件 / 无 projectId ⇒ InkIcon(imageMissing) + 图片丢失」（规则 5、6）。
- `test/theme/icons/ink_glyph_test.dart`：现有逐字形循环自动覆盖两个新字形（路径可解析、落在 20×20 网格内）；不需新用例时不改。
- `test/features/gallery/…`：不改，画廊时长断言保持「00:00:05」（规则 4 的回归由现有画廊测试承担）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 节点头改回 `'${node.type.name} / ${node.role.name}'` ⇒ node_summary 用例红。
2. `_roleLabel` 把 result 映射成 Config ⇒ node_summary 用例红。
3. 片长改回 `galleryFormatDuration` ⇒ video「5 秒」用例红。
4. 片长传 `estimated: true` ⇒ 多出「~」，用例红。
5. 视频浮标改回 `Icon(Icons.play_circle_outline, size: 40)` ⇒ InkIcon / 无 Icon 用例红。
6. 浮标尺寸写回字面量 24 ⇒ `InkIconSize.xl` 断言红。
7. image 坏图占位改用 `InkGlyph.progress` ⇒ imageMissing 用例红。
8. 等待生成改用 `playCircle` ⇒ progress 用例红。
9. 把 `imageMissing` 斜杠改成 `M4.75 4.75l20 20`（出格）⇒ ink_glyph_test 红；把 `playCircle` 两笔改成与 help 前两笔相同不会撞（第 2 笔不同），但若整条抄成 `run` ⇒「没有两个图标笔画完全相同」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/features/canvas/widgets test/theme/icons --exclude-tags golden`；上面 9 条变异。
- 截图（test/_harness/screenshot.dart，宿主 `CanvasInspectorPanel` 宽 301，zh / en 各一）：① image 产物单张已出图（节点头「图片 / 产物 · Gemini」+ 参数组）；② image 产物等待生成（progress 占位）；③ image 产物文件丢失（imageMissing 占位）；④ video 产物有首帧（首帧 + 40 播放浮标 + 片长「5 秒」）；⑤ video 产物有片无首帧（只有 playCircle）；⑥ video 产物还没出片。截图与 GapsPanels「产物检查器」两张示意并排给主 Agent 对齐看。

## 风险与不确定
- 新增两个字形会让 `ink_icon_sheet_golden_test` 的基线变（47 个、仍 6 行）；按项目规则不能本地修 golden，需主 Agent 合入后跑 `.github/workflows/update-goldens.yml` 重生成并在同一 PR 提交。docs/CLAUDE.md「45 个图标」要改 47，回报给主 Agent。
- 新字形路径是本片按 icons.js 的工具函数手写的，设计源 icons.js 要补同样两条，否则 ink_glyph 头注「同一份路径」不再成立。
- canvas_inspector_panel 被 W9 多选检查器改过、W3 改过三个产物检查器文件，行号以落地为准；本片只动上面点名的几行。
- 「图片」与画板「图像」叫法不一致，是否统一由主 Agent 决定（不在本片改 ARB 值）。
