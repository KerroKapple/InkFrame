# system-notifications · 窗口在后台时发系统通知
- 波次 W10 / lane E / 基底：origin/main（W0–W9 已合入）；依赖切片：job-timing（W8，`jobTimingSourceProvider` / `jobElapsedOf`）、duration-format（W0）；阻塞决定：新依赖 local_notifier → 按画板建议引入（`local_notifier`，与 window_manager 同作者）；ShellExport-Q1 → A（系统通知静音，只响 InkFrame 提示音）

## 目标（用户看到什么变化，2–4 行）
- 窗口失焦或最小化时，跑了 10 秒以上的生成 / 导出做完（成功或失败），系统通知中心 / macOS 横幅里出一条通知。
- 点通知：窗口还原并到前台，再执行那张卡的主按钮（生成完成 = 查看并定位节点；导出完成 = 卡上现有主按钮）。
- 2 秒内接连完成的几件事合成一条。窗口里的通知卡照出、照进铃铛，提示音照响（只响一次）。
- 设置 › 常规 › 通知 多一个「系统通知」开关；macOS 上系统里拒了权限时开关下写「系统里已关闭」。

## 设计依据（画板文件名 + 画板里的小节标题与规则要点；画板没画到的状态写「设计缺口：…」）
- `b2/project/ShellExport.dc.html` ·「系统通知」：
  - 三个条件同时满足才发：卡片带 chime（后台事件）· 窗口不在前台 · 任务用时 ≥ 10 秒；失败也发。
  - 前台判据复用 `ToastCenter.setWindowActive`（现由 toast_layer.dart:80–84 的 AppLifecycleListener 喂）。
  - 点通知 = 窗口还原并聚焦 + 执行卡片主按钮。窗口里的卡照出、照进铃铛；2 秒内连着完成的合成一条。
  - 「用时」与任务弹层同一个格式函数（W0 `formatDurationLabel`）。
  - 需新依赖 local_notifier；Windows 要开始菜单快捷方式带 AppUserModelID，macOS 首次开启时请求权限，被拒就在开关下写「系统里已关闭」。
  - 样稿：设置 › 常规 › 通知 下「系统通知」开关 + 说明「窗口不在前台时，跑了 10 秒以上的生成或导出做完，发一条系统通知。」
- `b2/project/ShellExport.dc.html` · 需要你定 Q1：建议 A——系统通知静音，照常响 InkFrame 提示音。
- `b2/project/GapsPanels.dc.html` ·「通知：按类型开关 · 位置」：「下面接『系统通知』开关（ShellExport），不变」——开关放在停留时长下面；按类型静音（W12 toast-category-mute）以后也要管系统通知，本片不做。
- 代码核对：导出完成卡在 `lib/features/export/widgets/export_video_dialog.dart:416–429`（`chime: true`，主按钮是「复制路径」，不是画板写的「打开文件夹」）；导出失败只在对话框内嵌 InkErrorBanner（第 431 行），不出卡 ⇒ 导出失败目前不会有系统通知。
- 设计缺口：合并成一条时标题 / 正文 / 点击行为画板没画。本片定：标题「N 件事已完成」或「N 件事已结束 · K 个失败」，正文 = 最新那条的标题；点击 = 还原聚焦 + 打开铃铛历史（铃铛承接不了时只聚焦）。
- 设计缺口：样稿出处行「示例项目 · 画布 1」、正文里的 provider 名，现有卡片数据里没有（卡只有 title / body / meta）。本片正文 = 卡的 body 与 meta 用「 · 」连起来，不另拼出处。
- 设计缺口：2 秒窗口结束时用户已经回到窗口，画板没说还发不发。本片定：不发（看得见窗口里的卡了）。
- 设计缺口：导出失败没有卡 ⇒ 没有系统通知；导出主按钮是「复制路径」。都按代码现状，待 W14 export-in-task-popover 等片统一。

