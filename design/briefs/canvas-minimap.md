# canvas-minimap · 小地图（M / 缩放条末格开合，全局记忆）
- 波次：W17；lane：C；基底：origin/main（W16 全部合入之后的 main）
- 依赖切片：硬依赖 esc-ladder（W0，`shortcuts/canvas_key_binding.dart` 的 `CanvasKeyBinding` / `CanvasKeyGate.notEditingText` / `ShortcutGroup` + 注册表 `kCanvasKeyRegistry`）、canvas-view-split（W0；注意 `LaneToolbar` 留在 canvas_view.dart 骨架的 `_CanvasBody` 外层 Stack 里，没有搬进 `stage/stage_overlays.dart`）、canvas-capsule（W1：tokens 里 `InkToolbarSize.zoomBarWidth = 143`、`zoomBarPercentCell = 46`，canvas_zoom_bar.dart 导出 `kCanvasZoomBarWidth = InkToolbarSize.zoomBarWidth`；胶囊左右避让读的是另一个 token `InkCanvasCapsuleSize.sideReserve = 171`〔= 12 + 143 + 16〕，不是缩放条常量）；软依赖 canvas-find-bar（W9，本片不读它，见行为规则 9）。以上在执行本片时都已合入 main。app_preferences 链上前一环是 W16 toast-corner，已合入。
- 阻塞决定：无（板 ImportSearch 本节没有「需要你定」项）

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
画布左下角缩放条多出一格「小地图」开关，按 M 也能开合；开着时在缩放条上方出现一块 152×64 的小地图，画出泳道色带、每张卡一个小块和琥珀色视口框。点小地图 = 视口跳到那一点（缩放不变），拖视口框 = 平移画布。开 / 关是全局的，重启后保持；默认关；空画布不显示。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
画板 `ImportSearch.dc.html`（文本版 boards/ImportSearch.txt，生成器 b2_import.js 第 171–199 行），小节「小地图 · 回到内容 —— 都在画布角落，不占工具条」。规则原文：
- M 或缩放条末格开合，默认收起；开合全局记在 preferences.json
- 贴在缩放条正上方、同宽，提示词条现有的避让不用改
- 画泳道色带、节点小块和视口框；点 = 跳过去，拖框 = 平移，滚轮不缩放
- 空画布不出（那里是空画布引导）；查找条开着时让位（见规则 9 与「风险」）
样稿尺寸（mockE）：小地图 160×64、圆角 6、底 s3、1px control 边、overflow 裁；泳道带 = s5 横条；节点块 18×14 圆角 2，颜色 fg4 / fg5 / fg6；视口框 1.5px accent 边 + wash 底、圆角 2。缩放条 160 宽，五格 26 | 36（百分比） | 26 | 36（适应，左分隔） | 34（小地图图标 minimap，左分隔；开着时 wash 底 + accent 图标）。KeyMap 板单键表：「M · 小地图 开 / 关 · 画布 · 第二批」，includeRepeats: false，对文字让位。
设计缺口：
- 样稿没画泳道工具栏（lane_toolbar，现叠在缩放条上方 bottom 48）。小地图不能「贴缩放条正上方」，改为叠在泳道工具栏之上（规则 2）。
- 样稿宽 160，但现有令牌 `InkToolbarSize.stageBottomLeftReserve = 176`（左 12 + 条宽 + 右 12，由 canvas_screen_layout_test 守着）只容得下 152；本片取 152（规则 1），不改令牌。
- 竖向泳道、折叠泳道、多选高亮在小地图上的样子没画。

