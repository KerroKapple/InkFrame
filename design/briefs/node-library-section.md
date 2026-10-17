# node-library-section · 节点库（模板页顶部）：六项「图像配置 · 视频配置 · 文本 · 镜头 · 便签 · 泳道」，搜索过滤，点击 = 工具条同一条路
- 波次：W18；lane：D；基底：origin/main（W17 全部合入后）。同 lane 后面紧跟 node-library-drag-recents（叠在本片之后，串行）。
- 依赖切片：
  - 硬依赖 rail-templates-page（W17）：`LeftRailPage.templates`、`templates_panel.dart`（顶部预留了插入位置）——已在 main。
  - 软依赖 note-variant（W14）：便签项、`CanvasToolKeys` 的便签键 N、建便签的函数——已在 main。
  - 已在 main：wrap-in-lane（W8，Ctrl G 包成泳道）、create-menu-pick-recent（W13，`create_menu_model` 的项形状）、naming-shot-unify（W0，类型统一叫「镜头」）。
- 阻塞决定：无（RailScript-R7 按建议 B：节点库并进模板页顶部，**不给 `LeftRailPage` 加 nodeLibrary 键**，导航条不变）

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
左栏模板页顶部多出「节点库」：一个「搜索节点、预设…」筛选框，下面一组「节点 6」：图像配置 I · 视频配置 G · 文本 T · 镜头 · 便签 N · 泳道 F，每行图标 + 名称 + 键位。
点一行 = 和工具条按钮 / 单键完全一样地在视口中心建一个节点；点「泳道」：没选中时开「新建泳道」框，有选中时把选中包成泳道（同 Ctrl G）。打字筛选六项。

## 设计依据
画板 `RailScript.dc.html`「节点库 · P2 · 新建菜单常驻版 · R7 B 时在模板页顶部」（生成器 b2_rail.js 第 102–145 行）：
- 筛选框：外边距 10 12 6、24 高、surface2 底、1px outline 边、圆角 3、搜索图标 13、提示 11 号 fg6「搜索节点、预设…」——就是现有 `LeftPanelFilterField`（left_panel_parts.dart:53）。
- 组头：24 高、左右 12、上外边距 4；标题 11 号 fg5，计数 10 号等宽 fg6（「节点 6」）。
- 行：30 高、左右 12、间距 8；图标 16 fg4；名称 fg2 单行省略；行尾键位 10 号等宽 fg5；悬停 surface5 底。
- 规则：「节点」= 新建菜单不带上下文的六项（`create_menu_model`；便签 N 见 ImportSearch），同一个搜索过滤，键位取 `CanvasToolKeys`；类型一律叫「镜头」，不叫分镜。
- 规则：点一下 = 工具条同一条路（`addNodeFromMenu`，视口中心 + 散布）。
- 规则：泳道：没选中时点它 = 开「新建泳道」框（同 F，F 不看选中）；有选中时点它 = 包成泳道（同 Ctrl G，见 Selection）。
- 导航条：节点库照 R7 建议 B 并进模板页顶部、不加键。
拖进画布、「最近用过」、提示词预设组属于 node-library-drag-recents，本片不做。
设计缺口：①节点库与下面的模板卡之间怎么分隔——本单定一条 1px borderSubtle 横线、上下各 4；②筛选只筛节点库还是也筛模板卡——本单定只筛节点库（含下一片的最近用过 / 预设），模板卡不受影响；③全部筛空时——组头不画，出一行 `LeftPanelNote` 「没有匹配的节点」；④镜头没有单键——行尾空着（与画板一致）。

## 允许改的文件
- `lib/features/canvas/util/node_library_model.dart`（新建，纯函数）：六项清单、键位、筛选。
- `lib/features/canvas/widgets/left_rail/node_library_section.dart`（新建）：筛选框 + 组头 + 六行。
- `lib/features/canvas/util/canvas_library_actions.dart`（新建）：点行要做的事（建节点 / 泳道两分支）。按 plan.md 第 0 节「新的画布动作写进新文件」，不碰 `canvas_tool_actions.dart`。
- `lib/features/canvas/widgets/left_rail/templates_panel.dart`（由 rail-templates-page 新建，W17）：在 rail-templates-page 留的位置放 `NodeLibrarySection(canvasId: …)` + 分隔线。
- `test/features/canvas/util/node_library_model_test.dart`（新建）
- `test/features/canvas/widgets/left_rail/node_library_section_test.dart`（新建）