## 允许改的文件（逐个路径 + 每个文件改什么）
> 执行代理约定：在自己的工作树里、从上面写的基底起分支；只改本节列出的文件；不跑构建和测试；不改 ARB、lib/l10n/generated、docs/CLAUDE.md（新文案键在回报里列出，由主 Agent 统一加）；W0/W1 建的注册表（canvas_shortcut_registry、canvas_menu/menu_registry、app_action_catalog、more_menu_model）每片只追加一行；CanvasNode 的新派生属性写成新文件里的 extension；不给 NodeRepository 加抽象方法（有 26 个 fake），用现有 patchTypeConfig / update。
> 另外：不给 JobQueueService（10 个实现）、JobRepository（9 个实现）、EdgeRepository（11 个实现）、UnitOfWork（7 个实现）加抽象方法；需要新能力就新建一个小接口 + 新 provider（core/di 一服务一文件）。

- `pubspec.yaml`：dependencies 加 `local_notifier: ^0.1.6`（主 Agent 跑 pub get 时取当前兼容的最新 0.1.x，以 lock 为准）。
- `pubspec.lock`、`windows/flutter/generated_plugin_registrant.cc`、`windows/flutter/generated_plugins.cmake`、`macos/Flutter/GeneratedPluginRegistrant.swift`、`macos/Podfile.lock`：执行代理不手改，由主 Agent 跑 `flutter pub get`（macOS 上 `pod install`）生成后一起提交。
- 新 `lib/core/interfaces/system_notification_service.dart`：接口 + `SystemNotice` 值类 + `SystemNotifyPermission` 枚举。
- 新 `lib/services/local_notifier_system_notification_service.dart`：真实现（local_notifier + window_manager 还原聚焦）。
- 新 `lib/services/noop_system_notification_service.dart`：默认 / 测试实现，什么都不发，permission 返回 unknown。
- 新 `lib/core/di/system_notification.dart`：`systemNotificationServiceProvider`，默认 noop（与 `core/di/notification_sound.dart` 同写法）。
- 新 `lib/features/settings/providers/system_notify_pref_controller.dart`：开关状态 + 权限状态（不改现有 notification_prefs_controller.dart 的记录类型，避开 W12 热点）。
- `lib/main.dart`：Windows / macOS 上 `localNotifier.setup(appName: 'InkFrame', shortcutPolicy: ShortcutPolicy.requireCreate)`（放在第 169–170 行 window_manager 初始化之后、建容器之前，计入 lifecycle 一个阶段）；容器 overrides 里加 `systemNotificationServiceProvider.overrideWith(...)` 换成真实现（第 198–218 行那一组）。
- `lib/features/notifications/providers/toast_center.dart`：show 时判三条件 → 2 秒合并窗 → 发系统通知；点击回调执行主按钮并收卡。
- `lib/features/notifications/models/notification_prefs.dart`：加常量 `kSystemNotifyMinElapsed = Duration(seconds: 10)`、`kSystemNotifyCoalesce = Duration(seconds: 2)`。
- `lib/core/models/app_preferences.dart`：加 `systemNotificationsEnabled`（bool，默认 true，键 `system_notifications_enabled`，fromMap 缺省 / 类型不符退 true），同步 copyWith / toMap / == / hashCode。字段数已到 20（W6 snapping 加过一个），`Object.hash` 最多 20 个参数，超了改 `Object.hashAll`。
- `lib/features/settings/widgets/notifications_section.dart`：停留时长下面加「系统通知」一行（照 `startup_section.dart:43` 的 `Switch` 写法）+ 说明 + 被拒时的「系统里已关闭」。
- `lib/features/notifications/widgets/job_notification_listener.dart`：成功 / 失败两处 `show` 加 `elapsed:`（取 `jobElapsedOf(timingOf(jobId), now)`，只在 finished 阶段传）。
- `lib/core/interfaces/toast_service.dart`（主 Agent 已准许）：`show` 加可选 `Duration? elapsed`（默认 null）。ToastService 在仓库里只有两个实现——`ToastCenter`（本片已拥有）与测试替身，两处签名同步。
- `test/_harness/fake_toast_service.dart`（主 Agent 已准许）：`RecordingToastService.show` 同步签名，`RecordedToast` 加 `final Duration? elapsed` 记下传入值。
- `lib/features/export/widgets/export_video_dialog.dart`（主 Agent 已准许）：`_onExport`（第 389 行起）在 `await ref.read(exportControllerProvider.notifier).export(...)` 前后各取一次 `ref.read(clockProvider).nowUtc()`（前一次与 toast / navigator 一起在 await 前取好），成功卡（第 416–429 行）传 `elapsed: 后 − 前`；失败 / 取消分支不动。
- 不改：`lib/features/notifications/models/toast_entry.dart`、`lib/services/file_preferences_service.dart`（核对过：后者整份读写 AppPreferences.toMap / fromMap，加字段无需改）。
- 测试（新建）：`test/features/notifications/providers/toast_center_system_notify_test.dart`、`test/features/settings/notifications_section_system_test.dart`、`test/core/models/app_preferences_system_notify_test.dart`、`test/features/notifications/widgets/job_notification_listener_system_test.dart`、`test/features/export/widgets/export_video_dialog_elapsed_test.dart`。

