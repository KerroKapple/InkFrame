# assets-gallery-import-origin · 导入的素材：「导入」小标、原文件名、来源筛选
- 波次：W16；lane：D；基底：origin/main（media-import-service、assets-hover-preview 已合入）
- 依赖切片：
  - media-import-service（硬依赖，W2 已合入 main）。它定义了导入式产物节点：`role = result`、没有 `sourceNodeId`，`type_config` 里写着 `origin: 'import'`、`original_name`，以及 `image_url` 或 `video_url`（画布相对路径）。按 plan 第 0 节，`isImported` / `originalFileName` 是写在新文件里的 `CanvasNode` extension。本片一律用这两个 getter，**不自己再读 typeConfig 键**。文件名以合入后的实际为准，预期是 `lib/features/canvas/models/` 下的某个 `*_x.dart`。
  - assets-hover-preview（硬依赖，W14 已合入 main）。它改过 `assets_panel.dart`，并新建了 `left_rail/asset_hover_preview.dart`。
- 阻塞决定：无。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
用户从电脑导入到画布的图片和视频，在左栏「素材」页和画廊里都能一眼认出来：格子左上角有「导入」小标，标签显示原文件名，不显示「take N」或「成片」。素材页的 chip 从三个变成四个：全部 / 图片 / 视频 / 导入。画廊左栏的「类型」组也多一行「导入」。

## 设计依据
画板 `GapsPanels`，小节「素材：悬停预览 · 导入的怎么显示」：
- chip 行画的是「全部 6 · 图片 3 · 视频 1 · 导入 2」，三项加起来正好等于「全部」。所以 chip 是**划分**：「图片」「视频」只算生成的产物，「导入」算全部导入的（图和视频都算）。
- 「导入的：左上「导入」小标，标签 = 原文件名，没有 take 号。」
- 「「导入」chip 筛来源，与图片 / 视频互斥；画廊同加；判据只有 `origin == import`。」
- 悬停预览的标题行画成「导入 · ref_山脊.jpg」，下一行是「1920×1080 · 今天 14:20」。
- 设计缺口：画廊里的「导入」画成什么样，画板没画。本片按「画廊同加」处理：在「类型」组末尾加一行「导入」，和图片 / 视频单选互斥，计数口径也和素材页一样按划分算。tile 左上的小标和素材页同款。
- 设计缺口：导入节点还在复制中（状态 `uploading`）时，素材格要不要显示，画板没说。按现状，这时节点还没有 `image_url`，画廊聚合本来就不收，所以不显示。

## 允许改的文件
- `lib/features/canvas/widgets/left_rail/assets_model.dart`：
  - `AssetKindFilter` 加 `imported`；
  - `AssetCounts` 加 `imported`；
  - `countAssets`、`assetsOfKind` 改成按划分计算，但它们只拿到 items，所以要多传一个 `bool Function(GalleryItem) isImported` 参数；
  - `AssetCaption` 加 `importedName`；
  - `assetCaptions` 遇到导入节点时填 `importedName`，`take` 和 `slot` 都填 null；
  - 新增纯函数 `isImportedItem(GalleryGraph graph, GalleryItem item, {List<CanvasNode>? canvasNodes, String? canvasId})`。
- `lib/features/canvas/widgets/left_rail/assets_panel.dart`：`_KindChips` 加第四个 chip；`_captionOf` 遇到导入项时直接返回原文件名；`_AssetTile` 加参数 `imported`，为 true 时左上角画 `ImportedBadge`。
- `lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`（由 assets-hover-preview 新建，W14）：只改标题行。如果它的标题来自 `assets_panel` 传进来的 caption，那就**不改这个文件**；如果它自己拼标题，就改成导入项写「导入 · 原文件名」。
- `lib/features/gallery/widgets/imported_badge.dart`（新建）：「导入」小标，素材格和画廊 tile 共用。
- `lib/features/gallery/util/gallery_meta.dart`：`GalleryItemMeta` 加 `imported`（bool，默认 false）和 `originalName`（String?）；`galleryMetaFor` 在「找不到 config 就返回 empty」那一步之前先判断导入节点，返回 `GalleryItemMeta(label: 原文件名, imported: true, originalName: …)`。
- `lib/features/gallery/providers/gallery_filter.dart`：`GalleryFilter` 加 `importedOnly`（bool，默认 false），同时补 `isActive`、`copyWith`、`==`、`hashCode`；`galleryFilterMatches` 按划分判断。
- `lib/features/gallery/widgets/gallery_filter_panel.dart`：「类型」组末尾加一行「导入」，key 是 `rowKey('type', 'imported')`，与图片 / 视频互斥。
- `lib/features/gallery/widgets/gallery_tile.dart`：`meta.imported` 为 true 时左上角画 `ImportedBadge`；名字用 `meta.label`，导入项的 label 已经是原文件名。
- 测试：`test/features/canvas/widgets/left_rail/assets_model_test.dart`、`test/features/canvas/widgets/left_rail/asset_captions_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/gallery/providers/gallery_filter_test.dart`、`test/features/gallery/util/gallery_meta_test.dart`、`test/features/gallery/widgets/gallery_tile_test.dart`。

