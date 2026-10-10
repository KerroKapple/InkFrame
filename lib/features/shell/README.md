# features/shell — 持久标签外壳

应用解锁后的唯一宿主。`lib/app.dart` 不再持有任何路由判据：body 恒为
`InkShell`，"哪个 surface 在台上"只在 `ShellContentStack` 一处决定。

```
InkFrameApp (MaterialApp)          # 全树唯一 MaterialApp
└ _StartupGate
  └ _UnlockedShell
    └ CommandPaletteShortcuts      # 必须在 _shellFocus 之上
      └ InkShell
        └ Scaffold                 # 外壳唯一的「根」Scaffold
           body: Column(
            ├ ShellChrome          56  # 全树唯一 InkWindowChrome
            ├ InkShellTabBar       44  # 在 DragToMoveArea 之外
            └ Expanded
               └ ShellContentStack       # 持 _shellFocus
                  └ Stack                       # 浮层盖在【遮暗可见】的标签体上（Screens 稿第 3 屏）
                     ├ ExcludeFocus(excluding: overlay != null)
                     │  └ ShellKeepAliveHost
                     │     └ IndexedStack(index: ShellTab.values.indexOf(tab))
                     │        └ 5 × KeyedSubtree(key: 'shellTabBody-<name>')
                     │              child = 已物化 ? <TabBody> : SizedBox.shrink()
                     └ if (overlay != null) ShellOverlayLayer(key: 'shellOverlay-<name>')
                          └ Stack[ ModalBarrier(scrim, 不可点关) , SettingsScreen | BuiltInShowcaseScreen ]
           )
```

## 不变量（动之前先读对应测试）

