# f6-notification-region · F6 跳到通知区
- 波次 W11 / lane E / 基底：origin/main（W0–W10 已合入）；依赖切片：system-notifications（W10，同改 toast_center.dart，串行）、esc-ladder（W0，`ShortcutRow` / `ShortcutGroup.app` / `buildShortcutRows` 的新形状）、app-action-table（W1，`PlannedKeys.focusNotifications` 与 `comingSoon(AppActionIds.focusNotifications …)` 占位行、文案 `appActionFocusNotifications`）；阻塞决定：无

## 目标（用户看到什么变化，2–4 行）
- 任何地方按 F6（包括正在输入框里打字时），焦点跳到右下角最新那张通知卡，所有卡停止倒计时；读屏念「通知，2 条」。
- ↑↓ 在卡之间换，↵ 按主按钮，Tab 在卡内按钮间走，Del 关掉这张；「还有 N 条」也能停上去，↵ 打开铃铛历史。
- 没有卡时 F6 直接打开铃铛历史并聚焦第一条。
- Esc 或再按一次 F6：焦点回到按 F6 之前的位置，卡接着倒计时。设置 › 快捷键里多一行 F6。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ShellExport.dc.html` ·「F6 跳到通知区」：键盘也能处理通知，不抢焦点；键位条 ↑↓ 切换 · ↵ 主按钮 · Tab 卡内按钮 · Del 关掉 · Esc 离开。
  - 应用级快捷键，与 Ctrl K 同层；输入框里也有效。
  - 进来聚焦最新一张，全部停表（同悬停）；离开后接着走。
  - 「还有 N 条」也是一站，↵ 打开铃铛；没有卡时 F6 直接开铃铛、聚焦第一条。
  - Esc 或再按 F6：焦点回到进来前的位置。
  - 读屏：进来播报「通知，2 条」，每张读「类型 · 标题 · 正文」。
- `b2/project/KeyMap.dc.html` · 单键表「F6 · 同左 · 跳到通知区 · 应用 · 第二批」；文字让位「另有去处：Ctrl K、Ctrl F、F6、单独 Alt」；弹层内部「F6 通知区：↑↓ 切卡 · Enter 主按钮 · Tab 卡内按钮 · Del 关卡 · Esc 回原处」；Esc 阶梯下注「F6 区里 Esc 回到进来前的位置」。
- `b2/project/ShellExport.dc.html` · 菜单栏「窗口 › 通知 · 新 · F6」。
- critic.txt 第 24 条（Esc 归属）与「弹层内部」段：F6 区内 ↑↓ ↵ Esc 与画布作用域隔开、Tab = 卡内按钮。
- 代码核对：卡片层在 `lib/features/notifications/widgets/toast_layer.dart`（MaterialApp.builder 那层，Navigator 之上、没有 Overlay）；ToastCenter 停表判据 `_paused`（toast_center.dart:183）；铃铛历史面板走 Navigator Overlay，Esc 由面板自己的 CallbackShortcuts 关（notification_bell.dart:219–223），历史行 `_HistoryRow` 目前不可聚焦。
- 设计缺口：铃铛承接不了历史（上面压着对话框、启动失败页没有铃铛，`historyHostReady == false`）时，没有卡按 F6 该怎样画板没画。本片定：不开面板，只播报「没有通知」。
- 设计缺口：↵ 执行主按钮之后焦点去哪没画。本片定：主按钮做完收卡并退出通知区；主按钮自己挪了焦点（如「查看」切到画布）就不抢回，否则回到进来前的位置。
- 设计缺口：历史面板里的行按 ↵ 做什么没画（行现在不能点）。本片只让行可聚焦、↑↓ 移动、读屏念内容，↵ 不做事。
- 设计缺口：通知区开着时又来新卡，焦点要不要跟过去没画。本片定：焦点留在原卡，新卡照常出现、也停表。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- 新 `lib/features/notifications/widgets/notification_region.dart`：F6 激活器常量、站点纯函数、`notificationRegionProvider`（进出 / 当前站）、`NotificationRegion` 包装件（应用级 F6 绑定、记住进来前的焦点、播报、离开时还焦点）。
- `lib/features/notifications/widgets/toast_layer.dart`：`build` 里把 Stack 包进 `NotificationRegion`；`_ToastSlot` / `_MorePill` 各包一层站点 Focus（每张卡一个 FocusScope，Tab 在卡内闭环），按键 ↑↓ ↵ Del Esc F6 在站点上处理；把「是否当前站」与读屏类型名传给卡片。
- `lib/theme/components/ink_toast_card.dart`：加两个可选参数——`bool regionFocused = false`（画整卡焦点环，用 `inkFocusRing`，`ink_activatable.dart` 的唯一出处）、`String? semanticsKindLabel`（读屏「类型 · 标题 · 正文」的类型名，theme 层不认识 ARB，由调用方传）。不 import core / features。
- `lib/features/notifications/providers/toast_center.dart`：加 `pauseAll()` / `resumeAll()`（并进 `_paused`）；`openHistory` 加可选 `{bool focusFirst = false}`，状态加 `historyFocusToken`（每次 focusFirst 打开 +1，铃铛据此聚焦第一行）。
- `lib/features/notifications/widgets/notification_bell.dart`：暴露 `static void openAndFocusFirst(ToastCenter center)`；监听 `historyFocusToken` 把焦点给第一行；`_HistoryRow` 改成可聚焦（Focus + 焦点环 + 语义「类型 · 标题 · 正文 · 时间」），面板 ↑↓ 在行间移动；空态时焦点给面板本身。
- `lib/features/settings/util/shortcut_catalog.dart`（W11 唯一）：W0 esc-ladder 已删掉 `ShortcutAction` 枚举与 `shortcutActionOf`，行改成 `ShortcutRow { String id; ShortcutGroup group; String Function(AppLocalizations) label; List<String> keys }`，`buildShortcutRows` 先出 group app 的 `commandPalette`、`overlayDismiss` 两行再按画布注册表合并。本片照那两行的写法在 `overlayDismiss` 之后加一行 app 组的 `ShortcutRow(id: 'notificationRegion', group: ShortcutGroup.app, label: (l) => l.settingsShortcutNotificationRegion, keys: [formatShortcutActivator(kNotificationRegionActivator, isMac: isMac)])`；`_keyLabels` 加 F6 → 'F6'。F6 不进 `kCanvasKeyRegistry`（它挂在 Navigator 之外的应用级 Shortcuts 上，不是画布键）。
- （不改 `lib/features/settings/widgets/shortcuts_section.dart`：esc-ladder 已把它的穷举 switch 换成 `row.label(l)`，主 Agent 那条有条件准许的前提不成立。）
- 注册表一行（允许的例外）：`lib/features/app_actions/app_action_catalog.dart` 里 app-action-table 登记的占位行 `comingSoon(AppActionIds.focusNotifications, AppActionGroup.window, …)`（label `appActionFocusNotifications`、键 `PlannedKeys.focusNotifications`）——把这一行换成真实一行：isEnabled 恒真、run 调 `notificationRegionProvider.notifier.enter()`、键位 `PlannedKeys.focusNotifications`。不是 W4 win-menubar 登记的，也不另追加一行。
- 测试（新建 / 随文件改）：新 `test/features/notifications/widgets/notification_region_test.dart`、新 `test/features/notifications/providers/toast_center_pause_all_test.dart`；`test/features/settings/shortcut_catalog_test.dart`（期望行表加 F6 一行）。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- batch-run-dialog：`widgets/left_rail/outline_panel.dart`、`widgets/canvas_toolbar.dart`、Ctrl ↵ 所在核心键文件、`lib/core/models/app_preferences.dart`、`lib/services/file_preferences_service.dart`。
- node-menu-append-chain / result-inspector-align：`widgets/canvas_inspector_panel.dart`、`widgets/result_inspector_parts.dart`、`widgets/video_result_inspector.dart`、`widgets/image_result_inspector.dart`、`lib/theme/icons/ink_glyph.dart`。
- script-import：`lib/features/storyboard/providers/script_import_controller.dart`、`util/script_splitter.dart`、`widgets/script_import_dialog.dart`。
- mention-token-core：`lib/features/generation/generation_controller.dart`、`lib/services/import/import_remapper.dart`、`util/clipboard_snapshot.dart`、prompt_assembler。
- 全波不归任何人：`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_shortcuts.dart` 骨架、注册表（除追加一行）。
- 本片额外不碰：`lib/features/notifications/widgets/job_notification_listener.dart`、`lib/core/interfaces/toast_service.dart`、`lib/features/notifications/models/toast_entry.dart`、`lib/features/settings/widgets/notifications_section.dart`（W12 toast-category-mute）、`lib/features/command_palette/**`（⌘K 绑定不动）、`lib/app.dart`（builder 接线不动，挂在 ToastLayer 内部）。
- 同波另有（交叉核对补）：batch-run-dialog 的 `shortcuts/core_canvas_keys.dart`、`util/more_menu_model.dart`、`app_action_ids.dart`（追加常量）与 `app_action_catalog.dart` 里它自己那一行、新 `widgets/batch_run_dialog.dart` / `util/canvas_batch_run_actions.dart`；node-menu-append-chain 的 `canvas_menu/menu_registry.dart`（追加行）、新 `util/append_to_chain.dart` / `util/canvas_append_chain_actions.dart` / `canvas_menu/append_chain_menu_entries.dart` / `models/commands/append_chain_command.dart`；result-inspector-align 的 `lib/theme/tokens.dart`；script-import 的新 `lib/features/storyboard/util/duration_estimate.dart`；mention-token-core 的新 `lib/core/text/character_mention.dart`；`lib/features/settings/widgets/shortcuts_section.dart`（本片也不碰，见上）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：mention-token-core：`lib/features/generation/services/prompt_assembler.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// lib/features/notifications/widgets/notification_region.dart
const SingleActivator kNotificationRegionActivator = PlannedKeys.focusNotifications; // app-action-table：第二批键位的唯一出处（F6、includeRepeats: false），不另写一份

sealed class RegionStation { const RegionStation(); }
final class CardStation extends RegionStation { const CardStation(this.id); final int id; }
final class MoreStation extends RegionStation { const MoreStation(); }

/// 站点，自上而下：「还有 N 条」（overflowCount > 0 且 historyHostReady 才算一站）+ 可见卡旧 → 新（不含淡出中的）。
List<RegionStation> regionStations(ToastCenterState s);
/// delta = -1（↑）/ +1（↓），到头不绕回；current 不在表里 ⇒ 最新一张。
RegionStation? stepStation(List<RegionStation> stations, RegionStation? current, int delta);
/// 当前站被移除后的落点：同位置的下一张（更新的）→ 上一张 → null（退出）。
RegionStation? stationAfterRemoval(List<RegionStation> before, List<RegionStation> after, RegionStation removed);

@immutable
class NotificationRegionState {
  const NotificationRegionState({this.active = false, this.current});
  final bool active;
  final RegionStation? current;
}
class NotificationRegionController extends Notifier<NotificationRegionState> {
  void enter();                       // 有站 ⇒ active + 最新卡 + pauseAll；无站 ⇒ 交给铃铛或播报「没有通知」
  void step(int delta);
  void exit({required bool restoreFocus}); // resumeAll；restoreFocus 由包装件执行
}
final notificationRegionProvider = NotifierProvider<NotificationRegionController, NotificationRegionState>(..., name: 'notificationRegionProvider');

class NotificationRegion extends ConsumerStatefulWidget {
  const NotificationRegion({super.key, required this.child});
  final Widget child;
  static const Key regionKey = Key('notifications.region');
  static Key stationKey(RegionStation s);
}

// toast_center.dart
void pauseAll();   // 幂等
void resumeAll();  // 幂等
void openHistory({bool focusFirst = false});
// ToastCenterState 加：final int historyFocusToken;

// notification_bell.dart
static void openAndFocusFirst(ToastCenter center); // = center.openHistory(focusFirst: true)
static Key rowKey(int entryId);

// ink_toast_card.dart：InkToastCard 加 {bool regionFocused = false, String? semanticsKindLabel}
```
- F6 绑定挂在 `NotificationRegion` 自己的 `Shortcuts` / `Actions` 上（它是 Navigator 的祖先：路由里——含对话框、输入框——没处理的 F6 冒泡到这里）。文本框不认 F6，所以输入框里也生效。
- 进来时记 `FocusManager.instance.primaryFocus`；离开时若它还挂着且可聚焦就 `requestFocus()` 还回去，否则不动。
- 站点上的按键用 `Focus.onKeyEvent` 处理并返回 handled：↑ / ↓ 换站；↵ / 小键盘 ↵ = 当前卡主按钮（走 `_ToastSlot._act` 同一条路：先做事再收卡）或「还有 N 条」打开铃铛（`openAndFocusFirst`）；Del / Backspace = 关当前卡；Esc / F6 = 离开。Tab / Shift+Tab 不拦，靠每卡一个 FocusScope 在卡内闭环。
- 播报：进来时 `SemanticsService.sendAnnouncement(View.of(context), l.notificationRegionAnnounce(n), …)`，n = 未淡出的在场卡数（含折叠的）；`MediaQuery.supportsAnnounceOf` 为 false 时不播，靠区域 Semantics label + 卡的语义标签。
- 读屏类型名：toast_layer 里 `ToastKind → l.toastKind*` 映射后传 `semanticsKindLabel`；卡片语义 label 拼成「类型 · 标题 · 正文」。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. F6 在任何位置生效：画布持焦、提示词输入框里、设置浮层里、对话框里；按住不连发（includeRepeats: false）。
2. 有卡：焦点落在最新一张（最靠角的那张），该卡画焦点环；ToastCenter 全部停表（与悬停同一个判据）。
3. ↑ 往旧的走、↓ 往新的走，到头停住不绕回；「还有 N 条」在最上面，只在铃铛承接得了时算一站。
4. ↵：卡有主按钮 ⇒ 执行并收卡，然后退出通知区（主按钮挪走了焦点就不抢回）；没有主按钮 ⇒ 不做事。「还有 N 条」上 ↵ ⇒ 打开铃铛并聚焦第一行，通知区退出、卡片栈照现有规则让位。
5. Tab / Shift+Tab：在当前卡的次按钮 / 主按钮 / × 之间循环，不跳出这张卡；↑↓ 从卡内按钮上按也换站。
6. Del：关当前卡（走 `ToastCenter.dismiss`），焦点落到 `stationAfterRemoval`；一张不剩 ⇒ 退出并还焦点。
7. 当前卡被别处收掉（句柄 dismiss、进度卡 complete 是原地换不算）⇒ 同第 6 条落点。
8. Esc / 再按 F6：退出，resumeAll，焦点回到进来前；进来前的节点已卸载（例如画布标签被切走）⇒ 不报错、焦点不强塞。
9. 鼠标点了通知区以外：区域失焦 ⇒ 退出并 resumeAll，不还焦点（点到哪就是哪）。
10. 停表与悬停 / 窗口失焦 / 历史开着叠加：任一仍成立就继续停；resumeAll 只撤销自己这一项。
11. 通知区里来了新卡：焦点不跟，新卡出现且也不倒计时；站点表随之更新。
12. 没有卡：铃铛承接得了 ⇒ 打开历史、焦点到第一行（历史为空 ⇒ 焦点到面板，读「还没有通知」）；承接不了 ⇒ 不开，播报「没有通知」。从这里 Esc / F6 关面板并还焦点。
13. 历史面板里 ↑↓ 在行间移动；↵ 不做事（行本来就不能点）。
14. 通知区里的单键（V、I、Del…）不会漏到画布：区域在 Navigator 之外，画布快捷键不是它的祖先。代价：区域持焦时 ⌘K 不生效，先 Esc 再按。
15. 系统通知（W10）的点击执行主按钮与通知区互不影响；通知区持焦时窗口失焦 ⇒ 区域保持，回来接着在原卡上。
16. 不进撤销栈。
17. mac / Windows：键位都写「F6」（快捷键页两平台同字）。Windows 原生 F10 = 菜单栏、F6 = 窗格轮换，W4 win-menubar 只用单独 Alt，无冲突；macOS 默认 F 键是媒体键，F6 要按 Fn+F6（系统设置可改），⌃F6 是系统「浮动窗口」快捷键——本片只绑无修饰的 F6，不冲突。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| notificationRegionAnnounce（占位 count） | Notifications, {count} | 通知，{count} 条 |
| notificationRegionEmpty | No notifications | 没有通知 |
| settingsShortcutNotificationRegion | Jump to notifications | 跳到通知区 |
| toastKindInfo | Info | 提示 |
| toastKindSuccess | Done | 完成 |
| toastKindWarning | Warning | 警告 |
| toastKindError | Failed | 失败 |
| toastKindProgress | In progress | 进行中 |
| toastKindUndo | Undo | 撤销 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/notifications/providers/toast_center_pause_all_test.dart`（fake_async）
  - 「pauseAll 停表」：一张 4 秒卡，pauseAll 后推 10 秒仍在；resumeAll 后再推 4 秒离场。
  - 「与悬停叠加」：setHovered(true) + pauseAll，resumeAll 后仍停（悬停还在）。
  - 「openHistory(focusFirst) 递增 token；普通 openHistory 不递增」。
- `test/features/notifications/widgets/notification_region_test.dart`（MaterialApp.builder = ToastLayer，home 里放一个 TextField + 一个 NotificationBell；ToastCenter 真实例）
  - 「输入框里 F6 进区域，聚焦最新卡」：TextField 持焦，show 三张，F6 ⇒ primaryFocus 在最新卡站点内、该卡 `regionFocused == true`。
  - 「进区域全部停表」：推 10 秒三张都在；Esc 后推 4 秒信息卡离场。
  - 「Esc 还焦点」「再按 F6 还焦点」：TextField 重新持焦。
  - 「↑↓ 换卡、到头不绕回」。
  - 「↵ 执行主按钮并收卡并退出」：主按钮计数 +1，卡 leaving，`notificationRegionProvider.active == false`。
  - 「Tab 在卡内闭环」：三次 Tab 回到起点按钮，焦点从未离开该卡。
  - 「Del 关卡并落到下一站」：中间卡 Del ⇒ 焦点到更新的那张；最后一张 Del ⇒ 退出并还焦点。
  - 「还有 N 条是一站，↵ 打开铃铛并聚焦第一行」：show 5 张，↑ 走到顶 ⇒ MoreStation；↵ ⇒ historyOpen、primaryFocus 在 `NotificationBell.rowKey(最新条目)` 上。
  - 「historyHostReady 为 false 时 MoreStation 不是一站」。
  - 「没有卡：F6 开铃铛聚焦第一行」；「没有卡且承接不了：不开、播报没有通知」（mock SystemChannels.accessibility，照 ink_toast_card_test 第 261 行写法）。
  - 「进来播报 通知，3 条」（supportsAnnounce: true）。
  - 「单键不漏到外面」：home 里放一个 CallbackShortcuts(V) 计数器，区域持焦按 V ⇒ 计数 0。
  - 「点区域外退出并恢复计时」。
- `test/features/settings/shortcut_catalog_test.dart`：期望行表在 overlayDismiss 后多一行 notificationRegion → ['F6']（mac / 非 mac 都是）。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. F6 绑定挪到 Navigator 里面（例如只包住 InkShell）⇒「输入框里 F6 进区域」在对话框场景红（加一条 showDialog 后按 F6 的子用例）。
2. `_paused` 不并入 pauseAll 标志 ⇒「pauseAll 停表」「进区域全部停表」红。
3. resumeAll 直接把 `_hovered` 也清掉 ⇒「与悬停叠加」红。
4. 离开时不 requestFocus 进来前的节点 ⇒「Esc 还焦点」红。
5. `stepStation` 改成绕回 ⇒「到头不绕回」红。
6. ↵ 不走 `_act`（只执行不收卡）⇒「↵ 执行主按钮并收卡并退出」红。
7. 去掉每卡 FocusScope ⇒「Tab 在卡内闭环」红。
8. `stationAfterRemoval` 先取旧的再取新的 ⇒「Del 关卡并落到下一站」红。
9. `regionStations` 不判 historyHostReady ⇒「historyHostReady 为 false 时 MoreStation 不是一站」红。
10. 铃铛不监听 historyFocusToken ⇒「没有卡：F6 开铃铛聚焦第一行」红。
11. 不发播报 ⇒「进来播报 通知，3 条」红。
12. 把站点 Focus 挂到 home 那棵子树里（CallbackShortcuts(V) 成了它的祖先）⇒「单键不漏到外面」红；站点 onKeyEvent 对 ↑ 返回 ignored ⇒「↑↓ 换卡」红。
13. shortcut_catalog 不 add F6 ⇒ 快捷键清单测试红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- `flutter analyze lib test`；`flutter test test/features/notifications test/features/settings test/theme/components --exclude-tags golden`；`test/quality/no_reverse_layer_import_test.dart` 不改仍绿（ink_toast_card 不 import core / features）。
- 截图（ToastLayer + 三张卡：失败「镜头 04 生成失败 / 可灵 · 余额不足 / 重试」、成功「镜头 01 已生成 / Gemini · 图像 · 用时 18 秒 / 查看」、一张信息卡；另一组 5 张带「还有 2 条」）：
  1. F6 刚进来，最新卡带焦点环；2. ↑ 到失败卡，Tab 到「重试」；3. 停在「还有 2 条」；4. 没有卡时 F6 打开的铃铛面板第一行带焦点环。深浅主题各一套。

## 风险与不确定
- `shortcuts_section.dart`：按 esc-ladder 派工单，W0 之后它只调 `row.label(l)`，本片不用改；若落地后穷举 switch 仍在，才按主 Agent 的有条件准许补一个分支。
- `test/features/settings/shortcut_catalog_test.dart` 属于本片拥有文件的测试，随改；若它与 W0 注册表改造后的测试同名不同形，以落地为准。
- `app_action_catalog` 里「窗口 › 通知」是否已由 W4 登记、动作 id 叫什么，以落地为准；本片只动那一行。
- 区域持焦时 ⌘K / Ctrl F 不生效（它们挂在 Navigator 里）；画板写「与 Ctrl K 同层」，若主 Agent 要求通知区里也能直接 ⌘K，需要把 palette 绑定上移到 builder 层，那是 command_palette 的改动，不在本片。
- 每卡一个 FocusScope 后，鼠标用户点卡内按钮也会进这个 scope；离开判据（第 9 条）只看区域是否 active，指针点击不会误进通知区状态。
- macOS 上 `MediaQuery.supportsAnnounce` 的取值依 Flutter 版本，播报用例只在 supportsAnnounce: true 下断言。
