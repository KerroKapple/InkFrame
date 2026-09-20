# 持久工作区标签外壳（UI 重构第 1 步）

**日期：** 2026-09-20
**状态：** 待实施
**来源：** `D:\Docs\UIUX设计需求.zip` → `design_handoff_inkframe_ui/README.md` §落地建议顺序 第 1 步
**范围：** 单独一个 PR，不含后续第 2–7 步

---

## 0. 取代声明：曾考虑过的 base + overlay 方案

2026-09-14 前后，工作区里出现过一份 `base + overlay` 导航模型的规格与实施计划，以两个**从未提交到任何分支**的未跟踪文件形式存在（`docs/superpowers/{specs,plans}/2026-09-14-shell-overlay-navigation.md`）。该方案**未被采用**，文件已于 2026-09-20 删除。此节保留它的要点与不采用的理由，以免后来者重新发明同一个方案。

**它的形态**：`ShellRoute = { base: studio | canvas, overlay: null | gallery | settings | showcase }`。画廊 / 设置 / 示例以**整屏覆盖层**挂在画布之上，画布用 `Offstage` 留在 widget 树中，关闭覆盖层即回到原画布。没有标签条，用户靠「返回」键退栈。序列与导出明确列为非目标，仍是画布顶栏的对话框。

**为何不采用**：

1. **B1 只解决了一半。** 覆盖层仍是整屏，画廊与画布依然不能同屏对照 —— 它解决的是「切走再回来不丢状态」，没有解决断点 B1 的另一半「画廊作为素材库，可达性低于它的分量」。持久标签给的是**零成本的持久入口**，覆盖层给不了。
2. **没有为后续步骤留位置。** 设计包 README 的第 5、6 步要把序列与导出做成视图；覆盖层模型里它们只能继续当对话框，第 1 步做完之后第 5 步要把外壳再改一次。
3. **授权链断裂。** 文件内记录的「2026-09-14 用户拍板」是不可核实的自述，项目所有者无对应决策记录。一份带着虚假授权印记的规格留在仓库里，会被后来者当成真实决策历史 —— 这是删除原文而非归档的原因。

**它被吸收的部分**（与形态无关的共同地基，本规格全部保留）：路由直写收口到单一写入口、删除 `_openSettings` 的跨清写、画布保活、备份还原重置、启动恢复守卫改判。

---

## 1. 问题

`lib/app.dart` 的 `_UnlockedShell` 按 `currentCanvasId → currentGalleryProject → currentScreen` 三级 if 链整屏替换，只 build 一个 body，没有导航模型。由此产生的架构断点（依据见设计包 `InkFrame-IA.dc.html`）：

- **B1** 画布打开时画廊被完全遮蔽（`app.dart:158` 的 canvasId 判断在前）。
- **B2** 画布内没有画廊入口；命令面板在画布上下文也不提供。
- **B6** 进设置会显式清空 canvasId 与 gallery（`command_actions.dart:180-182` 连写三个 provider），回来时画布视口与选择态丢失。

附带的两个既有缺陷，本 PR 顺带修掉：

- **Windows 无边框窗口 bug**：`SettingsScreen` 不含 `InkWindowChrome`（`settings_screen.dart:30-36`），设置作为整屏路由时窗口既不能拖也没有关闭按钮。
- **画廊筛选偶发丢失**：`galleryFilterProvider` 是全局 `StateProvider.autoDispose`，而其唯一 watcher `_GalleryContent` 在 loading / error / 空态三个分支里不存在（`gallery_screen.dart:43-52`），error 重试与 data→空 转换会静默复位筛选。

---

## 2. 已拍板的决定

| # | 决定 | 依据 |
|---|---|---|
| D1 | 导航模型 = 持久工作区标签栏，非 base+overlay | 设计包 README §落地建议顺序 第 1 步 |
| D2 | 五个标签全部真实可点：Studio / 画布 / 序列 / 画廊 / 导出 | 用户拍板 |
| D3 | Studio / 画布 / 画廊 装真内容并走完整保活；序列 / 导出 = 空态 + 按钮拉起**现有对话框**，对话框保持私有、`barrierDismissible: false` 不变 | 用户拍板，见 §8 |
| D4 | 设置 = 外壳内的一层，不是 Navigator 路由 | 见 §7.4 |
| D5 | 配色走仓库现有暖色 token，不照搬设计稿中性灰 | 用户拍板，见 §9 |
| D6 | 保活宿主持有全树唯一 `InkWindowChrome`，四处子界面一律剥掉 | 用户拍板 |
| D7 | `CanvasShortcuts` 仅当画布页可见时持有焦点；安全问题，优先级高于任何视觉改动，独立任务先落先测 | 用户拍板 |
| D8 | ARB key 前缀用 `shell*` / `shellTab*` | `arb_hygiene_test.dart:32-39` 硬禁 `startsWith('workspace')` |
| D9 | `AppPreferences` 新增 `shellKeepLastCanvas`（默认 `true`）；两处 `clearLastCanvas` 直写删除 | 用户拍板 |
| D10 | 设置浮层用 `InkToolBar`(44px) 取代 `AppBar`(56px) | 用户拍板：156px 三层横栏在 960×600 下内容区只剩 444，不可接受 |
| D11 | 浮层的 Esc 关闭**刻意不做**，记 BOARD 债 | 用户拍板，见 §7.5 |
| D12 | 本 PR 不提供「关闭当前画布」；画布空态必须是可行动的引导而非错误态 | 用户拍板，见 §8.1 |
| D13 | 画廊刷新用粗粒度脏标记 | 用户拍板，见 §8.3 |

---

## 3. 验收标准

用户定的四条，是本设计的锚点。每一条都必须由测试**证明**，且必须能在对应的实现 bug 下**变红**。

| ID | 标准 |
|---|---|
| **V1** | 五标签切换不丢状态：画布的视口变换矩阵、选中集、泳道折叠态；画廊的筛选、搜索框内容、滚动位置 |
| **V2** | 焦点归属正确：不可见的画布不吞 Delete / Backspace / Esc / ⌘A / ⌘0；重新可见时拿回焦点；浮层打开时 ⌘K 仍可用 |
| **V3a** | 窗口控件唯一：全树恰好一个 `InkWindowChrome` |
| **V3b** | Toast 单渲染：两个标签都已物化时 `ToastService.show` 一次，全树恰好一个 SnackBar |
| **V4** | `app_routing_test.dart` 那 5 个断言改成显式 `skipOffstage: false` 后**仍然真实有效**，即不得变成「保活让 `findsNothing` 恒真」的假绿 |

> V3 拆成 V3a/V3b 是必需的：「把 chrome 加回画布子树」与「去掉外壳根 Scaffold」是两个不同的变异，只测前者的话后者会照绿。

---

## 4. 外壳形态