## 不许碰的文件（同一波其他切片占用的热点文件，按 plan.md 第 2 节）
- batch-run-executor：`lib/features/generation/generation_controller.dart`、`lib/features/shell/widgets/shell_task_popover.dart`、`lib/features/shell/widgets/shell_task_capsule.dart`、新 `lib/features/generation/providers/batch_run_controller.dart`。
- next-shot：`util/create_menu_model.dart`、`canvas_menu/create_menu_entries.dart`、`canvas_shortcut_registry.dart`（追加一行），及新 `util/next_shot.dart` / `providers/next_shot_controller.dart` / `shortcuts/next_shot_keys.dart`。
- tc-next-shot-first-frame：`widgets/video_config_inspector.dart`、`canvas_menu/menu_registry.dart`（追加一行），及新 `util/next_shot_frame.dart` / `util/canvas_next_frame_actions.dart` / `canvas_menu/next_frame_menu_entries.dart` / `models/commands/replace_role_edge_command.dart`。
- script-tables 另有新文件：`lib/storage/schema/schema_v10.dart`、`lib/core/interfaces/script_repository.dart`、`lib/storage/repositories/postgres_script_repository.dart`、`lib/features/storyboard/models/script_document.dart`。
- script-tables：storage / schema / migrations / `lib/core/db/columns.dart` / `lib/core/di/repositories.dart` / unit_of_work / `lib/services/project_archive_service.dart` / `lib/services/import/import_remapper.dart` 等。
- 全波不归任何人：`util/canvas_tool_actions.dart`、`canvas_menu/node_menu_entries.dart`、`util/node_menu_model.dart`、`canvas_shortcuts.dart` 骨架、注册表（除追加一行）。
- 本片额外不碰：`lib/features/settings/providers/notification_prefs_controller.dart`（W12 toast-category-mute 要改）、`lib/features/notifications/widgets/toast_layer.dart` 与 `notification_bell.dart`（W11 f6-notification-region）、`lib/core/interfaces/window_state.dart` 与 `lib/services/window_manager_adapters.dart`（有 fake，不加方法；还原聚焦写在本片的新 service 里）、`lib/services/job_queue/job_timing.dart`（只读）。
- 自查补全（同波其余切片占用、上文未列出的现有文件）：script-tables：`lib/core/interfaces/project_archive_reader.dart`、`lib/core/interfaces/unit_of_work.dart`、`lib/core/models/import_plan_data.dart`、`lib/storage/migrations/app_migrations.dart`、`lib/storage/postgres_unit_of_work.dart`、`lib/storage/repositories/postgres_project_archive_reader.dart`、`lib/storage/repositories/postgres_project_import_writer.dart`。