## 允许改的文件（逐个路径 + 每个文件改什么；新建的标「新建」；前序切片新建的标「由 <id> 新建」）
- `lib/features/canvas/util/minimap_geometry.dart`（新建）：纯函数，舞台矩形 ↔ 小地图坐标、视口框、泳道带、拖框平移。
- `lib/features/canvas/providers/minimap_visible.dart`（新建）：`minimapVisibleProvider`（应用级 Notifier<bool>，从偏好播种、切换即落盘）。
- `lib/features/canvas/widgets/canvas_minimap.dart`（新建）：小地图 widget（CustomPaint + 指针处理）。
- `lib/features/canvas/widgets/shortcuts/minimap_keys.dart`（新建）：M 键 activator 常量、`CanvasToggleMinimapIntent`、`final List<CanvasKeyBinding> minimapKeys`（写法照 import-media-command 的 `importMediaKeys`）。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（由 esc-ladder 新建，W0）：`kCanvasKeyRegistry` 只追加一行 `...minimapKeys`。
- `lib/features/canvas/widgets/canvas_zoom_bar.dart`：加第五格「小地图」开关；`kCanvasZoomBarWidth` 改指向新 token `InkToolbarSize.zoomBarWithMinimapWidth`（152），百分比格改读 `InkToolbarSize.zoomBarCompactPercentCell`（36）。
- `lib/theme/tokens.dart`（只追加）：`InkToolbarSize.zoomBarWithMinimapWidth = 152`、`InkToolbarSize.zoomBarCompactPercentCell = 36`、`InkCanvasCapsuleSize.sideReserveWithMinimap = 180`（= 12 + 152 + 16），注释写清怎么来的；canvas-capsule 的旧值 143 / 46 / 171 不动（只许追加），变成死常量后由主 Agent rebase 时删（零兼容）。
- `lib/features/canvas/widgets/canvas_capsule_host.dart`（由 canvas-capsule 新建，W1；W17 无人占用）：`Positioned` 的 left / right 由 `InkCanvasCapsuleSize.sideReserve` 改读 `sideReserveWithMinimap`，只改这一处；`test/features/canvas/widgets/canvas_capsule_host_test.dart` 若断言了 171 一并改。
- `lib/features/canvas/widgets/canvas_screen.dart`（canvas_screen 链 W17 环归本片）：在缩放条那段 Stack 里挂 `CanvasMinimap`。
- `lib/core/models/app_preferences.dart`（app_preferences 链 W17 环归本片）：新字段 `canvasMinimapVisible`。
- `lib/services/file_preferences_service.dart`：不需要改代码（toMap 自动带上）；只在它的测试里加用例。
- 测试：`test/features/canvas/util/minimap_geometry_test.dart`（新建）、`test/features/canvas/widgets/canvas_minimap_test.dart`（新建）、`test/features/canvas/providers/minimap_visible_test.dart`（新建）、`test/core/models/app_preferences_test.dart`、`test/services/file_preferences_service_test.dart`、`test/features/canvas/widgets/canvas_zoom_bar_test.dart`、`test/features/canvas/widgets/canvas_screen_layout_test.dart`。