```
InkFrameApp (MaterialApp)                      // 不动；全树唯一 MaterialApp
└ _StartupGate                                 // 不动
  └ _UnlockedShell                             // build 塌成一行；initState 的启动决策保留
    └ CommandPaletteShortcuts                  // 不动；必须在 _shellFocus 之上
      └ InkShell
        └ Scaffold                             // 外壳唯一的「根」Scaffold
           body: Column(
            ├ ShellChrome          56px        // 全树唯一 InkWindowChrome
            ├ InkShellTabBar       44px        // 在 DragToMoveArea 之外
            └ Expanded
               └ ShellContentStack             // 持 _shellFocus
                  └ IndexedStack(index: overlay == null ? 0 : 1, sizing: StackFit.expand)
                     ├[0] ShellKeepAliveHost
                     │     └ IndexedStack(index: ShellTab.values.indexOf(tab),
                     │                    sizing: StackFit.expand)
                     │        └ 5 × KeyedSubtree(key: 'shellTabBody-<name>')
                     │              child = 已物化 ? <TabBody> : SizedBox.shrink()
                     └[1] overlay == null ? SizedBox.shrink()
                                          : ShellOverlayLayer(key: 'shellOverlay-<name>')
           )
```

### 4.1 为什么是两级 IndexedStack

三条都是**框架保证**而非手写纪律（已对 Flutter SDK 源码逐条核实）：

| 保证 | 依据 |
|---|---|
| 浮层打开 ⇒ 五个标签体一律 offstage | `_IndexedStackElement.debugVisitOnstageChildren`（`widgets/basic.dart:4952-4968`）只 visit `children.elementAt(index)` |
| 设置盖着时底下画布不会被点穿 | `RenderIndexedStack.hitTestChildren`（`rendering/stack.dart:846-861`）只命中 index 子；不依赖手写 `IgnorePointer` / `ModalBarrier` |
| 浮层打开时标签宿主整体失焦 | `IndexedStack` 把每个子包进 `Visibility(maintainFocusability: false)` → 隐藏子套 `ExcludeFocus(excluding: true)`（`visibility.dart:267`） |

反过来，`RenderIndexedStack` 未覆写 `performLayout`，所以**隐藏子照常 build / layout / 跑 LayoutBuilder 与 post-frame**，只是不 paint、不 hitTest。这既是保活成立的机制，也是 §4.4 副作用清单的根因。

`sizing: StackFit.expand` 是必需的：默认 `StackFit.loose` 会让画布/画廊 shrink-wrap，`Column + Expanded` 直接错位。

### 4.2 标签条绝不进 chrome 的槽位

整条 `InkWindowChrome` 包在 `DragToMoveArea` 里（`ink_window_chrome.dart:30`），其 `onDoubleTap` 让其中任何单击等满 `kDoubleTapTimeout`(300ms)。仓库已有三处测试为此写死 `pump(400ms)` 并留注释：`canvas_top_chrome_test.dart:75-78`（原文点名 kDoubleTapTimeout 300ms）、`gallery_screen_test.dart:179-180`、`built_in_showcase_screen_test.dart:122-123`。

标签是全应用最高频交互，300ms 延迟是真 UX 回归，还会给每个外壳测试加固定 400ms 税。

### 4.3 Scaffold 归属

`ToastService` 走 `MaterialApp.scaffoldMessengerKey` 的单 messenger（`toast_service.dart:22-27,36-51`），而 `ScaffoldMessengerState._updateScaffolds`（`material/scaffold.dart:231-238`）对**每个 root Scaffold** 都推一份 SnackBar。

保活之后，`CanvasScreen` 自带的 Scaffold（`canvas_screen.dart:33`）与 Studio 的 Scaffold 是 `IndexedStack` 里的兄弟，两个都算 root ⇒ **一条 toast 渲染两份**；而激活序列 / 导出标签（无 Scaffold）时，toast 全画在离台子树里，**用户根本看不见**。这是真功能回归。

**修法**：`InkShell` 持一个根 Scaffold。画布与设置自带的 Scaffold（连同 `floatingActionButton: CanvasAddNodeFab`）**原样保留**，它们因为有了 Scaffold 祖先而变成 nested，`_isRoot`（`scaffold.dart:240-245`）返回 false，被自动排除出广播。

> **明确否决**「撤掉 CanvasScreen / SettingsScreen 自带的 Scaffold、FAB 重新托管」：`Scaffold.floatingActionButton` 的定位/避让/动画全得手搓，且没有任何规则要求全树唯一 Scaffold —— `app_toast_messenger_test.dart:69-71` 断言的是唯一 **MaterialApp**。加一层祖先就够了。

### 4.4 隐藏标签的副作用（已知、接受、写进文档）

- `CanvasJobListener` 在任何标签下都会 invalidate 节点控制器并对新失败 job 弹 toast —— 这是**改善**（生成失败不再因切走标签而丢消息），在 PR 描述里点名，避免被当回归。
- 画廊的 `GridView` 在离台时仍 build 首屏 tile 并 `Image.file` 解码。懒物化把「首启即 N+2 次查询 + 一屏解码」挡在门外：不点画廊标签就零画廊查询。

### 4.5 高度预算

| 层 | 高 |
|---|---|
| `InkWindowChrome` | 56（`ink_window_chrome.dart:28` 硬值，不改） |
| `InkShellTabBar` | 44（`static const double height = 44`；chip 32 垂直居中） |
| 每个 surface 的 `InkToolBar` | 44（可选） |

960×600 最小窗口（`main.dart:212`）：固定 100，内容 500；带 `InkToolBar` 的标签剩 456。

---

## 5. 状态模型

### 5.1 `ShellState` —— 唯一真相源

`lib/features/shell/models/shell_state.dart`，零 Flutter widget 依赖，可纯 Dart 单测。**不新增 freezed**（build_runner 工具链受阻，见 `docs/BOARD.md`），`==` / `hashCode` 手写。

```dart
enum ShellTab { studio, canvas, sequence, gallery, export }  // 声明序 == 标签条序 == children 序
enum ShellOverlay { settings, showcase }

@immutable
class ProjectRef {
  const ProjectRef({required this.id, required this.name});
  final String id;
  final String name;
}

@immutable
class ShellState {
  const ShellState({this.tab = ShellTab.studio, this.overlay, this.canvasId, this.project});

  final ShellTab tab;           // 永不为 null；默认 studio（§10 的守卫依赖这个默认值）
  final ShellOverlay? overlay;  // 浮层不是标签，关掉后回到原标签
  final String? canvasId;       // null 是合法态 = 画布标签显示空态
  final ProjectRef? project;    // 画廊 / 序列 / 导出共享的项目上下文

  bool isTabVisible(ShellTab t) => overlay == null && tab == t;
  bool get isPristine => canvasId == null && overlay == null && tab == ShellTab.studio;
}
```

`ProjectRef` 刻意用具名类而非记录 `({String id, String name})`：记录是结构化类型，任何 `(id, name)` 对（画布引用、角色引用、备份条目）都能被静默传进项目上下文 —— 正是本 PR 要消灭的那类隐式状态。

