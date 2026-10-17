# create-menu-notes-characters · 新建菜单加便签 / 角色组
决定：IS-Q5 按建议 A（便签 = text 节点 + `type_config.variant = note`，不迁移）

- 波次：W18；lane：B；基底：origin/main（W0–W17 已全部合入）
- 依赖切片：create-menu-pick-recent（W13，硬：`CreateMenuAction` 已改成带载荷的 `CreateMenuPick`，`addNode` / `addNodeFromMenu` 已能收 `typeConfig`，新建菜单已有「最近用过」「模型」两组及组标题 / 右侧小字）；note-variant（W14，硬：新建菜单不带上下文的那组已有「便签 N」，`CanvasToolKeys.note`）；menu-split（W0，硬：`theme/components/ink_menu_panel.dart` + `widgets/canvas_menu/` 目录）；character-kind（W14，`Character` 已加 kind）。执行本片时以上都已在 main 上。
- 阻塞决定：IS-Q5 → 按建议 A 执行；N4（GapsCanvas）→ 按建议 A（点角色 = 建图像配置并挂上该角色）。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
- 双击空白 / Tab / 右键「新建…」打开的新建菜单（不带连线上下文时），在「最近用过」组之后多一组「角色 · 建图像配置并挂上」：列本项目最近改过的 3 个角色（缩略图 + 名字 + 「N 张参考图」）。
- 点一个角色 = 在菜单落点建一个图像配置节点，并把这个角色挂上（`type_config.character_ids = [id]`）。
- 建节点组里「便签 N」确认在位、叫法统一（便签项本身由 note-variant 加过，本片只核对和补测试）。

## 设计依据
画板 GapsCanvas.dc.html › 「新建菜单补项」（副标题「双击空白 / Tab / 右键『新建…』，不带连线上下文时」）。样稿：
搜索框「直接打字搜索…」| 图像配置 I · 视频配置 G · 文本 T · 便签 N · 镜头 · 泳道 F | 组标题「最近用过」+ 两行预设 | 组标题「角色 · 建图像配置并挂上」+「老渔夫（16px 缩略图）… 3 张参考图」「孤舟 … 1 张参考图」。
规则原文：
1. 建节点组加便签、统一叫「镜头」；带连线上下文的菜单不加新组。
2. 角色组列最近改过的 3 个，点了见 N4。
3. N4 建议 A：图像配置 + 挂上该角色——先出图再当首帧，是角色最常走的路。
样稿细节：角色行左侧是 16×16、圆角 3 的缩略图（代替图标），右侧 10 号 fg5 小字「N 张参考图」。
设计缺口：①打字搜索时角色组怎么出（只在 3 个里筛，还是在全部角色里找）没写；②角色没有参考图时缩略图位置画什么没画；③新建节点叫什么名字没写；④菜单开着时角色被删、再点它怎么办没写。处理见「行为规则」。

## 允许改的文件
- `lib/features/canvas/util/create_menu_model.dart`（热点链 W18 归本片）：加角色组的纯函数与 `CreateMenuPick` 的角色变体；核对 `kPlainCreateActions` 里有便签。
- `lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`（由 menu-split 新建，W0；新建菜单条目热点链 W18 归本片）：角色组条目（组标题、缩略图、右侧小字）与派发。
- `lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`（由 menu-split 新建，W0）：**仅当** `CreateMenuPick` 的 switch 写在宿主里（而不在 create_menu_entries.dart）时，给它加角色分支这一处；别的不动。
- `lib/theme/components/ink_menu_panel.dart`（由 menu-split 新建，W0；本波归本片）：**仅当**面板条目还不支持「左侧自定义 leading（代替 glyph）」时，给条目加 `final Widget? leading;`（给了就不画 glyph / swatch，占同一格，尺寸 16）。组标题、右侧小字若 pick-recent 已加则复用，不再动。theme 层不得 import 画布任何类型。
- `lib/features/canvas/models/character.dart`：加 `final DateTime? updatedAt`（`fromRow` 读 `CharacterCol.updatedAt`，`copyWith` 可改）。
- `lib/features/canvas/providers/characters_controller.dart`：乐观更新的那几处（rename 第 101 行、setDescription 第 140 行、addReferenceImage 第 163 行、reorderReferenceImages 第 225 行及删参考图等同形方法）在本地副本上同时写 `updatedAt: DateTime.now().toUtc()`，让「最近改过」在不重载时也立即生效。
- `lib/features/canvas/util/canvas_character_create_actions.dart`（新建）：建图像配置并挂角色的动作（plan 第 0 节：新画布动作进新文件，不碰 canvas_tool_actions.dart）。
- 测试：`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/canvas_create_menu_test.dart`、`test/features/canvas/providers/characters_controller_test.dart`、`test/features/canvas/models/character_test.dart`、`test/theme/components/ink_menu_panel_test.dart`（由 menu-split 新建，只在加了 `leading` 时追加用例）。