## 不许碰的文件
- 同波 cm-knife-cut：`stage_pointer_layer.dart`、`edge_cut_controller.dart`、`edge_cut_hit.dart`、`edge_cut_painter.dart`、`canvas_cut_actions.dart`、`escape_ladder.dart`、`models/commands/cut_edges_command.dart`。
- 同波 shortcuts-page-v2：`lib/features/settings/util/shortcut_catalog.dart`、`pointer_gesture_catalog.dart`、`settings/widgets/shortcuts_section.dart`、`create_node_menu.dart`、`command_palette/widgets/command_palette_dialog.dart`、`batch_compare_overlay.dart`、`gallery/widgets/gallery_grid.dart`。
- 同波 rail-templates-page：`left_rail_state.dart`、`left_rail/*`、`templates/*`、`create_menu_model.dart`、`canvas_toolbar.dart`、`studio/open_canvas.dart`。
- 同波 script-reimport-diff：`storyboard/*`、`script_repository.dart`、`postgres_script_repository.dart`。
- `canvas_view.dart` 骨架、`stage/stage_overlays.dart`、`lane_toolbar.dart`、`canvas_tool_actions.dart`。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W17 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - rail-templates-page：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/util/create_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/create_menu_entries.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/template_card.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`lib/features/templates/util/template_ui_actions.dart`、`lib/features/templates/widgets/template_thumbnail_painter.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/create_menu_model_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/templates_panel_test.dart`、`test/features/templates/widgets/template_thumbnail_painter_test.dart`
  - script-reimport-diff：`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/storyboard/providers/script_import_controller.dart`、`lib/features/storyboard/providers/script_reimport_controller.dart`、`lib/features/storyboard/util/script_diff.dart`、`lib/features/storyboard/widgets/script_import_dialog.dart`、`lib/features/storyboard/widgets/script_reimport_preview.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`、`test/features/storyboard/providers/script_import_controller_test.dart`、`test/features/storyboard/providers/script_reimport_controller_test.dart`、`test/features/storyboard/util/script_diff_test.dart`、`test/features/storyboard/widgets/script_import_dialog_test.dart`
  - cm-knife-cut：`lib/features/canvas/models/commands/cut_edges_command.dart`、`lib/features/canvas/providers/edge_cut_controller.dart`、`lib/features/canvas/util/canvas_cut_actions.dart`、`lib/features/canvas/util/edge_cut_hit.dart`、`lib/features/canvas/util/escape_ladder.dart`、`lib/features/canvas/widgets/edge_cut_painter.dart`、`lib/features/canvas/widgets/stage/stage_pointer_layer.dart`、`test/features/canvas/models/commands/cut_edges_command_test.dart`、`test/features/canvas/providers/edge_cut_controller_test.dart`、`test/features/canvas/util/edge_cut_hit_test.dart`、`test/features/canvas/widgets/canvas_knife_cut_test.dart`
  - shortcuts-page-v2：`lib/features/settings/util/overlay_key_catalog.dart`、`lib/features/settings/util/pointer_gesture_catalog.dart`、`lib/features/settings/util/shortcut_catalog.dart`、`lib/features/settings/widgets/shortcuts_section.dart`、`test/features/settings/overlay_key_catalog_test.dart`、`test/features/settings/pointer_gesture_catalog_test.dart`、`test/features/settings/shortcut_catalog_test.dart`、`test/features/settings/shortcuts_section_test.dart`

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// app_preferences.dart：字段、copyWith、toMap、fromMap、==、hashCode 六处都加
final bool canvasMinimapVisible;           // 默认 false；JSON 键 'canvas_minimap_visible'；非 bool → false

// minimap_visible.dart（模式照 settings/providers/shell_keep_last_canvas_controller.dart）
class MinimapVisibleController extends Notifier<bool> {
  bool build();          // ref.read(preferencesServiceProvider).current.canvasMinimapVisible
  void toggle();         // state 取反 + unawaited(prefs.update(copyWith(canvasMinimapVisible: …)))
}
final minimapVisibleProvider = NotifierProvider<MinimapVisibleController, bool>(…, name: 'minimapVisibleProvider');

// minimap_geometry.dart
const double kMinimapPadding = 6;                       // 小地图内边距（小地图像素）
@immutable class MinimapFrame { final Rect world; final double scale; final Offset offset; }
MinimapFrame minimapFrame({required Iterable<Rect> contentRects, required Rect viewportRect, required Size size, double padding = kMinimapPadding});
Rect stageRectToMinimap(Rect stageRect, MinimapFrame frame);
Offset minimapToStage(Offset minimapPoint, MinimapFrame frame);
Rect viewportStageRect({required Matrix4 transform, required Size viewportSize});
List<Rect> laneBandsStage({required List<({String id, double size})> laneSlices, required LaneDirection direction, required Matrix4 transform});
Matrix4 transformPannedByStage({required Matrix4 current, required Offset stageDelta});

// canvas_minimap.dart
class CanvasMinimap extends ConsumerStatefulWidget { const CanvasMinimap({super.key, required this.canvasId}); static const Size size = Size(152, 64); static const Key paintKey; }