## 不许碰的文件
- 同波 W16：note-heading-style 的 `typography.dart`、`node_card.dart`、`canvas_compact_cards.dart`、`node_position.dart`、`edge_geometry.dart`、`viewport_fit.dart`、`text_node_inspector.dart`、`outline_model.dart`；template-core 的 `lib/features/templates/**`、`canvas_bootstrap_controller.dart`；toast-corner 的 `notifications/` 各文件、`settings/` 下的通知文件、`app_preferences.dart`、`file_preferences_service.dart`；export-one-click 的 `export/` 下各文件、`shell_tab_bar.dart`、`ink_split_button.dart`、`app_action_catalog.dart`。
- `lib/features/gallery/models/gallery_item.dart`：它是 freezed 模型，生成件没法重新生成，**不加字段**。「是否导入」从图里的节点推出来，挂在 meta 上。
- `lib/features/canvas/models/canvas_node.dart`，以及 media-import-service 建的 extension 文件（只读）。
- `gallery_controller.dart`（聚合规则不变，导入节点本来就是 result，已经被收进来了）、`take_numbers.dart`。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W16 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - note-heading-style：`lib/features/canvas/models/canvas_node_note_style.dart`、`lib/features/canvas/providers/heading_note_zoom.dart`、`lib/features/canvas/util/drop_placement.dart`、`lib/features/canvas/util/note_geometry.dart`、`lib/features/canvas/util/selection_geometry.dart`、`lib/features/canvas/util/viewport_focus.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/theme/typography.dart`、`test/features/canvas/util/drop_placement_test.dart`、`test/features/canvas/util/note_geometry_test.dart`、`test/features/canvas/util/viewport_focus_test.dart`、`test/features/canvas/widgets/node_card_note_style_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/theme/typography_test.dart`
  - template-core：`lib/features/canvas/models/canvas_command.dart`、`lib/features/canvas/providers/canvas_bootstrap_controller.dart`、`lib/features/canvas/util/sample_seed.dart`、`lib/features/templates/builtin_templates.dart`、`lib/features/templates/models/canvas_template.dart`、`lib/features/templates/providers/template_insert_controller.dart`、`lib/features/templates/util/builtin_template_strings.dart`、`lib/features/templates/util/template_capture.dart`、`lib/features/templates/util/template_remap.dart`、`lib/features/templates/util/template_writer.dart`、`test/features/templates/builtin_templates_test.dart`、`test/features/templates/providers/template_insert_controller_test.dart`、`test/features/templates/util/template_capture_test.dart`、`test/features/templates/util/template_remap_test.dart`
  - toast-corner：`lib/core/models/app_preferences.dart`、`lib/features/notifications/models/notification_prefs.dart`、`lib/features/notifications/util/toast_placement.dart`、`lib/features/notifications/widgets/toast_layer.dart`、`lib/features/settings/providers/notification_prefs_controller.dart`、`lib/features/settings/widgets/notifications_section.dart`、`lib/services/file_preferences_service.dart`、`test/core/models/app_preferences_test.dart`、`test/features/notifications/util/toast_placement_test.dart`、`test/features/notifications/widgets/toast_layer_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`
  - export-one-click：`lib/features/export/open_export_dialog.dart`、`lib/features/export/providers/one_click_export_controller.dart`、`lib/features/export/util/export_file_name.dart`、`lib/features/export/util/last_export_settings.dart`、`lib/features/export/util/one_click_export_plan.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/shell/widgets/shell_tab_bar.dart`、`lib/features/shell/widgets/tabs/export_tab.dart`、`lib/theme/components/ink_split_button.dart`、`test/features/export/providers/one_click_export_controller_test.dart`、`test/features/export/util/export_file_name_test.dart`、`test/features/export/util/last_export_settings_test.dart`、`test/features/export/util/one_click_export_plan_test.dart`、`test/features/export/widgets/export_video_dialog_test.dart`、`test/features/shell/shell_tab_bar_test.dart`、`test/theme/components/ink_split_button_test.dart`

