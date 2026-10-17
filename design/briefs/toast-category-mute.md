# toast-category-mute · 通知按类型开关（生成完成 / 导出完成 / 失败 / 撤销 / 一般）
- 波次：W12 / lane：B / 基底：origin/main（W0–W11 已合入）
- 依赖切片：system-notifications（W10：`ToastService.show` 已有可选 `Duration? elapsed`；系统通知在 `ToastCenter.show` 里按三条件 + 2 秒合并窗发出；`notifications_section.dart` 停留时长下已有「系统通知」一行；`AppPreferences.systemNotificationsEnabled`）、f6-notification-region（W11：`toast_center.dart` 已加 `pauseAll / resumeAll`、`openHistory({focusFirst})`，`notification_bell.dart` 已改可聚焦行）；软相关 undo-stack / undo-shortcuts-ui（W0/W2，可能新增了撤销卡调用点）
- 阻塞决定：N1 → A（关掉的类别铃铛照记、不加未读）；N3 → A（「失败」只管后台任务，当场操作出错总提示）

## 执行约定
1. 在你自己的工作树里，从 origin/main（前序波已合入）起新分支 `feat/toast-category-mute`。
2. 只改「允许改的文件」；需要改别的文件时停下来在回报里说明，不要自行扩大范围。
3. 不跑构建和测试（flutter / dart 都不跑）；由主 Agent 统一跑。
4. 不改 ARB、lib/l10n/generated、docs/CLAUDE.md；新文案键在回报里按「新文案键」表列出，由主 Agent 统一加。代码里直接写 `context.l10n.<key>`。
5. 注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行——本片不碰任何注册表。
6. CanvasNode 新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法——本片不涉及。
7. 先写测试并确认（逻辑上）它在没有实现时会失败，再写实现；回报里列出每条测试与对应变异点。
8. 样式只用 tokens（tokens.dart 只追加），无硬编码字符串 / 颜色 / 尺寸。
9. 本片补充：「位置」（toastCorner / N2）不在本片，是 W16 toast-corner 的事；本片不碰 toast_layer.dart。偏好存字符串、读出时换枚举，与 toastDwell 同一做法，不动库。

## 目标
设置 › 常规 › 通知 在「提示音 / 停留时长」下面多出「显示哪些通知」五个开关：生成完成、导出完成、失败、撤销、一般提示。
关掉某一类后，这一类的通知不出卡、不响提示音、不发系统通知；铃铛历史里照记一行但不加未读、不点红。带「取消」的进度卡不受开关管。

## 设计依据
- 画板 `b2/project/GapsPanels.dc.html` 小节「通知：按类型开关 · 位置」（生成脚本 b2_gaps_panels.js 第 60–96 行）：
  - 五行：「生成完成 · 缩略图 + 查看」「导出完成 · 打开文件夹」「失败 · 只管后台任务」「撤销 · 关了 Ctrl Z 照样能撤」「一般提示 · 已复制 · 已保存」；每行 = 标签（fg2）+ 说明（10px fg6，单行省略）+ 右侧开关；画板默认前四开、一般关——**默认值以代码为准：全部开**（见风险 1）。
  - 规则原文：「新增 ToastCategory，调用处标，不从 ToastKind 推（同是 success，「已生成」与「已复制」要分开管）」；「任务监听标生成完成 / 失败；导出、交付标导出完成 / 失败；undo 卡归撤销；其余一般」；「关掉 = 不出卡、不响、不发系统通知（铃铛见 N1）；进度卡带「取消」，不受开关管」；「存 preferences.json：toastMuted + toastCorner，同 toastDwell 的字符串 → 枚举，不动库」。
  - 「位置」五选一与「上角」规则属于 toast-corner（W16），本片不做。
- N1 建议 A「照记，不加未读」；N3 建议 A「只管后台任务（生成 / 导出 / 下载），当场操作出错总提示」。
- 设计缺口：铃铛历史里被静音的行要不要有视觉区分——画板没画，本片不加区分（只是不算未读）。

