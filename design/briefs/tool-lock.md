# tool-lock · 工具锁（Q / 双击工具键，点放建节点）
决定：IS-Q4 按建议 A
- 波次：W19；lane：A；基底：origin/main（W18 全部合入之后的 main）
- 依赖切片：硬依赖 esc-ladder（W0，快捷键注册表 + Esc 阶梯「工具锁」登记口）、marquee-select（W3，stage_pointer_layer 里「挪不到 4px 算点空白」的判定）、cm-knife-cut（W17，stage_pointer_layer 链的前一环；Alt / 武装起切线的分支）、more-dropdown-panel（W18，改过 canvas_toolbar.dart 的「更多」）。软依赖 note-variant（W14，工具条已有「便签 N」键，锁定列表含便签）、naming-shot-unify（W0，类型统一叫「镜头」）。以上在执行本片时都已合入 main。
- 阻塞决定：IS-Q4（工具锁做不做；plan.md 第 5 节列为不阻塞、默认）→ 按建议 A 执行：做，Q + 双击工具按钮，进点放模式。

> 执行约定：在自己的工作树里、从基底起分支；只改「允许改的文件」；不跑构建和测试（flutter / dart 都不跑）；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。

## 目标（用户看到什么变化，2–4 行）
双击工具条上的「图像 / 视频 / 文本 / 镜头 / 便签」任一键，或按 Q，这个建节点工具就被锁住：键上多一枚图钉角标，工具条下方出现「图像配置 · 已锁定  Q 解锁」。锁定期间在画布空白处每点一下就在那里放一张该类型的卡，鼠标跟着一个虚线占位框。按 V、Esc、Q、H、L 或点别的工具解锁。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
画板 `ImportSearch.dc.html`（文本版 boards/ImportSearch.txt 第 142–169 行；生成器 b2_import.js 「F：工具锁与便签」）小节「工具锁 · 便签 —— 两个 P2 小工具」。规则原文：
- 现状 图像 I / 视频 G / 文本 T / 镜头 / 便签 N 一按就在视口中心建一个；锁定后改为点放，每点一下空白处建一个
- Q 或双击工具按钮锁定；V、Esc、换工具解锁；连线 L 本来就是模式，不参与
- 新键 Ctrl U、Ctrl F、M、Q、N 都不撞现有键；单键只在画布持焦且不在文字里时生效
- Esc 一次只收一层：菜单 > @ 弹层 > 查找条 > 框选进行中 > 工具锁 > 清空选中
样稿（mockF）：被锁的键 = accentWash 底 + 1px accentWashBorder 描边 + accent 图标；右下角 12×12 圆形角标（底 s4，图钉 pin 图标 9px accent，偏出键外 3px）。键下方一枚条：高 20、左右内边距 7、圆角 3、底 s5、10px fg2 文字「图像配置 · 已锁定」+ 键帽「Q 解锁」，左沿与工具条左沿对齐。画布上一个 1.5px accent 虚线框、圆角 4，框里图标 + 「点一下放一个」。KeyMap 板：单键表「Q · 工具锁 · 画布 · 第二批」、指针表「双击工具按钮 · 工具锁」；Esc 阶梯第 6 层「工具回到选择（工具锁 · 平移 · 连线）」；单键 includeRepeats: false。
设计缺口：
- Q 在没锁时锁「哪个工具」没写：本片锁「本画布最近一次在工具条上点过的建节点工具」，从没点过就锁图像配置。
- 锁定中按 I / G / T（键盘建节点）算不算「换工具」没写：本片照常在视口中心建一张、锁不变（这几个键的动作在核心快捷键文件里，本片不改）。
- 占位框尺寸：样稿 130×66 只是示意，本片画成真实卡片大小（kNodeCardSize，随缩放）并以指针为中心。
- 锁定中双击空白：本片不开新建菜单，两下各放一张（第二下若落在刚放的卡上就是点卡）。