**没有 `copyWith`。** 只有 7 个具名迁移，每个全量构造：

| 方法 | tab | overlay | canvasId | project | 副作用 |
|---|---|---|---|---|---|
| `goTab(t)` | `t` | 清空 | 保留 | 保留 | — |
| `openCanvas(id)` | canvas | 清空 | `id` | 保留 | — |
| `openCanvas(id, withProject: p)` | canvas | 清空 | `id` | `p` | — |
| `openGallery(p)` | gallery | 清空 | 保留 | `p` | — |
| `setProject(p)` | 保留 | 保留 | 保留 | `p` | — |
| `openOverlay(o)` | 保留 | `o` | 保留 | 保留 | — |
| `closeOverlay()` | 保留 | 清空 | 保留 | 保留 | — |
| `resetSession()` | studio | 清空 | 清空 | 清空 | `invalidate(galleryControllerProvider)` |

**禁止补 `copyWith`** —— 补了就等于把 60 个组合的合法性还给人工纪律，本 PR 的意义作废。写在文件头注。

**没有 `closeCanvas()`**（D12）。本 PR 不提供任何能清 `canvasId` 的公共动词（`resetSession` 除外）。老代码里那些「清 canvasId」写点的真实意图都是「回 Studio」，正确替代是 `goTab(studio)`。**这让「某处顺手清 canvasId 毁掉画布保活」在类型层面不可达** —— V1 不靠纪律守。

### 5.2 `ShellNavigator` —— 唯一写入口

`lib/features/shell/providers/shell_controller.dart`

```dart
class ShellNavigator extends Notifier<ShellState> {
  ShellNavigator({ShellState initial = const ShellState()}) : _initial = initial;
  @override ShellState build() => _initial;

  /// riverpod-2.6.1/lib/src/notifier.dart:113-115 的默认实现是 `!identical(previous, next)`。
  /// 外壳每次导航都构造新 ShellState，不覆写就会在每次切标签时唤醒全体订阅者。
  @override bool updateShouldNotify(ShellState p, ShellState n) => p != n;

  void _set(ShellState next) { if (next == state) return; state = next; }  // 第二道腰带：幂等
  // 七个迁移方法各一行委托给 ShellState
}

final shellControllerProvider =
    NotifierProvider<ShellNavigator, ShellState>(ShellNavigator.new, name: 'shellControllerProvider');
```

写权限天然被 Notifier 收口（字段全 final、迁移全在 Notifier 内），**不需要任何正则质量测试来「禁止绕过」**。

**抽象接口的豁免**（必须显式写在 `shell_controller.dart` 头注，不许沉默跳过）：`docs/CLAUDE.md` 的「Every injectable must have an abstract interface」针对的是注入的**服务**（`lib/core/interfaces/` 下 38 个文件）。`ShellNavigator` 是 `Notifier<ShellState>` —— 状态而非服务，仓库既有先例是 `CanvasSelectionController` / `CanvasViewportSize`，均无接口。给 Notifier 套接口还会让 `overrideWith(() => ShellNavigator(initial: …))` 这条最有用的测试播种通道失效。

导航器**不做 IO**：偏好落盘（`lastCanvasId` / `lastProjectId`）留在 `open_canvas.dart:27-29` 原处（SRP：导航器只管内存态，可纯单测、零 mock）。

### 5.3 两个派生只读投影

```dart
// lib/features/canvas/providers/current_canvas_id.dart —— 路径与名字不变，StateProvider → 派生只读 Provider
final currentCanvasIdProvider = Provider<String?>(
  (ref) => ref.watch(shellControllerProvider.select((s) => s.canvasId)),
  name: 'currentCanvasIdProvider');

// lib/features/shell/providers/active_project.dart —— 取代 current_gallery_project.dart
final activeProjectProvider = Provider<ProjectRef?>(
  (ref) => ref.watch(shellControllerProvider.select((s) => s.project)),
  name: 'activeProjectProvider');
```

**迁移杠杆（已实测）**：test 下 21 个文件引用 `currentCanvasIdProvider`，只有 17 处写 `.notifier`（含 lib 侧 8 处导航写点），其余全是 `overrideWith((_) => 'c1')` —— 两种 provider 的 `overrideWith` 收同样的 `(Ref) => T` lambda。**约 11 个纯画布测试文件一行不改。** 这是把 40 文件巨型 commit 拆成能逐个过门禁的任务的真杠杆。

降级本身也是收益：`Provider` 上不存在 `.notifier.state`，「谁都能偷改路由」在类型层面消失。

**必须与杠杆捆绑的 split-brain 警告**：override 投影会把它与真相源脱钩 —— widget 读投影看到 `'c1'`，任何读 `shellControllerProvider` 的代码看到 `null`。纪律：

- 两个投影文件的头注写明「本 provider 是 `ShellState` 的只读投影；**外壳级测试禁止 override 它**，一律用 `shellControllerProvider.overrideWith(() => ShellNavigator(initial: …))` 播种」。
- 新增 `test/quality/shell_projection_override_test.dart`：扫 `test/features/shell/**` 与 `test/app/app_routing_test.dart`，禁止 `currentCanvasIdProvider.overrideWith` / `activeProjectProvider.overrideWith`，失败信息直接给出正确写法。**纯画布组件测试目录不受限**（那正是杠杆的价值）。

### 5.4 退役

- `lib/core/di/current_screen.dart`（`AppScreen` + `currentScreenProvider`）—— 整文件删除
- `lib/features/gallery/providers/current_gallery_project.dart` —— 整文件删除，语义升格为 `activeProjectProvider`

零向后兼容：不留别名、不留转发。收口判据：`git grep -n "AppScreen\|currentScreenProvider\|currentGalleryProjectProvider"` 零命中。

---

## 6. 保活与焦点

### 6.1 保活机制

保活**只靠一件事**：元素留在树里。不能靠去掉 autoDispose（D3 跨画布隔离是刻意的）。

- **跨标签保留**：切标签不改 `canvasId`，`canvasTransformControllerProvider(c1)` 的 watcher 一直在 ⇒ 不 autoDispose ⇒ `TransformationController` 实例原样保留。
- **跨画布重置**：`canvasId` c1→c2 ⇒ family key 换 ⇒ c1 失去最后一个 watcher ⇒ `ref.onDispose(controller.dispose)`（`canvas_transform_controller.dart:22`）触发；c2 是全新 entry。

两者本来就同时成立。`canvas_shortcuts_test.dart:281-307` 的跨画布重置断言**一个字都不用改**。

> **禁止**用 `KeyedSubtree(key: ValueKey(canvasId))` 去重置全局非 family provider：旧子树拆掉、新子树同帧重新 watch 同一个 provider，Riverpod 的 autoDispose 是调度式的，dispose 任务跑之前被重新 listen 就直接续命，选中集**不会**被清。跨画布重置只能靠 family。

### 6.2 四个全局画布 provider 必须先 family 化