## 允许改的文件
- `lib/core/interfaces/toast_service.dart`：新增 `enum ToastCategory`；`ToastService.show` 加命名参数 `ToastCategory category = ToastCategory.general`。`ToastHandle.complete` 不加参数（类别在 show 时定）。
- `lib/features/notifications/models/toast_entry.dart`：加字段 `final ToastCategory category`（默认 general），`updated / completed / asLeaving` 原样带过去。
- `lib/features/notifications/models/notification_prefs.dart`：新增 `Set<ToastCategory> toastMutedFromPref(List<String> value)`（非法名丢弃）与 `List<String> toastMutedToPref(Set<ToastCategory>)`（按枚举声明序输出，保证落盘稳定）。
- `lib/features/notifications/providers/toast_center.dart`：show / _complete 按类别静音（见具体改动）；`_recorded` 增加「不标未读」的分支。
- `lib/features/notifications/widgets/job_notification_listener.dart`：约第 95 行成功卡标 `generationDone`，约第 128 行失败卡标 `failure`。
- `lib/features/notifications/widgets/notification_bell.dart`：只核对，不预期改动（未读 / 红点都由 ToastCenterState 算）；若核对后需改，限于本文件。
- `lib/features/export/widgets/export_video_dialog.dart`：约第 416 行导出成功卡标 `exportDone`；约第 425 行「已复制路径」保持 general。导出失败现在是对话框内 InkErrorBanner（约第 431 行注释「债144①」），不是通知卡，不改。
- `lib/features/canvas/util/canvas_snackbars.dart`：`showCanvasUndoSnack`（约第 29 行）标 `ToastCategory.undo`；`showCanvasSnack` 不变（general）。
- `lib/features/settings/providers/notification_prefs_controller.dart`（已存在，约第 28 行 NotificationPrefsController）：**不改原 record**，同文件新增 `ToastMuteController extends Notifier<Set<ToastCategory>>` + `toastMuteControllerProvider`（避免改动 `NotificationPrefs` record 牵连 notification_prefs_controller_test 第 81 / 100 / 222 行）。
- `lib/features/settings/widgets/notifications_section.dart`：停留时长那组与 W10 加的「系统通知」一行之后，加「显示哪些通知」五行；开关用 Material `Switch`（与 startup_section.dart 约第 43 行、W10 系统通知行同款）。
- `lib/core/models/app_preferences.dart`：加字段 `final List<String> toastMuted`（默认空 = 全部显示），JSON 键 `toast_muted`；toMap / fromMap（非 List / 元素非 String 退空；未知名保留在字符串层、读枚举时丢）/ copyWith / == / hashCode 全部补齐。
- `lib/services/file_preferences_service.dart`：只经 `AppPreferences.toMap/fromMap` 序列化（约第 74 行），不预期改动；仅核对。
- `test/_harness/fake_toast_service.dart`：`RecordingToastService.show` 跟着加 `category` 参数并记进 `RecordedToast.category`（唯一的另一个实现，`grep -rln "implements ToastService"` 只有它和 ToastCenter）。
- 测试：`test/features/notifications/providers/toast_center_test.dart`、`test/features/notifications/widgets/job_notification_listener_test.dart`、`test/features/settings/notifications_section_test.dart`、`test/features/settings/notification_prefs_controller_test.dart`（只追加用例）、`test/core/models/app_preferences_test.dart`、`test/features/canvas/util/canvas_snackbars_test.dart`（已存在，追加用例）。

## 不许碰的文件
- W12 其他片：`lib/features/canvas/util/node_menu_model.dart`、`canvas_menu/*`（cm-multi-select-menu）；`providers/left_rail_state.dart`、`widgets/left_rail/*`、`widgets/shot_config_inspector.dart`（rail-script-panel）；`widgets/canvas_prompt_bar.dart`、`providers/inspector_submit_controller.dart`、`widgets/characters_section.dart`、`widgets/character_library_panel.dart`、`util/mention_candidates.dart`、`widgets/mention_*.dart`（prompt-bar-mention-ui）；`lib/features/gallery/**`（locate-in-gallery）。
- 同 lane 后序：`lib/features/notifications/widgets/toast_layer.dart`（W16 toast-corner）；`AppPreferences.toastCorner` 不要预先加。
- `lib/features/canvas/widgets/create_node_menu.dart`（barrel）、`lib/features/canvas/models/canvas_node.dart`、ARB / generated / docs/CLAUDE.md。
- 其余约 25 处 `toast.show(...)` 调用点（settings 各 section、gallery_actions、canvas_tool_actions 等）一律不改，靠默认 general。