## 不许碰的文件
- 同波 more-dropdown-panel：`lib/features/canvas/widgets/canvas_toolbar.dart`、`lib/features/canvas/widgets/canvas_more_menu.dart`、`lib/features/canvas/util/more_menu_model.dart`、`lib/features/canvas/providers/edge_cut_controller.dart`、`lib/features/canvas/widgets/stage_pointer_layer.dart`、`test/features/canvas/util/more_menu_model_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`canvas_more_menu_test.dart`、`canvas_knife_cut_test.dart`（`app_action_catalog.dart` 是注册表，本片不需要）。
- 同波 back-to-content-chip：`lib/features/canvas/widgets/back_to_content_chip.dart`、`lib/features/canvas/util/viewport_fit.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`test/features/canvas/util/viewport_fit_test.dart`。
- 同波 node-library-section / node-library-drag-recents：`lib/features/canvas/util/canvas_tool_actions.dart`（只调用 `menuNodePlacement` / `viewportCenteredNodePoint` / `addNodeFromMenu`，不改）、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`templates_panel.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/core/interfaces/job_repository.dart`、`lib/storage/repositories/postgres_job_repository.dart`、`lib/features/canvas/providers/recent_generation_params.dart`、`recent_presets_provider.dart`、`lib/features/canvas/models/canvas_drag_payload.dart`、`image_config_inspector.dart`、`prompt_presets_controller.dart`。
- 同波 storyboard-pdf-export：`pubspec.yaml`、`pubspec.lock`、`assets/fonts/**`、`lib/core/licenses.dart`、`lib/core/di/video_export.dart`、`lib/features/export/**`、`lib/services/pdf_storyboard_service.dart`。
- 其它：`lib/storage/**`、`lib/core/interfaces/character_repository.dart`（`listByProject` 已 `SELECT ch.*`，行里本来就有 updated_at，不改 SQL、不加仓库方法）、`canvas_shortcuts.dart`、`menu_registry.dart`（新建菜单的组是 create_menu_model 按上下文算的，不进分组表）。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W18 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - node-library-drag-recents（另加）：`lib/features/canvas/widgets/canvas_view.dart`（舞台拖放派发的三个分支）
  - more-dropdown-panel：`lib/features/canvas/widgets/canvas_more_menu.dart`、`lib/features/canvas/widgets/canvas_toolbar.dart`、`test/features/canvas/widgets/canvas_more_menu_test.dart`、`test/features/canvas/widgets/canvas_toolbar_test.dart`
  - back-to-content-chip：`lib/features/canvas/util/viewport_fit.dart`、`lib/features/canvas/widgets/back_to_content_chip.dart`、`lib/features/canvas/widgets/canvas_screen.dart`、`test/features/canvas/util/viewport_fit_test.dart`、`test/features/canvas/widgets/back_to_content_chip_test.dart`
  - node-library-section：`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/widgets/left_rail/node_library_section_test.dart`
  - node-library-drag-recents：`lib/features/canvas/models/canvas_drag_payload.dart`、`lib/features/canvas/util/canvas_library_actions.dart`、`lib/features/canvas/util/node_library_model.dart`、`lib/features/canvas/util/prompt_preset_apply.dart`、`lib/features/canvas/widgets/image_config_inspector.dart`、`lib/features/canvas/widgets/left_rail/node_library_section.dart`、`test/features/canvas/util/node_library_model_test.dart`、`test/features/canvas/util/prompt_preset_apply_test.dart`、`test/features/canvas/widgets/left_rail/node_library_drag_test.dart`
  - storyboard-pdf-export：`assets/fonts/`、`assets/fonts/NotoSansSC-Regular.ttf`、`assets/fonts/OFL-NotoSansSC.txt`、`lib/core/di/storyboard_pdf.dart`、`lib/core/interfaces/storyboard_pdf_service.dart`、`lib/core/licenses.dart`、`lib/features/export/providers/storyboard_pdf_controller.dart`、`lib/features/export/util/storyboard_pages.dart`、`lib/features/export/widgets/export_history_row.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/storyboard_pdf_dialog.dart`、`lib/services/pdf_storyboard_service.dart`、`lib/services/ui_storyboard_thumbnail_loader.dart`、`pubspec.yaml`、`test/core/licenses_test.dart`、`test/features/export/providers/storyboard_pdf_controller_test.dart`、`test/features/export/util/storyboard_pages_test.dart`、`test/features/export/widgets/storyboard_pdf_dialog_test.dart`、`test/services/pdf_storyboard_service_test.dart`