| 不变量 | 为什么 | 守护它的测试 |
|---|---|---|
| 槽位 Key 恒在树里（`shellTabBody-*`，物化与否都在） | 保活断言锚在稳定 Key 上，不会因"画廊未选项目所以 `GalleryScreen` 不 mount"而假红 | `test/features/shell/shell_keep_alive_host_test.dart` |
| 内容懒物化、物化后永不换回占位 | V4 成立的唯一物理前提：没访问过的标签体 `findsNothing` 才是真断言 | `shell_keep_alive_host_test.dart` + `test/app/app_routing_test.dart` |
| 全树唯一 `InkWindowChrome` | 每个已物化标签各带一份 = 两套最小化/关闭按钮 | `shell_window_chrome_test.dart`（V3a） |
| 外壳持根 `Scaffold`，画布/设置自带的 Scaffold 保留不动 | `ScaffoldMessenger` 对每个 **root** Scaffold 各推一份 SnackBar；不加祖先 ⇒ 一条 toast 渲染两份，且序列/导出标签（无 Scaffold）激活时 toast 画在离台子树里 | `shell_window_chrome_test.dart`（V3b） |
| 标签条绝不进 chrome 的槽位 | `InkWindowChrome` 整条包在 `DragToMoveArea` 里，其 `onDoubleTap` 让单击等满 `kDoubleTapTimeout`(300ms) | `test/features/shell/shell_tab_bar_test.dart`（一帧落地） |
| `ShellContentStack` 的焦点重夺【无条件】，不许加 `hasFocus` 守卫 | 切换那一帧画布 FocusNode 还没 unfocus，守卫会跳过请求 → 焦点掉到 ModalScope 的 FocusScope → 全 app ⌘K 失效 | T8 的 V2 用例 |
| `ShellBreadcrumb` 条件 watch：`canvasId == null` 时不碰 `canvasRepository` | 否则每个 boot 级 widget test 都得额外密封画布仓储 | `shell_chrome_test.dart` + `test/widget_test.dart` |
| 序列/导出标签的 `canvasId == null` 分支不 watch 任何仓储 | 一旦 eager 碰仓储就会去起真内嵌 PG，测试挂到 isolate 超时 | `shell_tabs_empty_state_test.dart` 的 `_expectNoRepositoryTouched`。**注意断的是"仓储 provider 有没有被解析过"，不是 `tester.takeException()`**：控制器 build 是 async 的，里面抛的异常被 Riverpod 收进 `AsyncError`，既不冒到 zone 也不进 `takeException()`——T10 实测把 watch 提到 `if` 之前时，只留 `takeException` 的版本全绿 |
| 序列标签订阅节点 + 边控制器、导出标签订阅边控制器（`select` 收窄成常量） | 它们是 autoDispose family：无人订阅时 `_open` 里 `ref.read` 只拿到 `AsyncLoading` ⇒ 导出默认序静默退化成非叙事链序。旧 `CanvasTopChrome` 里两个按钮互相替对方撑着，拆成两个标签后这层**隐式**依赖断了 | `shell_tabs_empty_state_test.dart`：结构代理在「跨控制器订阅组」，真正有鉴别力的是 R49 顺序用例 |
| 序列监视器（`features/sequence/widgets/sequence_monitor.dart`）**不自动播放**；`paused`（= `!isTabVisible(sequence)`）变 true 立即 pause，回来**不**续播 | P2 把序列从「空态 + 对话框」抬成常驻标签视图，media_kit `Player` 随标签保活；不接这条就会在后台标签里一直播。这是原「`SequencePreviewContent` 只活在对话框里」不变量的替代物（用户 2026-09-28 拍板） | `test/features/sequence/widgets/sequence_monitor_test.dart`「拍板④ / ⑤」+ `shell_sequence_visibility_test.dart`（接线：切走标签 / 浮层盖住都走 `isTabVisible`；断言写 `skipOffstage: false`——保活宿主用 `Offstage` 藏非活动标签） |
| 导出的 `projectId` 与**门控**都取自 `ShellState.project`，不从节点数据摸。写点：`export/open_export_dialog.dart`（导出标签 / 序列标签「导出 mp4」共用）+ `command_palette/command_actions.dart`；门控 = `canExportVideo(nodes) && shell.project != null`（BOARD 210，P2 收掉） | 启用判据与 projectId 来源必须同源：旧写法门控看 `nodes.first.projectId`、动作看外壳态，外壳里项目上下文完好但原序首个 video 的 `project_id` 为空时"功能莫名其妙没了"（R86 / BOARD 210） | `shell_tabs_empty_state_test.dart` 的点击类用例（夹具 `_shellWith` 带 `ProjectRef`）+ `command_palette_test.dart` 的 R86 与「无项目上下文不出 Export video」用例 |
| 四处空态的「去 Studio」CTA 真的能走（不是哑键、不自跳），正文各标签不串 | D12：空态必须是**可行动的引导**，用户不能觉得卡死。该空态在 T7 之前的生产代码里根本不可达，本 PR 让它第一次真正可达 | `test/features/shell/shell_empty_state_cta_test.dart`（四标签各一例；文案与 CTA 两半各有独立变异证明，见该文件头注） |
| 标签条在浮层打开时仍可见、仍可点（点任一标签 = 关浮层 + 切标签） | 关浮层的途径之一（其余：Esc / ✕ / 完成 / ⌘K） | `test/features/shell/shell_tab_bar_overlay_test.dart` |
| 标签 chip **键盘可达**：可 Tab 聚焦、Enter / Space 激活（与鼠标点击同一个回调）、`onTap == null` 的格不可聚焦；焦点环走 `accent` token 且画在 `foregroundDecoration` 上（不参与布局 ⇒ 不动宽度阈值） | 标签条是全应用最高频交互，键盘用户此前根本到不了（chip 是裸 `GestureDetector` + `Semantics`）。激活必须复用同一个 `onTap`，否则键盘与指针两条路会走岔 | `test/theme/ink_shell_tab_bar_test.dart`「键盘可达性」五条 + `test/features/shell/shell_tab_bar_test.dart`「Tab 到画廊格按 Enter 即切标签」（跨层那条） |
| 浮层打开时标签体**仍在台上**（遮暗可见），但点不穿、不持焦 | 浮层形态（Screens 稿第 3 屏）：原界面在下面看得见。点穿由 `ShellOverlayLayer` 的 `ModalBarrier` 拦，失焦由 `ShellContentStack` 的显式 `ExcludeFocus` 保证——这两件事以前是外层 IndexedStack 代劳的 | `test/app/app_routing_test.dart`（`onstage: true, hittable: false`）+ `test/features/shell/shell_focus_test.dart` V2 |
| 浮层 Esc 分层：编辑框开着只关编辑框，没有编辑框才关浮层；开关浮层不写路由（不清 canvasId、不切标签） | 设置浮层自己持焦并挂 `CallbackShortcuts`；`showDialog` 的编辑框在 Navigator 另一条路由上，Esc 到不了浮层。D11 那条债由此解决 | `test/features/settings/settings_overlay_test.dart` |
| **同一时刻只保活一个 `canvasId`**：五槽保活是按 `ShellTab` 分的，不是按 `canvasId` 分的。`canvas` 那一槽从头到尾只有一个 `KeyedSubtree('shellTabBody-canvas')`，`CanvasTab` 内部 `watch(currentCanvasIdProvider)` 变了就在同一个槽位里换内容 | 从画布 A 切到画布 B 不是"多开一个保活槽"，是把槽位里的树换成 B；A 的滚动位置/本地 UI 态随之丢弃——这是当前设计的边界，不是 bug | `shell_keep_alive_host_test.dart`（五槽 == 五个 `ShellTab`，与 `canvasId` 无关） |