今天「跨画布选中不串味」是**偶然**的：靠切 `canvasId` 时 `nodesAsync` 回 loading ⇒ `_CanvasBody` 卸载 ⇒ 唯一 watcher 消失 ⇒ autoDispose 清空。`canvas_shortcuts_test.dart:285-293` 的注释自己承认这点（测试必须 `container.listen` 预热 c2 才能造出「无空档」）。任何预热出现（job listener invalidate / 会话恢复 / 将来任何缓存），A 的 nodeId 就带进 B，`deleteNodesWithUndo(canvasId: B, nodeIds: A的id)` 直接误删。

**若不先做这一步，V1 的「切标签选中集保留」断言恰恰是在为串味 bug 背书。**

改成 `AutoDispose*ProviderFamily<_, _, String>`（key = canvasId），与 `canvasTransformControllerProvider` 完全对称：

| provider | 现状 |
|---|---|
| `canvasSelectionControllerProvider` | 全局 `AutoDisposeNotifierProvider<_, Set<String>>`（`canvas_selection_controller.dart:10-13`） |
| `selectedEdgeControllerProvider` | 全局；残留 edgeId 会让新画布首次点击就连跨画布的边 |
| `linkModeControllerProvider` | 全局；残留 sourceNodeId 同理 |
| `canvasViewportSizeProvider` | 单个全局 `AutoDisposeNotifier<Size>` + `ref.keepAlive()`（`canvas_transform_controller.dart:27-45`） |

`canvasViewportSizeProvider` 的额外注意：`build()` 里的 `ref.keepAlive()` 在 family 上意味着**每个开过的 canvasId 都永久留一个 entry**，「与 transform 对称」这句话在 dispose 语义上并不成立。本 PR **保留** `keepAlive()`（原因不变：无人 watch 只有 read），把「entry 永不释放」记 `docs/BOARD.md` 债。

### 6.3 焦点四层

键盘派发规则：`FocusManager._handleKeyMessage`（`focus_manager.dart:2236-2261`）只沿 `primaryFocus` **及其 ancestors** 派发；`Shortcuts` 自身是 `Focus(canRequestFocus: false)`（`shortcuts.dart:1138-1146`），永远当不了 primaryFocus。所以画布能否吃到键完全取决于 `_focusNode` 是不是 primaryFocus 或其祖先。

**第 1 层 —— `CommandPaletteShortcuts`**（`command_palette_shortcuts.dart:23-35`）。不动。

**第 2 层 —— 外壳兜底 `_shellFocus`**，位置在第 1 层之内、外层 IndexedStack 之上（即 `ShellContentStack` 里）。`didUpdateWidget` 里只要 `(tab, overlay)` 任一变化就**无条件** post-frame `requestFocus()`。

> **千万别加 `if (!_shellFocus.hasFocus)` 守卫**：切换那一帧画布的 FocusNode 还没被 unfocus，`hasFocus` 仍为 true ⇒ 守卫跳过请求 ⇒ 焦点掉到 `ModalScope` 的 FocusScope（它在 `CommandPaletteShortcuts` 之**上**）⇒ **全 app 的 ⌘K 直接失效**。

顺序安全性来自**注册时机**：本回调在祖先重建时先注册（早），`CanvasShortcuts._claimFocus` 在后代 build 期间注册（晚），post-frame 队列 FIFO ⇒ 晚的赢 ⇒ 切回画布页时画布稳拿焦点。**这条是 load-bearing，写进注释。**

**第 3 层 —— `CanvasShortcuts` 新增 `required bool isActive`**

```dart
Focus(
  focusNode: _focusNode,
  skipTraversal: true,
  canRequestFocus: widget.isActive,
  descendantsAreFocusable: widget.isActive,   // 连 Inspector 的 TextField 一起排除
  child: widget.child,
)
```

- 变 false **不必**手动 unfocus：`focus_manager.dart:583-594` 在 `descendantsAreFocusable` 置 false 时自己会 `unfocus(previouslyFocusedChild)`。
- 变 true 时复焦**必须 post-frame**：隐藏期间 `canRequestFocus` 被祖先拉成 false（`focus_manager.dart:536`），同帧 `requestFocus()` 是彻底的 no-op 且不排队；要等这一帧的 `Focus.didUpdateWidget` 把开关拨回来。`ExcludeFocus` 文档（`focus_scope.dart:924-926`）明说重新可见**不会**自动复焦，所以这段 post-frame 是 V2 后半的唯一实现。

`isActive` 的计算全应用只有一处：`state.isTabVisible(ShellTab.canvas)` —— 一个谓词同时覆盖「切走标签」与「开浮层遮挡」两种不可见，V2 的两条用例走同一条代码路径而非两套特判。

> **不要**顺手把 `CanvasEscapeIntent`（`canvas_shortcuts.dart:173-175` 的裸 `CallbackAction`）统一成 `_EditingAwareAction` —— 会改变 Esc 在输入框里的既有语义。

**第 4 层 —— 框架自带冗余锁**：浮层打开时外层 IndexedStack 把整个标签宿主变 offstage ⇒ `Visibility(maintainFocusability: false)` ⇒ `ExcludeFocus(excluding: true)` ⇒ 画布焦点被框架强行收走。与 `isActive` 互为冗余，任一失效另一条仍守住 V2 前半。

### 6.4 跨标签保留 / 跨画布重置 对照

| 状态 | 跨标签（canvasId 不变） | 跨画布（canvasId 变） |
|---|---|---|
| 视口变换 | 保留 | 重置为初始相机 |
| 选中集 / 选中边 / 连线态 | 保留 | 清空（§6.2 family 化后） |
| 视口尺寸 | 保留 | 各自独立 |
| 泳道折叠 | 保留 | 各自独立（本来就是 family） |
| 画廊筛选 | 保留 | 换项目时复位 |
| 画廊滚动 | 保留 | 随 State 重建复位 |

---

## 7. 保活宿主与浮层

### 7.1 `ShellKeepAliveHost`

两条不变量，缺一 V4 就塌（在文件头注写明，并点名各自对应的测试文件）：

1. **Key 落在槽位上** —— 五个 `shellTabBody-*` 恒在树里，无论是否物化 ⇒ 保活断言锚在稳定 Key 上，不会因「画廊未选项目所以 `GalleryScreen` 不 mount」而假红。
2. **内容懒物化、物化后永不换回占位** ⇒ `find.byType(GalleryScreen, skipOffstage: false)` 在从未访问过画廊的用例里**真的** `findsNothing`。**这是 V4 成立的唯一物理前提。**

标签构造走 **exhaustive switch 函数** `Widget Function(BuildContext, ShellTab)`，不用 `Map<ShellTab, WidgetBuilder>` + `builders[t]!` —— 加第六个标签时编译器在 switch 上报错，Map 版本是运行时崩溃。

构造器每帧重新调用（不缓存 Widget 实例），`isActive` 靠这条路径逐帧下传。

### 7.2 `InkShellTabBar`