**同波（W12）其他切片占用的文件（主 Agent 汇总，一律不碰；注册表 / ARB / tokens 追加行除外）：**
- cm-multi-select-menu：`lib/features/canvas/util/node_menu_model.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_host.dart`、`lib/features/canvas/widgets/canvas_menu/canvas_menu_request.dart`、`lib/features/canvas/widgets/canvas_menu/multi_menu_entries.dart`、`lib/features/canvas/widgets/canvas_menu/node_menu_entries.dart`、`test/features/canvas/util/node_menu_model_test.dart`、`test/features/canvas/widgets/canvas_multi_menu_test.dart`
- rail-script-panel：`lib/features/canvas/providers/left_rail_state.dart`、`lib/features/canvas/providers/script_document_provider.dart`、`lib/features/canvas/util/canvas_shot_notes_actions.dart`、`lib/features/canvas/widgets/left_rail/canvas_left_rail.dart`、`lib/features/canvas/widgets/left_rail/left_rail_panel.dart`、`lib/features/canvas/widgets/left_rail/script_model.dart`、`lib/features/canvas/widgets/left_rail/script_panel.dart`、`lib/features/canvas/widgets/shot_config_inspector.dart`、`test/features/canvas/providers/left_rail_state_test.dart`、`test/features/canvas/util/canvas_shot_notes_actions_test.dart`、`test/features/canvas/widgets/left_rail/canvas_left_rail_test.dart`、`test/features/canvas/widgets/left_rail/script_model_test.dart`、`test/features/canvas/widgets/left_rail/script_panel_test.dart`
- prompt-bar-mention-ui：`lib/features/canvas/providers/inspector_submit_controller.dart`、`lib/features/canvas/util/mention_candidates.dart`、`lib/features/canvas/widgets/canvas_prompt_bar.dart`、`lib/features/canvas/widgets/character_library_panel.dart`、`lib/features/canvas/widgets/characters_section.dart`、`lib/features/canvas/widgets/mention_popover.dart`、`lib/features/canvas/widgets/mention_text_controller.dart`、`test/features/canvas/providers/inspector_submit_mention_test.dart`、`test/features/canvas/util/mention_candidates_test.dart`、`test/features/canvas/widgets/characters_section_mounted_guard_test.dart`、`test/features/canvas/widgets/mention_text_controller_test.dart`、`test/features/canvas/widgets/prompt_bar_mention_test.dart`
- locate-in-gallery：`lib/features/canvas/widgets/canvas_menu/node_locate_gallery_entry.dart`、`lib/features/gallery/providers/gallery_filter.dart`、`lib/features/gallery/providers/gallery_selection.dart`、`lib/features/gallery/util/locate_in_gallery.dart`、`lib/features/gallery/widgets/gallery_filter_panel.dart`、`lib/features/gallery/widgets/gallery_grid.dart`、`test/features/canvas/widgets/canvas_menu/node_locate_gallery_entry_test.dart`、`test/features/gallery/util/locate_in_gallery_test.dart`、`test/features/gallery/widgets/gallery_locate_test.dart`