## 不许碰的文件
- 同波：`widgets/canvas_toolbar.dart`、`widgets/canvas_more_menu.dart`、`util/more_menu_model.dart`、`command_palette/command_actions.dart`（more-dropdown-panel）；**`util/create_menu_model.dart`、`widgets/canvas_menu/create_menu_entries.dart`（或 `widgets/create_menu_entries.dart`）、`util/canvas_tool_actions.dart`、`providers/characters_controller.dart`**（create-menu-notes-characters，新建菜单链 W18 归它）；`widgets/back_to_content_chip.dart`、`util/viewport_fit.dart`、`widgets/canvas_screen.dart`（back-to-content-chip）；`pubspec.*`、`assets/fonts/**`、`core/licenses.dart`、`export/**`、`core/di/video_export.dart`（storyboard-pdf-export）。
- 只许 import、不许改：`create_menu_model.dart`（读 `kPlainCreateActions`、`filterMenuGroups`）、`canvas_tool_actions.dart`（调 `addNodeAtViewportCenter`、`addLaneViaDialog`）、`canvas_shortcuts.dart` / 注册表（读 `CanvasToolKeys`）、`canvas_lanes_controller.dart`、`canvas_selection_controller.dart`。
- `left_rail_state.dart`、`canvas_left_rail.dart`、`left_rail_panel.dart`（R7 B：不加键、不加页）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W18 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - more-dropdown-panel：`lib/features/canvas/widgets/canvas_more_menu.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`test/features/canvas/widgets/canvas_more_menu_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`
  - create-menu-notes-characters：`lib/features/canvas/models/character.dart`、`lib/features/canvas/providers/characters_controller.dart`、`lib/features/canvas/util/canvas_character_create_actions.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/theme/components/ink_menu_panel.dart`、`test/features/canvas/models/character_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/theme/components/ink_menu_panel_test.dart`
  - back-to-content-chip：`lib/features/canvas/util/viewport_fit.dart`、`lib/features/canvas/widgets/back_to_content_chip.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`test/features/canvas/util/viewport_fit_test.dart`、`test/features/canvas/widgets/back_to_content_chip_test.dart`
  - node-library-drag-recents：`lib/features/canvas/models/canvas_drag_payload.dart`、`lib/features/canvas/util/prompt_preset_apply.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`test/features/canvas/util/prompt_preset_apply_test.dart`、`test/features/canvas/widgets/left_rail/node_library_drag_test.dart`
  - storyboard-pdf-export：`assets/fonts/`、`assets/fonts/NotoSansSC-Regular.ttf`、`assets/fonts/OFL-NotoSansSC.txt`、`lib/core/di/storyboard_pdf.dart`、`lib/core/interfaces/storyboard_pdf_service.dart`、`lib/core/licenses.dart`、`lib/features/export/providers/storyboard_pdf_controller.dart`、`lib/features/export/util/storyboard_pages.dart`、`lib/features/export/widgets/export_history_row.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/storyboard_pdf_dialog.dart`、`lib/services/pdf_storyboard_service.dart`、`lib/services/ui_storyboard_thumbnail_loader.dart`、`pubspec.yaml`、`test/core/licenses_test.dart`、`test/features/export/providers/storyboard_pdf_controller_test.dart`、`test/features/export/util/storyboard_pages_test.dart`、`test/features/export/widgets/storyboard_pdf_dialog_test.dart`、`test/services/pdf_storyboard_service_test.dart`

## 具体改动
```dart
// util/node_library_model.dart
@immutable class NodeLibraryItem { final CreateMenuAction action; final InkGlyph glyph; final LogicalKeyboardKey? key; }
// action 的类型跟随 create_menu_model 届时的项类型（CreateMenuAction 枚举或 CreateMenuPick），这里写作 CreateMenuAction 仅示意
List<NodeLibraryItem> nodeLibraryItems();                       // = kPlainCreateActions 按原顺序映射，断言恰好 6 项且不含「从模板插入」
List<NodeLibraryItem> filterNodeLibrary(List<NodeLibraryItem> items, String query, String Function(NodeLibraryItem) labelOf);
// 筛选复用 filterMenuGroups（create_menu_model.dart）的口径：去首尾空白、不区分大小写、包含匹配