## 具体改动
```dart
// create_menu_model.dart
const int kCreateMenuCharacterLimit = 3;
/// 角色组候选：query 为空 ⇒ 按 updatedAt 倒序取前 3（null 排最后，再按 sortOrder、id 稳定排序）；
/// query 非空 ⇒ 在全部角色里按名字不区分大小写包含匹配，同样排序取前 3。
List<Character> characterMenuCandidates(List<Character> all, {String query = '', int limit = kCreateMenuCharacterLimit});
/// 带连线上下文（source != null）⇒ 永远不出角色组。
bool createMenuShowsCharacters({required bool hasSource});
// CreateMenuPick 加一个角色变体，写法跟 pick-recent 已有的变体一致，例如：
final class CreateMenuCharacterPick extends CreateMenuPick { const CreateMenuCharacterPick(this.characterId); final String characterId; }
// createdNodeType(角色变体) == CanvasNodeType.image；createdEdge(角色变体) == null

// canvas_character_create_actions.dart
const String kCharacterIdsKey = 'character_ids'; // 若 main 上已有同名常量（generation_controller / characters_section 用的那个键），import 它，不另起
Future<void> addImageConfigWithCharacter(
  BuildContext context, WidgetRef ref, {
  required String canvasId,
  required String projectId,
  required String characterId,
  required NodePlacement placement,
});
// = 先确认 charactersControllerProvider(projectId) 里仍有该角色；再 addNodeFromMenu(type: image, placement, typeConfig: {kCharacterIdsKey: [characterId]})
```
- 派发：`viewportCentered && sourceNodeId == null`（Tab 开的菜单）⇒ `placement = menuNodePlacement(ref, canvasId:, viewportPoint: viewportCenteredNodePoint(ref, canvasId:, type: CanvasNodeType.image))`；否则 `menuNodePlacement(ref, canvasId:, viewportPoint: request.anchor)`——与现在 `_pickCreate`（create_node_menu.dart 第 321–352 行，menu-split 后在 canvas_menu/ 下）同一套。
- 数据：projectId 取 `activeProjectProvider`（`lib/features/shell/providers/active_project.dart:13`）的 `id`；角色取 `ref.watch(charactersControllerProvider(projectId))`，loading / error / 无项目 ⇒ 不出角色组。
- 条目：组标题 `canvasCreateMenuCharactersGroup`；行 label = 角色名（空名用 `characterUnnamed` 之类已有键，没有就新键）；leading = 第一张参考图的 16×16 缩略图（`characterAssetServiceProvider.absolutePathOf`，同 character_library_panel.dart 第 437 行；`Image.file` 带 `cacheWidth`）；右侧小字 `canvasCreateMenuCharacterRefs(count)`；组位置在「最近用过」之后、「模型」组之前（「模型」组只在打字时出）。
- 便签：核对 `kPlainCreateActions`（或 pick-recent 之后的等价常量）里有便签、键位提示取 `CanvasToolKeys.note`、文案「便签」；已在位就只补测试，不调顺序（见「风险」）。