落 `lib/theme/components/`（`no_inline_styles_test.dart:27-30` 只对 `lib/theme/components/` 与 `lib/theme/primitives/` 豁免 hex / `Colors.*` / `BoxShadow`；但裸 `fontSize` / `EdgeInsets` / `BorderRadius` 数字全仓适用，一律走 `InkSpacing.*` / `InkRadius.*` / `context.inkTypography.*`）。

- 选中态：`fg1` + 500 字重 + 2px 琥珀下边框 + `surface5` 底
- 未选中：`fg3`
- **窄屏退化**：阈值取 `LayoutBuilder` 拿到的**实际约束**而非 `MediaQuery.size`（这样 textScale 放大也会先触发退化）。阈值按五组标签在 en / zh 下的**实测渲染宽度**定，不拍脑袋。退化时 chip 收成纯图标 + `Tooltip`，且**选中项必须同时给 `surface5` 底** —— 纯图标条上只靠琥珀下边框太弱。
- 960×600 + textScale 1.3 下 `tester.takeException()` 必须为 null。

### 7.3 设置 / 示例浮层

外层 `IndexedStack` 的第 2 槽，`overlay == null` 时是 `const SizedBox.shrink()` —— **关掉即销毁，浮层不保活**。因此 `find.byKey('shellOverlay-settings', skipOffstage: false) → findsNothing` 是真断言，`StoragePathSection` 的 pending frame / ffmpeg 探测 / api-key 探测不会在后台常驻。

浮层刻意在 chrome **之下**、内容区**之内**：设置因此继承外壳的 `DragToMoveArea` 与三个窗口按钮 —— 这正是 Windows 无边框 bug 的修法（D6）。标签条在浮层打开时仍可见、仍可点（点任一标签 = `goTab` = 关浮层 + 切标签）。

`SettingsScreen` **保留自己的 Scaffold**（因有外壳 Scaffold 祖先而变 nested），只把 `AppBar`(56) 换成 `InkToolBar`(44)（D10）。`SettingsBackButton` **保留 widget 名与 key**（`settings_screen_test.dart:14-29` 靠它），只把行为改成 `nav.closeOverlay()`。

`_EditorDialog`（`custom_providers_section.dart:388`，硬编码 width 420、走 root navigator）**不动**：设置不再是路由，root 栈里只有它自己，能弹能关。

### 7.4 与 `backup_section` 的 `rootNavigator` 兜底

`backup_section.dart:199` 在第一个 await 前捕获 `Navigator.of(context, rootNavigator: true)`，`:264-273` 的 `finally` 里优先按 barrier 自身 route 收，**barrierCtx 为 null 或 unmounted 时兜底 `navigator.pop()`**。

- 设置改成外壳内的一层（非 root 路由）之后，root 栈里只剩进度 barrier，这个兜底**变得更安全** —— 原本设置若是 root 路由，兜底有机会在还原中途把设置页本身 pop 掉。**这正是 D4 的理由。**
- **但兜底本身仍要改**：走 else 分支恰恰是 barrier **没进栈**的情况，此时 root 栈里只有 `MaterialApp` 的 home 路由，裸 `pop()` 会去弹它。改成 `} else if (navigator.canPop()) { navigator.pop(); }`。
- `:202-204` 三个 notifier 预捕获 → 一个 `final nav = ref.read(shellControllerProvider.notifier);`；`:277-279` 三行清场 → `nav.resetSession()`（内含 `invalidate(galleryControllerProvider)` 整族失效 —— 保活后画廊标签会捧着还原前那个库的产物继续显示，且 `activeProject.id` 可能在新库里已不存在）。

### 7.5 Esc（D11，刻意不做）

本 PR **不给浮层加 Esc 关闭**。理由：需要在外壳层新增 `CallbackShortcuts` 层，且会与设置内部 `_EditorDialog` 的 Flutter 默认 `DismissIntent` 竞争。关闭途径有三条：工具条返回键、点任一标签、⌘K → Back to Studio。

**BOARD 债条目必须写明「Esc 不可用是刻意的，不是遗漏」**，并附上后果：下一个人当 bug 顺手「修」掉之后，在设置里按 Esc 会连编辑框带浮层一起关。补做时必须同时加一条「`_EditorDialog` 打开时 Esc 先关对话框、不关浮层」的竞争用例。

### 7.6 `app_toast_messenger_test.dart:69` 哨兵

`tester.widget<MaterialApp>(find.byType(MaterialApp))` 假定全树唯一 MaterialApp。本设计不新增任何 MaterialApp（浮层是 widget 层不是路由），哨兵继续绿 —— **不要放宽它**，它是「有人把设置误做成嵌套 MaterialApp / root 路由」的现成警报。

---

## 8. 五个标签

| 标签 | 内容 | 空态条件 |
|---|---|---|
| studio | `StudioHomeScreen`（剥掉 `StudioTopChrome`） | 无 |
| canvas | `CanvasScreen(isVisible:)` | `canvasId == null` |
| sequence | 空态 + 按钮 → `showSequencePreviewDialog` | 三态，见 §8.2 |
| gallery | `GalleryScreen(projectId:, projectName:)` | `project == null` |
| export | 空态 + 按钮 → `showExportVideoDialog` | 三态，见 §8.2 |

`ShellEmptyState`（`lib/features/shell/widgets/shell_empty_state.dart`）沿用画廊空态的视觉语汇（`gallery_screen.dart:272-317`：72 圆形 `surface3` 底 + 图标 + 标题 + 副标题），加一个可选 `InkGhostButton`。四处复用。

### 8.1 画布空态（D12）

`canvasId == null` 时显示的**不是「出错了」，而是「从 Studio 选一个画布」**，并带一个直接跳 Studio 标签的按钮。因为本 PR 不提供「关闭当前画布」，这个空态在正常使用中只在首启/还原后出现 —— 但它必须是可行动的引导，用户不能觉得卡死。

> 该空态在今天的生产代码里**根本不可达**（`app.dart` 从不以 null canvasId 构建 `CanvasScreen`），本 PR 让它第一次真正可达。

### 8.2 序列 / 导出：过渡态的确切形状

**对话框一个字符都不改**：`showSequencePreviewDialog` / `showExportVideoDialog` 保持私有、`barrierDismissible: false` 不变。

理由（D3）：`SequencePreviewContent` 从 `initState` 持有 media_kit `Player` 到 `dispose` 且自动播放，抬成常驻视图会在后台标签里一直播；`_ExportVideoDialog` 的 barrier 是导出中的安全门，变成常驻视图后用户能在导出跑一半时切走标签，是功能回归。这两件各自留给 README 第 5、6 步单独设计。

三态（都必须真实可点进入，不是灰按钮一片）：