## 具体改动
```dart
// assets_model.dart
enum AssetKindFilter { all, image, video, imported }
typedef AssetCounts = ({int all, int image, int video, int imported});
bool isImportedItem(GalleryGraph graph, GalleryItem item, {String? canvasId, List<CanvasNode>? canvasNodes});
AssetCounts countAssets(List<GalleryItem> items, {required bool Function(GalleryItem) isImported});
List<GalleryItem> assetsOfKind(List<GalleryItem> items, AssetKindFilter kind, {required bool Function(GalleryItem) isImported});
class AssetCaption { /* 原字段 */ final String? importedName; bool get imported => importedName != null; }

// gallery_meta.dart
class GalleryItemMeta { /* 原字段 */ final bool imported; final String? originalName; }

// gallery_filter.dart
class GalleryFilter { /* 原字段 */ final bool importedOnly; }
GalleryFilter copyWith({..., bool? importedOnly});

// gallery/widgets/imported_badge.dart
class ImportedBadge extends StatelessWidget { const ImportedBadge({super.key}); static const Key badgeKey; }
```
- 判断「是不是导入」：先找到 `item.nodeId` 对应的节点。当前画布用 `canvasNodes`（实时节点表），其他画布用 `graph.nodesOf`。然后看 `node.isImported`，这个 getter 来自 media-import-service 的 extension。批量 slot（`slotIndex != null`）一律不算导入。
- 原文件名取 `node.originalFileName`；为空时回退到 `relativePath` 的最后一段。
- 划分规则：「图片」= kind 是 image 且不是导入；「视频」= kind 是 video 且不是导入；「导入」= 是导入。「全部」= 三项之和，也等于 items 的总数。
- 画廊筛选：`importedOnly == true` 时，只留 `meta.imported` 的项。`kind` 不为 null 时，要求 `!meta.imported && item.kind == kind`。点「导入」会把 `kind` 置成 null；点「图片」或「视频」会把 `importedOnly` 置成 false；再点一次已选中的行就取消选中，和现有行为一致。
- 计数：画廊「类型」组的计数也改成按划分算，「导入」行的计数 = `meta.imported` 的项数。
- 小标样式：外边距和「当前线」徽标同位（`left/top` 取现有徽标同一组数）；底色 `c.surface4`，文字 `t.micro` + `c.fg2`；圆角 `InkRadius.xs`。导入项不会在叙事链上，所以不会和「当前线」徽标撞位。

## 行为规则与边界情况
1. 导入的格子：左上有「导入」小标；标签 = 原文件名；**不显示** take 号，也不显示「成片」。
2. 生成的格子：显示和现在完全一样，标签仍是「源配置名 · take N / 成片」，批量 slot 仍是「#n」。
3. chip 计数随分段（本画布 / 项目全部）变化，并且满足 `image + video + imported == all`。
4. 选中「导入」后再切分段，过滤仍然生效。分段下没有导入项时，显示现有的空态文案。
5. 删掉导入节点后，格子立刻消失，走现有的 `assetsWithoutDeleted`，这条不变。
6. 导入项不在叙事链上、没有 config，所以画廊信息栏的 provider / 提示词等行本来就是空的，按现在「没有的行不画」处理。
7. 导入节点的原文件名为空，或者节点已经不在图里时，标签回退到 `relativePath` 的文件名部分，不能是空串。
8. 点导入格子 = 在画布上定位那个导入节点，走现有的 `_locate`，不做改动。
9. 画廊 `importedOnly` 和其他三组筛选（范围 / 模型 / 标记）是「且」的关系。导入项没有 providerId，所以选了某个模型后，导入项自然被排除。
10. `galleryFilterProvider` 按项目 keepAlive，`importedOnly` 跟着一起保留。