## 行为规则与边界情况
1. 只在不带连线上下文时出角色组；从出端口拖线到空白处开的菜单（带源节点）绝不出，`当首帧 / 当尾帧 / 当参考 / 下一镜` 那几组不变。
2. 不打字：最多 3 行，按「最近改过」倒序；本项目没有角色 / 角色还在加载 / 读失败 ⇒ 整组（含组标题与分隔线）不出，不画转圈。
3. 打字（缺口①）：在**全部**角色里按名字匹配，最多 3 行；一个都没匹配上 ⇒ 整组不出。搜索框、↑↓ / ↵ / Esc、置灰跳过的行为与菜单其它组一致。
4. 「最近改过」= `updated_at`；改名、改描述、增删 / 重排参考图都会让它排到前面——乐观更新时就写本地 `updatedAt`，不必等重载。新建角色走重载，自然带上库里的时间。
5. 缩略图（缺口②）：取 `referenceImagePaths.first`；没有参考图、路径解析失败或文件读不出 ⇒ 画 `InkGlyph.characters`（fg4）占同一格，行照样能点。小字写「0 张参考图」。
6. 点角色：建 1 个**图像配置**节点，`type_config` 只写 `character_ids: [id]`（不带提示词、不带预设参数）；落点规则同新建菜单其它项（Tab 菜单 = 视口中心 + 散布，其余 = 菜单锚点；判泳道写 laneId）；新节点单选、不挪相机；写库失败 = 现有「添加节点失败」错误卡，库里不留半个节点（addNodeFromMenu 已保证）。
7. 节点名（缺口③）：与其它新建项一样用默认名 `canvasNodeDefaultLabel`，不拿角色名当节点名。
8. 菜单开着时角色被删（缺口④）：点它时再查一次控制器状态，已不在 ⇒ 不建节点，弹画布错误卡 `canvasCreateMenuCharacterGone`；组列表本身随控制器变化即时重建。
9. 参考图配额：挂上的角色的参考图照常计入 `ref_image_budget`（不在这里截断或提示，检查器 / 生成侧已有口径）。
10. 撤销：若 undo-node-create-move（W4）已让 addNodeFromMenu 进栈，本动作随之成一步「新建节点」；本片不另造命令。
11. 便签项：与图像配置 I / 视频配置 G / 文本 T 同组；按 N 键与点这一项同效（note-variant 已实现）；带连线上下文时不出。
12. mac / Windows 无差异；缩略图解码失败不抛异常到菜单（errorBuilder 回落到图标）。

## 新文案键
| key | en | zh |
|---|---|---|
| canvasCreateMenuCharactersGroup | Characters · new image config with it | 角色 · 建图像配置并挂上 |
| canvasCreateMenuCharacterRefs | {count, plural, =1{1 reference} other{{count} references}} | {count} 张参考图 |
| canvasCreateMenuCharacterGone | That character was deleted | 这个角色已被删除 |
（「便签」项的文案键由 note-variant 加过，复用。）

## 测试
先写，确认在没实现时红。
- `test/features/canvas/util/create_menu_model_test.dart`：
  - `characterMenuCandidates：不打字取 updatedAt 最新的 3 个，null 排最后`。
  - `打字时在全部角色里按名字匹配（不区分大小写），第 4 个最近的也能被搜到`。
  - `一个都没匹配上 ⇒ 空`。
  - `带上下文时不出角色组（createMenuShowsCharacters(hasSource: true) == false）`。
  - `角色变体建 image、不连线`。
  - `不带上下文的建节点组里有便签，且带上下文的各组里没有便签`。
