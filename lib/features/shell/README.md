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
                  └ IndexedStack(index: overlay == null ? 0 : 1)
                     ├[0] ShellKeepAliveHost
                     │     └ IndexedStack(index: ShellTab.values.indexOf(tab))
                     │        └ 5 × KeyedSubtree(key: 'shellTabBody-<name>')
                     │              child = 已物化 ? <TabBody> : SizedBox.shrink()
                     └[1] overlay == null ? SizedBox.shrink()
                                          : ShellOverlayLayer(key: 'shellOverlay-<name>')
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
| 序列/导出标签的 `canvasId == null` 分支不 watch 任何仓储 | 一旦 eager 碰仓储就会去起真内嵌 PG，测试挂到 isolate 超时 | `shell_tabs_empty_state_test.dart`（会抛的 fake 仓储） |
| 序列标签订阅节点控制器、导出标签订阅边控制器（`select` 收窄成常量） | 它们是 autoDispose family：无人订阅时 `_open` 里 `ref.read` 只拿到 `AsyncLoading` ⇒ 序列按钮变哑键、导出默认序静默退化成非叙事链序。旧 `CanvasTopChrome` 里两个按钮互相替对方撑着，拆成两个标签后这层**隐式**依赖断了 | `shell_tabs_empty_state_test.dart`（跨控制器订阅组） |

## 已知且接受的副作用（隐藏标签仍会 build / layout）

`RenderIndexedStack` 未覆写 `performLayout`，隐藏子照常 build / layout / 跑
`LayoutBuilder` 与 post-frame，只是不 paint、不 hitTest。于是：

- `CanvasJobListener` 在任何标签下都会 invalidate 节点控制器并对新失败 job 弹 toast
  —— 这是**改善**（生成失败不再因切走标签而丢消息），不是回归。
- 画廊的 `GridView` 在离台时仍 build 首屏 tile 并解码图片。懒物化把"首启即 N+2
  次查询 + 一屏解码"挡在门外：不点画廊标签就零画廊查询。

## 刻意不做

- **浮层没有 Esc 关闭**（D11）。不是遗漏：加它要在外壳层新增 `CallbackShortcuts`，
  且会与设置内部 `_EditorDialog` 的默认 `DismissIntent` 竞争。关闭途径三条：
  工具条返回键、点任一标签、⌘K。补做时必须同时加一条"`_EditorDialog` 打开时
  Esc 先关对话框、不关浮层"的竞争用例。
- **没有"关闭当前画布"**：`ShellState` 没有任何能清 `canvasId` 的公共动词
  （`resetSession()` 除外）。老代码里"清 canvasId"的真实意图都是"回 Studio"，
  正确替代是 `goTab(studio)`。

## 目录

| 路径 | 职责 |
|---|---|
| `models/shell_state.dart` | `ShellTab` / `ShellOverlay` / `ProjectRef` / `ShellState`（手写不可变值对象，7 个具名迁移，无 copyWith） |
| `providers/shell_controller.dart` | `ShellNavigator` + `shellControllerProvider`——外壳状态的唯一写入口 |
| `providers/active_project.dart` | `activeProjectProvider`（`ShellState.project` 的只读投影） |
| `providers/gallery_dirty.dart` | `galleryDirtyProvider`——任一 job 转 `JobSucceeded` 即置脏；画廊标签由不可见→可见时刷一次再清脏（T9）。**不是实时刷新**：用户正看着画廊时不动，切走再切回才更新 |
| `widgets/ink_shell.dart` | 外壳根：唯一 Scaffold + chrome + 标签条 + 内容区 |
| `widgets/shell_content_stack.dart` | 两级 IndexedStack + `_shellFocus` 兜底焦点 |
| `widgets/shell_keep_alive_host.dart` | 懒物化 + 物化后常驻的五槽宿主 |
| `widgets/shell_chrome.dart` | 全树唯一 `InkWindowChrome` 的宿主（logo / 面包屑 / ⌘K / ⚙） |
| `widgets/shell_breadcrumb.dart` | `studio › project › canvas`（条件 watch） |
| `widgets/shell_empty_state.dart` | 复用空态（图标 + 标题 + 可选副标题 + 可选 CTA） |
| `widgets/shell_overlay_layer.dart` | 浮层槽分发（settings / showcase），**不保活** |
| `widgets/shell_tab_bar.dart` | 标签条接线层：ShellState → `InkShellTabBar` 的纯数据。呈现在 `lib/theme/components/ink_shell_tab_bar.dart`，**那一层不认识 `ShellTab`**（R47；`test/quality/no_reverse_layer_import_test.dart` 钉死） |
| `widgets/tabs/*.dart` | 五个标签体（序列 / 导出为 T7 过渡形状，真身在 T10；画廊真身已在 T9 落地，含脏刷新） |
| `util/tab_availability.dart` | `hasNarrativeEdges` / `canExportVideo`——从已删除的 `canvas_top_chrome.dart` 原样搬运的纯判据 |
