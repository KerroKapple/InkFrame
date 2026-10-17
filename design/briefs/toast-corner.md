# toast-corner · 通知卡位置五选一（跟随系统 / 四个角）
- 波次：W16；lane：C；基底：origin/main（toast-category-mute 已在 W12 合入）
- 依赖切片：toast-category-mute（硬依赖，W12 已合入 main）。它已经在 `notification_prefs.dart`、`notification_prefs_controller.dart`、`notifications_section.dart`、`app_preferences.dart` 里加了「按类型开关」：`AppPreferences.toastMuted`（JSON 键 `toast_muted`）、`notification_prefs.dart` 的 `toastMutedFromPref` / `toastMutedToPref`、**同文件另起的** `ToastMuteController` / `toastMuteControllerProvider`——它没有往 `NotificationPrefs` 记录里加字段（派工单原话「不改原 record」），所以本片给 `NotificationPrefs` 加 `corner` 是这个记录第一次加字段。本片在这几个文件里接着加位置，写法照它的 `toastMuted` 和现有的 `toastDwell`。
- 阻塞决定：无。GapsPanels N2 按建议 A：「跟随系统」在 Windows 上是右下，在 macOS 上是右上。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标
设置 › 常规 › 通知里新增「位置」一行，可选：跟随系统、右下、右上、左下、左上。通知卡栈按这个设置贴到对应的角。放在上面两个角时，最新的一张贴着角、旧的往下排，同时让开窗口顶部的标题栏和标签栏。改设置后，已经显示着的卡立刻挪到新位置，不重新进场，也不重新计时。

## 设计依据
画板 `GapsPanels`，小节「通知：按类型开关 · 位置」（设置 › 常规 › 通知，放在提示音 / 停留时长下面）：
- 「位置」标「新」，五个选项依次是：跟随系统 · 右下 · 右上 · 左下 · 左上。下面一行说明：「跟随系统 = Windows 右下 · macOS 右上（N2）」。
- 它下面紧接「系统通知」开关（ShellExport 板），本片不动那个开关。
- 存在 preferences.json 里，键是 `toastCorner`，和 toastDwell 一样存字符串、读出来转成枚举，不动数据库。
- 「上角：最新贴角向下长，让开 40 标题栏、43 导航条；改了在场的卡当场平移过去，不重计时。」
- 设计缺口：画板只写了上角卡片怎么排，没写进场 / 退场动画朝哪个方向。按建议镜像处理：上角的卡从上方滑入，退场时往上移。
- 设计缺口：画板上的 40 / 43 和代码对不上。实际标题栏 `InkWindowChrome.height` = 31，标签栏 `InkShellTabBar.height` = 35，画布左栏 `CanvasLeftRail.width` = 43。本片一律取代码里的常量，不写死数字，见「风险」。

## 允许改的文件
- `lib/features/notifications/models/notification_prefs.dart`：新增枚举 `ToastCorner`、解析函数 `toastCornerFromPref`，以及纯函数 `resolveToastCorner`，用来把「跟随系统」换成具体的角。
- `lib/features/notifications/util/toast_placement.dart`（新建）：纯函数，根据角、窗口宽度、是否窄窗口，算出卡片栈的 `Positioned` 参数和排列方向。
- `lib/features/notifications/widgets/toast_layer.dart`：`_ToastStack` 改为读取位置设置，按 `toast_placement` 定位；上角时把卡片顺序和「还有 N 条」胶囊的位置倒过来；`_ToastSlot` 的位移方向随角变化。
- `lib/features/settings/providers/notification_prefs_controller.dart`：`NotificationPrefs` 记录加字段 `corner`；新增 `setCorner`。
- `lib/features/settings/widgets/notifications_section.dart`：在「显示哪些通知」（toast-category-mute 加的）下面加「位置」五选一和说明行。
- `lib/core/models/app_preferences.dart`：加字段 `toastCorner`（字符串，默认 `'system'`，map 键 `'toast_corner'`），同时补 `copyWith`、`toMap`、`fromMap`（非法值回落为 `'system'`）、`==`、`hashCode`。如果字段已超过 20 个，`hashCode` 要用 `Object.hashAll`（前序切片可能已经改过）。
- `lib/services/file_preferences_service.dart`：本波这个文件归本片。按现在的写法它整份走 `toMap` / `fromMap`，**预期不用改**。只有发现它按字段白名单序列化时才补一行。
- `lib/theme/tokens.dart`：只许追加常量。本片预期不需要新 token，留着备用。
- 测试：`test/features/notifications/widgets/toast_layer_test.dart`、`test/features/notifications/util/toast_placement_test.dart`（新建）、`test/features/settings/notification_prefs_controller_test.dart`、`test/features/settings/notifications_section_test.dart`、`test/core/models/app_preferences_test.dart`。