// minimap_keys.dart
class MinimapKeys { static const SingleActivator toggle = SingleActivator(LogicalKeyboardKey.keyM, includeRepeats: false); }
class CanvasToggleMinimapIntent extends Intent { const CanvasToggleMinimapIntent(); }
```
- 舞台坐标口径：节点矩形一律 `nodeStageRect(node, lanes: collapseLaneSlices(…), direction, transform: 当前相机)`（util/viewport_focus.dart 第 21 行），只取不在折叠泳道里的节点，与 `_fitNodes`（canvas_tool_actions.dart 第 247 行）同一套取值。视口框 = 视口矩形过逆相机。泳道带：屏幕横截起点 = `laneStackOffset(m, direction)`（lane_pin_geometry.dart 第 28 行）+ 各道累计厚度，再过逆相机换成舞台横截；主轴方向铺满小地图。
- 点击跳转：复用 `transformCenteringRect(current:, viewportSize:, stageRect: Rect.fromCenter(center: p, width: 0, height: 0))`（viewport_focus.dart 第 39 行），写回 `canvasTransformControllerProvider(canvasId)`。
- 画法：一个 CustomPainter，`repaint:` 传 TransformationController，相机动只重绘这块；节点 / 泳道 / 折叠态用 ref.watch。块色：配置节点 fg4，文本 fg5，产物节点 fg6；选中的节点块用 accent（设计缺口里自定，见风险）。
- 缩放条：第五格 `_ZoomCell(width: 30, label: l.canvasMinimapToggle, …)`，图标 `InkGlyph.minimap`（ink_glyph.dart 第 187 行已有），开着时 accentWash 底 + accent 图标，并给 `InkActivatable` 传 `selected:`。各格宽改为 26 | 36 | 26 | 32 | 30，加 2px 边 = 152。
- 挂载（canvas_screen.dart）：`Positioned(left: InkSpacing.s12, bottom: InkToolbarSize.stageBottomInset + LaneToolbar.height + InkSpacing.s10, child: CanvasMinimap(canvasId: canvasId))`，放在 CanvasZoomBar 之后、CanvasPromptBar 之前。
- 注册表追加一行 `...minimapKeys`，其中 `CanvasKeyBinding(id: 'canvasToggleMinimap', activators: [MinimapKeys.toggle], intent: CanvasToggleMinimapIntent(), gate: CanvasKeyGate.notEditingText, group: ShortcutGroup.view, label: (l) => l.settingsShortcutCanvasToggleMinimap, onInvoke: (c, _) => c.ref.read(minimapVisibleProvider.notifier).toggle())`（文字里让位即 `notEditingText`，原 `_EditingAwareAction` 已被 esc-ladder 并进 gate）。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 尺寸：小地图 152×64，与缩放条同宽；左沿 s12，叠在泳道工具栏之上（bottom 84）。左下一簇总宽 12 + 152 + 12 = 176，不超过 `stageBottomLeftReserve`。
2. 显示条件 = `minimapVisibleProvider` 为 true 且画布有节点。空画布（节点列表为空）不画，缩放条开关仍可按、仍记状态；节点全在折叠泳道里时照画泳道带，没有节点块。
3. 默认 false；偏好文件里缺键或不是 bool → false。M 和缩放条末格都走 `toggle()`，切换后在同一帧生效，偏好写盘 fire-and-forget；写盘失败只记日志（FilePreferencesService 自己处理），内存态照样切换。
4. 开关是全局的：换画布、换项目、重启后都保持；不进撤销栈。
5. M：includeRepeats: false（按住不连切）；焦点在文本框（提示词条、检查器、筛选框）时让位，输入「m」不切。M 不在 Esc 阶梯上。
6. 映射：内容 = 节点矩形 ∪ 视口框，等比缩进 152×64 减内边距并居中。拖框过程中冻结按下时的那一帧映射（否则视口框动会让映射跟着变、拖起来抖）；松手后恢复实时映射。
7. 指针：按下点在视口框内 → 拖动 = 平移（舞台位移 = 小地图位移 / frame.scale，相机缩放不变）；按下点在框外 → 当场把视口中心跳到该点，之后继续拖同样按平移算。只认主键，右键 / 中键忽略。
8. 滚轮：小地图上滚动什么都不做，画布不缩放、小地图也不缩放（小地图是舞台的兄弟层，命中停在它这里）。
9. 查找条开着时小地图照常显示：查找条在顶部、小地图在左下，不相撞。板上「查找条开着时让位」按回到内容胶囊理解（见风险）。
10. 泳道：横向泳道画横带，竖向画竖带；折叠的道按 kCollapsedLaneSize 的有效厚度画；带色 surface5。
11. 性能：平移、缩放只重绘小地图这一层，不重建 CanvasScreen；拖卡途中（nodeDragDeltaProvider）不跟着重绘，松手节点位置更新后再画。
12. 节点或视口尺寸还没准备好（`canvasViewportSizeProvider` 为 Size.zero）时不画视口框，点击不动相机。
13. 语义：小地图整体 `Semantics(label: l.canvasMinimapLabel)`，不进 Tab 序（纯指针控件，键盘用 M / Shift 1）；缩放条末格可 Tab、Enter / Space 切换，读屏报 selected。
14. mac / Windows 无差异（M 单键，两平台同键）。

## 新文案键（key · en · zh 表；没有写「无」）
| key | en | zh |
|---|---|---|
| canvasMinimapToggle | Minimap | 小地图 |
| canvasMinimapLabel | Canvas minimap | 画布小地图 |
| settingsShortcutCanvasToggleMinimap | Minimap on / off | 小地图 开 / 关 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/util/minimap_geometry_test.dart`
  - 「内容等比缩进并居中」：两张卡 + 视口框，frame.scale = min(宽比, 高比)，四边留 kMinimapPadding。
  - 「stageRectToMinimap 与 minimapToStage 互逆」：任取三点往返误差 < 1e-6。
  - 「viewportStageRect 是视口过逆相机」：scale 0.5、平移 (100, 40) 时数值精确。
  - 「拖框平移只改平移不改缩放」：transformPannedByStage 后 scaleOf 不变，平移 = −scale·delta。
  - 「泳道带过逆相机」：两条道 120 / 80，scale 2 时舞台厚度 60 / 40，起点随 laneStackOffset。
  - 「折叠道按 36 算」：折叠一条后带厚 = 36 / scale。