## 具体改动（新类型 / 函数签名 / provider 名 / 状态机；代码块里只写签名，不写实现）
```dart
// lib/core/interfaces/system_notification_service.dart
enum SystemNotifyPermission { granted, denied, unknown }
@immutable
class SystemNotice { const SystemNotice({required this.title, this.body}); final String title; final String? body; }
abstract class SystemNotificationService {
  Future<SystemNotifyPermission> permission();         // 只查，不弹询问
  Future<SystemNotifyPermission> requestPermission();  // macOS 首次弹系统询问；Windows 直接 granted
  /// 静音发出（Q1 A）。点了：实现先把窗口还原 + 到前台，再调 [onActivate]。不抛。
  Future<void> show(SystemNotice notice, {required void Function() onActivate});
}

// lib/core/interfaces/toast_service.dart（需裁决）
ToastHandle show(String title, {..., bool chime = false, Duration? elapsed}); // elapsed：后台任务用时；null = 不是计时任务，永不发系统通知

// lib/features/notifications/providers/toast_center.dart
class ToastCenter ... {
  // show() 末尾：_maybeQueueSystemNotice(entry, chime: chime, elapsed: elapsed)
  // 待发队列 List<ToastEntry> _pendingNotices；Timer? _noticeFlush（kSystemNotifyCoalesce，从第一条起算，不顺延）
  // _flushNotices(): 窗口已在前台 / 开关已关 ⇒ 丢弃；1 条 ⇒ 单条；≥2 条 ⇒ 合并
  // 单条点击 ⇒ entry.primary?.onPressed() 后 dismiss(entry.id)；合并点击 ⇒ historyHostReady ? openHistory() : 无
}

// lib/features/settings/providers/system_notify_pref_controller.dart
typedef SystemNotifyPref = ({bool enabled, SystemNotifyPermission permission});
class SystemNotifyPrefController extends Notifier<SystemNotifyPref> {
  Future<void> refreshPermission();   // 设置页挂上时调一次 permission()
  Future<void> setEnabled(bool on);   // on 时先 requestPermission()；落盘 systemNotificationsEnabled
}
final systemNotifyPrefControllerProvider = NotifierProvider<SystemNotifyPrefController, SystemNotifyPref>(..., name: 'systemNotifyPrefControllerProvider');
```
- 真实现要点：`LocalNotification(title:, body:, silent: true)`，`onClick` 里依次 `windowManager.isMinimized()` ⇒ `restore()`、`show()`、`focus()`，再调 onActivate；第一次 `show` 前若从没 requestPermission 过就先请求一次（macOS 首次开启）。只捕 `PlatformException` / `MissingPluginException`，记 warn 日志（module `notifications.system`）后吞掉。
- 合并文案：全成功 `systemNotifyBatchDone(count)`；有失败 `systemNotifyBatchMixed(count, failed)`；正文 = 最新一条的标题。单条：标题 = 卡标题，正文 = `[body, meta]` 里非空的用「 · 」连接。

## 行为规则与边界情况（编号，每条可测；含失败、空态、取消、并发、与撤销栈的交互、mac / Windows 差异）
1. 三条件缺一不发：chime 为 false、窗口在前台、elapsed 为 null 或 < 10 秒，任一成立都不进待发队列。正好 10 000 ms 算满足。
2. 开关关着不发；开关在 2 秒窗内被关掉，到点也不发（flush 时再读一次偏好）。
3. 失败卡（ToastKind.error）同样发；dedupeKey 原地替换的失败也算一条新事件。
4. 2 秒合并：第一条进队起算 2 秒，期间再来的都并进这一条；窗口不顺延；到点后的下一条另起一个窗。
5. 到点时窗口已回到前台 ⇒ 整批丢弃，不发。
6. 单条点击：先还原聚焦（实现里），再执行卡的主按钮，再把卡收掉；卡已被用户关掉也照样执行主按钮（ToastAction 是独立闭包）；没有主按钮只聚焦。
7. 合并点击：还原聚焦 + 铃铛承接得了（historyHostReady）就打开历史，否则只聚焦。
8. 窗口里的卡、铃铛历史、未读、提示音都照旧：本片只「多发一条」，不改 show 的其他行为；系统通知本身静音（`silent: true`），不会一次响两声。
9. ToastCenter 销毁：待发队列清空、Timer 取消，迟到的点击回调空操作。
10. 取消不出卡 ⇒ 不发（现有行为）。进度卡（ToastKind.progress）没有 chime ⇒ 不发。
11. 导出：成功卡带 elapsed（对话框量出来的用时）才可能发；导出失败目前不出卡 ⇒ 不发（见设计缺口）。
12. 权限：Windows 恒 granted；macOS 被拒 ⇒ 开关保持用户的选择，开关下多一行「系统里已关闭」，发通知调用照常走（系统自己丢弃），不报错；权限 unknown（插件给不出）⇒ 不写这一行。
13. Windows zip 版：setup 时建带 AppUserModelID 的开始菜单快捷方式；没建成（权限 / 路径问题）通知静默不出，不影响卡片。
14. 偏好：老 preferences.json 没有这个键 ⇒ 默认开；值不是 bool ⇒ 退开。
15. 不进撤销栈。