## 不许碰的文件
- 同波 W16 其他切片：note-heading-style 的 `lib/theme/typography.dart`、`node_card.dart`、`canvas_compact_cards.dart`、`node_position.dart`、`edge_geometry.dart`、`viewport_fit.dart`、`text_node_inspector.dart`、`outline_model.dart`；template-core 的 `lib/features/templates/**`、`canvas_bootstrap_controller.dart`；assets-gallery-import-origin 的 `left_rail/assets_model.dart`、`assets_panel.dart`、`asset_hover_preview.dart`，以及 `gallery/` 下的 filter / meta / tile 文件；export-one-click 的 `export/` 下各文件、`shell_tab_bar.dart`、`ink_split_button.dart`、`app_action_catalog.dart`。
- `lib/features/notifications/providers/toast_center.dart`（热点链到 W12 为止，本片不需要动它：计时和暂停都在它里面，换角只是换画法）。
- `lib/core/interfaces/toast_service.dart`、`job_notification_listener.dart`、`notification_bell.dart`、`lib/theme/components/ink_toast_card.dart`。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W16 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - note-heading-style：`lib/features/canvas/models/canvas_node_note_style.dart`、`lib/features/canvas/providers/heading_note_zoom.dart`、`lib/features/canvas/util/drop_placement.dart`、`lib/features/canvas/util/note_geometry.dart`、`lib/features/canvas/util/viewport_focus.dart`、`lib/features/canvas/widgets/node_card.dart`、`lib/features/canvas/widgets/node_inline_text_editor.dart`、`lib/features/canvas/widgets/text_node_inspector.dart`、`lib/theme/typography.dart`、`test/features/canvas/util/drop_placement_test.dart`、`test/features/canvas/util/note_geometry_test.dart`、`test/features/canvas/util/viewport_focus_test.dart`、`test/features/canvas/widgets/node_card_note_style_test.dart`、`test/features/canvas/widgets/text_node_inspector_test.dart`、`test/theme/typography_test.dart`
  - template-core：`lib/features/canvas/models/commands/insert_template_command.dart`、`lib/features/canvas/providers/canvas_bootstrap_controller.dart`、`lib/features/templates/builtin_templates.dart`、`lib/features/templates/models/canvas_template.dart`、`lib/features/templates/providers/template_insert_controller.dart`、`lib/features/templates/util/builtin_template_strings.dart`、`lib/features/templates/util/template_capture.dart`、`lib/features/templates/util/template_remap.dart`、`lib/features/templates/util/template_writer.dart`、`test/features/templates/builtin_templates_test.dart`、`test/features/templates/providers/template_insert_controller_test.dart`、`test/features/templates/util/template_capture_test.dart`、`test/features/templates/util/template_remap_test.dart`
  - assets-gallery-import-origin：`lib/features/canvas/widgets/left_rail/asset_hover_preview.dart`、`lib/features/canvas/widgets/left_rail/assets_model.dart`、`lib/features/canvas/widgets/left_rail/assets_panel.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/util/gallery_meta.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_tile.dart`、`lib/features/gallery/widgets/imported_badge.dart`、`test/features/canvas/widgets/left_rail/asset_captions_test.dart`、`test/features/canvas/widgets/left_rail/assets_model_test.dart`、`test/features/canvas/widgets/left_rail/assets_panel_test.dart`、`test/features/gallery/providers/gallery_filter_test.dart`、`test/features/gallery/util/gallery_meta_test.dart`、`test/features/gallery/widgets/gallery_tile_test.dart`
  - export-one-click：`lib/features/export/open_export_dialog.dart`、`lib/features/export/providers/one_click_export_controller.dart`、`lib/features/export/util/export_file_name.dart`、`lib/features/export/util/last_export_settings.dart`、`lib/features/export/util/one_click_export_plan.dart`、`lib/features/export/widgets/export_new_cards.dart`、`lib/features/export/widgets/export_video_dialog.dart`、`lib/features/shell/widgets/shell_tab_bar.dart`、`lib/theme/components/ink_split_button.dart`、`test/features/export/providers/one_click_export_controller_test.dart`、`test/features/export/util/export_file_name_test.dart`、`test/features/export/util/last_export_settings_test.dart`、`test/features/export/util/one_click_export_plan_test.dart`、`test/features/export/widgets/export_video_dialog_test.dart`、`test/features/shell/shell_tab_bar_test.dart`、`test/theme/components/ink_split_button_test.dart`