## 允许改的文件（逐个路径 + 每个文件改什么；新建的标「新建」；前序切片新建的标「由 <id> 新建」）
- `lib/features/canvas/providers/canvas_tool_mode.dart`：新增 `canvasToolLockProvider`；`select()` / `pan()` / `togglePan()` 顺带解锁。
- `lib/features/canvas/util/canvas_tool_lock_actions.dart`（新建）：`placeLockedNodeAt`、`toggleToolLockByKey`。
- `lib/features/canvas/widgets/tool_lock_ghost.dart`（新建）：跟随指针的虚线占位框。
- `lib/features/canvas/widgets/stage_pointer_layer.dart`（由 canvas-view-split 新建，W0；stage_pointer_layer 链 W19 环归本片）：锁定时点空白 = 放卡；不开双击新建菜单；悬停画占位框。
- `lib/features/canvas/widgets/canvas_toolbar.dart`：建节点键支持双击锁定、图钉角标、键下锁定条。
- `lib/features/canvas/widgets/shortcuts/tool_lock_keys.dart`（新建；目录按 esc-ladder 在 main 上的实际位置）：Q 键 activator、`CanvasToggleToolLockIntent`、Action。
- `lib/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart`（由 esc-ladder 新建，W0）：只追加一行 Q。
- `lib/features/canvas/util/escape_ladder.dart`（由 esc-ladder 新建，W0）：只在「工具锁」登记口登记（若登记口不需要改此文件就不改）。
- `lib/features/settings/util/shortcut_catalog.dart`：若 `_keyLabels`（第 179 行）仍在且没有 Q，追加 `LogicalKeyboardKey.keyQ.keyId: 'Q'` 一行；若 esc-ladder 之后键名由注册表行自带，不改。
- `lib/features/settings/util/pointer_gesture_catalog.dart`（由 shortcuts-page-v2 新建，W17）：`kPointerGestureRows` 追加一行「双击工具按钮 = 工具锁」（范围 canvas，文案键 `settingsGestureToolLock`），排在「双击文本 / 便签」之后，与 KeyMap 板指针表顺序一致。
- 测试：`test/features/canvas/providers/canvas_tool_mode_test.dart`、`test/features/canvas/widgets/canvas_tool_lock_test.dart`（新建）、`test/features/canvas/widgets/canvas_toolbar_test.dart`、`test/features/settings/pointer_gesture_catalog_test.dart`（把「不含工具锁与切线两行」改成「含工具锁一行」）。

## 不许碰的文件
- 同波 lane-collapse-persist：`lib/storage/schema/*`、`app_migrations.dart`、`core/db/columns.dart`、`models/style_lane.dart`、`postgres_style_lane_repository.dart`、`lane_collapse_controller.dart`、`canvas_lanes_controller.dart`、`services/import/import_remapper.dart`、`test/quality/import_schema_sync_test.dart`、`test/storage/migrations_test.dart`。
- 同波 my-templates-table：`canvas_template_repository.dart`、`postgres_canvas_template_repository.dart`、`core/di/repositories.dart`、`templates/*`、`left_rail/templates_panel.dart`。
- 热点：`canvas_tool_actions.dart`（`addNodeFromMenu` / `menuNodePlacement` 已够用，只调用不改）、`canvas_shortcuts.dart` 核心键文件、`canvas_view.dart` 骨架、`node_card.dart`、`node_card_slot.dart`、`create_node_menu.dart`、`create_menu_model.dart`、`canvas_screen.dart`、`theme/tokens.dart`。

- **同波占用总表**（主 Agent 交叉核对时补全；下列文件在 W19 归所列切片，本片一律不碰，含它们的测试文件；例外只有 ARB / generated / docs/CLAUDE.md、`theme/tokens.dart` 只追加常量、四张注册表各追加一行）：
  - lane-collapse-persist：`lib/core/db/columns.dart`、`lib/features/canvas/models/style_lane.dart`、`lib/features/canvas/providers/canvas_lanes_controller.dart`、`lib/features/canvas/providers/lane_collapse_controller.dart`、`lib/services/import/import_remapper.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/schema/schema_v12.dart`、`test/features/canvas/canvas_lanes_controller_test.dart`、`test/features/canvas/lane_collapse_controller_test.dart`、`test/features/canvas/models/style_lane_test.dart`、`test/features/canvas/widgets/lane_interactions_test.dart`、`test/quality/migration_registry_test.dart`、`test/services/import/import_remapper_test.dart`、`test/services/project_roundtrip_integration_test.dart`
  - my-templates-table：`lib/core/db/columns.dart`、`lib/core/di/repositories.dart`、`lib/core/interfaces/canvas_template_repository.dart`、`lib/features/canvas/widgets/left_rail/template_card.dart`、`lib/features/canvas/widgets/left_rail/templates_panel.dart`、`lib/features/templates/providers/my_templates_controller.dart`、`lib/features/templates/util/my_template_actions.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/repositories/postgres_canvas_template_repository.dart`、`lib/storage/schema/schema_v13.dart`、`lib/theme/components/ink_name_dialog.dart`、`test/_harness/fake_canvas_template_repository.dart`、`test/core/db/columns_schema_test.dart`、`test/features/canvas/widgets/left_rail/templates_panel_test.dart`、`test/features/templates/providers/my_templates_controller_test.dart`、`test/quality/import_schema_sync_test.dart`、`test/quality/migration_registry_test.dart`、`test/storage/repositories/postgres_canvas_template_repository_integration_test.dart`、`test/storage/schema/populated_migration_test.dart`

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// canvas_tool_mode.dart（追加）
@immutable class CanvasToolLock { final CreateMenuAction? locked; final CreateMenuAction? lastTapped; final DateTime? lastTapAt; }
final canvasToolLockProvider = AutoDisposeNotifierProviderFamily<CanvasToolLockController, CanvasToolLock, String>(…, name: 'canvasToolLockProvider');
class CanvasToolLockController extends AutoDisposeFamilyNotifier<CanvasToolLock, String> {
  CanvasToolLock build(String canvasId);       // ref.listen(linkModeControllerProvider(canvasId)) 进连线即 unlock()
  void lock(CreateMenuAction tool);            // 先让工具态回选择、退出连线，再写 locked
  void unlock();
  /// 工具条点了一个建节点键：记 lastTapped；与上一下同键且间隔 ≤ kDoubleTapTimeout ⇒ 锁定并返回 true（这一下不再建卡）。
  bool tapCreateTool(CreateMenuAction tool);   // 时间取 ref.read(clockProvider).nowUtc()（core/di/clock.dart）
}
bool isLockableCreateAction(CreateMenuAction a); // imageConfig / videoConfig / text / shot（+ note-variant 加的便签项）；lane 与带连线的项不算