1. `canvasId == null` → 空态 + 按钮**禁用** + `shellNeedsCanvas` 说明行。**此分支不 watch 任何仓储** —— 硬约束：`app_routing_test` 的 studio/settings 两例只密封了 `workspaceProjectsProvider`，序列/导出标签一旦 eager 碰 canvas/node/edge 仓储就会去起真内嵌 PG（该文件 `:38-40`、`:96` 的注释自己点名：真 PG / dart:io 会让覆盖率收集永挂）。懒物化已挡住大半，但空态分支仍须自证不碰仓储 ⇒ 配一条「用会抛的 fake 仓储 override，被碰到就红」的用例。
2. `canvasId != null` 但不满足可用性（序列：无 narrative 边；导出：无可导出 video）→ 空态 + 按钮禁用 + 复用既有的 `sequencePreviewDisabledTooltip` / `exportVideoDisabledTooltip` 作为解释文案。
3. 满足条件 → 按钮可点 → 弹既有对话框。

**可用性判据原样搬运**：`canvas_top_chrome.dart` 里 `_SequencePreviewButton` 的 `_hasNarrative` 与 `_ExportVideoButton` 的 `_canExport` 两条纯函数路径整体迁到 `sequence_tab.dart` / `export_tab.dart`，不重写。`canvas_top_chrome_export_test.dart` / `_sequence_test.dart` 的禁用判据覆盖**整体搬**进 `shell_tabs_empty_state_test.dart` —— **不许删，只许搬**，PR 描述里点名这两个文件的测试数量前后一致。

**projectId 来源**：`ShellState.project!.id`，不再走 `nodes.first.projectId` 的静默 return（`canvas_top_chrome.dart:257,314` / `command_actions.dart:144-145` 今天在它为 null 时静默返回）。`openCanvas` 的 `withProject` 在 `open_canvas.dart` / `canvas_bootstrap_controller.dart` / `restore_last_session.dart` 三条路径上播种。

### 8.3 画廊标签的三个 bug

**Bug 3（今天就存在，独立成 commit 先行合入）** —— autoDispose 的筛选器只在有人 watch 时活着，而 `_GalleryContent` 在 loading / error / 空态三个分支里**不存在**（`gallery_screen.dart:43-52`），error 重试与 data→空 转换会静默复位筛选（表现为「偶发丢筛选」，最难查）。
→ 在 `GalleryScreen` 层补一条 `ref.watch(galleryFilterProvider.select((f) => f.isActive))`，天然理由是驱动工具条上的「筛选生效中 / 清除」chip —— 顺带把今天的死代码 `GalleryFilter.isActive`（`gallery_filter.dart:21-22`，lib 里零使用）用起来。
> 该 bug **不依赖标签模型也不依赖分键**，因此单独一个 commit（T4a），带一条今天就能复现的红测试。
> 此时 `galleryFilterProvider` 还是全局形态，watch 写法不带 key；T4b 分键后同步改成 `galleryFilterProvider(pid).select(...)`。
> 若这条红测试在今天的代码上**无法复现**，说明「loading/error/空态三分支无 watcher」的前提判断有误 —— 此时不得把测试改成绿的，应先重新核实 `gallery_screen.dart:43-52` 的分支结构再决定 T4a 是否成立。

**Bug 1 —— `galleryFilterProvider` 未按 projectId 分键**（`gallery_filter.dart:62` 全局 `StateProvider.autoDispose`）。今天不可复现（退出画廊即卸载复位），保活恰好掀开盖子：项目 A 选画布筛选 → 切 Studio 开项目 B → 回画廊标签 → `filterGalleryItems` 拿 A 的 canvasId 比 B 的项，零命中 → `_GalleryNoMatchState`；而**三个筛选控件都显示「未筛选」**（`gallery_screen.dart:157-159` 的失配回落把下拉显示成 All），界面在撒谎。
→ 改 `StateProvider.autoDispose.family<GalleryFilter, String>`（key = projectId）。

**Bug 2 —— 搜索框脱同步**：`_searchCtrl` 活在 `_GalleryContentState`（`gallery_screen.dart:98`），是 `onChanged` 的唯一输入源，从不从 `filter.query` 读回。
→ `initState` 从 `ref.read(galleryFilterProvider(widget.projectId)).query` 播种并把 selection 收到末尾；`_GalleryContent` 加 `key: ValueKey(projectId)` 作保险。

**chrome 剥离**：`_GalleryTopChrome`（`gallery_screen.dart:60-84`）删除，换 `InkToolBar(title: 项目名 + 产物计数, actions: [筛选生效中 chip, 「更换项目」ghost → goTab(studio)])`。标签模型下「返回」这个动作不存在了。

**`GalleryScreen` 的两个必填构造参保留不动**：`gallery_screen_test.dart` 的 6 个 pump 点与 `empty_states_golden_test.dart:138` 都直接 pump 它，改签名会引发不必要的连锁。`GalleryTab` 是薄壳：读 `activeProjectProvider`、处理 null 空态、向下透传。

**激活时刷新（与 V1 不冲突）**：`ref.invalidate` 在 riverpod 2.6.1 里走 refresh 而非 reload（`common.dart:585-586`），`when` 默认 `skipLoadingOnRefresh: true`（`common.dart:673-674,728-729`）⇒ 不走 loading 分支，旧网格原地留着，`_GalleryContent` 不卸载 ⇒ 滚动位置 / 搜索框 / 筛选全保。

代价是查询量（`gallery_controller.dart:41-43` 对每个画布并发 `listByCanvas`，一次刷新 = N+2 次查询），故加**粗粒度**脏标记 `galleryDirtyProvider`（D13）：`jobsRegistryProvider` 里任一 job 转 `JobSucceeded` → 置脏；`GalleryTab` 在「不可见→可见」且脏时才 invalidate，然后清脏。按 projectId 分别置脏留到有实际卡顿反馈时再做。

> **警告写进代码注释**：任何人给 `gallery_screen.dart:43-52` 的 `when` 加 `skipLoadingOnRefresh: false`，V1 的滚动/搜索框/筛选三条会同时静默失效且没有测试会红 ⇒ 配一条「invalidate 后 `ScrollPosition.pixels` 不变」的断言钉死。

### 8.4 Studio 标签与面包屑

`StudioHomeScreen` 的 `Column` 去掉第一件 `StudioTopChrome`（`studio_home_screen.dart:55-59`）；`studio_top_chrome.dart` 整文件删除，mini logo / 面包屑逻辑并入 `ShellChrome` / `ShellBreadcrumb`，⚙ 上移到 chrome trailing。

**同 commit 必须处理**：`test/features/studio/widgets/studio_top_chrome_test.dart` 与 `test/features/studio/studio_home_test.dart` 都引用它 —— 谁删这个文件，那个任务当场 `flutter analyze lib test` 红。

`ShellBreadcrumb` 必须**条件 watch**，避免炸开 boot 测试的密封面：`canvasId == null` 时只显示项目名、**不碰 `canvasRepository`**；非 null 时才 watch `currentCanvasNameProvider`。

---

## 9. Token（D5）

`lib/theme/tokens.dart` 的 `InkColors._` 私有构造由 28 槽增至 30，三个工厂各补两行。

```dart
final Color surface5;      // 最高抬升面：激活标签 chip 底 / 列表选中行底
final Color borderStrong;  // 结构性强分隔线：chrome ↔ 标签条 ↔ 内容 三段之间的硬边界
```