## 新文案键（key · en · zh 表；没有写无）
| key | en | zh |
|---|---|---|
| settingsSystemNotifyTitle | System notifications | 系统通知 |
| settingsSystemNotifySubtitle | When InkFrame isn't in front, send a system notification when a generation or export that ran for 10 seconds or more finishes. | 窗口不在前台时，跑了 10 秒以上的生成或导出做完，发一条系统通知。 |
| settingsSystemNotifyDenied | Turned off in system settings | 系统里已关闭 |
| systemNotifyBatchDone（占位 count） | {count} tasks finished | {count} 件事已完成 |
| systemNotifyBatchMixed（占位 count, failed） | {count} tasks finished · {failed} failed | {count} 件事已结束 · {failed} 个失败 |

## 测试（文件路径 + 每条用例名与断言要点；先写会失败的用例）
- `test/features/notifications/providers/toast_center_system_notify_test.dart`（ProviderContainer；覆盖 `systemNotificationServiceProvider` 为记录型 fake、`preferencesServiceProvider` 为 InMemoryPreferencesService、`notificationSoundServiceProvider` 为记录型 fake；fake_async 推进）
  - 「三条件齐 ⇒ 2 秒后发一条」：setWindowActive(false)，show(chime: true, elapsed: 12 s)；1.9 s 时 fake 收到 0 条，2 s 时 1 条，标题 = 卡标题。
  - 「前台不发」「chime=false 不发」「elapsed=null 不发」「elapsed=9 999 ms 不发」「elapsed=10 000 ms 发」。
  - 「开关关不发」「窗内关开关到点不发」。
  - 「到点已回前台 ⇒ 丢弃」。
  - 「2 秒内三条合成一条」：标题 = systemNotifyBatchMixed(3, 1)，正文 = 最新卡标题；第 2.5 s 再来一条 ⇒ 另一条。
  - 「单条点击执行主按钮并收卡」：fake 调 onActivate ⇒ primary 计数 +1、该卡 leaving。
  - 「合并点击打开历史」：historyHostReady=true ⇒ historyOpen；false ⇒ 不变。
  - 「系统通知不额外出声」：发通知前后提示音 fake 只记 1 次（来自 chime）。
  - 「销毁后不发」：容器 dispose 在 2 秒内 ⇒ fake 0 条、无挂起 Timer。
- `test/features/notifications/widgets/job_notification_listener_system_test.dart`
  - 「成功 / 失败卡带 elapsed」：注入计时表（提交 T0、完成 T0+72 s）⇒ RecordingToastService 记下 elapsed == 72 s（需 fake_toast_service 记录 elapsed）。
  - 「排队中取消没有 elapsed」（取消本来不出卡，断言 shown 为空）。
- `test/features/export/widgets/export_video_dialog_elapsed_test.dart`（覆盖 toastServiceProvider = RecordingToastService、clockProvider = FakeClock、exportControllerProvider 为假控制器：export() 里 FakeClock.advance(15 s) 后落 ExportVideoSuccess）
  - 「导出成功卡带 elapsed」：shown.single.elapsed == 15 s、chime == true。
  - 「导出失败不出卡」：假控制器落 ExportVideoFailure ⇒ shown 为空（现有行为不变）。