// canvas_tool_lock_actions.dart
Future<void> placeLockedNodeAt(BuildContext context, WidgetRef ref, {required String canvasId, required Offset viewportPoint});
void toggleToolLockByKey(WidgetRef ref, {required String canvasId});   // Q：锁着 ⇒ 解锁；没锁 ⇒ 锁 lastTapped ?? imageConfig

// tool_lock_keys.dart
class ToolLockKeys { static const SingleActivator toggle = SingleActivator(LogicalKeyboardKey.keyQ, includeRepeats: false); }
class CanvasToggleToolLockIntent extends Intent { const CanvasToggleToolLockIntent(); }
```
- 解锁入口：`CanvasToolModeController.select()`、`pan()`、`togglePan()` 在改 state 之前调 `ref.read(canvasToolLockProvider(arg).notifier).unlock()`——V（`activateSelectTool`）、H、工具条「选择 / 平移」、L（`toggleLinkMode` 内部调 `select()`，canvas_tool_actions.dart 第 172 行）都因此解锁，不必改 canvas_tool_actions。`lock()` 里先调 `select()` 再写 locked（顺序反了会被自己解掉）。
- 放卡：`placeLockedNodeAt` 取 `locked` → `createdNodeType(action, source: null, nodes: …)`（create_menu_model.dart 第 125 行）→ `addNodeFromMenu(context, ref, canvasId:, type:, placement: menuNodePlacement(ref, canvasId:, viewportPoint: 左上角))`（canvas_tool_actions.dart 第 343 / 311 行）。左上角 = 点击点 − `kNodeCardSize` × 当前缩放 / 2，让卡心落在指针上。便签：若 note-variant 合入后建便签另有函数（`type_config.variant = note`），走那一个，以 main 为准。
- 指针层（stage_pointer_layer）：在 marquee 的「挪不到 4px = 点空白」分支里，`locked != null` 时改调 `placeLockedNodeAt`（点位换成视口坐标：舞台点过相机），不清空选中；`locked != null` 时跳过双击计数；Alt / 切线武装分支（cm-knife-cut）优先于本分支，不受影响。`MouseRegion.onHover` 记舞台坐标，`locked != null` 时在该点画 `ToolLockGhost`（舞台坐标，kNodeCardSize，跟缩放自然一致），离开舞台或解锁时清掉。
- 工具条：建节点键的 onTap 改为「`tapCreateTool(action)` 返回 true ⇒ 已锁定、不建卡；否则锁定中点的是别的建节点键 ⇒ 解锁并照常在视口中心建一张；锁定中点的是被锁的键 ⇒ 解锁、不建卡；未锁定 ⇒ 照旧 `addNodeAtViewportCenter`」。被锁的键 `active: true` + 图钉角标（`InkGlyph.pin`，ink_glyph.dart 第 246 行）。`CanvasToolbar` 返回值外包 `Column(mainAxisSize: min, crossAxisAlignment: start)`，锁定时第二行是锁定条（`Padding(top: InkSpacing.xs)`）：底 `c.surface5`、圆角 `InkRadius.s3`、`EdgeInsets.symmetric(horizontal: InkSpacing.s6)`、高 20，文字 `l.canvasToolLockedChip(工具名)` + 键位提示 `l.canvasToolLockUnlockHint`（`t.meta` / `t.mono`，fg2 / fg4）。工具名用该键自己的 `_Tool.label`。
- 注册表追加一行：`ToolLockKeys.toggle → CanvasToggleToolLockIntent`，Action 用 esc-ladder 公开的对文字让位包装，invoke = `toggleToolLockByKey`；文案键 `settingsShortcutCanvasToolLock`。
- Esc 阶梯「工具锁」层：active = `locked != null`，dismiss = `unlock()`。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 双击（两次点击间隔 ≤ kDoubleTapTimeout 300ms、同一个键）锁定该工具；第一下照常在视口中心建了一张，第二下只锁不建。
2. Q：未锁 ⇒ 锁 lastTapped（本画布最近一次在工具条上点过的建节点键），没有就锁图像配置；已锁 ⇒ 解锁。includeRepeats: false；焦点在文本框里时 Q 让位（打字照常）。
3. 锁定时工具态被设为「选择」并退出连线模式；被锁的键亮起 + 图钉角标；工具条下出现锁定条。
4. 锁定中在空白处点一下（按下到抬起挪不到 4px）= 在该点放一张被锁类型的卡（卡心在指针下），新卡被单选、相机不动；不清空选中、不开双击新建菜单。
5. 落点判泳道与新建菜单同一套（`menuNodePlacement`）：点在泳道带里 ⇒ 卡进该道。
6. 写库失败：弹「添加节点失败」错误卡（addNodeFromMenu 自带），锁不变，可以继续点。
7. 锁定中拖空白：照旧框选（marquee）；Alt + 拖照旧切线；右键 / 中键拖照旧平移；右键单击照旧开空白处菜单。
8. 解锁：V、H、L（进连线）、工具条「选择 / 平移」、Q、Esc（阶梯「工具锁」层，前面的菜单 / @ / 查找 / 框选中都没有时）、点工具条上另一个建节点键（解锁并照常建一张）、点被锁的键本身（只解锁）。
9. Esc 次序：菜单开着先关菜单；框选 / 切线进行中先取消它；然后才解锁；再按一次才清空选中。
10. 按住空格临时平移：锁不变，松开空格后仍在点放模式；平移期间点击不放卡（指针被 `_PanGate` 挡掉）。
11. 锁定中按 I / G / T：照常在视口中心建一张，锁不变（设计缺口）。
12. 关掉画布（provider autoDispose）即解锁；换画布各自独立。
13. 进撤销栈的只是每次建卡（与新建菜单建卡同一条路，由 undo-node-create-move 已接入），锁定 / 解锁本身不进栈。
14. 便签：note-variant 已合入时「便签」键同样可锁；连线 L、泳道 F 不可锁（双击 F 不锁，照常开两次对话框的行为不变——第二下被对话框挡住）。
15. mac / Windows 无差异（Q 单键两平台同键；双击窗口取 kDoubleTapTimeout）。

## 新文案键（key · en · zh 表；没有写「无」）
| key | en | zh |
|---|---|---|
| canvasToolLockedChip | {tool} · Locked | {tool} · 已锁定 |
| canvasToolLockUnlockHint | Q to unlock | Q 解锁 |
| canvasToolLockGhostHint | Click to place | 点一下放一个 |
| canvasToolLockDoubleClickHint | Double-click to lock | 双击锁定 |
| settingsShortcutCanvasToolLock | Lock / unlock the creation tool | 工具锁 |
| settingsGestureToolLock | Double-click a tool button: lock the tool | 双击工具按钮：工具锁 |
（另：shortcuts-page-v2 的 Esc 阶梯说明键 `settingsEscLayerToolDesc` 改为「工具锁 · 平移 · 连线」/「Tool lock · pan · link」，由主 Agent 改 ARB 值。）
（`canvasToolLockedChip` 的 tool 是 String 占位符；`canvasToolLockDoubleClickHint` 拼在建节点键 tooltip 末尾，如「图像节点  I · 双击锁定」。）

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/canvas/providers/canvas_tool_mode_test.dart`（追加 group「工具锁」，ProviderContainer + 覆写 clockProvider 为可拨的假时钟，见 test/_harness/fake_clock.dart）
  - 「同键 300ms 内点两下 → 锁定、第二下返回 true」；「间隔 301ms 不锁」；「两下不同键不锁」。
  - 「select() / pan() / togglePan() 都解锁」。
  - 「lock() 后工具态是 select、连线模式退出、locked 仍在」（防止 lock 被自己的 select 解掉）。
  - 「进连线模式（linkModeController.start）自动解锁」。