- `test/features/canvas/widgets/canvas_create_menu_test.dart`：
  - `Tab 开菜单：「最近用过」之后出「角色 · 建图像配置并挂上」组，3 行按最近改过排序，行尾「N 张参考图」`。
  - `点「老渔夫」⇒ 视口中心建一个 image config，type_config.character_ids == [老渔夫.id]，新节点被单选`。
  - `双击空白开的菜单点角色 ⇒ 节点落在双击点`。
  - `从出端口拖到空白开的菜单里没有角色组`。
  - `没有参考图的角色画 characters 图标，照样能点`。
  - `菜单开着时删掉该角色再点 ⇒ 不建节点，出「这个角色已被删除」`。
  - `项目没有角色 ⇒ 没有组标题也没有多余分隔线`。
- `test/features/canvas/providers/characters_controller_test.dart`：`rename 后本地状态里该角色 updatedAt 晚于其它角色（不重载）`。
- `test/features/canvas/models/character_test.dart`：`fromRow 读 updated_at；缺列为 null`。
- `test/theme/components/ink_menu_panel_test.dart`（仅当加了 leading）：`给了 leading 就不画 glyph，行高仍 28`。

## 变异点
1. `characterMenuCandidates` 不排序（保持 sortOrder 顺序）→ 由 `不打字取 updatedAt 最新的 3 个` 抓住。
2. 打字时只在前 3 个里筛 → 由 `第 4 个最近的也能被搜到` 抓住。
3. 带上下文时也出角色组 → 由 `从出端口拖到空白开的菜单里没有角色组` 抓住。
4. 派发时不写 `character_ids`（typeConfig 传空）→ 由 `点「老渔夫」⇒ … character_ids == [老渔夫.id]` 抓住。
5. 角色变体建 video → 由 `角色变体建 image、不连线` 抓住。
6. rename 的乐观副本不写 updatedAt → 由 `rename 后本地状态里该角色 updatedAt 晚于其它角色` 抓住。
7. 去掉点击时的「角色还在吗」复查 → 由 `菜单开着时删掉该角色再点 ⇒ 不建节点` 抓住。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/theme --exclude-tags golden` 与上面的变异；`test/quality/no_reverse_layer_import_test.dart`（theme 层不引画布类型）必须绿。
- 截图：`CanvasScreen`（ProviderScope 覆盖 charactersControllerProvider 与 activeProjectProvider），数据 = 4 个角色（老渔夫 3 张图、孤舟 1 张、无图角色、一个更早改过的）+ 两条最近用过的预设。状态：① Tab 打开菜单（角色组 3 行）；② 输入「孤」（角色组只剩孤舟，模型组按 pick-recent 规则）；③ 从出端口拖到空白开的菜单（无角色组）。

## 风险与不确定
- GapsCanvas 样稿的建节点组顺序是「文本 · 便签 · 镜头」，而 RailScript 节点库、ImportSearch 工具锁、工具条都是「文本 · 镜头 · 便签」。本片**不调**已在 main 上的顺序（与工具条一致优先），只核对便签在位；若主 Agent 要按 GapsCanvas 样稿改，需另外动 create_menu_model_test 里的顺序断言。
- `CreateMenuPick` 的具体写法（sealed 类 / 工厂构造 / 组标题与右侧小字的字段名）由 create-menu-pick-recent 决定，本片照它的风格加一个变体；派发的 switch 写在哪个文件也以 main 为准（create_menu_entries.dart 或 canvas_menu_host.dart，二选一只改一处）。
- `Character.updatedAt` 不进 `==` / `hashCode`（只用于排序，避免已有用例里按字段比较 Character 的断言因时间戳失败）；在模型头注写明。若主 Agent 认为应该进相等判断，需要同时改 characters_controller_test 等处的期望值。
- `ink_menu_panel.dart` 本波归本片；同波 more-dropdown-panel 想要的「置灰悬停写原因」字段若 main 上还没有，本片**不**顺手加（不在本片范围），由主 Agent 决定下一波补。
- slices.json 给本片列了 `canvas_tool_actions.dart`，但它本波被 node-library-section / node-library-drag-recents 占用；按 plan 第 0 节改为新文件 `canvas_character_create_actions.dart`，只调用已有函数。前提是 pick-recent 已让 `addNodeFromMenu` 收 `typeConfig`；若没有，停下回报主 Agent，不要改 canvas_tool_actions.dart。