| 槽位 | dark (Amber Noir) | light (Paper Ivory) | highContrast |
|---|---|---|---|
| `surface5` | `Color(0xFF36302A)` | `Color(0xFFD9CDB6)` | `Color(0xFF2B241C)` |
| `borderStrong` | `Color(0xFF0D0A08)` | `Color(0xFF9A8B70)` | `Color(0xFFFFFFFF)` |

推导（对着 `tokens.dart:79-180` 的实际 ramp 核过）：

- **dark** ramp `0B0908 → 100C0A → 15110E → 1C1814 → 2A2520`。`surface5 = 36302A` 延续这条暖褐爬升，与设计稿中性 `#2E2E2E` 同明度但带暖偏 —— 直接照搬中性灰会在琥珀金 accent 旁边泛青。`borderStrong = 0D0A08` 比 `surfaceCanvas(0B0908)` 略亮一丝、比任何 surface 都暗，是一条「刻进去的缝」而非描边。
- **light** 的面是越活跃越压暗（`surfaceCanvas F5EFE3 / s1 FAF5EB / s2 FFFAF0 / s3 EFE7D5 / s4 E5DBC4`，**注意这条 ramp 本身不单调**）。`surface5 = D9CDB6` 是 `E5DBC4` 再压一档。`borderStrong = 9A8B70` 比 `border` 与 `borderHover` 都深；**刻意不取 `8A7E70`**（那是 `fg3` 的值，会被误读为文字）。
- **highContrast** ramp `000000 / 000000 / 0A0807 / 15110E / 201A14` → `surface5 = 2B241C`（比 surface4 更亮，方向正确）。HC 的 `border` 本来就是纯白（`tokens.dart:174`），「强」分隔线不可能比纯白更强，故 `borderStrong = FFFFFF` 与 `border` 同值 —— **这是刻意的、不是遗漏**，在字段注释里写明。

`InkPalette` 不需要新增常量（两者都不在 `runApp` 之前使用）。

### 9.1 `tokens_test.dart` 必补

现有测试只断「槽位存在」，写反了照样绿。必须补三类：

1. **方向性不变量** —— 暗色 / HC 下 `surface5` 更亮，浅色下更暗。
2. **防复制** —— `surface5 != surface4`，三变体各一条。有人为省事把 surface5 复制成 surface4，激活标签与非激活标签视觉上不可区分，而所有功能测试照绿。
3. **对比率** —— 激活标签的 label 直接画在 `surface5` 上，是新增的彩底前景组合：dark/light `wcagContrast(surface5, fg1) >= 4.5`，HC `>= 7.0`（用现成的 `test/theme/wcag.dart`）。

另需把 `:29-46` 与 `:105-127` 的全槽位清单与测试名里的数字同步更新（否则名实不符）。`onAccent` / `onDanger` 的既有 AA 断言不受影响。

### 9.2 消费约束

- `surface5` 只用于「激活 / 选中」的**底**，不做卡片底（那是 surface2/surface3）。
- `borderStrong` 只用于外壳级分区（chrome 下沿、标签条下沿、工具条下沿）；组件内部细线继续用 `borderSubtle`。
- 高度用具名 `static const double`，与 `ink_window_chrome.dart:28` 的 `height: 56` 同例（`SizedBox.height` 不在无内联样式规则覆盖面内）。

---

## 10. 会话恢复（D9）

`AppPreferences` 新增 `bool shellKeepLastCanvas`，默认 `true`。

> **`fromMap` 缺省必须退 `true`**，与 `app_preferences.dart:158` 现成的 `updateCheckEnabled: uce is bool ? uce : true` 对齐。写反的后果是所有老用户（`preferences.json` 无此键）升级后会话恢复静默失效，且**没有任何现有测试会红** ⇒ 必须补一条「空 map 解析出 `true`」的断言。

设置页「常规」区出开关，文案见 §11。

恢复守卫（`restore_last_session.dart:40-47`）改判：

```dart
if (!prefs.current.shellKeepLastCanvas) return;
if (!ref.read(shellControllerProvider).isPristine) return;   // canvasId==null && overlay==null && tab==studio
```

`tab` 默认就是 `studio`，所以用户在 PG 启动窗口期内主动切到任何标签，`isPristine` 自然为假，**不需要额外的布尔闩**。这堵住了旧判据在标签模型下的两个缺口：第三个子句 `currentScreen != studio` 在标签模型下会永远为真；而设置改浮层后旧判据会**保持通过却行为回归**（债 145，已翻车过一次，见 BOARD PR-8 / #213）。

两处 `clearLastCanvas` 直写（`canvas_top_chrome.dart:39-45`、`command_actions.dart:157-162`）随文件删除/改写一并消失。

---

## 11. i18n

全部走 `shell*` / `shellTab*` 前缀。en 是真相源，zh 同 commit 补齐；**每个改 ARB 的任务各自跑 `flutter gen-l10n` 并把 `lib/l10n/generated/` 一起提交** —— generated 陈旧 `flutter test` 抓不到，只有 `flutter analyze lib test` 会红。

**新增 24 条**（标签名 ×5、面包屑、关闭、去 Studio、画布空态 ×2、画廊 ×5、序列 ×3、导出 ×3、`shellNeedsCanvas`、恢复开关 ×2）。其中 `shellGalleryItemCount` 需要 `@` metadata 块声明 `{count}` 占位符（两个 ARB 都要写，否则 gen-l10n 生成的签名不带参）。

**退役 7 条死 key**（连 `@` metadata 一起删）：`studioBreadcrumbAll`、`canvasBreadcrumbProject`、`canvasBreadcrumbCanvas`、`canvasBackToStudio`、`galleryBreadcrumb`、`galleryBackTooltip`、`showcaseBackTooltip`。

> `arb_hygiene_test.dart:24-40` 只查 en/zh key 集合一致 + `workspace*` 前缀，**死 key 一律静默放过**，违反零向后兼容。收口判据是对这 7 个 key 的 `grep` 零命中。

**保留不动**（易误删，已逐条核过使用点）：`studioOpenSettings`（`command_actions.dart:178`、`library_sidebar.dart:266` 仍在用，外壳 ⚙ 直接复用，文案一字未变，退役它纯 churn）、`commandBackToStudio`（label 不变，只是 run 语义改为 `goTab(studio)`）、`sequencePreviewTooltip` / `sequencePreviewDisabledTooltip` / `exportVideoTooltip` / `exportVideoDisabledTooltip`、`settingsTitle` / `showcaseTitle` / `showcaseSubtitle`、`windowMinimize` / `windowMaximize` / `windowClose`、`canvasDefaultName` / `studioDefaultName`、画廊既有的 `Clear filters` / 空态 / 无命中态 key。

---

## 12. 测试策略

### 12.1 V4 不假绿的物理前提