- `test/features/canvas/widgets/canvas_minimap_test.dart`（夹具照 canvas_pan_tool_test：pumpInkApp + fake_canvas 的 RecordingNodesController / twoNodes）
  - 「关着不画」「开着且有节点才画」「空画布不画」：find.byKey(CanvasMinimap.paintKey)。
  - 「点框外一点 = 视口中心跳到那里、缩放不变」：tap 后比对 TransformationController 的平移与 scaleOf。
  - 「拖视口框 = 平移」：drag 20px，相机平移 = −20 / frame.scale · scale；缩放不变。
  - 「拖动中映射冻结」：拖动两步之间读到的 MinimapFrame 相同（通过 painter 暴露的 frame 断言）。
  - 「滚轮不缩放」：在小地图上发 PointerScrollEvent，相机矩阵不变。
  - 「M 开合 + 输入框里不响应」：画布持焦按 M → provider 翻转；聚焦一个 TextField 按 M → 不变。
  - 「按住 M 只切一次」：sendKeyDownEvent + 两个 repeat 事件后 provider 只翻转一次。
- `test/features/canvas/providers/minimap_visible_test.dart`：「从偏好播种」「toggle 写回偏好」（InMemoryPreferencesService 断言 current.canvasMinimapVisible）。
- `test/core/models/app_preferences_test.dart`：「canvasMinimapVisible 默认 false、往返、非 bool 退 false、copyWith」。
- `test/services/file_preferences_service_test.dart`：「小地图开关落盘后新实例读回 true」。
- `test/features/canvas/widgets/canvas_zoom_bar_test.dart`：「末格切换 provider、开着时 selected = true」「条宽 152」。
- `test/features/canvas/widgets/canvas_screen_layout_test.dart`：「小地图右沿 + 12 ≤ stageBottomLeftReserve」「小地图底边在泳道工具栏顶边之上」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，并写「由测试 <用例名> 抓住」）
1. fromMap 里 `canvas_minimap_visible` 缺省改成 true → 由「canvasMinimapVisible 默认 false、往返…」抓住。
2. `toggle()` 里去掉 prefs.update → 由「toggle 写回偏好」抓住。
3. canvas_minimap 显示条件去掉「有节点」→ 由「空画布不画」抓住。
4. 拖框时不冻结映射（每次 move 重新算 frame）→ 由「拖动中映射冻结」抓住。
5. transformPannedByStage 里平移符号写反 → 由「拖框平移只改平移不改缩放」与「拖视口框 = 平移」抓住。
6. M 的 activator 去掉 includeRepeats: false → 由「按住 M 只切一次」抓住（esc-ladder 的守卫测试也会红）。
7. M 的 Action 换成不让位的 CallbackAction → 由「M 开合 + 输入框里不响应」抓住。
8. 小地图外包一层 Listener 把滚轮转给相机缩放 → 由「滚轮不缩放」抓住。
9. 挂载点 bottom 改回 stageBottomInset（压住泳道工具栏）→ 由「小地图底边在泳道工具栏顶边之上」抓住。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/core/models test/services/file_preferences_service_test.dart --exclude-tags golden`，再逐条跑变异。
- 截图（test/_harness/screenshot.dart，中文界面）：`CanvasScreen(isVisible: true)`，数据 = 两条横向泳道（「水墨」「夜景」）+ 6 个节点（4 配置、1 文本、1 产物，其中一个选中）+ 相机平移到只看得见 2 张卡。截三张：① 小地图关着（缩放条第五格灰）；② 开着（第五格 wash 底，小地图在泳道工具栏上方，视口框在右侧）；③ 拖视口框到左边之后。

## 风险与不确定
- （已按 canvas-capsule 派工单落定）缩放条宽在 tokens（143），按「只许追加」新增 152 / 36 / 180 三个常量，并由本片把 `kCanvasZoomBarWidth` 和胶囊宿主改读新值；胶囊避让从 171 变 180，`canvas_capsule_host_test` / `canvas_screen_layout_test` 里相关断言随之改。旧常量的删除交给主 Agent。
- 画板写 160 宽、贴缩放条正上方；与现有 176 的左下保留宽和泳道工具栏冲突，本片按 152 宽、叠在泳道工具栏之上。主 Agent 若要 160，就要改令牌 176 → 184 并重跑 prompt_bar_width 相关测试。
- slices.json 的 notes 认为「查找条开着时让位」也管小地图；本片按画板行序理解为只管回到内容胶囊（两者都在顶部居中）。如主 Agent 认为小地图也要让位，追加一个 `canvasFindControllerProvider` 判据即可（由 canvas-find-bar 新建，W9）。
- 快捷键页的键名表 `_keyLabels`（shortcut_catalog.dart 第 179 行）没有 M；同波 shortcuts-page-v2 占着这个文件，它的派工单已写明预先加 `keyM: 'M'`。若本片先合，shortcut_catalog_test 可能因 M 没认领而变红，主 Agent 要按 shortcuts-page-v2 → canvas-minimap 的顺序合，或在 rebase 时补这一行。
- 「更多」下拉里的「小地图 M ✓」一项由 W18 more-dropdown-panel 加（`more_menu_model.dart` 是 W1 app-action-table 建的注册表，W18 把它改成分组表），那一片调 `minimapVisibleProvider`；本片不加 catalog 行。