## 新文案键
| key | en | zh |
|---|---|---|
| leftRailAssetsKindImported | Imported {count} | 导入 {count} |
| assetImportedBadge | Imported | 导入 |
| galleryKindImported | Imported | 导入 |
| assetHoverImportedTitle | Imported · {name} | 导入 · {name} |

（最后一条只有在 `asset_hover_preview` 需要自己拼标题时才用。）

## 测试
先写下面这些用例，确认它们失败后再实现。用例里直接构造导入节点：`role: result`、没有 sourceNodeId，type_config 写 `origin: 'import'`、`original_name: 'ref_山脊.jpg'`、`image_url`。
- `assets_model_test.dart`
  - `countAssets 按划分计：2 生成图 + 1 生成视频 + 2 导入 → all 5 / image 2 / video 1 / imported 2`
  - `assetsOfKind(imported) 只留导入；image 不含导入的图`
- `asset_captions_test.dart`
  - `导入节点：importedName = 原文件名，take / slot 为 null`
  - `导入节点 original_name 缺失 → 回退到 relativePath 文件名`
- `assets_panel_test.dart`
  - `导入格：有 ImportedBadge.badgeKey、标签是原文件名、不出现「成片」`
  - `点「导入」chip：只剩导入格；再点「图片」：导入格消失`
- `gallery_meta_test.dart`
  - `galleryMetaFor：导入节点 → imported true、label = 原文件名（不再是空 meta）`
- `gallery_filter_test.dart`
  - `importedOnly 只命中导入；kind = image 不命中导入的图`
  - `copyWith / == 含 importedOnly`
- `gallery_tile_test.dart`
  - `meta.imported → 左上有「导入」小标，名字是原文件名`

## 变异点
1. `galleryMetaFor` 去掉导入分支（导入项仍返回 empty），会被 `galleryMetaFor：导入节点 → imported true…` 和 `gallery_tile` 那条抓住。
2. `countAssets` 的 image 计数不排除导入，会被 `countAssets 按划分计…` 抓住。
3. `assetsOfKind(image)` 不排除导入，会被 `assetsOfKind(imported) 只留导入；image 不含导入的图` 抓住。
4. `assetCaptions` 对导入节点照样填 take，会被 `导入节点：importedName = 原文件名，take / slot 为 null` 抓住。
5. `galleryFilterMatches` 忽略 `importedOnly`，会被 `importedOnly 只命中导入…` 抓住。
6. `GalleryFilter.==` 漏掉 `importedOnly`，会被 `copyWith / == 含 importedOnly` 抓住。
7. `_captionOf` 对导入项仍然走 `leftRailAssetFinal`，会被 `导入格：…不出现「成片」` 抓住。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/canvas/widgets/left_rail test/features/gallery`，并按上面每条变异做一次。
- 截图场景：
  - `AssetsPanel`，宽 241，暗色。数据是同一画布上 3 张生成图（其中一张有两个 take）、1 段生成视频、2 个导入项（一张 jpg、一段 mp4，都带缩略图）。截「全部」「导入」两个 chip 状态，以及悬停在导入格上的预览。
  - `GalleryScreen`，用同一份数据，截「类型 › 导入」选中时的网格和左栏计数。

## 风险与不确定
- 「与图片 / 视频互斥」有两种理解：一是只指 chip 单选，二是计数也按划分算。本片按画板上的计数（3 + 1 + 2 = 6）选了划分。副作用是：在画廊里点「图片」，看不到导入的参考图。如果主 Agent 选「图片含导入」，只需要改 `assetsOfKind`、`countAssets`、`galleryFilterMatches` 三处的谓词。
- media-import-service 实际给出的 getter 名或文件名可能和这里不同，以合入后的代码为准。如果它最终没有 extension，而是把常量放在别处，就在 `assets_model.dart` 里**引用它的常量**，不要另写一份 `'origin'` / `'import'` 字面量。
- `assets_panel.dart` 在 W14 之后的结构，以 assets-hover-preview 合入后的代码为准。如果 `_AssetTile` 已经拆进别的文件，本片改那个文件，并在回报里说明。