## 具体改动
```dart
// notification_prefs.dart
enum ToastCorner { system, bottomRight, topRight, bottomLeft, topLeft }
ToastCorner toastCornerFromPref(String value); // 非法值 → ToastCorner.system
/// system → 具体的角：macOS 是 topRight，其余平台（Windows / Linux）是 bottomRight；非 system 原样返回。
ToastCorner resolveToastCorner(ToastCorner pref, TargetPlatform platform);

// util/toast_placement.dart
@immutable
class ToastPlacement {
  final double? left, right, top, bottom; // 直接喂给 Positioned
  final bool growsDown;                   // true = 上角：最新的在最上，旧的往下排
  final bool alignRight;                  // 「还有 N 条」胶囊靠哪边
}
ToastPlacement toastPlacementFor(ToastCorner resolved, {required bool narrow});

// notification_prefs_controller.dart
typedef NotificationPrefs = ({ /* 原有字段 + toast-category-mute 的字段 */ ToastCorner corner });
void setCorner(ToastCorner corner); // 先改内存态，再调 _persist(p.copyWith(toastCorner: corner.name))
```
定位规则（`toastPlacementFor`，所有数值都来自常量）：
- 下角：`bottom = ShellStatusBar.height`，卡片栈底部再留 `InkSpacing.md`，和现在一样，仍然用 Padding 而不是在 widget 里做加法。
- 上角：`top = InkWindowChrome.height + InkShellTabBar.height`，卡片栈顶部再留 `InkSpacing.md`。上下两种都只把常量相加一次，加法写在 `toast_placement.dart` 里，不写在 widget 里。
- 右角：`right = InkSpacing.md`。
- 左角：`left = CanvasLeftRail.width + InkSpacing.md`，这是在让开画布左栏那条 43 宽的导航条。
- 窄窗口（宽度 < `InkToastSize.narrowWindow`）：`left = right = InkSpacing.md`，宽度撑满，横向位置不管选的是哪个角，纵向仍然按角来。
- `_ToastStack` 用 `ref.watch(notificationPrefsControllerProvider.select((p) => p.corner))` 取设置，平台用 `defaultTargetPlatform`。**widget 树的形状在各个角之间必须完全一样**（Positioned → Visibility → Padding → MouseRegion → Semantics → Material → Column），只改参数和子项顺序。卡片的 `ValueKey<int>(e.id)` 不变，这样换角时 `_ToastSlot` 的 State 会保留，进场动画不会重放。
- 上角时 Column 的子项倒过来排：最新的卡在最上面，「还有 N 条」放在最下面；胶囊左角靠左对齐（`Alignment.centerLeft`），右角靠右对齐。
- `_ToastSlot` 加一个参数 `bool fromTop`。为 true 时位移 dy 取反：进场时从上方 `InkSpacing.md` 处落下来，退场时往上移 `InkSpacing.sm`。减弱动效时仍然 dy = 0。

## 行为规则与边界情况
1. 偏好里存的是 `'system'|'bottomRight'|'topRight'|'bottomLeft'|'topLeft'`。缺失、类型不对或值不合法，都按 `'system'` 处理，并且不抛异常。
2. 选「跟随系统」时，macOS 是右上，Windows 是右下，其他平台也是右下。
3. 下角时，最新的卡贴着角，旧的往上叠，这就是现在的行为，必须保持一模一样（现有用例不能改断言）。
4. 上角时，最新的卡贴着角，也就是离窗口顶部最近；旧的往下排；「还有 N 条」在整个栈的最下面。
5. 上角卡片的顶边 = 标题栏高 + 标签栏高 + `InkSpacing.md`，不能压在标签栏上。
6. 左角卡片的左边 = 43 + `InkSpacing.md`。窄窗口时左右各留 16，宽度撑满。
7. 卡片在场时改位置：卡片当场出现在新的角，不重放进场动画（State 保留）。原来剩下的停留时间照常走完，不重新计时。ToastCenter 的状态不应该有任何变化。
8. 铃铛历史开着时，卡片栈照样让位、不画；关上后出现在新的角。
9. 悬停停表、窗口失焦停表的行为在每个角都一样（MouseRegion 一直留在树里）。
10. 设置页点选后马上生效，同时异步落盘；落盘失败不回滚内存态，和 setDwell 一样。