## 已知且接受的副作用（隐藏标签仍会 build / layout）

`RenderIndexedStack` 未覆写 `performLayout`，隐藏子照常 build / layout / 跑
`LayoutBuilder` 与 post-frame，只是不 paint、不 hitTest。于是：

- `CanvasJobListener` 在任何标签下都会 invalidate 节点控制器并对新失败 job 弹 toast
  —— 这是**改善**（生成失败不再因切走标签而丢消息），不是回归。
- 画廊的 `GridView` 在离台时仍 build 首屏 tile 并解码图片。懒物化把"首启即 N+2
  次查询 + 一屏解码"挡在门外：不点画廊标签就零画廊查询。

## 刻意不做

- **点遮罩不关浮层**：设置里可能有没提交的输入，关闭只走 Esc / ✕ / 完成 / 点标签 / ⌘K。
  （D11「浮层没有 Esc」已在视觉重做设置浮层时解决，见不变量表与 `docs/BOARD.md`。）
- **没有"关闭当前画布"**：`ShellState` 没有任何能清 `canvasId` 的公共动词
  （`resetSession()` 除外）。老代码里"清 canvasId"的真实意图都是"回 Studio"，
  正确替代是 `goTab(studio)`。
  2026-10-10 复核把 BOARD 上那张「待补卡」**判定不做**并关闭：产品里没有任何
  「关闭画布」入口，而加一个没有调用方的具名迁移会被 #249 立的死 API 闸
  （`test/quality/shell_transition_reachability_test.dart`）当场判死。
  真有入口要求它时的入场条件：同一个 PR 里接上调用点 + 一条"调用后画布保活槽
  真被销毁"的显式断言。（另见 BOARD 新列的一条**不同**的真 bug：删掉正在打开的
  画布 / 项目后 `canvasId` / `project` 悬空——那条的正解不只是一个动词。）

## 目录

| 路径 | 职责 |
|---|---|
| `models/shell_state.dart` | `ShellTab` / `ShellOverlay` / `ProjectRef` / `ShellState`（手写不可变值对象，6 个具名迁移，无 copyWith） |
| `providers/shell_controller.dart` | `ShellNavigator` + `shellControllerProvider`——外壳状态的唯一写入口 |
| `providers/active_project.dart` | `activeProjectProvider`（`ShellState.project` 的只读投影） |
| `providers/gallery_dirty.dart` | `galleryDirtyProvider`——任一 job 转 `JobSucceeded` 即把**它所属项目**（`JobState.projectId`）的画廊置脏；画廊标签由不可见→可见时，若**当前项目**脏就刷一次再清该项目的脏（T9）。状态是 `Set<String?>`，集合里的 `null` 是"不知道是哪个项目"的通配位（生产不可达，退回全局语义：宁多刷不漏刷）。**不是实时刷新**：用户正看着画廊时不动，切走再切回才更新 |
| `widgets/ink_shell.dart` | 外壳根：唯一 Scaffold + chrome + 标签条 + 内容区 |
| `widgets/shell_content_stack.dart` | 两级 IndexedStack + `_shellFocus` 兜底焦点 |
| `widgets/shell_keep_alive_host.dart` | 懒物化 + 物化后常驻的五槽宿主 |
| `widgets/shell_chrome.dart` | 全树唯一 `InkWindowChrome` 的宿主（logo / 面包屑 / ⌘K / ⚙） |
| `widgets/shell_breadcrumb.dart` | `studio › project › canvas`（条件 watch） |
| `widgets/shell_empty_state.dart` | 复用空态（图标 + 标题 + 可选副标题 + 可选 CTA） |
| `widgets/shell_overlay_layer.dart` | 浮层槽分发（只有 settings——内置示例页已随 P7 删除），**不保活** |
| `widgets/shell_tab_bar.dart` | 标签条接线层：ShellState → `InkShellTabBar` 的纯数据。呈现在 `lib/theme/components/ink_shell_tab_bar.dart`，**那一层不认识 `ShellTab`**（R47；`test/quality/no_reverse_layer_import_test.dart` 钉死） |
| `widgets/tabs/*.dart` | 五个标签体（序列：`canvasId == null` 空态 → 无叙事边引导文案 → `SequenceScreen` 只读序列 lens，见上表；导出：空态 + 拉起既有对话框；画廊含脏刷新） |
| `util/tab_availability.dart` | `hasNarrativeEdges` / `canExportVideo`——从已删除的 `canvas_top_chrome.dart` 原样搬运的纯判据 |