- `test/features/canvas/widgets/canvas_tool_lock_test.dart`（pumpInkApp + CanvasShortcuts + CanvasView + CanvasToolbar 放在一个 Stack 里，fake_canvas 的 RecordingNodesController）
  - 「Q 锁图像配置（没点过任何键）」：锁定条出现、文字含图像节点名。
  - 「锁定中点空白放一张，卡心在指针下」：RecordingNodesController 记录 addNode 的 position，换算回视口 = 点击点 − 半卡 × 缩放。
  - 「锁定中点两次放两张，不开新建菜单」：canvasMenuRequestProvider 仍为 null，addNode 两次。
  - 「锁定中拖空白 6px 仍是框选、不放卡」。
  - 「Esc 先取消框选，再解锁，再清空选中」：三次 Esc 依次断言。
  - 「V 解锁」「H 解锁」「再按 Q 解锁」。
  - 「焦点在 TextField 时按 Q 不锁」。
  - 「按住 Q 只切一次」：keyDown + repeat 事件。
  - 「写库失败出错误卡、锁仍在」：节点控制器 addNode 抛 InkError。
- `test/features/canvas/widgets/canvas_toolbar_test.dart`
  - 「双击图像键 → 只建一张卡并锁定、键上有图钉角标」（find.byKey 角标 Key）。
  - 「锁定中点视频键 → 解锁并建一张视频配置」。
  - 「锁定中点被锁的键 → 只解锁」。