`find.byType` 默认 `skipOffstage: true`。V4 的成立**不靠断言写法**，靠 §7.1 的两条不变量：槽位 Key 恒在、内容懒物化且物化后永不换回占位。

V4 还必须跑一次**反向变异**：把断言改回默认 `skipOffstage`（即 true）并确认它**不红**，以此证明 `skipOffstage: false` 是 load-bearing 的。只做正向变异回答不了用户问的那个问题。

### 12.2 变异清单（逐条跑红再删）

| 变异 | 应跳的断言 |
|---|---|
| 宿主 eager 建五子 | V4：从未访问过的标签体应 `findsNothing` |
| `IndexedStack` 换 `Stack` | V4 / 点穿 |
| children 顺序调乱 | `shell_tab_order_test.dart` |
| 切标签时卸载 | V1 |
| **把 chrome 加回画布子树** | **V3a**（`find.byType(InkWindowChrome, skipOffstage: false)` 唯一） |
| **去掉外壳根 Scaffold** | **V3b**（SnackBar 单渲染） |
| `_shellFocus` 加 `hasFocus` 守卫 | V2 的 ⌘K 一例 |
| `canRequestFocus` 改回常量 true | V2 的 Delete 一例 |
| `surface5` 复制成 `surface4` | tokens 防复制断言 |
| 默认 `skipOffstage` 写法 | **必须不红**（反向变异） |

> V3a / V3b 必须分开：只测 chrome 唯一的话，「去掉外壳根 Scaffold」这个变异会照绿。

### 12.3 新 harness

`pumpInkApp`（`test/_harness/test_app.dart:17`）零外壳感知，需要新增 `pumpInkShell(tester, {initial, overrides})` + `expectShellSurface(...)`。harness README 禁止手搓 `pumpWidget(MaterialApp(...))`。

两条硬纪律：

- `orphanReapStartupProvider` **必须与 `pgMigratedPoolProvider` 分开单独 override** —— 前者直接 await `nodeRepositoryProvider`，不吃 pool 封印（`app_routing_test.dart:155-157` 的注释已经踩过这个坑）。
- 全外壳测试**禁止 `pumpAndSettle`**，只固定次数 `pump()`（`StoragePathSection` 留 pending frame；`app_routing_test.dart:136-137` 是现成先例）。

### 12.4 会保持通过但行为已回归的测试（最危险的一类）

- `restore_last_session_test.dart:125-160` 三例：前提是「seed `currentScreen=settings` 或 gallery 目标 = 用户已导航」。设置改浮层后这两个 provider 不再被写，测试会**继续通过而行为回归** ⇒ 必须按 §10 的新判据重写，不是微调。
- `app_routing_test.dart` 五例：若用 Offstage 实现，`skipOffstage: true` 的默认值会让 `findsNothing` 恒真 ⇒ 必须改成显式 `skipOffstage: false` 并配反向变异。

### 12.5 golden

重铸 **4 张**：`studio_empty` / `studio_error` / `gallery_empty` / `settings_screen`。

**`canvas_empty.png` 不在清单内** —— 它 pump 的是裸 `const CanvasView()`（`empty_states_golden_test.dart:120-134`），整棵子树无 chrome，像素不变；重铸它会把「它为什么变了」的信号永久抹掉。

`studio_empty` / `studio_error` 必须在列：`studio_home_screen.dart:52-59` 的 `Column` 第一件就是 `StudioTopChrome`，而 `empty_states_golden_test.dart:88/106` 直接 pump `const StudioHomeScreen()`。漏列会因 `ci.yml:136`（有基线但零 golden 跑过 → exit 1）变成一次无人预期的 CI 红。

> **不要**给画廊 golden 用例加 `activeProjectProvider` override：该用例走 `GalleryScreen` 的两个必填构造参（`empty_states_golden_test.dart:136-154`），根本不读任何项目上下文 provider。

golden 只能在 CI ubuntu 的 `update-goldens` workflow 铸线，本地跑必假红。

---

## 13. 任务序列与依赖

```
T1 焦点安全 ────┐
T2 画布态分族 ──┤
T3 两个 token ──┼──→ T5 ShellState ──→ T6 三 provider 退役 ──→ T7 外壳骨架 ──┬──→ T8  V1+V2 端到端
T4a 画廊 bug3 ──┤                                                           ├──→ T9  画廊标签真身
T4b 分键+播种 ──┘                                                           ├──→ T10 序列/导出标签
                                                                            └──→ T11 恢复+开关 → T12 收口 → T13 文档+golden
```

- **T1–T4b 五路并行**，互不依赖。T1 优先级最高（安全问题）。T4a 独立成 commit、可先行合入（今天就存在的 bug）。
- **T6 是唯一不可再分的原子 commit**（约 20 文件，全机械），但有**自证闸门**：这一步 `app.dart` 仍然只 build 一个 body 且**判序保持 canvasId-first**，渲染逐帧等价，`app_routing_test` 那 5 条断言**一字不改**，只换 override 写法。**若这一步需要改断言，说明改多了，回退。** V4 刻意留到 T7。
  > 明确否决 overlay-first 的 exhaustive switch：它反转了 `app.dart:158` 今天的 canvasId 优先级，第 5 例（canvasId + showcase）必红，会把自证闸门变成噪声。
- T7 之后四条支线可并行。

每个任务的完成判据（两条都必须全绿）：

```bash
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat analyze lib test
NO_PROXY=127.0.0.1,localhost /c/Users/Kerro/flutter/bin/flutter.bat test --exclude-tags golden
```

TDD 纪律：每任务先写**必红**的测试、跑一次确认它红、再写实现、再跑绿。

---

## 14. 非目标

- 序列 / 导出标签装真内容（常驻播放视图、常驻导出面板）—— README 第 5、6 步。
- 同时保活多个 canvasId。外壳不变量是「同一时刻只保活一个 canvasId」，写进 `ink_shell.dart` 头注。
- `canvasId` 下沉为构造参数。七个画布 widget 仍从全局投影重取；保活后它们依然一致（同一 provider、同帧同一值）。单独排一张重构卡。
- 项目改名后面包屑 / 画廊标题显示旧名（`activeProject.name` 是快照，与今天 `currentGalleryProjectProvider` 行为一致）。
- `canvasViewportSizeProvider` 的 family + keepAlive 导致每个开过的 canvasId 永久留一个 entry —— 记 BOARD 债。
- 浮层的 Esc 关闭 —— 记 BOARD 债，条目须写明「刻意不做」（§7.5）。
- 「关闭当前画布」动作 —— 后续补卡。
- 按 projectId 分别置脏的细粒度画廊刷新 —— 有实际卡顿反馈时再做。
- 撤掉 `CanvasScreen` / `SettingsScreen` 自带的 Scaffold 与 FAB 重新托管（§4.3 已说明为何不必）。
- 命令面板的跨实体搜索（B5）与 `≤6 条` 上限 —— 本 PR 只改三个动作的语义。
- 设计稿的中性灰配色 —— 已按 D5 改为暖色 ramp。