## 具体改动
```dart
// core/interfaces/toast_service.dart
enum ToastCategory { generationDone, exportDone, failure, undo, general }
ToastHandle show(String title, {ToastKind kind = ToastKind.info, ..., bool chime = false,
    Duration? elapsed /* W10 已加 */, ToastCategory category = ToastCategory.general});

// notification_prefs.dart
Set<ToastCategory> toastMutedFromPref(List<String> value);
List<String> toastMutedToPref(Set<ToastCategory> muted);

// notification_prefs_controller.dart
class ToastMuteController extends Notifier<Set<ToastCategory>> {
  Set<ToastCategory> build();                         // 从 preferencesServiceProvider.current.toastMuted 播种
  void setShown(ToastCategory category, bool shown);  // 即时改内存 + fire-and-forget 落盘（同 _persist 模式）
}
final toastMuteControllerProvider = NotifierProvider<ToastMuteController, Set<ToastCategory>>(...);
```
ToastCenter 状态机：
- 新私有 `bool _muted(ToastCategory c)`：现读 `preferencesServiceProvider.current.toastMuted`（同 `_dwellFor` 的做法，约第 421 行），`c` 在集合里即静音。
- `show`：`kind != ToastKind.progress && _muted(category)` ⇒ 生成一条 `ToastEntry`（新 id）只经 `_recorded(..., unread: false)` 进历史，不进 `live`、不 `_setRemaining`、不 `_chime`；返回一个绑定该 id 的句柄（之后 update/complete/dismiss 只改历史那一行，或空操作——二选一，测试钉住为「空操作，历史行不变」）。
- `_complete`：卡片的 `category` 被静音 ⇒ 历史行更新为终态但不标未读、不响，在场卡直接 `_leave(id)`（进度阶段已经显示过，终态静默收走）。
- `_recorded(ToastCenterState s, ToastEntry entry, {bool unread = true})`：`unread == false` 时不把 `entry.id` 加进 `unreadIds`。
- 系统通知：W10 system-notifications 的出口就在 `ToastCenter.show`（三条件判定 → 2 秒合并窗 → 发系统通知）。被静音的 show 在进入这段判定之前就分流走，系统通知自然不发；`_complete` 静音分支同样不触发系统通知。job_notification_listener 不需要另判。

## 行为规则与边界情况
- R1 默认（`toastMuted` 为空）一切与现状相同：老 preferences.json 没有 `toast_muted` 键 ⇒ 全部显示。
- R2 关掉某类：该类 show 不进 live、不响、`unreadCount` 不变、`hasUnreadError` 不变；历史最前多一行。
- R3 `kind == progress` 的卡不论类别都照常出（「进度卡带取消，不受开关管」）；它 `complete` 成被静音类别时：在场卡收走、不响、历史行不标未读。
- R4 「失败」只管后台任务（N3=A）：只有 job_notification_listener 的失败卡标 `failure`；画布 / 设置里的当场失败（`showCanvasSnack` 默认 error）仍是 general，关掉「失败」不影响它们。
- R5 「撤销」关掉后撤销卡不出，但撤销本身仍可用（快捷键 Ctrl Z / ⌘Z 由 undo-shortcuts-ui 提供）；本片不碰撤销逻辑。
- R6 开关切换不追溯：已在场的卡不收走；之后到达的才按新设置。
- R7 dedupeKey：被静音的 show 不替换在场卡（它根本不进 live）；历史里照按 id 记。
- R8 偏好非法值（非 List、元素非 String、未知名）一律忽略，不抛。
- R9 开关即时落盘（与 setDwell 同为 fire-and-forget），重开设置页状态还在。
- R10 无平台差异：纯状态机 + 偏好文件；Ctrl Z 说明文字由 ARB 写，不按平台分（键位文字不进这一行，见新文案键）。

## 新文案键
| key | en | zh |
|---|---|---|
| settingsNotificationShowTitle | Show notifications for | 显示哪些通知 |
| settingsNotificationCatGeneration | Generation finished | 生成完成 |
| settingsNotificationCatGenerationHint | Thumbnail + View | 缩略图 + 查看 |
| settingsNotificationCatExport | Export finished | 导出完成 |
| settingsNotificationCatExportHint | Open folder | 打开文件夹 |
| settingsNotificationCatFailure | Failures | 失败 |
| settingsNotificationCatFailureHint | Background tasks only | 只管后台任务 |
| settingsNotificationCatUndo | Undo | 撤销 |
| settingsNotificationCatUndoHint | Undo still works when off | 关了照样能撤 |
| settingsNotificationCatGeneral | General | 一般提示 |
| settingsNotificationCatGeneralHint | Copied · Saved | 已复制 · 已保存 |