// widgets/left_rail/node_library_section.dart
class NodeLibrarySection extends ConsumerStatefulWidget { const NodeLibrarySection({super.key, required this.canvasId});
  static Key rowKeyOf(String itemId); static const Key filterKey; }
String nodeLibraryLabel(AppLocalizations l, NodeLibraryItem item);  // 复用新建菜单同一组 ARB：canvasCreateMenuImageConfig / …VideoConfig / …Text / …Shot / 便签键（note-variant 加的那个）/ …Lane

// util/canvas_library_actions.dart
Future<void> runNodeLibraryItem(BuildContext context, WidgetRef ref, {required String canvasId, required NodeLibraryItem item});
```
- 键位：`item.key` 取 `CanvasToolKeys`（image → `imageNode` I、video → `videoNode` G、text → `textNode` T、note → note-variant 加的 N、lane → `lane` F、shot → null），显示用 `key.keyLabel`，与新建菜单 `_createEntry`（create_node_menu.dart:803 起，拆分后在条目文件里）同一种写法。
- 图标：imageConfig / videoConfig / text / shot / note / lane 六个 `InkGlyph`（ink_glyph.dart 已有）。
- `runNodeLibraryItem`：
  - 建节点类（图像 / 视频 / 文本 / 镜头）：`addNodeAtViewportCenter(context, ref, canvasId: canvasId, type: …)`（canvas_tool_actions.dart:110）——与工具条按钮、I / G / T 同一个函数。
  - 便签：调工具条「便签」键与 N 键共用的那个函数（note-variant 落地，W14；在 canvas_toolbar.dart 的便签按钮 onTap 里找到它的名字，直接调，不另写）。
  - 泳道：`canvasSelectionControllerProvider(canvasId)` 为空 ⇒ `addLaneViaDialog(context, ref, canvasId: canvasId)`（canvas_tool_actions.dart:135，与 F 同一个）；非空 ⇒ 调 Ctrl G 绑定的那个包成泳道函数（wrap-in-lane 落地，W8；名字在快捷键注册表 Ctrl G 那一行里取），参数与 Ctrl G 完全相同。
- 节点库不管焦点：点完之后焦点按被调函数自己的规则走（建节点后画布持焦与否不在本片改）。
- `templates_panel.dart`：在 rail-templates-page 留的注释处放 `NodeLibrarySection(canvasId: widget.canvasId)`，其下一条 1px `borderSubtle` 分隔线（上下外边距 `InkSpacing.xs`），再接原来的模板卡列表；整页一个滚动容器（节点库随列表一起滚）。

## 行为规则与边界情况
1. 六行顺序与 `kPlainCreateActions` 一致，组头计数 = 当前筛选后剩下的行数（未筛选为 6）。
2. 「从模板插入…」绝不出现在节点库里（它在独立分组 `kTemplateCreateActions`）。
3. 筛选：输入「视频」只剩视频配置；输入「 VIDEO 」（英文界面）大小写与首尾空白不影响；输入不匹配任何项 ⇒ 组头隐藏、出一行「没有匹配的节点」；清空恢复六项。
4. 筛选文字是面板本地状态：切走模板页再回来清空（与大纲筛选一致）。
5. 点「图像配置」：画布多一个 image 配置节点，落在视口中心 ± 散布，单选它、相机不动——与按 I 的结果逐项相同（同一个函数）。
6. 点「泳道」无选中：弹「新建泳道」框；取消 ⇒ 什么都不变；确认失败 ⇒ 现有错误卡「创建泳道失败」。
7. 点「泳道」有选中（含多选）：与 Ctrl G 结果相同（新道包住选中、一次撤销）；选中里只有不可包的节点时，以 Ctrl G 的既有处理为准（本片不加判断）。
8. 写库失败：沿用被调函数自己的错误卡（「添加节点失败」等），本片不另加提示。
9. 键盘：每行可 Tab 聚焦，↵ / 空格触发（`InkActivatable`）；行内键位只是提示，按 I / G / T 等仍由画布快捷键处理，焦点在筛选框里时字母键归输入框。
10. 画布标签以外不会出现节点库（左栏只在画布页里）；没有活动项目也照常可用（建节点不需要项目）。
11. mac / Windows 无差异；键位文字取 `keyLabel`，两平台相同。

## 新文案键
| key | en | zh |
|---|---|---|
| leftRailNodeLibraryFilterHint | Search nodes, presets… | 搜索节点、预设… |
| leftRailNodeLibraryGroupNodes | Nodes | 节点 |
| leftRailNodeLibraryNoMatch | No matching nodes | 没有匹配的节点 |
六项名称复用新建菜单已有键（`canvasCreateMenuImageConfig` / `…VideoConfig` / `…Text` / `…Shot` / `…Lane` + note-variant 加的便签键），不新增。

## 测试
先写会失败的用例。
- `test/features/canvas/util/node_library_model_test.dart`
  - `节点库恰好六项，顺序 图像配置 · 视频配置 · 文本 · 镜头 · 便签 · 泳道`（断言 action 序列）。
  - `不含从模板插入`。
  - `键位：图像 I、视频 G、文本 T、便签 N、泳道 F、镜头无`。
  - `筛选：大小写与首尾空白不敏感；无匹配返回空`。
- `test/features/canvas/widgets/left_rail/node_library_section_test.dart`（外壳级 pump，停在模板页；fake 控制器写法照 `canvas_left_rail_test.dart`）
  - `模板页顶部出现节点库：组头「节点 6」与六行`。
  - `输入「视频」只剩一行，组头计数 1`；`输入「zzz」组头消失、出现没有匹配的节点`。
  - `点图像配置：节点控制器 addNode 被调一次，类型 image`（`RecordingNodesController`，`test/_harness/fake_canvas.dart:51`）。
  - `点泳道且无选中：弹出新建泳道对话框`（找 `showLaneEditDialog` 的对话框类型）。
  - `点泳道且有选中：走包成泳道，不弹对话框`（override 选中控制器初值 + 记录型泳道控制器，断言调用了 wrap 方法、没有对话框）。
  - `↵ 触发聚焦的行`。
  - `模板卡仍在节点库下方`。

## 变异点
1. `nodeLibraryItems` 把 `kTemplateCreateActions` 也并进来 ⇒ `不含从模板插入` 红。
2. 泳道分支去掉「有选中」判断、一律开对话框 ⇒ `点泳道且有选中：走包成泳道，不弹对话框` 红。
3. 泳道分支反过来一律包 ⇒ `点泳道且无选中：弹出新建泳道对话框` 红。
4. 筛选去掉 `trim()` ⇒ `筛选：大小写与首尾空白不敏感` 红。
5. 镜头行硬塞一个键位 ⇒ `键位：…镜头无` 红。
6. 组头计数写死 6 ⇒ `输入「视频」只剩一行，组头计数 1` 红。

## 验收
- `flutter analyze lib test`；`flutter test test/features/canvas/util/node_library_model_test.dart test/features/canvas/widgets/left_rail`；逐条变异。
- 截图（screenshot 标签）：`InkShell` 画布标签、左栏模板页、fake 画布两节点；截①未筛选（节点 6 + 下方模板卡）；②筛选「视频」；③悬停「图像配置」行（surface5 底）。

## 风险与不确定
1. 便签建节点的函数名、Ctrl G 的包成泳道函数名、`kPlainCreateActions` 的元素类型都以 W14 / W8 / W13 合入后的代码为准；本单只规定「调同一个函数、不另写」。若 Ctrl G 的实现只写在快捷键 Action 里没有独立函数，执行代理不得改 `canvas_shortcuts` / 注册表，改为在 `canvas_library_actions.dart` 里直接调 `canvasLanesControllerProvider(canvasId).notifier` 上 wrap-in-lane 加的方法（参数照 Ctrl G 处的调用抄），并在 PR 里说明。
2. slices.json 原足迹要改 `canvas_tool_actions.dart`（泳道两分支）；该文件 W18 不归本片（热点链 W13 止，且同波 create-menu-notes-characters 在改），所以改为新文件 `canvas_library_actions.dart`。
3. 筛选框提示写着「预设」，但预设组在下一片才出；两片同 lane 串行合入，中间窗口很短，接受。