- `test/features/settings/pointer_gesture_catalog_test.dart`：「含『双击工具按钮 = 工具锁』一行、范围 canvas」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写，并写「由测试 <用例名> 抓住」）
1. `tapCreateTool` 的间隔判定 `≤ kDoubleTapTimeout` 改成不限时 → 由「间隔 301ms 不锁」抓住。
2. `select()` 里去掉 unlock → 由「select() / pan() / togglePan() 都解锁」与「V 解锁」抓住。
3. `lock()` 里先写 locked 再调 select() → 由「lock() 后工具态是 select…locked 仍在」抓住。
4. 指针层锁定分支去掉（点空白回到清空选中）→ 由「锁定中点空白放一张…」抓住。
5. 放卡时不减半卡（左上角 = 点击点）→ 由「锁定中点空白放一张，卡心在指针下」抓住。
6. 锁定时不跳过双击计数 → 由「锁定中点两次放两张，不开新建菜单」抓住。
7. Esc 登记层序放到框选之前 → 由「Esc 先取消框选，再解锁，再清空选中」抓住。
8. Q 的 activator 去掉 includeRepeats: false → 由「按住 Q 只切一次」抓住。
9. 双击第二下仍建卡 → 由「双击图像键 → 只建一张卡并锁定…」抓住。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 跑 `flutter analyze lib test`、`flutter test test/features/canvas test/features/settings --exclude-tags golden`，逐条变异。
- 截图（test/_harness/screenshot.dart，中文界面）：`CanvasScreen(isVisible: true)`，数据 = 一条横向泳道 + 2 张卡。截三张：① 未锁定的工具条；② 双击图像键后：键亮 + 图钉角标 + 下方「图像节点 · 已锁定  Q 解锁」，指针悬停空白处有虚线占位框；③ 连点三下后三张新卡、最后一张被选中。

## 风险与不确定
- Q 没锁时锁哪个工具、锁定中 I / G / T 算不算换工具，画板都没写；本片按「设计缺口」里的取法，主 Agent 可改。若要 I / G / T 也解锁，需要改核心快捷键文件（W19 不归本片），或由 esc-ladder 的注册表提供「任一建节点键被按」的钩子。
- 锁定条挂在工具条下方左对齐，与查找条（工具条下方居中、stageTopInset 64）可能在窄窗口下相撞；锁定条高 20、从 58 起，与查找条上沿有 6px 重叠的可能，执行代理要在截图里核对，必要时把锁定条改成画在工具条右侧。
- `createdNodeType` 对便签的处理取决于 note-variant 的实现；若便签不走 CreateMenuAction，`isLockableCreateAction` 要按 main 上的便签入口另判。
- 撤销：建卡进栈由 undo-node-create-move 在 `addNodeFromMenu` 里接好，本片只走这条路；若 main 上进栈点不在 addNodeFromMenu，而在调用方，执行代理要照新建菜单那条路同样进栈。