## 测试
- `test/features/notifications/providers/toast_center_test.dart`（新 group 'category mute'）：
  - `muted category: no live card, no chime, recorded in history without unread` —— 预置 toastMuted=[general]，show info ⇒ live 空、提示音服务 0 次、history.length==1、unreadCount==0。
  - `muted failure does not turn the bell red` —— 静音 failure，show(kind:error, category:failure) ⇒ hasUnreadError==false。
  - `unmuted category behaves as before` —— 静音 undo，show general ⇒ 在 live、未读 1。
  - `progress card ignores mute; completing into a muted category leaves silently` —— 静音 exportDone，show(progress, category:exportDone) 在 live；complete(success, chime:true) ⇒ 卡进入 leaving、提示音 0 次、unreadCount 不增。
  - `toggling mute does not retract cards already on screen`。
- `test/features/notifications/widgets/job_notification_listener_test.dart`：`success toast is tagged generationDone`、`failure toast is tagged failure`（用 RecordingToastService.category 断言）。
- `test/features/canvas/util/canvas_snackbars_test.dart`：`undo snack is tagged undo; plain snack stays general`。
- `test/features/settings/notifications_section_test.dart`：`five category switches, all on by default`；`turning a switch off persists toast_muted`（InMemoryPreferencesService.current.toastMuted 含 'general'）；`switch reflects stored prefs on open`。
- `test/features/settings/notification_prefs_controller_test.dart`：`ToastMuteController seeds from prefs and drops unknown names`。
- `test/core/models/app_preferences_test.dart`：`toastMuted defaults to empty and round-trips`；`fromMap tolerates non-list / non-string toast_muted`。

## 变异点
- M1 把 toast_center.dart `show` 里的静音分支删掉（静音类别照进 live）→ `muted category: no live card...` 红。
- M2 `_recorded` 的 `unread` 参数忽略（总加未读）→ `muted failure does not turn the bell red` 红。
- M3 静音判断去掉 `kind != ToastKind.progress` 条件 → `progress card ignores mute...` 红。
- M4 `_complete` 不判类别 → `progress card ... completing into a muted category leaves silently` 红。
- M5 job_notification_listener 失败卡改回默认类别 → `failure toast is tagged failure` 红。
- M6 `showCanvasUndoSnack` 去掉 `category: ToastCategory.undo` → `undo snack is tagged undo` 红。
- M7 `AppPreferences.fromMap` 不读 `toast_muted` → `toastMuted defaults to empty and round-trips` 红。
- M8 `ToastMuteController.setShown` 不落盘 → `turning a switch off persists toast_muted` 红。

## 验收
- `flutter analyze lib test`。
- `flutter test test/features/notifications test/features/settings test/core/models test/features/canvas/util/canvas_snackbars_test.dart --exclude-tags golden`。
- 变异 M1–M8 逐条。
- 截图：`NotificationsSection`，ProviderScope 覆写 `preferencesServiceProvider` 为 `InMemoryPreferencesService(AppPreferences(toastMuted: ['general']))`；截「默认全开」与「一般提示关」两态，深色主题、宽 560。

## 风险与不确定
1. 画板 mock 里「一般提示」画成关，规则没说默认值；本片定为**全部默认开**（不改变现有用户体验），回报里请主 Agent 确认。
2. system-notifications（W10）派工单把系统通知出口放在 `ToastCenter.show`；若合入后出口不在那里（例如挪到 job_notification_listener），在那一处判 `ref.read(toastMuteControllerProvider)`，仍不在本片文件里就停下回报。测试补一条：静音 generationDone 时，W10 的 fake `SystemNotificationService` 收到 0 次。
3. undo-stack / undo-shortcuts-ui（W0/W2）若新增了不经 `showCanvasUndoSnack` 的撤销卡（`grep -rn "ToastKind.undo" lib`），那些调用点不在本片允许列表里——列出来回报，不擅自改。
4. 交付面板（delivery）导出完成目前没有通知卡（`grep -rn toast lib/features/export` 只有 export_video_dialog）；画板说「导出、交付标导出完成」，交付侧无可标，记为已知缺口。
5. 改动抽象 `ToastService.show` 签名：只有两个实现（ToastCenter、RecordingToastService），都在本片允许列表内。