- `test/features/settings/notifications_section_system_test.dart`
  - 「开关默认开、点了落盘 false」。
  - 「打开时请求权限」：fake.requestPermission 调用次数 1。
  - 「被拒写 系统里已关闭」：fake.permission 返回 denied ⇒ 找到 settingsSystemNotifyDenied 文案；granted / unknown ⇒ 找不到。
- `test/core/models/app_preferences_system_notify_test.dart`
  - 「缺键默认 true」「非 bool 退 true」「toMap/fromMap 往返」「== / hashCode 区分该字段」。

## 变异点（主 Agent 验收时把哪一行改回什么，测试必须变红；逐条写）
1. 去掉「窗口不在前台」判据 ⇒「前台不发」红。
2. 阈值 `>=` 改 `>` ⇒「elapsed=10 000 ms 发」红；阈值改 0 ⇒「elapsed=9 999 ms 不发」红。
3. 不判 `elapsed == null` ⇒「elapsed=null 不发」红。
4. flush 不再读开关 ⇒「窗内关开关到点不发」红。
5. flush 不再判前台 ⇒「到点已回前台 ⇒ 丢弃」红。
6. 合并窗改成每条顺延 ⇒「第 2.5 s 再来一条 ⇒ 另一条」红。
7. 合并改成逐条发 ⇒「2 秒内三条合成一条」红。
8. 点击回调不调 primary ⇒「单条点击执行主按钮并收卡」红。
9. `silent` 改 false 或在发通知时再调一次 `_chime` ⇒「系统通知不额外出声」红（chime 部分；silent 由真实现人工核对）。
10. ToastCenter onDispose 不取消 `_noticeFlush` ⇒「销毁后不发」红。
11. fromMap 缺省退 false ⇒「缺键默认 true」红。
12. 设置页不看 permission ⇒「被拒写 系统里已关闭」红。
13. 导出对话框不传 `elapsed:`，或把「前」那次取时刻挪到 export() 之后 ⇒「导出成功卡带 elapsed」红。
14. RecordingToastService 不记 elapsed（恒 null）⇒「成功 / 失败卡带 elapsed」「导出成功卡带 elapsed」红。

## 验收（主 Agent 会跑 flutter analyze lib test、相关测试目录、变异；UI 片写截图场景：用哪个 widget、什么数据、截哪几个状态）
- 主 Agent 先 `flutter pub get`（macOS 另跑 pod install），把 lock 与插件注册文件一起提交；再 `flutter analyze lib test`；`flutter test test/features/notifications test/features/settings test/core/models --exclude-tags golden`。
- 截图：`NotificationsSection`（SettingsScreen 常规页）三态——开关开 + 权限 granted；开关关；开关开 + 权限 denied 出「系统里已关闭」。
- 人工实测（不进 CI）：Windows zip 版解压到无管理员权限目录，开始菜单出现 InkFrame 快捷方式、失焦后跑一条 ≥10 秒生成，通知中心出一条、无系统提示音、点了窗口回前台并定位节点；macOS 首次触发弹权限询问，拒绝后设置页出「系统里已关闭」。

## 风险与不确定
- 签名演进：本片给 `ToastService.show` 加 `elapsed`；W12 toast-category-mute 会在其后再改 show 签名（加 `category`），届时 ToastCenter 与 fake_toast_service 再同步一次。导出对话框的改动只限 `_onExport` 里取时刻与传参，W6 export-records-recording 若已改过这段，以落地为准合并。
- local_notifier 0.1.x 在 macOS 上用的是哪套通知 API、有没有权限查询 / 请求接口，需执行代理读 pub 源码核对；没有就 permission / requestPermission 返回 unknown，「系统里已关闭」这一行在 macOS 上也就不会出现（设计缺口，回报主 Agent）。
- Windows zip 版：快捷方式建在当前用户开始菜单；用户删了解压目录会留下失效快捷方式；首次 setup 之后第一条通知可能要重启才出（AUMID 注册时机），必须实测。
- `Object.hash` 20 参上限：W6 snapping 若已改成 `hashAll`，这里只追加。
- 「用时」口径来自 W8 计时表（完成 − 提交，不含排队）；导出的用时由对话框自己量（含 ffmpeg 全程），两者口径不同但都符合「任务用时」。