## 新文案键
| key | en | zh |
|---|---|---|
| settingsNotificationCornerLabel | Position | 位置 |
| settingsNotificationCornerSystem | Follow system | 跟随系统 |
| settingsNotificationCornerBottomRight | Bottom right | 右下 |
| settingsNotificationCornerTopRight | Top right | 右上 |
| settingsNotificationCornerBottomLeft | Bottom left | 左下 |
| settingsNotificationCornerTopLeft | Top left | 左上 |
| settingsNotificationCornerHint | Follow system = bottom right on Windows, top right on macOS | 跟随系统 = Windows 右下 · macOS 右上 |

## 测试
先写下面这些用例，确认它们失败后再实现。
- `test/features/notifications/util/toast_placement_test.dart`（新建）
  - `resolveToastCorner：system 在 macOS 是右上、在 Windows 是右下、显式值原样`
  - `上角：top = 标题栏 + 标签栏，growsDown 为 true，bottom 为 null`
  - `下角：bottom = 状态栏高，growsDown 为 false`
  - `左角：left = 左栏宽 + md；窄窗口左右都是 md`
- `test/core/models/app_preferences_test.dart`
  - `toastCorner 往返：toMap → fromMap 保持 topLeft`
  - `toastCorner 非法值 / 缺失 → system`
- `test/features/settings/notification_prefs_controller_test.dart`
  - `setCorner 立即更新状态并写入偏好 toastCorner`
- `test/features/settings/notifications_section_test.dart`
  - `位置五选一：点「左上」→ 控制器 corner = topLeft，按钮呈选中态；说明行在`
- `test/features/notifications/widgets/toast_layer_test.dart`（沿用 `_pumpLayer`，偏好用 override 喂进去）
  - `右上角：卡片顶边 = 31 + 35 + 16，右边距 16`（断言用常量相加，不写字面量）
  - `上角：最新的贴角，旧的往下排；「还有 N 条」在最下`
  - `左下角：左边 = 43 + 16，底边在状态栏 + 16 之上`
  - `跟随系统：debugDefaultTargetPlatformOverride = macOS 时在右上，windows 时在右下`
  - `在场时换角：同一张卡的 State 保留（不重放进场，opacity 立即为 1），按原计时到点自动关闭`
  - 现有的 `右下角：右边距 16…`、`最多 3 张在场…` 两条用例不改断言，继续通过。

## 变异点
1. `resolveToastCorner` 里把 macOS 改成返回 `bottomRight`，会被 `resolveToastCorner：system 在 macOS 是右上…` 和 `跟随系统：…macOS 时在右上…` 抓住。
2. `toastPlacementFor` 上角的 top 去掉 `InkShellTabBar.height`，会被 `右上角：卡片顶边 = 31 + 35 + 16…` 抓住。
3. `_ToastStack` 上角时不倒序（Column 仍按旧 → 新排），会被 `上角：最新的贴角，旧的往下排…` 抓住。
4. 换角时给 `_ToastSlot` 换一个 key（例如带上 corner），会被 `在场时换角：同一张卡的 State 保留…` 抓住。
5. `AppPreferences.fromMap` 不读 `toast_corner`（总是返回 system），会被 `toastCorner 往返…` 抓住。
6. 左角的 left 去掉 `CanvasLeftRail.width`，会被 `左下角：左边 = 43 + 16…` 抓住。

## 验收
- 主 Agent 跑 `flutter analyze lib test`、`flutter test test/features/notifications test/features/settings test/core/models`，并按上面每条变异做一次。
- 截图场景：用 `ToastLayer` 包住空 Scaffold，窗口 1280×800，暗色主题，放 4 张卡（info、success、带缩略图的 success、error），这样会出现「还有 1 条」。分别截 右下 / 右上 / 左下 / 左上 四个角；再截一张窄窗口 420 宽的右上角；还要截设置页 `NotificationsSection`，选中「左上」的状态。

## 风险与不确定
- 画板写的是「让开 40 标题栏、43 导航条」，代码里标题栏是 31、标签栏是 35，加起来 66。这里按代码常量取 66。43 理解为画布左栏的宽度，用在左角。如果主 Agent 认为 43 指的是上方的某一栏，只需要改 `toastPlacementFor` 一处。
- 左角在工作室、画廊等标签下也让出 43，即使那里没有左栏。这样所有标签下的位置一致，代价是工作室下左边会空出一条。
- toast-category-mute 没有改 `NotificationPrefs` 记录（它用独立的 `ToastMuteController`）；本片只给记录追加 `corner`，不动 `ToastMuteController`。若 main 上实际不同，以 main 为准、只追加。
- `toast_layer.dart` 引用 `features/canvas` 的 `CanvasLeftRail.width`，属于跨 feature 引用。现在已经有先例（引用了 `ShellStatusBar`），不会触发 `no_reverse_layer_import_test`。
